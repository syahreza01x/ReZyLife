import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/finance_store.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'transaction_editor_sheet.dart';

/// Manage wallet balances (initial balance sync), add new custom wallets, or
/// start a wallet-to-wallet transfer.
class WalletsManagerSheet extends StatelessWidget {
  const WalletsManagerSheet({super.key, required this.store});

  final FinanceStore store;

  static Future<void> show(BuildContext context, FinanceStore store) {
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
      builder: (_) => RepaintBoundary(child: WalletsManagerSheet(store: store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Dompet & Saldo', style: textTheme.titleLarge),
                          const SizedBox(height: 2),
                          Text(
                            'Total gabungan ${formatRupiah(store.totalBalance)}',
                            style: textTheme.bodySmall?.copyWith(
                              fontFeatures: kTabularFigures,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        TransactionEditorSheet.show(
                          context,
                          store: store,
                          initialType: TransactionType.transfer,
                        );
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('Transfer'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: tokens.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: tokens.border, width: 1.15),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < store.wallets.length; i++) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: tokens.border.withOpacity(0.6),
                          ),
                        _WalletBalanceRow(
                          wallet: store.wallets[i],
                          onAdjust: () => _openBalanceDialog(
                            context,
                            store.wallets[i],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => _openAddWalletDialog(context),
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('Tambah Dompet Baru'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openBalanceDialog(BuildContext context, Wallet wallet) {
    return showDialog<void>(
      context: context,
      builder: (_) => _AdjustBalanceDialog(store: store, wallet: wallet),
    );
  }

  Future<void> _openAddWalletDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => _AddWalletDialog(store: store),
    );
  }
}

class _AdjustBalanceDialog extends StatefulWidget {
  const _AdjustBalanceDialog({required this.store, required this.wallet});

  final FinanceStore store;
  final Wallet wallet;

  @override
  State<_AdjustBalanceDialog> createState() => _AdjustBalanceDialogState();
}

class _AdjustBalanceDialogState extends State<_AdjustBalanceDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.wallet.balance.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed == null) {
      setState(() => _error = 'Masukkan angka saldo yang valid.');
      return;
    }
    await widget.store.updateWalletBalance(widget.wallet.id, parsed);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ReZyTokens.of(context).paperBg,
      title: Text('Sesuaikan Saldo ${widget.wallet.name}'),
      content: TextField(
        controller: _controller,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        autofocus: true,
        decoration: InputDecoration(
          labelText: 'Saldo saat ini (Rp)',
          prefixText: 'Rp ',
          errorText: _error,
          helperText: 'Cocok untuk set saldo awal atau sinkronisasi manual.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}

class _AddWalletDialog extends StatefulWidget {
  const _AddWalletDialog({required this.store});

  final FinanceStore store;

  @override
  State<_AddWalletDialog> createState() => _AddWalletDialogState();
}

class _AddWalletDialogState extends State<_AddWalletDialog> {
  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0');
  WalletKind _kind = WalletKind.ewallet;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Nama dompet wajib diisi.');
      return;
    }
    final bal = int.tryParse(_balanceCtrl.text.trim()) ?? 0;
    final palette = switch (_kind) {
      WalletKind.cash => (0xFF237A5B, 'cash'),
      WalletKind.bank => (0xFF2B59C3, 'bank'),
      WalletKind.ewallet => (0xFF6B52AE, 'gopay'),
    };
    await widget.store.addWallet(
      name: name,
      kind: _kind,
      initialBalance: bal,
      colorValue: palette.$1,
      iconKey: palette.$2,
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: ReZyTokens.of(context).paperBg,
      title: const Text('Tambah Dompet'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Nama Dompet',
              hintText: 'Misal: SeaBank, OVO, Blu, Mandiri',
              errorText: _error,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _balanceCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Saldo Awal (Rp)',
              prefixText: 'Rp ',
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final k in WalletKind.values)
                ChoiceChip(
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                  label: Text(switch (k) {
                    WalletKind.cash => 'Cash',
                    WalletKind.bank => 'Bank',
                    WalletKind.ewallet => 'E-Wallet',
                  }),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Tambah'),
        ),
      ],
    );
  }
}

class _WalletBalanceRow extends StatelessWidget {
  const _WalletBalanceRow({required this.wallet, required this.onAdjust});

  final Wallet wallet;
  final VoidCallback onAdjust;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onAdjust,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: wallet.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(wallet.icon, color: wallet.color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wallet.name, style: textTheme.titleMedium),
                  Text(
                    switch (wallet.kind) {
                      WalletKind.cash => 'Uang Tunai',
                      WalletKind.bank => 'Rekening Bank',
                      WalletKind.ewallet => 'E-Wallet',
                    },
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatRupiah(wallet.balance),
                  style: textTheme.titleMedium?.copyWith(
                    fontFeatures: kTabularFigures,
                  ),
                ),
                Text(
                  'Atur saldo',
                  style: textTheme.labelSmall?.copyWith(color: tokens.accent),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
