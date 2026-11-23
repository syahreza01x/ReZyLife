import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/finance_store.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'stationery_widgets.dart';

/// Fast <5s transaction add/edit bottom sheet with an Indonesian-friendly
/// custom numpad (`000` shortcut), quick-amount chips, and inline validation.
class TransactionEditorSheet extends StatefulWidget {
  const TransactionEditorSheet({
    super.key,
    required this.store,
    this.existing,
    this.initialType = TransactionType.expense,
    this.initialWalletId,
  });

  final FinanceStore store;
  final TransactionItem? existing;
  final TransactionType initialType;
  final String? initialWalletId;

  static Future<bool?> show(
    BuildContext context, {
    required FinanceStore store,
    TransactionItem? existing,
    TransactionType initialType = TransactionType.expense,
    String? initialWalletId,
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
        child: TransactionEditorSheet(
          store: store,
          existing: existing,
          initialType: initialType,
          initialWalletId: initialWalletId,
        ),
      ),
    );
  }

  @override
  State<TransactionEditorSheet> createState() => _TransactionEditorSheetState();
}

class _TransactionEditorSheetState extends State<TransactionEditorSheet> {
  late TransactionType _type;
  late String _digits;
  late String _categoryId;
  late String _walletId;
  String? _toWalletId;
  late DateTime _createdAt;
  late final TextEditingController _descController;
  final FocusNode _descFocus = FocusNode();

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final wallets = widget.store.wallets;
    final defaultWallet = wallets.isNotEmpty ? wallets.first.id : 'cash';

    _type = existing?.type ?? widget.initialType;
    _digits = existing != null ? existing.amount.toString() : '';
    _categoryId = existing?.categoryId ?? categoriesForType(_type).first.id;
    _walletId = existing?.walletId ?? widget.initialWalletId ?? defaultWallet;
    _toWalletId = existing?.toWalletId ?? _fallbackDestination(_walletId);
    _createdAt = existing?.createdAt ?? DateTime.now();
    _descController = TextEditingController(text: existing?.description ?? '');
  }

  @override
  void dispose() {
    _descController.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  String? _fallbackDestination(String fromId) {
    for (final w in widget.store.wallets) {
      if (w.id != fromId) return w.id;
    }
    return null;
  }

  void _switchType(TransactionType next) {
    if (_type == next) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = next;
      _error = null;
      final cats = categoriesForType(next);
      if (!cats.any((c) => c.id == _categoryId)) {
        _categoryId = cats.first.id;
      }
      if (next == TransactionType.transfer &&
          (_toWalletId == null || _toWalletId == _walletId)) {
        _toWalletId = _fallbackDestination(_walletId);
      }
    });
  }

  void _appendKey(String key) {
    HapticFeedback.selectionClick();
    setState(() {
      _error = null;
      if (key == 'BACK') {
        if (_digits.isNotEmpty) {
          _digits = _digits.substring(0, _digits.length - 1);
        }
        return;
      }
      if (_digits.isEmpty && (key == '0' || key == '000')) return;
      final candidate = '$_digits$key';
      if (candidate.length <= 10) {
        _digits = candidate;
      }
    });
  }

  void _addPreset(int value) {
    HapticFeedback.selectionClick();
    final current = int.tryParse(_digits) ?? 0;
    final next = current + value;
    if (next <= 9999999999) {
      setState(() {
        _error = null;
        _digits = next.toString();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _createdAt = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _createdAt.hour,
        _createdAt.minute,
      );
    });
  }

  Future<void> _save() async {
    final amount = int.tryParse(_digits) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Masukkan nominal lebih dari Rp0.');
      return;
    }
    if (_type == TransactionType.transfer) {
      if (_toWalletId == null || _toWalletId == _walletId) {
        setState(() => _error = 'Pilih dompet tujuan yang berbeda.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        final previous = widget.existing!;
        final updated = previous.copyWith(
          type: _type,
          amount: amount,
          categoryId: _type == TransactionType.transfer ? 'transfer' : _categoryId,
          walletId: _walletId,
          toWalletId: _type == TransactionType.transfer ? _toWalletId : null,
          clearToWallet: _type != TransactionType.transfer,
          description: _descController.text.trim(),
          createdAt: _createdAt,
        );
        await widget.store.updateTransaction(previous, updated);
      } else {
        await widget.store.addTransaction(
          type: _type,
          amount: amount,
          categoryId: _categoryId,
          walletId: _walletId,
          toWalletId: _toWalletId,
          description: _descController.text.trim(),
          createdAt: _createdAt,
        );
      }
      HapticFeedback.lightImpact();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Gagal menyimpan transaksi: $e';
        });
      }
    }
  }

  Future<void> _deleteExisting() async {
    final existing = widget.existing;
    if (existing == null) return;
    final label = existing.description.isNotEmpty
        ? existing.description
        : categoryById(existing.categoryId).label;
    final ok = await confirmDeleteDialog(
      context,
      title: 'Hapus Transaksi?',
      message:
          'Transaksi "$label" (${formatRupiah(existing.amount)}) akan dihapus dan saldo dompet akan disesuaikan kembali.',
    );
    if (!ok || !mounted) return;

    setState(() => _saving = true);
    await widget.store.deleteTransaction(existing);
    HapticFeedback.lightImpact();
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final wallets = widget.store.wallets;
    final categories = categoriesForType(_type);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 80;

    final Color activeTone = switch (_type) {
      TransactionType.expense => tokens.expense,
      TransactionType.income => tokens.income,
      TransactionType.transfer => tokens.transfer,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _isEdit ? 'Edit Transaksi' : 'Catat Transaksi',
                              style: textTheme.titleLarge,
                            ),
                          ),
                          if (_isEdit)
                            IconButton(
                              onPressed: _saving ? null : _deleteExisting,
                              tooltip: 'Hapus transaksi',
                              icon: Icon(
                                Icons.delete_outline_rounded,
                                color: tokens.expense,
                              ),
                            ),
                          TextButton.icon(
                            onPressed: _pickDate,
                            icon: const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                            ),
                            label: Text(formatShortDate(_createdAt)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _TypeSegmentBar(
                        selected: _type,
                        onChanged: _switchType,
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color:
                                _error != null ? tokens.expense : tokens.border,
                            width: 1.2,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  'Rp',
                                  style: textTheme.titleLarge?.copyWith(
                                    color: activeTone,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    formatDigitsGrouped(_digits),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.displaySmall?.copyWith(
                                      fontSize: 28,
                                      color: _digits.isEmpty
                                          ? tokens.inkMuted.withOpacity(0.5)
                                          : tokens.ink,
                                      fontFeatures: kTabularFigures,
                                    ),
                                  ),
                                ),
                                if (_digits.isNotEmpty)
                                  IconButton(
                                    onPressed: () =>
                                        setState(() => _digits = ''),
                                    tooltip: 'Bersihkan nominal',
                                    visualDensity: VisualDensity.compact,
                                    icon: Icon(
                                      Icons.close_rounded,
                                      size: 20,
                                      color: tokens.inkMuted,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  for (final preset in const [
                                    10000,
                                    20000,
                                    50000,
                                    100000,
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: _LightPillChip(
                                        label: '+${preset ~/ 1000}rb',
                                        selected: false,
                                        backgroundColor: tokens.surfaceAlt,
                                        foregroundColor: tokens.ink,
                                        borderColor: Colors.transparent,
                                        onTap: () => _addPreset(preset),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _error!,
                          style: textTheme.bodySmall?.copyWith(
                            color: tokens.expense,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      Text(
                        _type == TransactionType.transfer
                            ? 'Dari Dompet'
                            : 'Dompet',
                        style: textTheme.labelSmall
                            ?.copyWith(color: tokens.inkMuted),
                      ),
                      const SizedBox(height: 6),
                      _WalletChipRow(
                        wallets: wallets,
                        selectedId: _walletId,
                        onSelect: (id) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _walletId = id;
                            if (_type == TransactionType.transfer &&
                                _toWalletId == id) {
                              _toWalletId = _fallbackDestination(id);
                            }
                          });
                        },
                      ),
                      if (_type == TransactionType.transfer) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Ke Dompet',
                          style: textTheme.labelSmall
                              ?.copyWith(color: tokens.inkMuted),
                        ),
                        const SizedBox(height: 6),
                        _WalletChipRow(
                          wallets:
                              wallets.where((w) => w.id != _walletId).toList(),
                          selectedId: _toWalletId,
                          onSelect: (id) {
                            HapticFeedback.selectionClick();
                            setState(() => _toWalletId = id);
                          },
                        ),
                      ] else ...[
                        const SizedBox(height: 10),
                        Text(
                          'Kategori',
                          style: textTheme.labelSmall
                              ?.copyWith(color: tokens.inkMuted),
                        ),
                        const SizedBox(height: 6),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (final cat in categories)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: _LightPillChip(
                                    label: cat.label,
                                    icon: cat.icon,
                                    iconColor: _categoryId == cat.id
                                        ? tokens.onAccent
                                        : cat.tileFg(tokens.isDark),
                                    selected: _categoryId == cat.id,
                                    backgroundColor: _categoryId == cat.id
                                        ? tokens.accent
                                        : tokens.surface,
                                    foregroundColor: _categoryId == cat.id
                                        ? tokens.onAccent
                                        : tokens.ink,
                                    borderColor: _categoryId == cat.id
                                        ? tokens.accent
                                        : tokens.border,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(() => _categoryId = cat.id);
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      TextField(
                        controller: _descController,
                        focusNode: _descFocus,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          labelText: 'Deskripsi',
                          isDense: true,
                          hintText: _type == TransactionType.transfer
                              ? 'Misal: Tarik tunai atau top-up e-wallet'
                              : _type == TransactionType.income
                                  ? 'Misal: Kiriman bulanan atau fee proyek'
                                  : 'Misal: Ayam geprek kantin + es teh',
                          prefixIcon:
                              const Icon(Icons.edit_note_rounded, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!keyboardOpen) ...[
                const SizedBox(height: 10),
                _RupiahNumpad(onKey: _appendKey),
              ],
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: activeTone),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(_isEdit ? 'Simpan Perubahan' : 'Simpan Transaksi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSegmentBar extends StatelessWidget {
  const _TypeSegmentBar({required this.selected, required this.onChanged});

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    const items = [
      (TransactionType.expense, 'Keluar', Icons.north_east_rounded),
      (TransactionType.income, 'Masuk', Icons.south_west_rounded),
      (TransactionType.transfer, 'Transfer', Icons.swap_horiz_rounded),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final item in items)
            Expanded(
              child: InkWell(
                onTap: () => onChanged(item.$1),
                borderRadius: BorderRadius.circular(11),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
                  decoration: BoxDecoration(
                    color: selected == item.$1
                        ? tokens.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    border: selected == item.$1
                        ? Border.all(color: tokens.border)
                        : null,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item.$3,
                          size: 16,
                          color: selected == item.$1
                              ? _toneFor(tokens, item.$1)
                              : tokens.inkMuted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.$2,
                          maxLines: 1,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: selected == item.$1
                                        ? tokens.ink
                                        : tokens.inkMuted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _toneFor(ReZyTokens tokens, TransactionType type) => switch (type) {
        TransactionType.expense => tokens.expense,
        TransactionType.income => tokens.income,
        TransactionType.transfer => tokens.transfer,
      };
}

class _WalletChipRow extends StatelessWidget {
  const _WalletChipRow({
    required this.wallets,
    required this.selectedId,
    required this.onSelect,
  });

  final List<Wallet> wallets;
  final String? selectedId;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final w in wallets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _LightPillChip(
                label: w.name,
                icon: w.icon,
                iconColor: selectedId == w.id ? tokens.onAccent : w.color,
                selected: selectedId == w.id,
                backgroundColor:
                    selectedId == w.id ? tokens.ink : tokens.surface,
                foregroundColor:
                    selectedId == w.id ? tokens.surface : tokens.ink,
                borderColor: selectedId == w.id ? tokens.ink : tokens.border,
                onTap: () => onSelect(w.id),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lightweight tactile pill chip that avoids Material 3 RawChip build overhead
/// so bottom sheets open on frame 0 without dropping the slide-up animation.
class _LightPillChip extends StatelessWidget {
  const _LightPillChip({
    required this.label,
    required this.selected,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.onTap,
    this.icon,
    this.iconColor,
  });

  final String label;
  final bool selected;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: backgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
          side: BorderSide(color: borderColor),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: iconColor ?? foregroundColor),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foregroundColor,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RupiahNumpad extends StatelessWidget {
  const _RupiahNumpad({required this.onKey});

  final ValueChanged<String> onKey;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['000', '0', 'BACK'],
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        for (final row in _rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var i = 0; i < row.length; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Expanded(
                    child: Material(
                      color: tokens.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: tokens.border),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onKey(row[i]),
                        child: SizedBox(
                          height: 44,
                          child: Center(
                            child: row[i] == 'BACK'
                                ? Icon(
                                    Icons.backspace_outlined,
                                    size: 20,
                                    color: tokens.ink,
                                    semanticLabel: 'Hapus digit',
                                  )
                                : Text(
                                    row[i],
                                    style: textTheme.titleMedium?.copyWith(
                                      fontSize: row[i] == '000' ? 15 : 18,
                                      fontWeight: FontWeight.w700,
                                      fontFeatures: kTabularFigures,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
