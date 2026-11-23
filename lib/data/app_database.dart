import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../models/finance_models.dart';

class AppDatabase {
  AppDatabase({this.customPath, this.customFactory});

  final String? customPath;
  final DatabaseFactory? customFactory;

  static const _dbName = 'rezylife_finance.db';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    DatabaseFactory factory;
    if (customFactory != null) {
      factory = customFactory!;
    } else if (!kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    } else {
      factory = databaseFactory;
    }

    final dbPath = customPath ?? p.join(await factory.getDatabasesPath(), _dbName);

    return factory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: _dbVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: _onCreate,
      ),
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE wallets (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        balance INTEGER NOT NULL DEFAULT 0,
        color_value INTEGER NOT NULL,
        icon_key TEXT NOT NULL,
        package_name TEXT,
        sort_order INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        amount INTEGER NOT NULL,
        category_id TEXT NOT NULL,
        wallet_id TEXT NOT NULL,
        to_wallet_id TEXT,
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'manual',
        raw_notif_hash TEXT UNIQUE,
        FOREIGN KEY (wallet_id) REFERENCES wallets(id),
        FOREIGN KEY (to_wallet_id) REFERENCES wallets(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE debts (
        id TEXT PRIMARY KEY,
        direction TEXT NOT NULL,
        person_name TEXT NOT NULL,
        amount INTEGER NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        created_at INTEGER NOT NULL,
        is_settled INTEGER NOT NULL DEFAULT 0,
        settled_at INTEGER,
        linked_transaction_id TEXT,
        FOREIGN KEY (linked_transaction_id) REFERENCES transactions(id) ON DELETE SET NULL
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_tx_created ON transactions (created_at DESC)',
    );
    await db.execute(
      'CREATE INDEX idx_tx_wallet ON transactions (wallet_id)',
    );
    await db.execute(
      'CREATE INDEX idx_debts_status ON debts (is_settled, created_at DESC)',
    );

    final batch = db.batch();
    for (final wallet in kDefaultWallets) {
      batch.insert('wallets', wallet.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<List<Wallet>> getWallets() async {
    final db = await database;
    final rows = await db.query('wallets', orderBy: 'sort_order ASC');
    return rows.map(Wallet.fromMap).toList();
  }

  Future<List<TransactionItem>> getTransactions() async {
    final db = await database;
    final rows = await db.query('transactions', orderBy: 'created_at DESC');
    return rows.map(TransactionItem.fromMap).toList();
  }

  Future<List<DebtItem>> getDebts() async {
    final db = await database;
    final rows = await db.query(
      'debts',
      orderBy: 'is_settled ASC, created_at DESC',
    );
    return rows.map(DebtItem.fromMap).toList();
  }

  Future<void> insertWallet(Wallet wallet) async {
    final name = wallet.name.trim();
    if (name.isEmpty) {
      throw ArgumentError('Nama dompet tidak boleh kosong.');
    }
    final db = await database;
    await db.insert('wallets', wallet.copyWith(name: name).toMap());
  }

  Future<void> updateWalletBalance(String walletId, int newBalance) async {
    final db = await database;
    await db.update(
      'wallets',
      {'balance': newBalance},
      where: 'id = ?',
      whereArgs: [walletId],
    );
  }

  Future<void> insertTransaction(TransactionItem tx) async {
    _validateTransaction(tx);
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('transactions', tx.toMap());
      await _applyBalanceDelta(txn, tx, multiplier: 1);
    });
  }

  /// Atomically inserts an auto-captured notification transaction only if its
  /// [rawNotifHash] has not been recorded yet. Returns true when inserted.
  Future<bool> insertTransactionIfUnique(TransactionItem tx) async {
    _validateTransaction(tx);
    final db = await database;
    var inserted = false;
    await db.transaction((txn) async {
      if (tx.rawNotifHash != null) {
        final existing = await txn.query(
          'transactions',
          columns: ['id'],
          where: 'raw_notif_hash = ?',
          whereArgs: [tx.rawNotifHash],
          limit: 1,
        );
        if (existing.isNotEmpty) return;
      }
      await txn.insert('transactions', tx.toMap());
      await _applyBalanceDelta(txn, tx, multiplier: 1);
      inserted = true;
    });
    return inserted;
  }

  Future<void> updateTransaction(
    TransactionItem previous,
    TransactionItem updated,
  ) async {
    _validateTransaction(updated);
    final db = await database;
    await db.transaction((txn) async {
      await _applyBalanceDelta(txn, previous, multiplier: -1);
      await txn.update(
        'transactions',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [updated.id],
      );
      await _applyBalanceDelta(txn, updated, multiplier: 1);
    });
  }

  Future<void> deleteTransaction(TransactionItem tx) async {
    final db = await database;
    await db.transaction((txn) async {
      final deleted = await txn.delete(
        'transactions',
        where: 'id = ?',
        whereArgs: [tx.id],
      );
      if (deleted > 0) {
        await _applyBalanceDelta(txn, tx, multiplier: -1);
      }
    });
  }

  Future<void> insertDebt(
    DebtItem debt, {
    String? walletId,
    String? newTransactionId,
  }) async {
    if (debt.personName.trim().isEmpty) {
      throw ArgumentError('Nama teman tidak boleh kosong.');
    }
    if (debt.amount <= 0) {
      throw ArgumentError('Nominal harus lebih dari Rp0.');
    }
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert('debts', debt.toMap());
      if (walletId != null && newTransactionId != null) {
        final isReceivable = debt.direction == DebtDirection.receivable;
        final tx = TransactionItem(
          id: newTransactionId,
          type: isReceivable ? TransactionType.expense : TransactionType.income,
          amount: debt.amount,
          categoryId: isReceivable ? 'debt_paid' : 'debt_repaid',
          walletId: walletId,
          description: isReceivable
              ? 'Talangin ${debt.personName}${debt.description.isNotEmpty ? ' (${debt.description})' : ''}'
              : 'Pinjam dari ${debt.personName}${debt.description.isNotEmpty ? ' (${debt.description})' : ''}',
          createdAt: debt.createdAt,
        );
        await txn.insert('transactions', tx.toMap());
        await _applyBalanceDelta(txn, tx, multiplier: 1);
      }
    });
  }

  Future<void> deleteDebt(String debtId) async {
    final db = await database;
    await db.delete('debts', where: 'id = ?', whereArgs: [debtId]);
  }

  /// Marks a debt settled and optionally posts the cash movement to [walletId].
  Future<TransactionItem?> settleDebt(
    DebtItem debt, {
    String? walletId,
    required String newTransactionId,
  }) async {
    if (debt.isSettled) return null;
    final db = await database;
    final now = DateTime.now();
    TransactionItem? linkedTx;

    await db.transaction((txn) async {
      if (walletId != null) {
        final isReceivable = debt.direction == DebtDirection.receivable;
        linkedTx = TransactionItem(
          id: newTransactionId,
          type: isReceivable ? TransactionType.income : TransactionType.expense,
          amount: debt.amount,
          categoryId: isReceivable ? 'debt_repaid' : 'debt_paid',
          walletId: walletId,
          description: isReceivable
              ? 'Pelunasan dari ${debt.personName}${debt.description.isNotEmpty ? ' (${debt.description})' : ''}'
              : 'Bayar hutang ke ${debt.personName}${debt.description.isNotEmpty ? ' (${debt.description})' : ''}',
          createdAt: now,
        );
        await txn.insert('transactions', linkedTx!.toMap());
        await _applyBalanceDelta(txn, linkedTx!, multiplier: 1);
      }

      await txn.update(
        'debts',
        {
          'is_settled': 1,
          'settled_at': now.millisecondsSinceEpoch,
          'linked_transaction_id': linkedTx?.id,
        },
        where: 'id = ?',
        whereArgs: [debt.id],
      );
    });

    return linkedTx;
  }

  Future<void> unsettleDebt(DebtItem debt) async {
    if (!debt.isSettled) return;
    final db = await database;

    await db.transaction((txn) async {
      await txn.update(
        'debts',
        {
          'is_settled': 0,
          'settled_at': null,
          'linked_transaction_id': null,
        },
        where: 'id = ?',
        whereArgs: [debt.id],
      );

      if (debt.linkedTransactionId != null) {
        final rows = await txn.query(
          'transactions',
          where: 'id = ?',
          whereArgs: [debt.linkedTransactionId],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          final linked = TransactionItem.fromMap(rows.first);
          await txn.delete(
            'transactions',
            where: 'id = ?',
            whereArgs: [linked.id],
          );
          await _applyBalanceDelta(txn, linked, multiplier: -1);
        }
      }
    });
  }

  Future<void> _applyBalanceDelta(
    Transaction txn,
    TransactionItem tx, {
    required int multiplier,
  }) async {
    final signedAmount = tx.amount * multiplier;
    switch (tx.type) {
      case TransactionType.income:
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance + ? WHERE id = ?',
          [signedAmount, tx.walletId],
        );
      case TransactionType.expense:
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance - ? WHERE id = ?',
          [signedAmount, tx.walletId],
        );
      case TransactionType.transfer:
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance - ? WHERE id = ?',
          [signedAmount, tx.walletId],
        );
        await txn.rawUpdate(
          'UPDATE wallets SET balance = balance + ? WHERE id = ?',
          [signedAmount, tx.toWalletId],
        );
    }
  }

  void _validateTransaction(TransactionItem tx) {
    if (tx.amount <= 0) {
      throw ArgumentError('Nominal transaksi harus lebih dari Rp0.');
    }
    if (tx.type == TransactionType.transfer) {
      if (tx.toWalletId == null || tx.toWalletId!.isEmpty) {
        throw ArgumentError('Dompet tujuan transfer wajib dipilih.');
      }
      if (tx.toWalletId == tx.walletId) {
        throw ArgumentError('Dompet asal dan tujuan transfer harus berbeda.');
      }
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
