import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/finance_store.dart';
import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/donut_chart.dart';
import '../widgets/persona_motifs.dart';
import '../widgets/stationery_widgets.dart';
import '../widgets/transaction_editor_sheet.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key, required this.store});

  final FinanceStore store;

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.month;
  DateTime _anchor = DateTime.now();
  TransactionType _chartType = TransactionType.expense;
  String? _selectedCategoryId;

  void _stepMonth(int delta) {
    HapticFeedback.selectionClick();
    setState(() {
      _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
      _selectedCategoryId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;

    final items = store.transactionsInPeriod(_period, _anchor);
    final income = store.sumByType(items, TransactionType.income);
    final expense = store.sumByType(items, TransactionType.expense);
    final net = income - expense;
    final summaries = store.categoryBreakdown(items, _chartType);
    final activeTotal = _chartType == TransactionType.expense ? expense : income;
    final totalFlow = income + expense;
    final chartAnimKey =
        '${_chartType.name}_${_period.name}_${_anchor.year}_${_anchor.month}';

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 104),
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Ringkasan', style: textTheme.headlineMedium),
            ),
            SegmentedButton<AnalyticsPeriod>(
              segments: const [
                ButtonSegment(
                  value: AnalyticsPeriod.week,
                  label: Text('7 Hari'),
                ),
                ButtonSegment(
                  value: AnalyticsPeriod.month,
                  label: Text('Bulanan'),
                ),
              ],
              selected: {_period},
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                side: WidgetStatePropertyAll(BorderSide(color: tokens.border)),
              ),
              onSelectionChanged: (set) {
                HapticFeedback.selectionClick();
                setState(() {
                  _period = set.first;
                  _anchor = DateTime.now();
                  _selectedCategoryId = null;
                });
              },
            ),
          ],
        ),
        if (_period == AnalyticsPeriod.month) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => _stepMonth(-1),
                tooltip: 'Bulan sebelumnya',
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              Text(
                formatMonthYear(_anchor),
                style: textTheme.titleMedium?.copyWith(color: tokens.ink),
              ),
              IconButton(
                onPressed: () => _stepMonth(1),
                tooltip: 'Bulan berikutnya',
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'Menampilkan transaksi 7 hari terakhir',
            style: textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        StationerySurface(
          showPersonaRibbon: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Selisih Arus Kas',
                      style: textTheme.bodySmall,
                    ),
                  ),
                  PersonaStamp(
                    label: net >= 0 ? 'SURPLUS' : 'DEFISIT',
                    backgroundColor:
                        net >= 0 ? tokens.incomeSoft : tokens.expenseSoft,
                    foregroundColor: net >= 0 ? tokens.income : tokens.expense,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              AnimatedRupiah(
                amount: net,
                withSign: true,
                style: textTheme.headlineMedium?.copyWith(
                  color: net >= 0 ? tokens.income : tokens.expense,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 10,
                  child: totalFlow == 0
                      ? ColoredBox(color: tokens.surfaceAlt)
                      : Row(
                          children: [
                            if (income > 0)
                              Expanded(
                                flex: income,
                                child: ColoredBox(color: tokens.income),
                              ),
                            if (income > 0 && expense > 0)
                              const SizedBox(width: 2),
                            if (expense > 0)
                              Expanded(
                                flex: expense,
                                child: ColoredBox(color: tokens.expense),
                              ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Masuk', style: textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Text(
                          formatRupiah(income),
                          style: textTheme.titleMedium?.copyWith(
                            color: tokens.income,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('Total Keluar', style: textTheme.labelSmall),
                        const SizedBox(height: 2),
                        Text(
                          formatRupiah(expense),
                          style: textTheme.titleMedium?.copyWith(
                            color: tokens.expense,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        PersonaSectionHeading(
          title: 'Porsi Kategori',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ChoiceChip(
                label: const Text('Keluar'),
                selected: _chartType == TransactionType.expense,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _chartType = TransactionType.expense;
                  _selectedCategoryId = null;
                }),
                selectedColor: tokens.expenseSoft,
                side: BorderSide(
                  color: _chartType == TransactionType.expense
                      ? tokens.expense
                      : tokens.border,
                ),
                labelStyle: textTheme.labelMedium?.copyWith(
                  color: _chartType == TransactionType.expense
                      ? tokens.expense
                      : tokens.inkMuted,
                ),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Masuk'),
                selected: _chartType == TransactionType.income,
                showCheckmark: false,
                onSelected: (_) => setState(() {
                  _chartType = TransactionType.income;
                  _selectedCategoryId = null;
                }),
                selectedColor: tokens.incomeSoft,
                side: BorderSide(
                  color: _chartType == TransactionType.income
                      ? tokens.income
                      : tokens.border,
                ),
                labelStyle: textTheme.labelMedium?.copyWith(
                  color: _chartType == TransactionType.income
                      ? tokens.income
                      : tokens.inkMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (summaries.isEmpty)
          StationeryEmptyState(
            assetPath: 'assets/images/empty_transactions.png',
            title: _chartType == TransactionType.expense
                ? 'Belum ada pengeluaran di periode ini'
                : 'Belum ada pemasukan di periode ini',
            message:
                'Grafik porsi kategori otomatis muncul setelah ada transaksi di rentang waktu ini.',
            actionLabel: 'Catat Transaksi',
            onAction: () => TransactionEditorSheet.show(
              context,
              store: store,
              initialType: _chartType,
            ),
          )
        else ...[
          StationerySurface(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              children: [
                StationeryDonutChart(
                  animationKey: chartAnimKey,
                  summaries: summaries,
                  totalAmount: activeTotal,
                  centerLabel: _chartType == TransactionType.expense
                      ? 'Total Keluar'
                      : 'Total Masuk',
                  selectedCategoryId: _selectedCategoryId,
                  onSelectCategory: (id) =>
                      setState(() => _selectedCategoryId = id),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ketuk bagian grafik atau daftar di bawah untuk detail',
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Divider(height: 1, color: tokens.border.withOpacity(0.6)),
                const SizedBox(height: 8),
                for (var i = 0; i < summaries.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      color: tokens.border.withOpacity(0.45),
                    ),
                  _CategoryRankRow(
                    animationKey: chartAnimKey,
                    summary: summaries[i],
                    selected: _selectedCategoryId == summaries[i].category.id,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        final id = summaries[i].category.id;
                        _selectedCategoryId =
                            _selectedCategoryId == id ? null : id;
                      });
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CategoryRankRow extends StatelessWidget {
  const _CategoryRankRow({
    required this.animationKey,
    required this.summary,
    required this.selected,
    required this.onTap,
  });

  final String animationKey;
  final CategorySummary summary;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final pct = (summary.ratio * 100).round();
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 11),
        decoration: BoxDecoration(
          color: selected
              ? summary.category.tileBg(tokens.isDark).withOpacity(0.7)
              : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: summary.category.tileBg(tokens.isDark),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      summary.category.icon,
                      size: 18,
                      color: summary.category.tileFg(tokens.isDark),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        summary.category.label,
                        style: textTheme.titleMedium,
                      ),
                      Text(
                        '${summary.count} transaksi · $pct%',
                        style: textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  formatRupiah(summary.total),
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabularFigures,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                key: ValueKey('${animationKey}_${summary.category.id}'),
                tween: Tween<double>(
                  begin: disableAnimations ? summary.ratio : 0,
                  end: summary.ratio,
                ),
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 460),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: tokens.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation(summary.category.color),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
