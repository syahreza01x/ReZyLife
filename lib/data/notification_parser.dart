import '../models/finance_models.dart';

class RawFinanceNotification {
  const RawFinanceNotification({
    required this.packageName,
    required this.title,
    required this.text,
    required this.postedAt,
  });

  final String packageName;
  final String title;
  final String text;
  final DateTime postedAt;

  factory RawFinanceNotification.fromMap(Map<Object?, Object?> map) {
    return RawFinanceNotification(
      packageName: (map['packageName'] as String?) ?? '',
      title: (map['title'] as String?) ?? '',
      text: (map['text'] as String?) ?? '',
      postedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['postedAt'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

class ParsedFinanceNotification {
  const ParsedFinanceNotification({
    required this.walletId,
    required this.sourceTag,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.description,
    required this.postedAt,
    required this.dedupHash,
  });

  final String walletId;
  final String sourceTag; // 'notif_brimo', 'notif_gopay', 'notif_dana', 'notif_shopeepay'
  final TransactionType type;
  final int amount;
  final String categoryId;
  final String description;
  final DateTime postedAt;
  final String dedupHash;
}

class FinanceNotificationParser {
  FinanceNotificationParser._();

  static const Map<String, ({String walletId, String sourceTag, String label})>
      supportedPackages = {
    'id.co.bri.brimo': (
      walletId: 'brimo',
      sourceTag: 'notif_brimo',
      label: 'BRImo',
    ),
    'com.gojek.app': (
      walletId: 'gopay',
      sourceTag: 'notif_gopay',
      label: 'GoPay',
    ),
    'com.gopay.app': (
      walletId: 'gopay',
      sourceTag: 'notif_gopay',
      label: 'GoPay',
    ),
    'com.gojek.gopay': (
      walletId: 'gopay',
      sourceTag: 'notif_gopay',
      label: 'GoPay',
    ),
    'id.dana': (
      walletId: 'dana',
      sourceTag: 'notif_dana',
      label: 'DANA',
    ),
    'com.shopee.id': (
      walletId: 'shopeepay',
      sourceTag: 'notif_shopeepay',
      label: 'ShopeePay',
    ),
    'com.shopeepay.id': (
      walletId: 'shopeepay',
      sourceTag: 'notif_shopeepay',
      label: 'ShopeePay',
    ),
  };

  /// Strict anti-promo & security-OTP filter so marketing/OTP alerts never
  /// pollute real financial records.
  static const List<String> _blockedKeywords = [
    'promo',
    'diskon',
    'voucher',
    'cashback s.d',
    'cashback hingga',
    'gratis ongkir',
    'klaim sekarang',
    'jangan lewatkan',
    'penawaran',
    'undian',
    'menangkan',
    'flash sale',
    'kode otp',
    'kode verifikasi',
    'otp:',
    'jangan berikan kode',
    'rahasia',
    'login dari perangkat',
    'reset pin',
    'ubah password',
    'yuk bayar',
    'waktunya bayar',
    'pengingat tagihan',
    'keranjangmu',
    'cek sekarang',
  ];

  static final List<RegExp> _incomePatterns = [
    RegExp(r'\bmasuk\s+ke\s+(rekening|saldo|dompet)\b'),
    RegExp(r'\b(dana|uang|saldo|transfer)\b.{0,45}\bmasuk\b'),
    RegExp(r'\b(kamu|anda|berhasil|sukses)\b.{0,35}\b(menerima|terima|diterima)\b'),
    RegExp(r'\b(telah\s+)?diterima(\s+dari)?\b'),
    RegExp(r'\b(telah\s+)?menerima\s+(gopay|dana|shopeepay|uang|saldo|transfer)\b'),
    RegExp(r'\bkirim\s+(dana|uang|saldo|gopay|shopeepay)\s+ke\s+(kamu|anda)\b'),
    RegExp(r'\b(menerima|terima)\s+(uang|dana|saldo|transfer|rp\.?|idr)\b'),
    RegExp(r'\b(top\s*up|isi\s*saldo|setor\s*tunai)\b.{0,45}\b(berhasil|sukses)\b'),
    RegExp(r'\b(berhasil|sukses)\b.{0,35}\b(top\s*up|isi\s*saldo|setor\s*tunai)\b'),
    RegExp(r'\b(refund|pengembalian\s*dana|mutasi\s*kredit|kredit\s*sebesar|cashback\s*(masuk|diterima))\b'),
  ];

  static final List<RegExp> _expensePatterns = [
    RegExp(r'\btransfer\s+dari\b.{0,100}\b(berhasil|sukses)\b'),
    RegExp(r'\brekening\s+tujuan\b.{0,70}\b(berhasil|sukses)\b'),
    RegExp(
      r'\b(pembayaran|transaksi|transfer|pembelian|tarik\s*tunai|kirim(\s+(uang|dana|saldo))?|bayar|checkout|pesanan)\b.{0,90}\b(berhasil|sukses|dibayar|terbayar)\b',
    ),
    RegExp(
      r'\b(berhasil|sukses)\b.{0,45}\b(bayar|membayar|dibayar|transfer|kirim|mengirim|beli|membeli|tarik\s*tunai)\b',
    ),
    RegExp(r'\b(kamu|anda)\s+(bayar|membayar|mengirim|kirim)\b'),
    RegExp(
      r'\b(uang\s*keluar|dana\s*keluar|transfer\s*keluar|saldo\s*terpotong|mutasi\s*debit|debit\s*sebesar|pembayaran\s*(qris|gopay|dana|shopeepay|brimo|sebesar|tagihan)|transaksi\s*qris)\b',
    ),
  ];

  // Matches Rp25.000, Rp 25.000,00, IDR 150,000.00, Rp1.250.000 etc.
  static final RegExp _rupiahPattern = RegExp(
    r'(?:rp\.?|idr)\s*([0-9]{1,3}(?:[.,][0-9]{3})+|[0-9]+)(?:[.,]([0-9]{2}))?(?![0-9])',
    caseSensitive: false,
  );

  // Fallback for GoPay/DANA alerts that omit "Rp" (e.g. "sebanyak 800.000", "ke kamu 1.000.000 !").
  static final RegExp _bareGroupedAmountPattern = RegExp(
    r'(?<![0-9/:-])([1-9][0-9]{0,2}(?:\.[0-9]{3})+)(?:,([0-9]{2}))?(?![0-9])',
  );

  /// Parses a notification into a structured transaction, or returns null when
  /// the notification is unsupported, promotional, lacks a valid amount, or
  /// cannot be confidently classified as income/expense.
  static ParsedFinanceNotification? parse(
    RawFinanceNotification raw, {
    Set<String>? enabledWalletIds,
  }) {
    final pkg = raw.packageName.trim().toLowerCase();
    final provider = supportedPackages[pkg];
    if (provider == null) return null;
    if (enabledWalletIds != null &&
        !enabledWalletIds.contains(provider.walletId)) {
      return null;
    }

    final combined = '${raw.title} ${raw.text}'
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ');
    if (combined.isEmpty) return null;
    final lower = combined.toLowerCase();

    // Shopee/Gojek main apps send many non-wallet alerts (driver arrived, package shipped).
    if (pkg == 'com.shopee.id' &&
        !lower.contains('shopeepay') &&
        !lower.contains('pembayaran') &&
        !lower.contains('saldo') &&
        !lower.contains('transfer') &&
        !lower.contains('top up') &&
        !lower.contains('refund') &&
        !lower.contains('terima') &&
        !lower.contains('masuk')) {
      return null;
    }
    if (pkg == 'com.gojek.app' &&
        !lower.contains('gopay') &&
        !lower.contains('pembayaran') &&
        !lower.contains('transfer') &&
        !lower.contains('saldo') &&
        !lower.contains('bayar') &&
        !lower.contains('terima') &&
        !lower.contains('masuk')) {
      return null;
    }

    for (final blocked in _blockedKeywords) {
      if (lower.contains(blocked)) return null;
    }

    final amount = extractRupiahAmount(combined);
    if (amount == null || amount <= 0) return null;

    final direction = _detectDirection(lower);
    if (direction == null) return null;

    final categoryId = _inferCategory(lower, direction);
    final description = _buildDescription(raw, provider.label, direction);
    final dedupHash = _computeDedupHash(
      walletId: provider.walletId,
      direction: direction,
      amount: amount,
      postedAt: raw.postedAt,
    );

    return ParsedFinanceNotification(
      walletId: provider.walletId,
      sourceTag: provider.sourceTag,
      type: direction,
      amount: amount,
      categoryId: categoryId,
      description: description,
      postedAt: raw.postedAt,
      dedupHash: dedupHash,
    );
  }

  static int? extractRupiahAmount(String text) {
    final match = _rupiahPattern.firstMatch(text) ??
        _bareGroupedAmountPattern.firstMatch(text);
    if (match == null) return null;
    final wholePart = match.group(1);
    if (wholePart == null) return null;
    final digitsOnly = wholePart.replaceAll(RegExp(r'[^0-9]'), '');
    final parsed = int.tryParse(digitsOnly);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  static TransactionType? _detectDirection(String lower) {
    final isIncome = _incomePatterns.any((p) => p.hasMatch(lower));
    final isExpense = _expensePatterns.any((p) => p.hasMatch(lower));

    if (isIncome && !isExpense) return TransactionType.income;
    if (isExpense && !isIncome) return TransactionType.expense;

    // Disambiguate overlapping phrases like "Transaksi berhasil: kamu menerima Rp..."
    if (isIncome && isExpense) {
      if (lower.contains('menerima') ||
          lower.contains('diterima') ||
          lower.contains('masuk ke rekening') ||
          lower.contains('uang masuk') ||
          lower.contains('dana masuk') ||
          lower.contains('transfer masuk') ||
          RegExp(r'\b(dana|uang|saldo)\b.{0,45}\bmasuk\b').hasMatch(lower) ||
          lower.contains('top up') ||
          lower.contains('isi saldo') ||
          lower.contains('refund')) {
        return TransactionType.income;
      }
      return TransactionType.expense;
    }
    return null;
  }

  static String _inferCategory(String lower, TransactionType type) {
    if (type == TransactionType.income) {
      if (lower.contains('cashback') || lower.contains('refund') || lower.contains('pengembalian')) {
        return 'cashback';
      }
      if (lower.contains('beasiswa')) return 'scholarship';
      return 'other_in';
    }

    const foodWords = [
      'gofood', 'shopeefood', 'grabfood', 'kopi', 'coffee', 'cafe',
      'resto', 'warteg', 'geprek', 'bakso', 'mie', 'kantin', 'makan',
      'bakery', 'minum', 'boba', 'alfamart', 'indomaret', 'lawson',
      'familymart', 'mixue', 'starbucks', 'kfc', 'mcd', 'hokben',
    ];
    if (foodWords.any(lower.contains)) return 'food';

    const transportWords = [
      'goride', 'gocar', 'grab', 'ojek', 'parkir', 'bensin', 'pertamina',
      'spbu', 'shell', 'krl', 'mrt', 'transjakarta', 'kai', 'gojek',
    ];
    if (transportWords.any(lower.contains)) return 'transport';

    const kostWords = [
      'pln', 'listrik', 'token', 'pulsa', 'paket data', 'telkomsel',
      'indosat', 'xl ', 'tri ', 'by.u', 'wifi', 'indihome', 'biznet', 'pdam', 'kos',
    ];
    if (kostWords.any(lower.contains)) return 'kost';

    const campusWords = [
      'gramedia', 'fotokopi', 'print', 'buku', 'kampus', 'ukt', 'spp',
    ];
    if (campusWords.any(lower.contains)) return 'campus';

    return 'other_out';
  }

  /// Extracts a concise, scannable title (sender / recipient / merchant / clean
  /// action) instead of dumping raw timestamps or marketing greetings into rows.
  static String _buildDescription(
    RawFinanceNotification raw,
    String providerLabel,
    TransactionType direction,
  ) {
    final text = raw.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final lower = text.toLowerCase();

    String cleanEntity(String s) {
      return s
          .replaceAll(RegExp(r'[^\w\s&.\-/]'), '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .replaceAll(RegExp(r'[.,!]+$'), '')
          .trim();
    }

    if (direction == TransactionType.income) {
      // 1. "diterima dari FERDIYANSYAH 💰" / "dari BUDI SANTOSO berhasil"
      final fromMatch = RegExp(
        r'\bdari\s+([A-Za-z][A-Za-z0-9\s.&-]{1,36}?)(?=\s+(?:sebesar|pada|berhasil|sukses|ke|via|rp\.?|idr|klik|info)\b|[^A-Za-z0-9\s.&-]|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (fromMatch != null) {
        final name = cleanEntity(fromMatch.group(1)!);
        if (name.isNotEmpty && !name.toLowerCase().startsWith('rekening')) {
          return 'Dari $name';
        }
      }

      // 2. "Hi, bella baru saja Kirim DANA ke kamu ..."
      final hiMatch = RegExp(
        r'\b(?:hi|hai),?\s+([A-Za-z][A-Za-z0-9\s.&-]{1,28}?)\s+baru\s+saja\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (hiMatch != null) {
        final name = cleanEntity(hiMatch.group(1)!);
        if (name.isNotEmpty) {
          final cap = name[0].toUpperCase() + name.substring(1);
          return 'Dari $cap';
        }
      }

      // 3. Top-up / Isi saldo via <bank/source>
      if (lower.contains('top up') ||
          lower.contains('topup') ||
          lower.contains('isi saldo')) {
        final viaMatch = RegExp(
          r'\bvia\s+([A-Za-z0-9\s.&-]{2,24}?)(?=\s+(?:berhasil|sukses|pada)\b|[.,!]|$)',
          caseSensitive: false,
        ).firstMatch(text);
        if (viaMatch != null) {
          final src = cleanEntity(viaMatch.group(1)!);
          if (src.isNotEmpty) return 'Isi Saldo via $src';
        }
        return 'Isi Saldo $providerLabel';
      }

      if (lower.contains('refund') || lower.contains('pengembalian')) {
        return 'Refund $providerLabel';
      }
      if (lower.contains('cashback')) {
        return 'Cashback $providerLabel';
      }
      return 'Dana Masuk $providerLabel';
    }

    // Expense descriptions:
    // 1. BRImo / bank transfer with masked destination account "rekening tujuan XXXX3506"
    final acctMatch = RegExp(
      r'rekening\s+tujuan\s+[Xx*\d]*(\d{4})\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (acctMatch != null) {
      return 'Transfer ke ••${acctMatch.group(1)}';
    }

    // 2. Merchant after "di <Merchant>" (e.g., "di Kopi Kenangan berhasil")
    final atMatch = RegExp(
      r'\bdi\s+([A-Za-z0-9][A-Za-z0-9\s.&-]{1,34}?)(?=\s+(?:sebesar|berhasil|sukses|pada|rp\.?|idr|telah)\b|[.,!]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (atMatch != null) {
      final merchant = cleanEntity(atMatch.group(1)!);
      if (merchant.isNotEmpty) return 'Bayar di $merchant';
    }

    // 3. Recipient after "ke <Name>" (excluding "ke rekening" / "ke kamu")
    final toMatch = RegExp(
      r'\bke\s+([A-Za-z][A-Za-z0-9\s.&-]{1,34}?)(?=\s+(?:sebesar|berhasil|sukses|pada|rp\.?|idr|telah)\b|[.,!]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (toMatch != null) {
      final target = cleanEntity(toMatch.group(1)!);
      final targetLower = target.toLowerCase();
      if (target.isNotEmpty &&
          targetLower != 'rekening' &&
          targetLower != 'kamu' &&
          targetLower != 'anda') {
        return 'Transfer ke $target';
      }
    }

    // 4. Purpose after "untuk <Item>" (e.g., "untuk GoRide menuju Kampus")
    final forMatch = RegExp(
      r'\buntuk\s+([A-Za-z0-9][A-Za-z0-9\s.&-]{1,36}?)(?=\s+(?:sebesar|berhasil|sukses|pada|rp\.?|idr)\b|[.,!]|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (forMatch != null) {
      final purpose = cleanEntity(forMatch.group(1)!);
      if (purpose.isNotEmpty) return purpose;
    }

    if (lower.contains('qris')) return 'Bayar QRIS $providerLabel';
    if (lower.contains('transfer') || lower.contains('kirim')) {
      return 'Transfer $providerLabel';
    }
    if (lower.contains('tarik tunai')) return 'Tarik Tunai $providerLabel';
    return 'Bayar via $providerLabel';
  }

  /// Deterministic hash keyed by wallet + direction + amount + 2-minute window
  /// (intentionally excluding exact wording) so dual notifications from sibling
  /// apps like Gojek + GoPay or Shopee + ShopeePay never double-record.
  static String _computeDedupHash({
    required String walletId,
    required TransactionType direction,
    required int amount,
    required DateTime postedAt,
  }) {
    final bucket = postedAt.millisecondsSinceEpoch ~/ 120000;
    return 'nf_${walletId}_${direction.name}_${amount}_$bucket';
  }
}
