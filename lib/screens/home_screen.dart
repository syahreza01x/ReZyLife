import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/finance_store.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/auto_capture_sheet.dart';
import '../widgets/persona_date_header.dart';
import '../widgets/persona_motifs.dart';
import '../widgets/stationery_widgets.dart';
import '../widgets/transaction_editor_sheet.dart';
import '../widgets/wallets_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.store,
    this.onToggleTheme,
  });

  final FinanceStore store;
  final VoidCallback? onToggleTheme;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _selectedWalletId;
  TransactionType? _selectedType;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TransactionItem> _filteredTransactions(List<TransactionItem> all) {
    final q = _searchQuery.trim().toLowerCase();
    return all.where((tx) {
      if (_selectedWalletId != null &&
          tx.walletId != _selectedWalletId &&
          tx.toWalletId != _selectedWalletId) {
        return false;
      }
      if (_selectedType != null && tx.type != _selectedType) {
        return false;
      }
      if (q.isNotEmpty) {
        final cat = categoryById(tx.categoryId).label.toLowerCase();
        final desc = tx.description.toLowerCase();
        final wName =
            widget.store.walletById(tx.walletId)?.name.toLowerCase() ?? '';
        if (!desc.contains(q) && !cat.contains(q) && !wName.contains(q)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  List<_DayGroup> _groupByDay(List<TransactionItem> items) {
    final map = <DateTime, List<TransactionItem>>{};
    for (final tx in items) {
      final key = DateTime(tx.createdAt.year, tx.createdAt.month, tx.createdAt.day);
      map.putIfAbsent(key, () => []).add(tx);
    }
    final days = map.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final d in days) _DayGroup(date: d, items: map[d]!)];
  }

  Future<void> _deleteWithUndo(TransactionItem tx) async {
    final label =
        tx.description.isNotEmpty ? tx.description : categoryById(tx.categoryId).label;
    final ok = await confirmDeleteDialog(
      context,
      title: 'Hapus Transaksi?',
      message: 'Transaksi "$label" (${formatRupiah(tx.amount)}) akan dihapus dan saldo dompet akan disesuaikan kembali.',
    );
    if (!ok || !mounted) return;

    await widget.store.deleteTransaction(tx);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'Transaksi ${formatRupiah(tx.amount)} dihapus',
          ),
          action: SnackBarAction(
            label: 'Urungkan',
            onPressed: () => widget.store.restoreTransaction(tx),
          ),
        ),
      );
  }

  void _resetFilters() {
    setState(() {
      _selectedWalletId = null;
      _selectedType = null;
      _searchQuery = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();

    final monthItems = store.transactionsInPeriod(AnalyticsPeriod.month, now);
    final monthIncome = store.sumByType(monthItems, TransactionType.income);
    final monthExpense = store.sumByType(monthItems, TransactionType.expense);
    final filtered = _filteredTransactions(store.transactions);
    final dayGroups = _groupByDay(filtered);
    final hasAnyTx = store.transactions.isNotEmpty;
    final hasActiveFilter = _selectedWalletId != null ||
        _selectedType != null ||
        _searchQuery.trim().isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 104),
      children: [
        PersonaDateHeader(
          now: now,
          preset: store.themePreset,
          onTogglePreset: widget.onToggleTheme ?? store.toggleThemePreset,
          autoCaptureActive: store.isAutoCaptureActive,
          onOpenAutoCapture: () => AutoCaptureSheet.show(context, store),
        ),
        const SizedBox(height: 18),
        _TotalBalanceCard(
          totalBalance: store.totalBalance,
          monthIncome: monthIncome,
          monthExpense: monthExpense,
          hideBalance: store.hideBalance,
          monthLabel: formatMonthYear(now),
          onToggleHide: store.toggleHideBalance,
          onOpenTransfer: () => TransactionEditorSheet.show(
            context,
            store: store,
            initialType: TransactionType.transfer,
          ),
        ),
        const SizedBox(height: 20),
        PersonaSectionHeading(
          title: 'Dompet Kamu',
          trailing: TextButton.icon(
            onPressed: () => WalletsManagerSheet.show(context, store),
            icon: const Icon(Icons.tune_rounded, size: 17),
            label: const Text('Atur Saldo'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: store.wallets.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final wallet = store.wallets[index];
              final isSelected = _selectedWalletId == wallet.id;
              return _WalletRailCard(
                key: ValueKey(wallet.id),
                wallet: wallet,
                selected: isSelected,
                hideBalance: store.hideBalance,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedWalletId = isSelected ? null : wallet.id;
                  });
                },
                onLongPress: () => WalletsManagerSheet.show(context, store),
              );
            },
          ),
        ),
        const SizedBox(height: 22),
        PersonaSectionHeading(
          title: 'Catatan Transaksi',
          trailing: hasActiveFilter
              ? TextButton(
                  onPressed: _resetFilters,
                  child: const Text('Reset Filter'),
                )
              : null,
        ),
        if (hasAnyTx) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Cari catatan, kategori, atau dompet...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      tooltip: 'Hapus pencarian',
                      icon: const Icon(Icons.close_rounded, size: 18),
                    )
                  : null,
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChipItem(
                  label: 'Semua',
                  selected: _selectedType == null,
                  onTap: () => setState(() => _selectedType = null),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Keluar',
                  selected: _selectedType == TransactionType.expense,
                  onTap: () =>
                      setState(() => _selectedType = TransactionType.expense),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Masuk',
                  selected: _selectedType == TransactionType.income,
                  onTap: () =>
                      setState(() => _selectedType = TransactionType.income),
                ),
                const SizedBox(width: 8),
                _FilterChipItem(
                  label: 'Transfer',
                  selected: _selectedType == TransactionType.transfer,
                  onTap: () =>
                      setState(() => _selectedType = TransactionType.transfer),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        if (!hasAnyTx)
          StationeryEmptyState(
            assetPath: 'assets/images/empty_transactions.png',
            title: 'Buku kas masih bersih',
            message:
                'Mulai catat uang masuk atau jajan hari ini. Saldo Cash, BRImo, GoPay, DANA, dan ShopeePay otomatis terhitung.',
            actionLabel: 'Catat Transaksi Pertama',
            onAction: () =>
                TransactionEditorSheet.show(context, store: store),
          )
        else if (dayGroups.isEmpty)
          StationerySurface(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            child: Column(
              children: [
                Icon(
                  Icons.filter_list_off_rounded,
                  size: 32,
                  color: tokens.inkMuted,
                ),
                const SizedBox(height: 10),
                Text(
                  'Tidak ada transaksi yang cocok',
                  style: textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Coba ganti kata kunci pencarian atau pilih dompet lain.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _resetFilters,
                  child: const Text('Tampilkan Semua'),
                ),
              ],
            ),
          )
        else
          for (final group in dayGroups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      formatDaySectionHeader(group.date, now: now),
                      style: textTheme.labelMedium?.copyWith(
                        color: tokens.inkMuted,
                      ),
                    ),
                  ),
                  if (group.netCashflow != 0)
                    Text(
                      formatRupiah(group.netCashflow, withSign: true),
                      style: textTheme.labelMedium?.copyWith(
                        color: group.netCashflow > 0
                            ? tokens.income
                            : tokens.inkMuted,
                        fontFeatures: kTabularFigures,
                      ),
                    ),
                ],
              ),
            ),
            StationerySurface(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < group.items.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 66,
                        color: tokens.border.withOpacity(0.55),
                      ),
                    _TransactionRow(
                      key: ValueKey(group.items[i].id),
                      tx: group.items[i],
                      store: store,
                      onTap: () => TransactionEditorSheet.show(
                        context,
                        store: store,
                        existing: group.items[i],
                      ),
                      onDismissed: () => _deleteWithUndo(group.items[i]),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class _TotalBalanceCard extends StatelessWidget {
  const _TotalBalanceCard({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.hideBalance,
    required this.monthLabel,
    required this.onToggleHide,
    required this.onOpenTransfer,
  });

  final int totalBalance;
  final int monthIncome;
  final int monthExpense;
  final bool hideBalance;
  final String monthLabel;
  final VoidCallback onToggleHide;
  final VoidCallback onOpenTransfer;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isP5 = tokens.preset == PersonaThemePreset.shibuya;
    final moon = PersonaMoonPhaseIcon(
      date: DateTime.now(),
      size: 13,
      litColor: tokens.accent,
      shadowColor: tokens.surface,
      outlineColor: tokens.ink,
    );

    return StationerySurface(
      showPersonaRibbon: true,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Total Uang',
                style: textTheme.titleMedium?.copyWith(color: tokens.inkMuted),
              ),
              IconButton(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onToggleHide();
                },
                tooltip: hideBalance ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  hideBalance
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                  color: tokens.inkMuted,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isP5)
                          const PhantomMaskBadge()
                        else
                          const SeesArmbandBadge(),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: isP5
                                ? tokens.accent
                                : tokens.surface.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isP5
                                  ? Colors.white.withOpacity(0.75)
                                  : tokens.accent.withOpacity(0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ExcludeSemantics(
                                child: isP5
                                    ? const PersonaStarIcon(
                                        size: 12,
                                        color: Colors.white,
                                        outlineColor: Color(0xFF101015),
                                      )
                                    : moon,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isP5 ? 'ROYAL' : 'RELOAD',
                                maxLines: 1,
                                style: textTheme.labelSmall?.copyWith(
                                  fontSize: 10.5,
                                  color: isP5 ? Colors.white : tokens.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ExcludeSemantics(
                child: isP5
                    ? Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: PersonaStarIcon(
                          size: 18,
                          color: tokens.accent,
                          outlineColor: Colors.white,
                        ),
                      )
                    : Container(
                        width: 4,
                        height: 28,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              tokens.accent,
                              tokens.accentSecondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
              ),
              Expanded(
                child: AnimatedRupiah(
                  amount: totalBalance,
                  hidden: hideBalance,
                  style: textTheme.displaySmall?.copyWith(color: tokens.ink),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Gabungan seluruh dompet · $monthLabel',
                  style: textTheme.bodySmall,
                ),
              ),
              InkWell(
                onTap: onOpenTransfer,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.swap_horiz_rounded,
                        size: 16,
                        color: tokens.accent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pindah',
                        style: textTheme.labelMedium?.copyWith(
                          color: tokens.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: tokens.border.withOpacity(0.7)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InlineFlowMetric(
                  label: 'Masuk bulan ini',
                  amount: monthIncome,
                  hidden: hideBalance,
                  color: tokens.income,
                  tint: tokens.incomeSoft,
                  icon: Icons.south_west_rounded,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: tokens.border.withOpacity(0.7),
              ),
              Expanded(
                child: _InlineFlowMetric(
                  label: 'Keluar bulan ini',
                  amount: monthExpense,
                  hidden: hideBalance,
                  color: tokens.expense,
                  tint: tokens.expenseSoft,
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InlineFlowMetric extends StatelessWidget {
  const _InlineFlowMetric({
    required this.label,
    required this.amount,
    required this.hidden,
    required this.color,
    required this.tint,
    required this.icon,
  });

  final String label;
  final int amount;
  final bool hidden;
  final Color color;
  final Color tint;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        ExcludeSemantics(
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.labelSmall,
              ),
              const SizedBox(height: 1),
              AnimatedRupiah(
                amount: amount,
                hidden: hidden,
                compact: amount >= 10000000,
                style: textTheme.labelLarge?.copyWith(
                  color: color,
                  fontFeatures: kTabularFigures,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WalletRailCard extends StatelessWidget {
  const _WalletRailCard({
    super.key,
    required this.wallet,
    required this.selected,
    required this.hideBalance,
    required this.onTap,
    required this.onLongPress,
  });

  final Wallet wallet;
  final bool selected;
  final bool hideBalance;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isP5 = tokens.preset == PersonaThemePreset.shibuya;
    final iconColor = tokens.isDark
        ? Color.lerp(wallet.color, Colors.white, 0.35)!
        : wallet.color;

    return Semantics(
      button: true,
      selected: selected,
      label:
          'Dompet ${wallet.name}, saldo ${hideBalance ? 'tersembunyi' : formatRupiah(wallet.balance)}',
      child: Material(
        color: selected ? tokens.accentSoft : tokens.surface,
        shape: isP5
            ? RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: selected ? tokens.accent : tokens.border,
                  width: selected ? 1.5 : 1.1,
                ),
              )
            : BeveledRectangleBorder(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                  topRight: Radius.circular(4),
                  bottomLeft: Radius.circular(4),
                ),
                side: BorderSide(
                  color: selected ? tokens.accent : tokens.border,
                  width: selected ? 1.5 : 1.1,
                ),
              ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: 138,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: wallet.color
                              .withOpacity(tokens.isDark ? 0.24 : 0.14),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: WalletIcon(
                          wallet: wallet,
                          size: 16,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          wallet.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelLarge?.copyWith(
                            color: tokens.ink,
                          ),
                        ),
                      ),
                      if (selected)
                        ExcludeSemantics(
                          child: isP5
                              ? PersonaStarIcon(
                                  size: 12,
                                  color: tokens.accent,
                                  outlineColor: Colors.white,
                                )
                              : Icon(
                                  Icons.bolt_rounded,
                                  size: 14,
                                  color: tokens.accent,
                                ),
                        ),
                    ],
                  ),
                  Text(
                    hideBalance
                        ? 'Rp •••••'
                        : formatRupiah(
                            wallet.balance,
                            compact: wallet.balance.abs() >= 10000000,
                          ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: tokens.ink,
                      fontWeight: FontWeight.w800,
                      fontFeatures: kTabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChipItem extends StatelessWidget {
  const _FilterChipItem({
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

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    super.key,
    required this.tx,
    required this.store,
    required this.onTap,
    required this.onDismissed,
  });

  final TransactionItem tx;
  final FinanceStore store;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final category = categoryById(tx.categoryId);
    final fromName = store.walletById(tx.walletId)?.name ?? tx.walletId;
    final toName = tx.toWalletId != null
        ? (store.walletById(tx.toWalletId!)?.name ?? tx.toWalletId!)
        : null;

    final isAuto = tx.source != 'manual';
    final title = tx.description.isNotEmpty ? tx.description : category.label;
    final walletLabel = tx.type == TransactionType.transfer
        ? '$fromName → ${toName ?? '?'}'
        : fromName;
    final timeLabel = formatTimeHm(tx.createdAt);

    final (String amountText, Color amountColor) = switch (tx.type) {
      TransactionType.income => (
          '+${formatRupiah(tx.amount)}',
          tokens.income,
        ),
      TransactionType.expense => (
          '-${formatRupiah(tx.amount)}',
          tokens.expense,
        ),
      TransactionType.transfer => (
          '⇄ ${formatRupiah(tx.amount)}',
          tokens.transfer,
        ),
    };

    // Tap edits (and exposes Delete); long-press quick-deletes with Undo so
    // horizontal left/right swipes stay 100% conflict-free for tab PageView.
    return InkWell(
      onTap: onTap,
      onLongPress: () {
        HapticFeedback.mediumImpact();
        onDismissed();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: category.tileBg(tokens.isDark),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  category.icon,
                  size: 20,
                  color: category.tileFg(tokens.isDark),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(color: tokens.ink),
                  ),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(
                      style: textTheme.bodySmall?.copyWith(
                        fontFeatures: kTabularFigures,
                      ),
                      children: [
                        TextSpan(text: '$walletLabel · $timeLabel'),
                        if (isAuto)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5.5,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.accentSoft,
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: tokens.accent.withOpacity(0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'Auto',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 9.5,
                                    height: 1.2,
                                    color: tokens.accent,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              amountText,
              style: textTheme.titleMedium?.copyWith(
                color: amountColor,
                fontWeight: FontWeight.w800,
                fontFeatures: kTabularFigures,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayGroup {
  const _DayGroup({required this.date, required this.items});

  final DateTime date;
  final List<TransactionItem> items;

  int get netCashflow {
    var net = 0;
    for (final tx in items) {
      if (tx.type == TransactionType.income) net += tx.amount;
      if (tx.type == TransactionType.expense) net -= tx.amount;
    }
    return net;
  }
}
