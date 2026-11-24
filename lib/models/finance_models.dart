import 'package:flutter/material.dart';

enum PersonaThemePreset {
  tatsumi, // Persona 3 Reload flavor on Japanese Stationery Pastel
  shibuya, // Persona 5 Royal flavor on Japanese Stationery Pastel
}

enum WalletKind { cash, bank, ewallet }

enum TransactionType { income, expense, transfer }

enum DebtDirection {
  receivable, // Piutang: aku talangin / teman pinjam
  payable, // Hutang: aku pinjam teman
}

enum AnalyticsPeriod { week, month }

class Wallet {
  const Wallet({
    required this.id,
    required this.name,
    required this.kind,
    required this.balance,
    required this.colorValue,
    required this.iconKey,
    this.packageName,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final WalletKind kind;
  final int balance; // Integer Rupiah — avoids floating-point drift.
  final int colorValue;
  final String iconKey;
  final String? packageName; // Reserved for Phase 2 Android notification mapping.
  final int sortOrder;

  Color get color => Color(colorValue);

  IconData get icon => walletIconFromKey(iconKey);

  Wallet copyWith({
    String? name,
    WalletKind? kind,
    int? balance,
    int? colorValue,
    String? iconKey,
    String? packageName,
    int? sortOrder,
  }) {
    return Wallet(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      balance: balance ?? this.balance,
      colorValue: colorValue ?? this.colorValue,
      iconKey: iconKey ?? this.iconKey,
      packageName: packageName ?? this.packageName,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'balance': balance,
        'color_value': colorValue,
        'icon_key': iconKey,
        'package_name': packageName,
        'sort_order': sortOrder,
      };

  factory Wallet.fromMap(Map<String, Object?> map) => Wallet(
        id: map['id'] as String,
        name: map['name'] as String,
        kind: WalletKind.values.byName(map['kind'] as String),
        balance: map['balance'] as int,
        colorValue: map['color_value'] as int,
        iconKey: map['icon_key'] as String,
        packageName: map['package_name'] as String?,
        sortOrder: map['sort_order'] as int,
      );
}

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.walletId,
    this.toWalletId,
    required this.description,
    required this.createdAt,
    this.source = 'manual',
    this.rawNotifHash,
  });

  final String id;
  final TransactionType type;
  final int amount;
  final String categoryId;
  final String walletId;
  final String? toWalletId;
  final String description;
  final DateTime createdAt;
  final String source; // 'manual' or Phase 2 'notif_brimo' / 'notif_gopay' etc.
  final String? rawNotifHash; // Phase 2 notification deduplication key.

  TransactionItem copyWith({
    TransactionType? type,
    int? amount,
    String? categoryId,
    String? walletId,
    String? toWalletId,
    bool clearToWallet = false,
    String? description,
    DateTime? createdAt,
    String? source,
    String? rawNotifHash,
  }) {
    return TransactionItem(
      id: id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      walletId: walletId ?? this.walletId,
      toWalletId: clearToWallet ? null : (toWalletId ?? this.toWalletId),
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      rawNotifHash: rawNotifHash ?? this.rawNotifHash,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'type': type.name,
        'amount': amount,
        'category_id': categoryId,
        'wallet_id': walletId,
        'to_wallet_id': toWalletId,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
        'source': source,
        'raw_notif_hash': rawNotifHash,
      };

  factory TransactionItem.fromMap(Map<String, Object?> map) => TransactionItem(
        id: map['id'] as String,
        type: TransactionType.values.byName(map['type'] as String),
        amount: map['amount'] as int,
        categoryId: map['category_id'] as String,
        walletId: map['wallet_id'] as String,
        toWalletId: map['to_wallet_id'] as String?,
        description: (map['description'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        source: (map['source'] as String?) ?? 'manual',
        rawNotifHash: map['raw_notif_hash'] as String?,
      );
}

class DebtItem {
  const DebtItem({
    required this.id,
    required this.direction,
    required this.personName,
    required this.amount,
    required this.description,
    required this.createdAt,
    this.isSettled = false,
    this.settledAt,
    this.linkedTransactionId,
  });

  final String id;
  final DebtDirection direction;
  final String personName;
  final int amount;
  final String description;
  final DateTime createdAt;
  final bool isSettled;
  final DateTime? settledAt;
  final String? linkedTransactionId;

  Map<String, Object?> toMap() => {
        'id': id,
        'direction': direction.name,
        'person_name': personName,
        'amount': amount,
        'description': description,
        'created_at': createdAt.millisecondsSinceEpoch,
        'is_settled': isSettled ? 1 : 0,
        'settled_at': settledAt?.millisecondsSinceEpoch,
        'linked_transaction_id': linkedTransactionId,
      };

  factory DebtItem.fromMap(Map<String, Object?> map) => DebtItem(
        id: map['id'] as String,
        direction: DebtDirection.values.byName(map['direction'] as String),
        personName: map['person_name'] as String,
        amount: map['amount'] as int,
        description: (map['description'] as String?) ?? '',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
        isSettled: (map['is_settled'] as int) == 1,
        settledAt: map['settled_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['settled_at'] as int),
        linkedTransactionId: map['linked_transaction_id'] as String?,
      );
}

class AppCategory {
  const AppCategory({
    required this.id,
    required this.label,
    required this.type,
    required this.icon,
    required this.color,
    required this.tint,
  });

  final String id;
  final String label;
  final TransactionType type;
  final IconData icon;
  final Color color;
  final Color tint;

  Color tileBg(bool isDark) => isDark ? color.withOpacity(0.22) : tint;

  Color tileFg(bool isDark) =>
      isDark ? Color.lerp(color, Colors.white, 0.38)! : color;
}

class CategorySummary {
  const CategorySummary({
    required this.category,
    required this.total,
    required this.count,
    required this.ratio,
  });

  final AppCategory category;
  final int total;
  final int count;
  final double ratio;
}

const List<AppCategory> kExpenseCategories = [
  AppCategory(
    id: 'food',
    label: 'Makan & Minum',
    type: TransactionType.expense,
    icon: Icons.restaurant_rounded,
    color: Color(0xFFC75B39),
    tint: Color(0xFFFCECE6),
  ),
  AppCategory(
    id: 'kost',
    label: 'Kos & Tagihan',
    type: TransactionType.expense,
    icon: Icons.home_rounded,
    color: Color(0xFF3E63A8),
    tint: Color(0xFFE7EFFC),
  ),
  AppCategory(
    id: 'transport',
    label: 'Transport',
    type: TransactionType.expense,
    icon: Icons.directions_bus_rounded,
    color: Color(0xFF287D7D),
    tint: Color(0xFFE2F3F2),
  ),
  AppCategory(
    id: 'campus',
    label: 'Kampus & Tugas',
    type: TransactionType.expense,
    icon: Icons.menu_book_rounded,
    color: Color(0xFF6B52AE),
    tint: Color(0xFFEEEAF9),
  ),
  AppCategory(
    id: 'hangout',
    label: 'Nongkrong',
    type: TransactionType.expense,
    icon: Icons.local_cafe_rounded,
    color: Color(0xFFB56E25),
    tint: Color(0xFFFBF0E1),
  ),
  AppCategory(
    id: 'shopping',
    label: 'Belanja',
    type: TransactionType.expense,
    icon: Icons.shopping_bag_rounded,
    color: Color(0xFFB8456A),
    tint: Color(0xFFFAEAF0),
  ),
  AppCategory(
    id: 'hobby',
    label: 'Hobi',
    type: TransactionType.expense,
    icon: Icons.sports_esports_rounded,
    color: Color(0xFF0284C7),
    tint: Color(0xFFE0F2FE),
  ),
  AppCategory(
    id: 'health',
    label: 'Kesehatan',
    type: TransactionType.expense,
    icon: Icons.medical_services_rounded,
    color: Color(0xFF2E8555),
    tint: Color(0xFFE4F4EB),
  ),
  AppCategory(
    id: 'other_out',
    label: 'Lainnya',
    type: TransactionType.expense,
    icon: Icons.category_rounded,
    color: Color(0xFF5A6577),
    tint: Color(0xFFEDF0F5),
  ),
];

const List<AppCategory> kIncomeCategories = [
  AppCategory(
    id: 'allowance',
    label: 'Kiriman Ortu',
    type: TransactionType.income,
    icon: Icons.volunteer_activism_rounded,
    color: Color(0xFF1F7A5C),
    tint: Color(0xFFE1F4EC),
  ),
  AppCategory(
    id: 'scholarship',
    label: 'Beasiswa',
    type: TransactionType.income,
    icon: Icons.school_rounded,
    color: Color(0xFF2563EB),
    tint: Color(0xFFE4EEFE),
  ),
  AppCategory(
    id: 'work',
    label: 'Kerja / Freelance',
    type: TransactionType.income,
    icon: Icons.work_rounded,
    color: Color(0xFF7C4DFF),
    tint: Color(0xFFF0EBFE),
  ),
  AppCategory(
    id: 'cashback',
    label: 'Bonus / Refund',
    type: TransactionType.income,
    icon: Icons.redeem_rounded,
    color: Color(0xFFB7721E),
    tint: Color(0xFFFBF0DF),
  ),
  AppCategory(
    id: 'debt_repaid',
    label: 'Pelunasan Teman',
    type: TransactionType.income,
    icon: Icons.handshake_rounded,
    color: Color(0xFF1E7B85),
    tint: Color(0xFFE2F3F5),
  ),
  AppCategory(
    id: 'other_in',
    label: 'Lainnya',
    type: TransactionType.income,
    icon: Icons.add_card_rounded,
    color: Color(0xFF5A6577),
    tint: Color(0xFFEDF0F5),
  ),
];

const AppCategory kTransferCategory = AppCategory(
  id: 'transfer',
  label: 'Pindah Dana',
  type: TransactionType.transfer,
  icon: Icons.swap_horiz_rounded,
  color: Color(0xFF4F5DA8),
  tint: Color(0xFFECEEF9),
);

const AppCategory kDebtPayoffCategory = AppCategory(
  id: 'debt_paid',
  label: 'Bayar Hutang',
  type: TransactionType.expense,
  icon: Icons.handshake_rounded,
  color: Color(0xFFA64B58),
  tint: Color(0xFFF9E9EC),
);

final Map<String, AppCategory> _categoryIndex = {
  for (final c in kExpenseCategories) c.id: c,
  for (final c in kIncomeCategories) c.id: c,
  kTransferCategory.id: kTransferCategory,
  kDebtPayoffCategory.id: kDebtPayoffCategory,
};

AppCategory categoryById(String id) =>
    _categoryIndex[id] ?? kExpenseCategories.last;

List<AppCategory> categoriesForType(TransactionType type) {
  switch (type) {
    case TransactionType.expense:
      return kExpenseCategories;
    case TransactionType.income:
      return kIncomeCategories;
    case TransactionType.transfer:
      return const [kTransferCategory];
  }
}

IconData walletIconFromKey(String key) {
  switch (key) {
    case 'cash':
      return Icons.payments_rounded;
    case 'bank':
      return Icons.account_balance_rounded;
    case 'gopay':
      return Icons.account_balance_wallet_rounded;
    case 'dana':
      return Icons.account_balance_wallet_outlined;
    case 'shopeepay':
      return Icons.shopping_basket_rounded;
    default:
      return Icons.credit_card_rounded;
  }
}

const List<Wallet> kDefaultWallets = [
  Wallet(
    id: 'cash',
    name: 'Cash',
    kind: WalletKind.cash,
    balance: 0,
    colorValue: 0xFF237A5B,
    iconKey: 'cash',
    sortOrder: 0,
  ),
  Wallet(
    id: 'brimo',
    name: 'BRImo',
    kind: WalletKind.bank,
    balance: 0,
    colorValue: 0xFF1A5CC8,
    iconKey: 'bank',
    packageName: 'id.co.bri.brimo',
    sortOrder: 1,
  ),
  Wallet(
    id: 'gopay',
    name: 'GoPay',
    kind: WalletKind.ewallet,
    balance: 0,
    colorValue: 0xFF0B8457,
    iconKey: 'gopay',
    packageName: 'com.gojek.app',
    sortOrder: 2,
  ),
  Wallet(
    id: 'dana',
    name: 'DANA',
    kind: WalletKind.ewallet,
    balance: 0,
    colorValue: 0xFF0E7DC2,
    iconKey: 'dana',
    packageName: 'id.dana',
    sortOrder: 3,
  ),
  Wallet(
    id: 'shopeepay',
    name: 'ShopeePay',
    kind: WalletKind.ewallet,
    balance: 0,
    colorValue: 0xFFD04A2B,
    iconKey: 'shopeepay',
    packageName: 'com.shopee.id',
    sortOrder: 4,
  ),
];
