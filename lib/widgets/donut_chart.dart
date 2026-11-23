import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Custom-painted stationery donut chart with 12-o'clock largest-slice start,
/// tap hit-testing, sweep animation, and reduced-motion support.
class StationeryDonutChart extends StatelessWidget {
  const StationeryDonutChart({
    super.key,
    required this.summaries,
    required this.totalAmount,
    required this.centerLabel,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    this.animationKey,
  });

  final List<CategorySummary> summaries;
  final int totalAmount;
  final String centerLabel;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelectCategory;
  final Object? animationKey;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    CategorySummary? selected;
    for (final s in summaries) {
      if (s.category.id == selectedCategoryId) {
        selected = s;
        break;
      }
    }

    const double size = 208;

    return Semantics(
      label:
          '$centerLabel total ${formatRupiah(totalAmount)} dalam ${summaries.length} kategori',
      child: SizedBox(
        width: size,
        height: size,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) => _handleTap(details.localPosition, size),
          child: TweenAnimationBuilder<double>(
            key: ValueKey(animationKey),
            tween: Tween<double>(begin: disableAnimations ? 1 : 0, end: 1),
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(size, size),
                    painter: _DonutPainter(
                      summaries: summaries,
                      selectedCategoryId: selectedCategoryId,
                      progress: progress,
                      trackColor: tokens.surfaceAlt,
                      gapColor: tokens.surface,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          selected?.category.label ?? centerLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textTheme.labelSmall?.copyWith(
                            color: tokens.inkMuted,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formatRupiah(
                            selected?.total ?? totalAmount,
                            compact: (selected?.total ?? totalAmount) >= 10000000,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium?.copyWith(
                            color: tokens.ink,
                            fontWeight: FontWeight.w800,
                            fontFeatures: kTabularFigures,
                          ),
                        ),
                        if (selected != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${(selected.ratio * 100).round()}% · ${selected.count}x',
                            style: textTheme.labelSmall?.copyWith(
                              color: selected.category.color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleTap(Offset pos, double size) {
    if (summaries.isEmpty) return;
    final center = Offset(size / 2, size / 2);
    final dx = pos.dx - center.dx;
    final dy = pos.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final outerR = size / 2;
    final innerR = outerR - 36;

    if (dist < innerR) {
      if (selectedCategoryId != null) {
        HapticFeedback.selectionClick();
        onSelectCategory(null);
      }
      return;
    }
    if (dist > outerR) return;

    // Normalize angle starting from 12 o'clock (-pi/2) clockwise [0, 2pi).
    var angle = math.atan2(dy, dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;

    var cursor = 0.0;
    for (final s in summaries) {
      final sweep = s.ratio * math.pi * 2;
      if (angle >= cursor && angle <= cursor + sweep) {
        HapticFeedback.selectionClick();
        final next = selectedCategoryId == s.category.id ? null : s.category.id;
        onSelectCategory(next);
        return;
      }
      cursor += sweep;
    }
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.summaries,
    required this.selectedCategoryId,
    required this.progress,
    required this.trackColor,
    required this.gapColor,
  });

  final List<CategorySummary> summaries;
  final String? selectedCategoryId;
  final double progress;
  final Color trackColor;
  final Color gapColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 28.0;
    final radius = (size.width - strokeWidth) / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    if (summaries.isEmpty) return;

    var startAngle = -math.pi / 2;
    final gapRadians = summaries.length > 1 ? 0.032 : 0.0;

    for (final item in summaries) {
      final fullSweep = item.ratio * math.pi * 2 * progress;
      final isSelected = selectedCategoryId == item.category.id;
      final isDimmed = selectedCategoryId != null && !isSelected;

      final paint = Paint()
        ..color = isDimmed
            ? item.category.color.withOpacity(0.28)
            : item.category.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 5 : strokeWidth
        ..strokeCap = StrokeCap.butt;

      final sweep = math.max(0.0, fullSweep - gapRadians);
      if (sweep > 0) {
        canvas.drawArc(rect, startAngle + gapRadians / 2, sweep, false, paint);
      }
      startAngle += fullSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.summaries != summaries ||
      oldDelegate.selectedCategoryId != selectedCategoryId ||
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor;
}
