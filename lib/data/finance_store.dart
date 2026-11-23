import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/finance_models.dart';
import 'app_database.dart';
import 'notification_bridge.dart';
import 'notification_parser.dart';

class FinanceStore extends ChangeNotifier {
  FinanceStore({
    required AppDatabase database,
    SharedPreferences? preferences,
    NotificationBridge? notificationBridge,
  })  : _db = database,
        _prefs = preferences,
        _notifBridge = notificationBridge ?? NotificationBridge();

  final AppDatabase _db;
  SharedPreferences? _prefs;
  final NotificationBridge _notifBridge;

  static const _prefThemeKey = 'rezylife_theme_preset';
  static const _prefHideBalanceKey = 'rezylife_hide_balance';
  static const _prefAutoCaptureKey = 'rezylife_auto_capture_enabled';
  static const _prefAutoWalletsKey = 'rezylife_auto_capture_wallets';

  static const List<String> kAutoCaptureWalletIds = [
    'brimo',
    'gopay',
    'dana',
    'shopeepay',
  ];

  List<Wallet> _wallets = const [];
  List<TransactionItem> _transactions = const [];
  List<DebtItem> _debts = const [];
  PersonaThemePreset _themePreset = PersonaThemePreset.tatsumi;
  bool _hideBalance = false;
  bool _autoCaptureEnabled = true;
  bool _notificationAccessGranted = false;
  Set<String> _enabledAutoWallets = Set<String>.from(kAutoCaptureWalletIds);
  bool _isLoading = true;
  int _idCounter = 0;

  List<Wallet> get wallets => List.unmodifiable(_wallets);
  List<TransactionItem> get transactions => List.unmodifiable(_transactions);
  List<DebtItem> get debts => List.unmodifiable(_debts);
  PersonaThemePreset get themePreset => _themePreset;
  bool get hideBalance => _hideBalance;
  bool get autoCaptureEnabled => _autoCaptureEnabled;
  bool get notificationAccessGranted => _notificationAccessGranted;
  bool get isAutoCaptureActive =>
      _autoCaptureEnabled && _notificationAccessGranted;
  Set<String> get enabledAutoWallets => Set.unmodifiable(_enabledAutoWallets);
  bool get isLoading => _isLoading;
  NotificationBridge get notificationBridge => _notifBridge;

  /// Combined total money across Cash, BRImo, GoPay, DANA, ShopeePay, etc.
  int get totalBalance =>
      _wallets.fold<int>(0, (sum, w) => sum + w.balance);

  int get totalUnsettledReceivable => _debts
      .where((d) => !d.isSettled && d.direction == DebtDirection.receivable)
      .fold<int>(0, (sum, d) => sum + d.amount);

  int get totalUnsettledPayable => _debts
      .where((d) => !d.isSettled && d.direction == DebtDirection.payable)
      .fold<int>(0, (sum, d) => sum + d.amount);

  Wallet? walletById(String id) {
    for (final w in _wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  String _nextId(String prefix) {
    _idCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_idCounter';
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      final savedTheme = _prefs?.getString(_prefThemeKey);
      if (savedTheme == PersonaThemePreset.shibuya.name) {
        _themePreset = PersonaThemePreset.shibuya;
      } else {
        _themePreset = PersonaThemePreset.tatsumi;
      }
      _hideBalance = _prefs?.getBool(_prefHideBalanceKey) ?? false;
      _autoCaptureEnabled = _prefs?.getBool(_prefAutoCaptureKey) ?? true;
      final savedWallets = _prefs?.getStringList(_prefAutoWalletsKey);
      if (savedWallets != null) {
        _enabledAutoWallets = savedWallets.toSet();
      }
    } catch (_) {
      // Keep default preferences if platform storage is unavailable in tests.
    }

    _notificationAccessGranted = await _notifBridge.isAccessEnabled();
    await reload();
    await syncPendingNotifications();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> reload() async {
    final results = await Future.wait([
      _db.getWallets(),
      _db.getTransactions(),
      _db.getDebts(),
    ]);
    _wallets = results[0] as List<Wallet>;
    _transactions = results[1] as List<TransactionItem>;
    _debts = results[2] as List<DebtItem>;
    notifyListeners();
  }

  Future<void> setThemePreset(PersonaThemePreset preset) async {
    if (_themePreset == preset) return;
    _themePreset = preset;
    notifyListeners();
    try {
      await _prefs?.setString(_prefThemeKey, preset.name);
    } catch (_) {}
  }

  Future<void> toggleThemePreset() => setThemePreset(
        _themePreset == PersonaThemePreset.tatsumi
            ? PersonaThemePreset.shibuya
            : PersonaThemePreset.tatsumi,
      );

  Future<void> toggleHideBalance() async {
    _hideBalance = !_hideBalance;
    notifyListeners();
    try {
      await _prefs?.setBool(_prefHideBalanceKey, _hideBalance);
    } catch (_) {}
  }

  Future<void> setAutoCaptureEnabled(bool enabled) async {
    if (_autoCaptureEnabled == enabled) return;
    _autoCaptureEnabled = enabled;
    notifyListeners();
    try {
      await _prefs?.setBool(_prefAutoCaptureKey, enabled);
    } catch (_) {}
  }

  Future<void> toggleAutoWallet(String walletId) async {
    final next = Set<String>.from(_enabledAutoWallets);
    if (!next.remove(walletId)) {
      next.add(walletId);
    }
    _enabledAutoWallets = next;
    notifyListeners();
    try {
      await _prefs?.setStringList(_prefAutoWalletsKey, next.toList());
    } catch (_) {}
  }

  Future<void> refreshNotificationAccess() async {
    final granted = await _notifBridge.isAccessEnabled();
    if (granted != _notificationAccessGranted) {
      _notificationAccessGranted = granted;
      notifyListeners();
    }
  }

  Future<List<TransactionItem>> syncPendingNotifications() async {
    final pending = await _notifBridge.drainPendingNotifications();
    if (pending.isEmpty) return const [];
    return ingestRawNotifications(pending);
  }

  /// Parses & atomically records auto-captured notifications (with dedup).
  Future<List<TransactionItem>> ingestRawNotifications(
    List<RawFinanceNotification> notifications,
  ) async {
    if (!_autoCaptureEnabled || notifications.isEmpty) return const [];

    final insertedItems = <TransactionItem>[];
    for (final raw in notifications) {
      final parsed = FinanceNotificationParser.parse(
        raw,
        enabledWalletIds: _enabledAutoWallets,
      );
      if (parsed == null) continue;
      if (walletById(parsed.walletId) == null) continue;

      final tx = TransactionItem(
        id: _nextId('tx'),
        type: parsed.type,
        amount: parsed.amount,
        categoryId: parsed.categoryId,
        walletId: parsed.walletId,
        description: parsed.description,
        createdAt: parsed.postedAt,
        source: parsed.sourceTag,
        rawNotifHash: parsed.dedupHash,
      );

      final inserted = await _db.insertTransactionIfUnique(tx);
      if (inserted) {
        insertedItems.add(tx);
      }
    }

    if (insertedItems.isNotEmpty) {
      await reload();
    }
    return insertedItems;
  }

  Future<TransactionItem> addTransaction({
    required TransactionType type,
    required int amount,
    required String categoryId,
    required String walletId,
    String? toWalletId,
    required String description,
    DateTime? createdAt,
  }) async {
    final item = TransactionItem(
      id: _nextId('tx'),
      type: type,
      amount: amount,
      categoryId: type == TransactionType.transfer ? 'transfer' : categoryId,
      walletId: walletId,
      toWalletId: type == TransactionType.transfer ? toWalletId : null,
      description: description.trim(),
      createdAt: createdAt ?? DateTime.now(),
    );
    await _db.insertTransaction(item);
    await reload();
    return item;
  }

  Future<void> restoreTransaction(TransactionItem tx) async {
    await _db.insertTransaction(tx);
    await reload();
  }

  Future<void> updateTransaction(
    TransactionItem previous,
    TransactionItem updated,
  ) async {
    await _db.updateTransaction(previous, updated);
    await reload();
  }

  Future<void> deleteTransaction(TransactionItem tx) async {
    await _db.deleteTransaction(tx);
    await reload();
  }

  Future<void> addWallet({
    required String name,
    required WalletKind kind,
    required int initialBalance,
    required int colorValue,
    required String iconKey,
  }) async {
    final wallet = Wallet(
      id: _nextId('w'),
      name: name.trim(),
      kind: kind,
      balance: initialBalance,
      colorValue: colorValue,
      iconKey: iconKey,
      sortOrder: _wallets.length,
    );
    await _db.insertWallet(wallet);
    await reload();
  }

  Future<void> updateWalletBalance(String walletId, int newBalance) async {
    await _db.updateWalletBalance(walletId, newBalance);
    await reload();
  }

  Future<DebtItem> addDebt({
    required DebtDirection direction,
    required String personName,
    required int amount,
    required String description,
    DateTime? createdAt,
    String? walletId,
  }) async {
    final item = DebtItem(
      id: _nextId('debt'),
      direction: direction,
      personName: personName.trim(),
      amount: amount,
      description: description.trim(),
      createdAt: createdAt ?? DateTime.now(),
    );
    await _db.insertDebt(
      item,
      walletId: walletId,
      newTransactionId: walletId != null ? _nextId('tx') : null,
    );
    await reload();
    return item;
  }

  Future<void> settleDebt(DebtItem debt, {String? walletId}) async {
    await _db.settleDebt(
      debt,
      walletId: walletId,
      newTransactionId: _nextId('tx'),
    );
    await reload();
  }

  Future<void> unsettleDebt(DebtItem debt) async {
    await _db.unsettleDebt(debt);
    await reload();
  }

  Future<void> deleteDebt(String debtId) async {
    await _db.deleteDebt(debtId);
    await reload();
  }

  /// Transactions inside a calendar month or rolling 7-day week ending [anchor].
  List<TransactionItem> transactionsInPeriod(
    AnalyticsPeriod period,
    DateTime anchor,
  ) {
    final DateTime start;
    final DateTime end;
    if (period == AnalyticsPeriod.month) {
      start = DateTime(anchor.year, anchor.month, 1);
      end = DateTime(anchor.year, anchor.month + 1, 1);
    } else {
      final anchorDay = DateTime(anchor.year, anchor.month, anchor.day);
      start = anchorDay.subtract(const Duration(days: 6));
      end = anchorDay.add(const Duration(days: 1));
    }

    return _transactions
        .where((tx) => !tx.createdAt.isBefore(start) && tx.createdAt.isBefore(end))
        .toList();
  }

  int sumByType(List<TransactionItem> items, TransactionType type) => items
      .where((tx) => tx.type == type)
      .fold<int>(0, (sum, tx) => sum + tx.amount);

  /// Ranked largest-first so the donut starts its biggest slice at 12 o'clock.
  List<CategorySummary> categoryBreakdown(
    List<TransactionItem> items,
    TransactionType type,
  ) {
    final filtered = items.where((tx) => tx.type == type);
    final totals = <String, int>{};
    final counts = <String, int>{};
    var grandTotal = 0;

    for (final tx in filtered) {
      totals[tx.categoryId] = (totals[tx.categoryId] ?? 0) + tx.amount;
      counts[tx.categoryId] = (counts[tx.categoryId] ?? 0) + 1;
      grandTotal += tx.amount;
    }

    if (grandTotal == 0) return const [];

    final summaries = totals.entries.map((entry) {
      return CategorySummary(
        category: categoryById(entry.key),
        total: entry.value,
        count: counts[entry.key] ?? 0,
        ratio: entry.value / grandTotal,
      );
    }).toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    return summaries;
  }
}
