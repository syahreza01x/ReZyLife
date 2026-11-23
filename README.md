# ReZyLife

Aplikasi pencatat keuangan pribadi berbasis Flutter (offline-first, SQLite lokal) dengan tampilan bertema **Persona 3 Reload (S.E.E.S. Light Mode)** dan **Persona 5 Royal (Phantom Dark Mode)**.

> **Catatan Penggunaan:**
> Project ini dibuat khusus untuk **pemakaian pribadi**. Kalau kamu mau clone, pakai, atau modifikasi ulang untuk kebutuhan sendiri, **sebaiknya ganti nama aplikasinya** (di `AndroidManifest.xml`, `pubspec.yaml`, dan teks UI) karena nama **ReZy** diambil dari nama saya sendiri (**Reza**). 😄

---

## Fitur Utama

- **Multi-Dompet & Total Uang** — Mendukung `Cash`, `BRImo`, `GoPay`, `DANA`, `ShopeePay`, tambah dompet custom, serta sinkronisasi saldo awal.
- **Catat Transaksi Cepat** — Pengeluaran, pemasukan, dan pindah saldo (transfer antar dompet) dengan numpad Rupiah (`000`) dan pilihan kategori.
- **Auto-Catat dari Notifikasi (Android)** — Membaca notifikasi masuk/keluar secara lokal (tanpa internet/server) untuk `BRImo`, `GoPay`, `DANA`, dan `ShopeePay`, lengkap dengan filter anti-promo/OTP dan deduplikasi otomatis.
- **Quick Settings Tile (`Catat Cepat`)** — Shortcut langsung di Pusat Kontrol Android untuk membuka aplikasi dan menaikkan form catat transaksi secara instan.
- **Ringkasan & Analisis** — Grafik donut animasi, perbandingan pemasukan vs pengeluaran, dan rincian pengeluaran per kategori per bulan.
- **Patungan & Hutang** — Catat hutang/piutang teman, opsi potong/tambah saldo dompet otomatis, dan tombol tandai lunas yang tersinkronisasi dengan dompet.
- **Dual Theme Persona** — Switch instan antara **P3R (S.E.E.S. Putih-Biru)** dan **P5R (Dark Mode Hitam-Merah)** dengan dukungan layar 120Hz.

## Menjalankan Project

1. Pastikan Flutter SDK (`>=3.5.0`) dan Android SDK terpasang.
2. Cek `android/gradle.properties` — sesuaikan atau hapus baris `org.gradle.java.home` sesuai lokasi JDK 17/21 di komputermu.
3. Jalankan:
   ```bash
   flutter pub get
   flutter test
   flutter run
   ```
4. Untuk build APK release ARM64:
   ```bash
   flutter build apk --release --target-platform android-arm64
   ```
