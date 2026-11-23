import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/finance_store.dart';
import '../theme/app_theme.dart';
import 'stationery_widgets.dart';

/// Bottom sheet to configure Android Notification Listener auto-recording
/// for BRImo, GoPay, DANA, and ShopeePay.
class AutoCaptureSheet extends StatelessWidget {
  const AutoCaptureSheet({super.key, required this.store});

  final FinanceStore store;

  static Future<void> show(BuildContext context, FinanceStore store) {
    store.refreshNotificationAccess();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (_) => RepaintBoundary(child: AutoCaptureSheet(store: store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final granted = store.notificationAccessGranted;
        final enabled = store.autoCaptureEnabled;

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: tokens.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Auto-Catat Notifikasi',
                        style: textTheme.titleLarge,
                      ),
                    ),
                    PersonaStamp(
                      label: granted ? 'IZIN AKTIF' : 'PERLU IZIN',
                      backgroundColor:
                          granted ? tokens.incomeSoft : tokens.expenseSoft,
                      foregroundColor: granted ? tokens.income : tokens.expense,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Notifikasi transaksi masuk & keluar dari BRImo, GoPay, DANA, dan ShopeePay langsung tercatat otomatis ke dompet terkait (100% lokal di HP).',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                StationerySurface(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            granted
                                ? Icons.verified_user_rounded
                                : Icons.notifications_active_outlined,
                            color: granted ? tokens.income : tokens.accent,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              granted
                                  ? 'ReZyLife sudah diizinkan membaca notifikasi.'
                                  : 'Aktifkan Akses Notifikasi untuk ReZyLife di pengaturan Android.',
                              style: textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          store.notificationBridge
                              .openNotificationAccessSettings();
                        },
                        icon: const Icon(Icons.settings_rounded, size: 18),
                        label: Text(
                          granted
                              ? 'Kelola Akses Notifikasi'
                              : 'Buka Pengaturan Akses Notifikasi',
                        ),
                      ),
                      if (!granted) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Tips Android 13–16: jika toggle ReZyLife diblokir, buka Info Aplikasi → ketuk ⋮ kanan atas → "Izinkan setelan terbatas", lalu aktifkan lagi.',
                          style: textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            store.notificationBridge.openAppDetailsSettings();
                          },
                          icon: const Icon(Icons.info_outline_rounded, size: 18),
                          label: const Text('Buka Info Aplikasi ReZyLife'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                StationerySurface(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: enabled,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      store.setAutoCaptureEnabled(v);
                    },
                    title: Text('Catat Otomatis', style: textTheme.titleMedium),
                    subtitle: Text(
                      'Promo, iklan & OTP disaring otomatis',
                      style: textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Aplikasi yang Dipantau',
                  style: textTheme.labelMedium?.copyWith(color: tokens.inkMuted),
                ),
                const SizedBox(height: 8),
                StationerySurface(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0;
                          i < FinanceStore.kAutoCaptureWalletIds.length;
                          i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            color: tokens.border.withOpacity(0.55),
                          ),
                        _AppSourceToggleRow(
                          walletId: FinanceStore.kAutoCaptureWalletIds[i],
                          store: store,
                          masterEnabled: enabled,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AppSourceToggleRow extends StatelessWidget {
  const _AppSourceToggleRow({
    required this.walletId,
    required this.store,
    required this.masterEnabled,
  });

  final String walletId;
  final FinanceStore store;
  final bool masterEnabled;

  @override
  Widget build(BuildContext context) {
    final wallet = store.walletById(walletId);
    if (wallet == null) return const SizedBox.shrink();
    final isOn = store.enabledAutoWallets.contains(walletId);

    return SwitchListTile.adaptive(
      value: isOn,
      onChanged: masterEnabled
          ? (_) {
              HapticFeedback.selectionClick();
              store.toggleAutoWallet(walletId);
            }
          : null,
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: wallet.color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(wallet.icon, color: wallet.color, size: 19),
      ),
      title: Text(wallet.name, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        wallet.packageName ?? '',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
