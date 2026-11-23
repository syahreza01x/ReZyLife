import 'package:flutter_test/flutter_test.dart';
import 'package:keuangan_reza/data/notification_parser.dart';
import 'package:keuangan_reza/models/finance_models.dart';

void main() {
  final now = DateTime(2026, 11, 23, 14, 30);

  test('parses real BRImo income & transfer-out notifications accurately', () {
    // Exact wording from real BRImo incoming notification.
    final realIncome = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.co.bri.brimo',
        title: 'BRImo',
        text:
            'Sobat BRI! Dana Rp10.000 masuk\nke rekening 160301010540530\npada 23/11/2026 21:24:00\nKET.:200001012_OB_1074564333460512',
        postedAt: now,
      ),
    );
    expect(realIncome, isNotNull);
    expect(realIncome!.walletId, 'brimo');
    expect(realIncome.sourceTag, 'notif_brimo');
    expect(realIncome.type, TransactionType.income);
    expect(realIncome.amount, 10000);
    expect(realIncome.description, 'Dana Masuk BRImo');

    // Exact wording from real BRImo outgoing transfer notification.
    final realTransferOut = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.co.bri.brimo',
        title: 'BRImo',
        text:
            '23/11/2026 21:25:25 - Transfer dari\nXXXXXXXXXXX0530 dengan nomor rekening\ntujuan XXXXXXXXXXX3506 sebesar\nRp10.000,00 BERHASIL. Info lebih lanjut\nhubungi Call Center BRI 1500017',
        postedAt: now,
      ),
    );
    expect(realTransferOut, isNotNull);
    expect(realTransferOut!.walletId, 'brimo');
    expect(realTransferOut.type, TransactionType.expense);
    expect(realTransferOut.amount, 10000);
    expect(realTransferOut.description, 'Transfer ke ••3506');

    final qrisExpense = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.co.bri.brimo',
        title: 'BRImo',
        text: 'Pembayaran QRIS sebesar Rp23.500 di Kopi Kenangan berhasil.',
        postedAt: now,
      ),
    );
    expect(qrisExpense, isNotNull);
    expect(qrisExpense!.walletId, 'brimo');
    expect(qrisExpense.type, TransactionType.expense);
    expect(qrisExpense.amount, 23500);
    expect(qrisExpense.categoryId, 'food');
    expect(qrisExpense.description, 'Bayar di Kopi Kenangan');
  });

  test('parses spaced GoPay, DANA, and ShopeePay notifications accurately', () {
    final gopay = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.gojek.gopay',
        title: 'GoPay',
        text: 'Pembayaran di Indomaret sebesar Rp22.000 berhasil.',
        postedAt: now,
      ),
    );
    expect(gopay, isNotNull);
    expect(gopay!.walletId, 'gopay');
    expect(gopay.type, TransactionType.expense);
    expect(gopay.amount, 22000);
    expect(gopay.categoryId, 'food');

    final gopayIn = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.gojek.gopay',
        title: 'GoPay',
        text: 'Saldo Rp50.000 berhasil masuk ke akun GoPay kamu.',
        postedAt: now,
      ),
    );
    expect(gopayIn, isNotNull);
    expect(gopayIn!.type, TransactionType.income);
    expect(gopayIn.amount, 50000);

    final dana = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.dana',
        title: 'DANA',
        text: 'Kamu berhasil kirim uang Rp 75.000 ke Raka Pratama!',
        postedAt: now,
      ),
    );
    expect(dana, isNotNull);
    expect(dana!.walletId, 'dana');
    expect(dana.type, TransactionType.expense);
    expect(dana.amount, 75000);

    final shopee = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.shopeepay.id',
        title: 'ShopeePay',
        text: 'Isi saldo sebesar Rp100.000 via BRI berhasil.',
        postedAt: now,
      ),
    );
    expect(shopee, isNotNull);
    expect(shopee!.walletId, 'shopeepay');
    expect(shopee.type, TransactionType.income);
    expect(shopee.amount, 100000);

    // Real-world GoPay & DANA notifications (including omitted "Rp" prefix).
    final gopayNoRp = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.gojek.app',
        title: 'GoPay',
        text: 'Anda telah menerima GoPay sebanyak 800.000.',
        postedAt: now,
      ),
    );
    expect(gopayNoRp, isNotNull);
    expect(gopayNoRp!.walletId, 'gopay');
    expect(gopayNoRp.type, TransactionType.income);
    expect(gopayNoRp.amount, 800000);

    final gopayWithRp = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.gojek.gopay',
        title: 'GoPay',
        text: 'Anda telah menerima GoPay sebanyak Rp5.000.',
        postedAt: now,
      ),
    );
    expect(gopayWithRp, isNotNull);
    expect(gopayWithRp!.walletId, 'gopay');
    expect(gopayWithRp.type, TransactionType.income);
    expect(gopayWithRp.amount, 5000);

    final danaIncomingNoRp = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.dana',
        title: 'DANA',
        text: 'Hi, bella baru saja Kirim DANA ke kamu 1.000.000 !',
        postedAt: now,
      ),
    );
    expect(danaIncomingNoRp, isNotNull);
    expect(danaIncomingNoRp!.walletId, 'dana');
    expect(danaIncomingNoRp.type, TransactionType.income);
    expect(danaIncomingNoRp.amount, 1000000);

    // Exact real-world DANA incoming notification from Infinix test.
    final danaReceived = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.dana',
        title: 'DANA',
        text: 'Rp1 telah diterima dari FERDIYANSYAH 💰',
        postedAt: now,
      ),
    );
    expect(danaReceived, isNotNull);
    expect(danaReceived!.walletId, 'dana');
    expect(danaReceived.type, TransactionType.income);
    expect(danaReceived.amount, 1);
    expect(danaReceived.description, 'Dari FERDIYANSYAH');

    // Exact real-world ShopeePay incoming notification from Infinix test.
    final shopeePayReceived = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.shopeepay.id',
        title: 'Saldo ShopeePay Diterima',
        text: 'Rp1 telah diterima dari FERDIYANSYAH.\nKlik untuk cek rinciannya.',
        postedAt: now,
      ),
    );
    expect(shopeePayReceived, isNotNull);
    expect(shopeePayReceived!.walletId, 'shopeepay');
    expect(shopeePayReceived.type, TransactionType.income);
    expect(shopeePayReceived.amount, 1);
    expect(shopeePayReceived.description, 'Dari FERDIYANSYAH');
  });

  test('blocks promotional, OTP, and non-payment Shopee/Gojek alerts', () {
    final promo = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.dana',
        title: 'Promo Gajian!',
        text: 'Cashback hingga Rp50.000 buat kamu hari ini! Klaim sekarang.',
        postedAt: now,
      ),
    );
    expect(promo, isNull);

    final otp = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.co.bri.brimo',
        title: 'Kode OTP BRImo',
        text: 'Kode verifikasi 482910 rahasia, jangan berikan kode ke siapa pun.',
        postedAt: now,
      ),
    );
    expect(otp, isNull);

    final shipping = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.shopee.id',
        title: 'Paketmu sedang diantar!',
        text: 'Kurir sedang menuju alamatmu. Siapkan uang Rp45.000.',
        postedAt: now,
      ),
    );
    expect(shipping, isNull);
  });

  test('generates identical dedup hash for duplicate notifications in same window',
      () {
    final first = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.dana',
        title: 'DANA',
        text: 'Pembayaran berhasil Rp15.000 di Alfamart.',
        postedAt: now,
      ),
    );
    final duplicate = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.dana',
        title: 'DANA',
        text: 'Pembayaran berhasil Rp15.000 di Alfamart.',
        postedAt: now.add(const Duration(seconds: 25)),
      ),
    );
    expect(first, isNotNull);
    expect(duplicate, isNotNull);
    expect(first!.dedupHash, duplicate!.dedupHash);

    // Cross-app duplicate: Gojek + GoPay standalone with different wording.
    final fromGojek = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.gojek.app',
        title: 'Pembayaran GoPay berhasil',
        text: 'Kamu bayar Rp25.000 di Warteg.',
        postedAt: now,
      ),
    );
    final fromGopayApp = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.gojek.gopay',
        title: 'GoPay',
        text: 'Transaksi berhasil Rp25.000 untuk pembayaran QRIS.',
        postedAt: now.add(const Duration(seconds: 5)),
      ),
    );
    expect(fromGojek, isNotNull);
    expect(fromGopayApp, isNotNull);
    expect(fromGojek!.dedupHash, fromGopayApp!.dedupHash);

    // Cross-app duplicate: Shopee + ShopeePay standalone.
    final fromShopee = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.shopee.id',
        title: 'ShopeePay',
        text: 'Pembayaran berhasil Rp40.000.',
        postedAt: now,
      ),
    );
    final fromShopeePay = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'com.shopeepay.id',
        title: 'Transaksi ShopeePay',
        text: 'Saldo terpotong Rp40.000 untuk transaksi berhasil.',
        postedAt: now.add(const Duration(seconds: 8)),
      ),
    );
    expect(fromShopee, isNotNull);
    expect(fromShopeePay, isNotNull);
    expect(fromShopee!.dedupHash, fromShopeePay!.dedupHash);
  });

  test('respects enabledWalletIds filter', () {
    final disabled = FinanceNotificationParser.parse(
      RawFinanceNotification(
        packageName: 'id.dana',
        title: 'DANA',
        text: 'Pembayaran berhasil Rp15.000 di Warteg.',
        postedAt: now,
      ),
      enabledWalletIds: {'brimo', 'gopay'},
    );
    expect(disabled, isNull);
  });
}
