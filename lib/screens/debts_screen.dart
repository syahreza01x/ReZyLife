import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/finance_store.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/stationery_widgets.dart';

enum _DebtFilter { receivable, payable, settled }

class DebtsScreen extends StatefulWidget {
  const DebtsScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<DebtsScreen> createState() => _DebtsScreenState();
}

class _DebtsScreenState extends State<DebtsScreen> {
  _DebtFilter _filter = _DebtFilter.receivable;

  List<DebtItem> _filteredDebts(List<DebtItem> all) {
    return all.where((d) {
      switch (_filter) {
        case _DebtFilter.receivable:
          return !d.isSettled && d.direction == DebtDirection.receivable;
        case _DebtFilter.payable:
          return !d.isSettled && d.direction == DebtDirection.payable;
        case _DebtFilter.settled:
          return d.isSettled;
      }
    }).toList();
  }

  Future<void> _confirmSettle(DebtItem debt) async {
    final store = widget.store;
    bool recordToWallet = true;
    String selectedWalletId =
        store.wallets.isNotEmpty ? store.wallets.first.id : 'cash';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final tokens = ReZyTokens.of(ctx);
          final textTheme = Theme.of(ctx).textTheme;
          final isReceivable = debt.direction == DebtDirection.receivable;

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
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
                Text('Tandai Lunas?', style: textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  isReceivable
                      ? '${debt.personName} melunasi ${formatRupiah(debt.amount)}.'
                      : 'Kamu melunasi ${formatRupiah(debt.amount)} ke ${debt.personName}.',
                  style: textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
                ),
                const SizedBox(height: 14),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: recordToWallet,
                  onChanged: (v) => setSheetState(() => recordToWallet = v),
                  title: Text(
                    isReceivable
                        ? 'Catat sebagai uang masuk ke dompet'
                        : 'Catat sebagai uang keluar dari dompet',
                    style: textTheme.titleMedium,
                  ),
                  subtitle: Text(
                    'Saldo dompet otomatis ikut diperbarui',
                    style: textTheme.bodySmall,
                  ),
                ),
                if (recordToWallet) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final w in store.wallets)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              selected: selectedWalletId == w.id,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setSheetState(() => selectedWalletId = w.id),
                              avatar: Icon(
                                w.icon,
                                size: 17,
                                color: selectedWalletId == w.id
                                    ? tokens.onAccent
                                    : w.color,
                              ),
                              label: Text(w.name),
                              selectedColor: tokens.ink,
                              backgroundColor: tokens.surface,
                              labelStyle: textTheme.labelMedium?.copyWith(
                                color: selectedWalletId == w.id
                                    ? tokens.surface
                                    : tokens.ink,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Konfirmasi Lunas'),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (confirmed == true) {
      await store.settleDebt(
        debt,
        walletId: recordToWallet ? selectedWalletId : null,
      );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            recordToWallet
                ? 'Lunas & tercatat ke saldo dompet.'
                : 'Catatan ditandai lunas.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final items = _filteredDebts(store.debts);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 104),
      children: [
        Text('Patungan & Hutang', style: textTheme.headlineMedium),
        const SizedBox(height: 14),
        StationerySurface(
          showPersonaRibbon: true,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Piutang (Talangin)', style: textTheme.labelSmall),
                    const SizedBox(height: 4),
                    AnimatedRupiah(
                      amount: store.totalUnsettledReceivable,
                      style: textTheme.titleLarge?.copyWith(
                        color: tokens.income,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Teman belum ganti', style: textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 14),
                color: tokens.border.withOpacity(0.75),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hutang (Pinjam)', style: textTheme.labelSmall),
                    const SizedBox(height: 4),
                    AnimatedRupiah(
                      amount: store.totalUnsettledPayable,
                      style: textTheme.titleLarge?.copyWith(
                        color: tokens.expense,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text('Perlu kamu bayar', style: textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _TabPill(
              label: 'Talangin',
              selected: _filter == _DebtFilter.receivable,
              onTap: () => setState(() => _filter = _DebtFilter.receivable),
            ),
            _TabPill(
              label: 'Pinjam',
              selected: _filter == _DebtFilter.payable,
              onTap: () => setState(() => _filter = _DebtFilter.payable),
            ),
            _TabPill(
              label: 'Lunas',
              selected: _filter == _DebtFilter.settled,
              onTap: () => setState(() => _filter = _DebtFilter.settled),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          StationeryEmptyState(
            assetPath: 'assets/images/empty_debts.png',
            title: switch (_filter) {
              _DebtFilter.receivable => 'Tidak ada piutang aktif',
              _DebtFilter.payable => 'Bebas hutang teman',
              _DebtFilter.settled => 'Belum ada riwayat lunas',
            },
            message: switch (_filter) {
              _DebtFilter.receivable =>
                'Kalau kamu talangin makan, print tugas, atau patungan kos, catat di sini biar tidak lupa.',
              _DebtFilter.payable =>
                'Semua urusan pinjam-meminjam bersih. Catat di sini jika ada tanggungan baru.',
              _DebtFilter.settled =>
                'Catatan patungan atau hutang yang sudah beres akan tersimpan rapi di tab ini.',
            },
            actionLabel: _filter == _DebtFilter.settled
                ? null
                : 'Catat Patungan / Hutang',
            onAction: _filter == _DebtFilter.settled
                ? null
                : () => DebtEditorSheet.show(
                      context,
                      store: store,
                      initialDirection: _filter == _DebtFilter.payable
                          ? DebtDirection.payable
                          : DebtDirection.receivable,
                    ),
          )
        else
          StationerySurface(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: tokens.border.withOpacity(0.55),
                    ),
                  _DebtRow(
                    key: ValueKey(items[i].id),
                    debt: items[i],
                    onSettle: () => _confirmSettle(items[i]),
                    onUnsettle: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      await store.unsettleDebt(items[i]);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Status lunas dibatalkan.'),
                        ),
                      );
                    },
                    onDelete: () async {
                      final debt = items[i];
                      final messenger = ScaffoldMessenger.of(context);
                      final ok = await confirmDeleteDialog(
                        context,
                        title: 'Hapus Catatan Patungan?',
                        message:
                            'Catatan ${debt.personName} sebesar ${formatRupiah(debt.amount)} akan dihapus permanen.',
                      );
                      if (!ok || !mounted) return;
                      await store.deleteDebt(debt.id);
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Catatan ${debt.personName} dihapus.'),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) {
        HapticFeedback.selectionClick();
        onTap();
      },
      selectedColor: tokens.ink,
      backgroundColor: tokens.surface,
      side: BorderSide(color: selected ? tokens.ink : tokens.border),
      labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected ? tokens.surface : tokens.ink,
          ),
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow({
    super.key,
    required this.debt,
    required this.onSettle,
    required this.onUnsettle,
    required this.onDelete,
  });

  final DebtItem debt;
  final VoidCallback onSettle;
  final VoidCallback onUnsettle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isReceivable = debt.direction == DebtDirection.receivable;
    final tone = isReceivable ? tokens.income : tokens.expense;
    final tint = isReceivable ? tokens.incomeSoft : tokens.expenseSoft;
    final initial =
        debt.personName.trim().isNotEmpty ? debt.personName.trim()[0].toUpperCase() : '?';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 10, 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: tint,
                foregroundColor: tone,
                child: Text(
                  initial,
                  style: textTheme.titleMedium?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            debt.personName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: 8),
                        PersonaStamp(
                          label: debt.isSettled
                              ? 'LUNAS'
                              : (isReceivable ? 'TALANGIN' : 'PINJAM'),
                          backgroundColor:
                              debt.isSettled ? tokens.surfaceAlt : tint,
                          foregroundColor:
                              debt.isSettled ? tokens.inkMuted : tone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${debt.description.isNotEmpty ? '${debt.description} · ' : ''}${formatShortDate(debt.createdAt)}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatRupiah(debt.amount),
                style: textTheme.titleMedium?.copyWith(
                  color: debt.isSettled ? tokens.inkMuted : tone,
                  fontWeight: FontWeight.w800,
                  fontFeatures: kTabularFigures,
                  decoration:
                      debt.isSettled ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onDelete,
                tooltip: 'Hapus catatan',
                icon: Icon(
                  Icons.delete_outline_rounded,
                  size: 20,
                  color: tokens.inkMuted,
                ),
              ),
              const SizedBox(width: 4),
              if (!debt.isSettled)
                FilledButton.tonalIcon(
                  onPressed: onSettle,
                  style: FilledButton.styleFrom(
                    backgroundColor: tint,
                    foregroundColor: tone,
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Tandai Lunas'),
                )
              else
                OutlinedButton(
                  onPressed: onUnsettle,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  child: const Text('Batal Lunas'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet to add a friend IOU (Piutang / Hutang).
class DebtEditorSheet extends StatefulWidget {
  const DebtEditorSheet({
    super.key,
    required this.store,
    this.initialDirection = DebtDirection.receivable,
  });

  final FinanceStore store;
  final DebtDirection initialDirection;

  static Future<bool?> show(
    BuildContext context, {
    required FinanceStore store,
    DebtDirection initialDirection = DebtDirection.receivable,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      sheetAnimationStyle: AnimationStyle(
        duration: const Duration(milliseconds: 320),
        reverseDuration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      builder: (_) => RepaintBoundary(
        child: DebtEditorSheet(
          store: store,
          initialDirection: initialDirection,
        ),
      ),
    );
  }

  @override
  State<DebtEditorSheet> createState() => _DebtEditorSheetState();
}

class _DebtEditorSheetState extends State<DebtEditorSheet> {
  late DebtDirection _direction;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  bool _affectWalletNow = false;
  late String _selectedWalletId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _direction = widget.initialDirection;
    _selectedWalletId = widget.store.wallets.isNotEmpty
        ? widget.store.wallets.first.id
        : 'cash';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;

    if (name.isEmpty) {
      setState(() => _error = 'Nama teman wajib diisi.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Nominal harus lebih dari Rp0.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    await widget.store.addDebt(
      direction: _direction,
      personName: name,
      amount: amount,
      description: _descController.text.trim(),
      walletId: _affectWalletNow ? _selectedWalletId : null,
    );
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
            Text('Catat Patungan / Hutang', style: textTheme.titleLarge),
            const SizedBox(height: 14),
            SegmentedButton<DebtDirection>(
              segments: const [
                ButtonSegment(
                  value: DebtDirection.receivable,
                  label: Text('Aku Talangin'),
                  icon: Icon(Icons.south_west_rounded, size: 16),
                ),
                ButtonSegment(
                  value: DebtDirection.payable,
                  label: Text('Aku Pinjam'),
                  icon: Icon(Icons.north_east_rounded, size: 16),
                ),
              ],
              selected: {_direction},
              showSelectedIcon: false,
              onSelectionChanged: (s) {
                HapticFeedback.selectionClick();
                setState(() => _direction = s.first);
              },
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama Teman',
                hintText: 'Misal: Dimas, Nadia, Raka',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                prefixText: 'Rp ',
                hintText: '25000',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: 'Keperluan / Deskripsi',
                hintText: 'Misal: Patungan print tugas atau ayam geprek',
                prefixIcon: Icon(Icons.edit_note_rounded),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _affectWalletNow,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _affectWalletNow = v);
              },
              title: Text(
                'Ubah saldo dompet sekarang?',
                style: textTheme.titleMedium,
              ),
              subtitle: Text(
                _direction == DebtDirection.receivable
                    ? 'Potong saldo dompet saat ini (matikan jika sudah tercatat lewat transaksi/notif)'
                    : 'Tambah saldo dompet saat ini (matikan jika cuma dibayarin teman)',
                style: textTheme.bodySmall,
              ),
            ),
            if (_affectWalletNow) ...[
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final w in widget.store.wallets)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          selected: _selectedWalletId == w.id,
                          showCheckmark: false,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedWalletId = w.id);
                          },
                          avatar: Icon(
                            w.icon,
                            size: 17,
                            color: _selectedWalletId == w.id
                                ? tokens.onAccent
                                : w.color,
                          ),
                          label: Text(w.name),
                          selectedColor: tokens.ink,
                          backgroundColor: tokens.surface,
                          labelStyle: textTheme.labelMedium?.copyWith(
                            color: _selectedWalletId == w.id
                                ? tokens.surface
                                : tokens.ink,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: textTheme.bodySmall?.copyWith(
                  color: tokens.expense,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Simpan Catatan'),
            ),
          ],
        ),
      ),
    );
  }
}
