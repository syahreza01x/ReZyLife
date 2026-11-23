import 'package:flutter_test/flutter_test.dart';
import 'package:keuangan_reza/data/app_database.dart';
import 'package:keuangan_reza/data/finance_store.dart';
import 'package:keuangan_reza/models/finance_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late FinanceStore store;

  setUp(() async {
    db = AppDatabase(
      customPath: inMemoryDatabasePath,
      customFactory: databaseFactoryFfi,
    );
    store = FinanceStore(database: db);
    await store.initialize();
  });

  tearDown(() async {
    await db.close();
  });

  test('seeds student wallets with Phase 2 notification package names', () {
    expect(store.wallets.map((w) => w.id), [
      'cash',
      'brimo',
      'gopay',
      'dana',
      'shopeepay',
    ]);
    expect(store.walletById('brimo')?.packageName, 'id.co.bri.brimo');
    expect(store.walletById('gopay')?.packageName, 'com.gojek.app');
    expect(store.walletById('dana')?.packageName, 'id.dana');
    expect(store.walletById('shopeepay')?.packageName, 'com.shopee.id');
    expect(store.totalBalance, 0);
  });

  test('income, expense, and transfer keep per-wallet & total balance atomic',
      () async {
    await store.addTransaction(
      type: TransactionType.income,
      amount: 500000,
      categoryId: 'allowance',
      walletId: 'brimo',
      description: 'Kiriman ortu',
    );
    expect(store.walletById('brimo')!.balance, 500000);
    expect(store.totalBalance, 500000);

    await store.addTransaction(
      type: TransactionType.transfer,
      amount: 150000,
      categoryId: 'transfer',
      walletId: 'brimo',
      toWalletId: 'gopay',
      description: 'Top up GoPay',
    );
    expect(store.walletById('brimo')!.balance, 350000);
    expect(store.walletById('gopay')!.balance, 150000);
    expect(store.totalBalance, 500000);

    await store.addTransaction(
      type: TransactionType.expense,
      amount: 25000,
      categoryId: 'food',
      walletId: 'gopay',
      description: 'Ayam geprek',
    );
    expect(store.walletById('gopay')!.balance, 125000);
    expect(store.totalBalance, 475000);

    // Transfers must not inflate monthly income or expense totals.
    final monthTx =
        store.transactionsInPeriod(AnalyticsPeriod.month, DateTime.now());
    expect(store.sumByType(monthTx, TransactionType.income), 500000);
    expect(store.sumByType(monthTx, TransactionType.expense), 25000);
  });

  test('updating and deleting transactions revert previous deltas atomically',
      () async {
    final tx = await store.addTransaction(
      type: TransactionType.expense,
      amount: 40000,
      categoryId: 'food',
      walletId: 'cash',
      description: 'Makan siang',
    );
    expect(store.walletById('cash')!.balance, -40000);

    final updated = tx.copyWith(amount: 60000, walletId: 'dana');
    await store.updateTransaction(tx, updated);
    expect(store.walletById('cash')!.balance, 0);
    expect(store.walletById('dana')!.balance, -60000);

    await store.deleteTransaction(updated);
    expect(store.walletById('dana')!.balance, 0);
    expect(store.totalBalance, 0);
  });

  test('rejects invalid transaction and debt inputs at trust boundary',
      () async {
    await expectLater(
      store.addTransaction(
        type: TransactionType.expense,
        amount: 0,
        categoryId: 'food',
        walletId: 'cash',
        description: 'Zero',
      ),
      throwsArgumentError,
    );

    await expectLater(
      store.addTransaction(
        type: TransactionType.transfer,
        amount: 10000,
        categoryId: 'transfer',
        walletId: 'cash',
        toWalletId: 'cash',
        description: 'Same wallet',
      ),
      throwsArgumentError,
    );

    await expectLater(
      store.addDebt(
        direction: DebtDirection.receivable,
        personName: '   ',
        amount: 10000,
        description: 'Empty name',
      ),
      throwsArgumentError,
    );
  });

  test('settling and unsettling debt syncs linked transaction and wallet',
      () async {
    final debt = await store.addDebt(
      direction: DebtDirection.receivable,
      personName: 'Dimas',
      amount: 35000,
      description: 'Talangin print makalah',
    );
    expect(store.totalUnsettledReceivable, 35000);

    await store.settleDebt(debt, walletId: 'gopay');
    expect(store.totalUnsettledReceivable, 0);
    expect(store.walletById('gopay')!.balance, 35000);
    expect(store.transactions.length, 1);

    final settled = store.debts.first;
    expect(settled.isSettled, isTrue);
    expect(settled.linkedTransactionId, isNotNull);

    await store.unsettleDebt(settled);
    expect(store.totalUnsettledReceivable, 35000);
    expect(store.walletById('gopay')!.balance, 0);
    expect(store.transactions, isEmpty);
  });

  test('adding debt with walletId immediately updates wallet balance atomically',
      () async {
    await store.addDebt(
      direction: DebtDirection.receivable,
      personName: 'Budi',
      amount: 50000,
      description: 'Pinjam tunai',
      walletId: 'cash',
    );
    expect(store.walletById('cash')!.balance, -50000);
    expect(store.totalUnsettledReceivable, 50000);

    await store.addDebt(
      direction: DebtDirection.payable,
      personName: 'Siti',
      amount: 20000,
      description: 'Pinjam cash',
      walletId: 'cash',
    );
    expect(store.walletById('cash')!.balance, -30000);
    expect(store.totalUnsettledPayable, 20000);
  });

  test('categoryBreakdown sorts largest slice first for 12-o-clock donut start',
      () async {
    final now = DateTime.now();
    await store.addTransaction(
      type: TransactionType.expense,
      amount: 15000,
      categoryId: 'transport',
      walletId: 'cash',
      description: 'Busway',
      createdAt: now,
    );
    await store.addTransaction(
      type: TransactionType.expense,
      amount: 85000,
      categoryId: 'food',
      walletId: 'cash',
      description: 'Makan bareng',
      createdAt: now,
    );

    final breakdown = store.categoryBreakdown(
      store.transactionsInPeriod(AnalyticsPeriod.month, now),
      TransactionType.expense,
    );
    expect(breakdown.length, 2);
    expect(breakdown.first.category.id, 'food');
    expect(breakdown.first.ratio, closeTo(0.85, 0.001));
    expect(breakdown.last.category.id, 'transport');
  });
}
