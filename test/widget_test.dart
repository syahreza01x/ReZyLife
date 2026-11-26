import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keuangan_reza/data/app_database.dart';
import 'package:keuangan_reza/data/finance_store.dart';
import 'package:keuangan_reza/data/notification_parser.dart';
import 'package:keuangan_reza/main.dart';
import 'package:keuangan_reza/models/finance_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  Future<(AppDatabase, FinanceStore)> createTestStore() async {
    SharedPreferences.setMockInitialValues({});
    final db = AppDatabase(
      customPath: inMemoryDatabasePath,
      customFactory: databaseFactoryFfiNoIsolate,
    );
    final store = FinanceStore(database: db);
    await store.initialize();
    return (db, store);
  }

  testWidgets('1. Full wallet, transaction, edit, undo, search & filter QA',
      (tester) async {
    tester.view.physicalSize = const Size(375 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final (db, store) = await createTestStore();
    addTearDown(() async => db.close());

    await tester.pumpWidget(ReZyLifeApp(store: store));
    await tester.pumpAndSettle();

    // Initial state checks.
    expect(find.text('ReZyLife'), findsOneWidget);
    expect(find.text('PERSONA'), findsOneWidget);
    expect(find.text('RELOAD'), findsOneWidget);
    expect(find.text('Buku kas masih bersih'), findsOneWidget);

    // 1a. Wallet manager: adjust Cash initial balance & add custom wallet SeaBank.
    await tester.tap(find.text('Atur Saldo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cash').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '200000');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(store.walletById('cash')!.balance, 200000);
    expect(store.totalBalance, 200000);

    await tester.tap(find.text('Tambah Dompet Baru'));
    await tester.pumpAndSettle();
    // Validate empty wallet name rejected inline.
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(find.text('Nama dompet wajib diisi.'), findsOneWidget);

    final dialogFields = find.byType(TextField);
    await tester.enterText(dialogFields.at(0), 'SeaBank');
    await tester.enterText(dialogFields.at(1), '100000');
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    expect(store.totalBalance, 300000);

    // Close wallets sheet.
    Navigator.of(tester.element(find.text('Dompet & Saldo'))).pop();
    await tester.pumpAndSettle();

    // 1b. Hide & reveal balance toggle (hides Total, Monthly Income & Expense).
    await tester.tap(find.byTooltip('Sembunyikan saldo'));
    await tester.pumpAndSettle();
    expect(find.text('Rp ••••••'), findsNWidgets(3));
    await tester.tap(find.byTooltip('Tampilkan saldo'));
    await tester.pumpAndSettle();
    expect(find.text('Rp300.000'), findsOneWidget);

    // 1c. Transaction validation (Rp0 rejected) + preset + numpad + expense.
    await tester.tap(find.text('Catat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(find.text('Masukkan nominal lebih dari Rp0.'), findsOneWidget);

    await tester.tap(find.text('+20rb'));
    await tester.tap(find.text('5'));
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
    // Amount is 20,000. Add description & save expense on Cash.
    await tester.enterText(find.byType(TextField).last, 'Ayam geprek');
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(store.totalBalance, 280000);
    expect(store.walletById('cash')!.balance, 180000);

    // 1d. Transfer Cash -> BRImo keeps Total Balance unchanged.
    await tester.tap(find.text('Pindah'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+50rb'));
    await tester.enterText(find.byType(TextField).last, 'Setor BRImo');
    await tester.tap(find.text('Simpan Transaksi'));
    await tester.pumpAndSettle();
    expect(store.walletById('cash')!.balance, 130000);
    expect(store.walletById('brimo')!.balance, 50000);
    expect(store.totalBalance, 280000);

    // 1e. Tap existing transaction to edit amount atomically.
    final listScroll = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Ayam geprek'),
      180,
      scrollable: listScroll,
    );
    await tester.tap(find.text('Ayam geprek'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Transaksi'), findsOneWidget);

    await tester.tap(find.byTooltip('Bersihkan nominal'));
    await tester.tap(find.text('2'));
    await tester.tap(find.text('5'));
    await tester.tap(find.text('000'));
    await tester.tap(find.text('Simpan Perubahan'));
    await tester.pumpAndSettle();
    expect(store.totalBalance, 275000);
    expect(store.walletById('cash')!.balance, 125000);

    // 1f. Long-press opens delete confirmation dialog, then deletes with Undo.
    await tester.longPress(find.text('Ayam geprek'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Transaksi?'), findsOneWidget);
    await tester.tap(find.text('Hapus'));
    await tester.pumpAndSettle();
    expect(store.totalBalance, 300000);
    expect(find.text('Urungkan'), findsOneWidget);

    await tester.tap(find.text('Urungkan'));
    await tester.pumpAndSettle();
    expect(store.totalBalance, 275000);
    expect(find.text('Ayam geprek'), findsOneWidget);

    // 1g. Search empty state & Reset Filter.
    await tester.scrollUntilVisible(
      find.byType(TextField),
      -180,
      scrollable: listScroll,
    );
    await tester.enterText(find.byType(TextField).first, 'tidakada123');
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada transaksi yang cocok'), findsOneWidget);

    await tester.tap(find.text('Tampilkan Semua'));
    await tester.pumpAndSettle();
    expect(find.text('Tidak ada transaksi yang cocok'), findsNothing);

    // 1h. Swipe left/right smoothly switches Beranda -> Ringkasan -> Patungan -> Beranda.
    await tester.scrollUntilVisible(
      find.text('ReZyLife'),
      -300,
      scrollable: listScroll,
    );
    await tester.pumpAndSettle();
    await tester.fling(find.text('Total Uang'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Selisih Arus Kas'), findsOneWidget);

    await tester.fling(find.text('Selisih Arus Kas'), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Patungan & Hutang'), findsOneWidget);

    await tester.fling(find.text('Patungan & Hutang'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    await tester.fling(find.text('Selisih Arus Kas'), const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('Total Uang'), findsOneWidget);

    // 1i. Full-manual mode: Auto-Catat header action removed & auto-ingest stays off.
    expect(find.byTooltip('Auto-Catat Notifikasi'), findsNothing);
    expect(store.isAutoCaptureActive, isFalse);

    final sampleNotif = RawFinanceNotification(
      packageName: 'com.gojek.app',
      title: 'Pembayaran GoPay berhasil',
      text: 'Kamu bayar Rp15.000 di Kopi Susu.',
      postedAt: DateTime.now(),
    );
    final firstIngest = await store.ingestRawNotifications([sampleNotif]);
    await tester.pumpAndSettle();

    expect(firstIngest, isEmpty);
    expect(store.totalBalance, 275000);
  });

  testWidgets('2. Analytics donut, mode switching, and Debts settle/unsettle QA',
      (tester) async {
    tester.view.physicalSize = const Size(375 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final (db, store) = await createTestStore();
    addTearDown(() async => db.close());

    await store.addTransaction(
      type: TransactionType.income,
      amount: 600000,
      categoryId: 'allowance',
      walletId: 'brimo',
      description: 'Kiriman ortu',
    );
    await store.addTransaction(
      type: TransactionType.expense,
      amount: 120000,
      categoryId: 'food',
      walletId: 'gopay',
      description: 'Makan minggu ini',
    );
    await store.addTransaction(
      type: TransactionType.expense,
      amount: 40000,
      categoryId: 'transport',
      walletId: 'cash',
      description: 'Bensin motor',
    );

    await tester.pumpWidget(ReZyLifeApp(store: store));
    await tester.pumpAndSettle();

    // Switch to Ringkasan (Analytics).
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    expect(find.text('SURPLUS'), findsOneWidget);
    expect(find.text('Makan & Minum'), findsOneWidget);
    expect(find.text('Transport'), findsOneWidget);

    // Tap category row to focus donut slice & switch Keluar -> Masuk.
    final analyticsScroll = find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Makan & Minum'),
      180,
      scrollable: analyticsScroll,
    );
    await tester.ensureVisible(find.text('Makan & Minum'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Makan & Minum'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('7 Hari'),
      -200,
      scrollable: analyticsScroll,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masuk'));
    await tester.pumpAndSettle();
    expect(find.text('Kiriman Ortu'), findsOneWidget);

    // Switch 7 Hari <-> Bulanan.
    await tester.tap(find.text('7 Hari'));
    await tester.pumpAndSettle();
    expect(find.text('Menampilkan transaksi 7 hari terakhir'), findsOneWidget);
    await tester.tap(find.text('Bulanan'));
    await tester.pumpAndSettle();

    // Switch to Patungan (Debts): validate, add, settle into wallet, then unsettle!
    await tester.tap(find.text('Patungan'));
    await tester.pumpAndSettle();
    expect(find.text('Patungan & Hutang'), findsOneWidget);

    await tester.tap(find.text('Catat Patungan'));
    await tester.pumpAndSettle();

    // Validation check.
    await tester.tap(find.text('Simpan Catatan'));
    await tester.pumpAndSettle();
    expect(find.text('Nama teman wajib diisi.'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Nadia');
    await tester.enterText(fields.at(1), '35000');
    await tester.enterText(fields.at(2), 'Patungan print');
    await tester.tap(find.text('Simpan Catatan'));
    await tester.pumpAndSettle();
    expect(find.text('Nadia'), findsOneWidget);
    expect(store.totalUnsettledReceivable, 35000);

    // Settle debt into Cash wallet automatically.
    final beforeBalance = store.totalBalance;
    await tester.tap(find.text('Tandai Lunas'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Konfirmasi Lunas'));
    await tester.pumpAndSettle();
    expect(store.totalUnsettledReceivable, 0);
    expect(store.totalBalance, beforeBalance + 35000);

    // Check Lunas tab and verify Batal Lunas reverts wallet balance atomically.
    await tester.tap(find.text('Lunas'));
    await tester.pumpAndSettle();
    expect(find.text('Nadia'), findsOneWidget);
    await tester.tap(find.text('Batal Lunas'));
    await tester.pumpAndSettle();
    expect(store.totalUnsettledReceivable, 35000);
    expect(store.totalBalance, beforeBalance);
  });

  testWidgets(
      '3. Persona P3R<->P5R wipe, reduced motion, landscape & 1.35x text scale QA',
      (tester) async {
    final (db, store) = await createTestStore();
    addTearDown(() async => db.close());

    // 3a. Portrait + 1.35x Dynamic Type accessibility text scale (no overflow!).
    tester.view.physicalSize = const Size(375 * 2, 740 * 2);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 740),
          textScaler: TextScaler.linear(1.35),
        ),
        child: ReZyLifeApp(store: store),
      ),
    );
    await tester.pumpAndSettle();

    // Toggle P3R -> P5R through full 2-controller wipe animation.
    await tester.tap(find.text('P3R'));
    await tester.pumpAndSettle();
    expect(store.themePreset, PersonaThemePreset.shibuya);
    expect(find.text('P5R'), findsOneWidget);
    expect(find.text('ROYAL'), findsOneWidget);
    expect(find.text('PERSONA'), findsOneWidget);

    // 3b. Landscape orientation check across all 3 tabs (no overflow!).
    tester.view.physicalSize = const Size(740 * 2, 375 * 2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ringkasan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Patungan'));
    await tester.pumpAndSettle();

    // 3c. Reduced motion skips wipe cleanly and switches instantaneously.
    await tester.tap(find.text('Beranda'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(375, 740),
          disableAnimations: true,
        ),
        child: ReZyLifeApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('P5R'));
    await tester.pump();
    expect(store.themePreset, PersonaThemePreset.tatsumi);
  });
}
