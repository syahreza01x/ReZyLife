import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/finance_models.dart';
import '../theme/app_theme.dart';

/// Subtle Hobonichi-style Japanese notebook dot-grid background with faint
/// theme-aware corner geometry (P3R clock arc vs P5R comic halftone dots).
class StationeryCanvasBackground extends StatelessWidget {
  const StationeryCanvasBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    return Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _NotebookDotGridPainter(
                preset: tokens.preset,
                dotColor: tokens.border.withOpacity(0.68),
                accentColor: tokens.accent,
                accentSoft: tokens.accentSoft,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _NotebookDotGridPainter extends CustomPainter {
  const _NotebookDotGridPainter({
    required this.preset,
    required this.dotColor,
    required this.accentColor,
    required this.accentSoft,
  });

  final PersonaThemePreset preset;
  final Color dotColor;
  final Color accentColor;
  final Color accentSoft;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle 22dp Hobonichi stationery dot-grid batched into 1 GPU draw call.
    const step = 22.0;
    final points = <Offset>[];
    for (double y = 14; y < size.height; y += step) {
      for (double x = 14; x < size.width; x += step) {
        points.add(Offset(x, y));
      }
    }
    canvas.drawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = dotColor
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );

    // 2. Subtle top-right & bottom-left Persona watermark geometry (clean & restrained).
    if (preset == PersonaThemePreset.tatsumi) {
      // P3R S.E.E.S. top-right clock dial rings + diagonal water-shard ray.
      final center = Offset(size.width - 22, 58);
      final ringPaint = Paint()
        ..color = accentColor.withOpacity(0.11)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4;
      canvas.drawCircle(center, 74, ringPaint);
      canvas.drawCircle(center, 98, ringPaint);

      final tickPaint = Paint()
        ..color = accentColor.withOpacity(0.18)
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 12; i++) {
        final angle = i * (math.pi * 2 / 12);
        final inner = Offset(
          center.dx + math.cos(angle) * 65,
          center.dy + math.sin(angle) * 65,
        );
        final outer = Offset(
          center.dx + math.cos(angle) * 74,
          center.dy + math.sin(angle) * 74,
        );
        canvas.drawLine(inner, outer, tickPaint);
      }

      // Bottom-left S.E.E.S. translucent cerulean shard accents.
      final shard1 = Path()
        ..moveTo(0, size.height * 0.78)
        ..lineTo(size.width * 0.24, size.height * 0.90)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(shard1, Paint()..color = accentSoft.withOpacity(0.7));

      final shard2 = Path()
        ..moveTo(0, size.height * 0.85)
        ..lineTo(size.width * 0.14, size.height * 0.94)
        ..lineTo(size.width * 0.08, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(shard2, Paint()..color = accentColor.withOpacity(0.10));
    } else {
      // P5R Dark Mode: top-right crimson phantom slash + scattered 5-point stars.
      final stripe = Path()
        ..moveTo(size.width * 0.58, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, 110)
        ..lineTo(size.width * 0.76, 60)
        ..close();
      canvas.drawPath(stripe, Paint()..color = accentColor.withOpacity(0.14));

      _drawPersonaStar(
        canvas,
        Offset(size.width - 34, 48),
        24,
        Paint()..color = accentColor.withOpacity(0.20),
        tilt: -0.22,
      );
      _drawPersonaStar(
        canvas,
        Offset(size.width - 76, 26),
        10,
        Paint()..color = Colors.white.withOpacity(0.10),
        tilt: 0.18,
      );

      // Bottom-left Phantom crimson corner wedge + crisp stars.
      final bottomCut = Path()
        ..moveTo(0, size.height * 0.82)
        ..lineTo(size.width * 0.26, size.height)
        ..lineTo(0, size.height)
        ..close();
      canvas.drawPath(bottomCut, Paint()..color = accentColor.withOpacity(0.13));

      _drawPersonaStar(
        canvas,
        Offset(30, size.height * 0.90),
        15,
        Paint()..color = accentColor.withOpacity(0.22),
        tilt: 0.15,
      );
      _drawPersonaStar(
        canvas,
        Offset(60, size.height * 0.94),
        8,
        Paint()..color = Colors.white.withOpacity(0.12),
        tilt: -0.3,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _NotebookDotGridPainter oldDelegate) =>
      oldDelegate.preset != preset ||
      oldDelegate.dotColor != dotColor ||
      oldDelegate.accentColor != accentColor;
}

/// Real astronomical lunar phase icon inspired by Persona 3 Reload's HUD.
class PersonaMoonPhaseIcon extends StatelessWidget {
  const PersonaMoonPhaseIcon({
    super.key,
    required this.date,
    this.size = 20,
    required this.litColor,
    required this.shadowColor,
    required this.outlineColor,
  });

  final DateTime date;
  final double size;
  final Color litColor;
  final Color shadowColor;
  final Color outlineColor;

  /// Approximate lunar cycle [0..1), 0 = new moon, 0.5 = full moon.
  double get _phase {
    const synodicMonth = 29.53058867;
    final refNewMoon = DateTime.utc(2000, 1, 6, 18, 14);
    final days = date.toUtc().difference(refNewMoon).inHours / 24.0;
    final mod = days % synodicMonth;
    return (mod < 0 ? mod + synodicMonth : mod) / synodicMonth;
  }

  String get phaseNameIndonesian {
    final p = _phase;
    if (p < 0.06 || p >= 0.94) return 'Bulan Baru';
    if (p < 0.22) return 'Sabit Awal';
    if (p < 0.28) return 'Kuartal Awal';
    if (p < 0.44) return 'Cembung Awal';
    if (p < 0.56) return 'Purnama';
    if (p < 0.72) return 'Cembung Akhir';
    if (p < 0.78) return 'Kuartal Akhir';
    return 'Sabit Akhir';
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MoonPhasePainter(
          phase: _phase,
          litColor: litColor,
          shadowColor: shadowColor,
          outlineColor: outlineColor,
        ),
      ),
    );
  }
}

class _MoonPhasePainter extends CustomPainter {
  const _MoonPhasePainter({
    required this.phase,
    required this.litColor,
    required this.shadowColor,
    required this.outlineColor,
  });

  final double phase;
  final Color litColor;
  final Color shadowColor;
  final Color outlineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 1.2;

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: r)));
    canvas.drawCircle(center, r, Paint()..color = shadowColor);

    // Draw waxing/waning lit crescent cleanly via overlapping ellipse mask.
    final isWaxing = phase < 0.5;
    final litRect = Rect.fromCircle(center: center, radius: r);
    final litPaint = Paint()..color = litColor;

    final halfStart = isWaxing ? -math.pi / 2 : math.pi / 2;
    canvas.drawArc(litRect, halfStart, math.pi, true, litPaint);

    final cosVal = math.cos(phase * math.pi * 2);
    final terminatorWidth = (cosVal.abs() * r).clamp(0.0, r);
    final terminatorRect = Rect.fromCenter(
      center: center,
      width: terminatorWidth * 2,
      height: r * 2,
    );
    final isGibbous = phase > 0.25 && phase < 0.75;
    canvas.drawOval(
      terminatorRect,
      Paint()..color = isGibbous ? litColor : shadowColor,
    );
    canvas.restore();

    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25,
    );
  }

  @override
  bool shouldRepaint(covariant _MoonPhasePainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.litColor != litColor ||
      oldDelegate.shadowColor != shadowColor;
}

/// Crisp asymmetric 5-point star inspired by Persona 5 Royal's visual language.
class PersonaStarIcon extends StatelessWidget {
  const PersonaStarIcon({
    super.key,
    this.size = 18,
    required this.color,
    this.outlineColor,
    this.tilt = -0.18,
  });

  final double size;
  final Color color;
  final Color? outlineColor;
  final double tilt;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PersonaStarPainter(
          color: color,
          outlineColor: outlineColor,
          tilt: tilt,
        ),
      ),
    );
  }
}

class _PersonaStarPainter extends CustomPainter {
  const _PersonaStarPainter({
    required this.color,
    this.outlineColor,
    required this.tilt,
  });

  final Color color;
  final Color? outlineColor;
  final double tilt;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.46;
    _drawPersonaStar(canvas, center, radius, Paint()..color = color, tilt: tilt);
    if (outlineColor != null) {
      _drawPersonaStar(
        canvas,
        center,
        radius,
        Paint()
          ..color = outlineColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.15
          ..strokeJoin = StrokeJoin.miter,
        tilt: tilt,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PersonaStarPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.outlineColor != outlineColor ||
      oldDelegate.tilt != tilt;
}

void _drawPersonaStar(
  Canvas canvas,
  Offset center,
  double outerRadius,
  Paint paint, {
  double tilt = -0.18,
}) {
  final innerRadius = outerRadius * 0.42;
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? outerRadius : innerRadius;
    final angle = -math.pi / 2 + tilt + (i * math.pi / 5);
    final pt = Offset(
      center.dx + math.cos(angle) * r,
      center.dy + math.sin(angle) * r,
    );
    if (i == 0) {
      path.moveTo(pt.dx, pt.dy);
    } else {
      path.lineTo(pt.dx, pt.dy);
    }
  }
  path.close();
  canvas.drawPath(path, paint);
}

/// Hero surface artwork painted inside StationerySurface top-right corner:
/// - Tatsumi (P3R): layered cerulean glass/water shards + thin clock dial arc.
/// - Shibuya (P5R): pastel halftone dot matrix + crimson/sumi calling-card slash + stars.
class PersonaHeroCornerPainter extends CustomPainter {
  const PersonaHeroCornerPainter({
    required this.preset,
    required this.accent,
    required this.accentSoft,
    required this.ink,
  });

  final PersonaThemePreset preset;
  final Color accent;
  final Color accentSoft;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    if (preset == PersonaThemePreset.tatsumi) {
      // P3R layered diagonal water-glass shards + subtle clock arc ticks.
      final softShard = Path()
        ..moveTo(size.width * 0.14, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height * 0.96)
        ..lineTo(size.width * 0.42, size.height * 0.48)
        ..close();
      canvas.drawPath(softShard, Paint()..color = accentSoft.withOpacity(0.92));

      final midShard = Path()
        ..moveTo(size.width * 0.48, 0)
        ..lineTo(size.width * 0.78, 0)
        ..lineTo(size.width, size.height * 0.42)
        ..lineTo(size.width * 0.76, size.height * 0.66)
        ..close();
      canvas.drawPath(midShard, Paint()..color = accent.withOpacity(0.24));

      final crispSlash = Path()
        ..moveTo(size.width * 0.64, 0)
        ..lineTo(size.width * 0.76, 0)
        ..lineTo(size.width, size.height * 0.46)
        ..lineTo(size.width, size.height * 0.64)
        ..close();
      canvas.drawPath(crispSlash, Paint()..color = accent.withOpacity(0.9));

      // Delicate P3R clock dial arc in the corner.
      final dialCenter = Offset(size.width - 14, 14);
      canvas.drawCircle(
        dialCenter,
        34,
        Paint()
          ..color = ink.withOpacity(0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1,
      );
      final tickPaint = Paint()
        ..color = ink.withOpacity(0.32)
        ..strokeWidth = 1.3;
      for (var i = 0; i < 6; i++) {
        final a = math.pi * 0.55 + i * 0.19;
        canvas.drawLine(
          Offset(
            dialCenter.dx + math.cos(a) * 28,
            dialCenter.dy + math.sin(a) * 28,
          ),
          Offset(
            dialCenter.dx + math.cos(a) * 34,
            dialCenter.dy + math.sin(a) * 34,
          ),
          tickPaint,
        );
      }
    } else {
      // P5R Dark Mode: crimson halftone corner + crisp white & crimson calling-card slashes + stars.
      final softCut = Path()
        ..moveTo(size.width * 0.20, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * 0.50, size.height * 0.56)
        ..close();
      canvas.drawPath(softCut, Paint()..color = accentSoft.withOpacity(0.95));

      // Comic halftone dots inside the crimson wash corner.
      final dotPaint = Paint()..color = accent.withOpacity(0.32);
      for (double y = 10; y < size.height * 0.74; y += 9) {
        for (double x = size.width * 0.34; x < size.width - 6; x += 9) {
          if (x + (size.height - y) * 0.55 > size.width * 0.70) {
            canvas.drawCircle(Offset(x, y), 1.45, dotPaint);
          }
        }
      }

      // Twin crisp off-white & velvet-crimson calling-card strips.
      final whiteStrip = Path()
        ..moveTo(size.width * 0.56, 0)
        ..lineTo(size.width * 0.63, 0)
        ..lineTo(size.width, size.height * 0.55)
        ..lineTo(size.width, size.height * 0.65)
        ..close();
      canvas.drawPath(whiteStrip, Paint()..color = ink.withOpacity(0.88));

      final crimsonStrip = Path()
        ..moveTo(size.width * 0.67, 0)
        ..lineTo(size.width * 0.80, 0)
        ..lineTo(size.width, size.height * 0.34)
        ..lineTo(size.width, size.height * 0.52)
        ..close();
      canvas.drawPath(crimsonStrip, Paint()..color = accent);

      // Pair of crisp Persona 5 stars.
      _drawPersonaStar(
        canvas,
        Offset(size.width - 28, 20),
        8.5,
        Paint()..color = Colors.white,
        tilt: -0.22,
      );
      _drawPersonaStar(
        canvas,
        Offset(size.width - 52, 16),
        5.5,
        Paint()..color = accent,
        tilt: 0.14,
      );
    }
  }

  @override
  bool shouldRepaint(covariant PersonaHeroCornerPainter oldDelegate) =>
      oldDelegate.preset != preset ||
      oldDelegate.accent != accent ||
      oldDelegate.accentSoft != accentSoft ||
      oldDelegate.ink != ink;
}

/// Clean S.E.E.S. armband-inspired micro badge (midnight navy + scarlet armband
/// stripe) for Persona 3 Reload light mode.
class SeesArmbandBadge extends StatelessWidget {
  const SeesArmbandBadge({super.key, this.label = 'S.E.E.S.'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1D3A),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: const Color(0xFF38BDF8).withOpacity(0.55),
          width: 0.9,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 10,
            decoration: BoxDecoration(
              color: const Color(0xFFD92638), // Authentic S.E.E.S. scarlet armband accent
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 9.5,
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
          ),
        ],
      ),
    );
  }
}

/// Iconic Persona 5 Joker domino mask vector icon (sharp upswept white wing
/// silhouette, pointed nose bridge, and fierce slanted eye cutouts).
class PhantomMaskIcon extends StatelessWidget {
  const PhantomMaskIcon({
    super.key,
    this.width = 18,
    this.height = 10,
    this.maskColor = Colors.white,
    this.cutoutColor = const Color(0xFF0E0E13),
  });

  final double width;
  final double height;
  final Color maskColor;
  final Color cutoutColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _PhantomMaskPainter(
        maskColor: maskColor,
        cutoutColor: cutoutColor,
      ),
    );
  }
}

class _PhantomMaskPainter extends CustomPainter {
  const _PhantomMaskPainter({
    required this.maskColor,
    required this.cutoutColor,
  });

  final Color maskColor;
  final Color cutoutColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Sharp upswept Joker domino mask silhouette.
    final mask = Path()
      ..moveTo(w * 0.50, h * 0.24) // forehead center dip
      ..quadraticBezierTo(w * 0.34, h * 0.04, w * 0.14, h * 0.14)
      ..lineTo(0, h * 0.04) // sharp left wing tip
      ..quadraticBezierTo(w * 0.07, h * 0.48, w * 0.18, h * 0.78)
      ..quadraticBezierTo(w * 0.34, h * 0.90, w * 0.43, h * 0.72)
      ..lineTo(w * 0.50, h * 0.96) // pointed nose bridge
      ..lineTo(w * 0.57, h * 0.72)
      ..quadraticBezierTo(w * 0.66, h * 0.90, w * 0.82, h * 0.78)
      ..quadraticBezierTo(w * 0.93, h * 0.48, w, h * 0.04) // sharp right wing tip
      ..lineTo(w * 0.86, h * 0.14)
      ..quadraticBezierTo(w * 0.66, h * 0.04, w * 0.50, h * 0.24)
      ..close();

    canvas.drawPath(
      mask,
      Paint()
        ..color = maskColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Fierce slanted almond eye cutouts.
    final leftEye = Path()
      ..moveTo(w * 0.17, h * 0.34)
      ..quadraticBezierTo(w * 0.31, h * 0.32, w * 0.41, h * 0.52)
      ..quadraticBezierTo(w * 0.29, h * 0.64, w * 0.17, h * 0.34)
      ..close();

    final rightEye = Path()
      ..moveTo(w * 0.83, h * 0.34)
      ..quadraticBezierTo(w * 0.69, h * 0.32, w * 0.59, h * 0.52)
      ..quadraticBezierTo(w * 0.71, h * 0.64, w * 0.83, h * 0.34)
      ..close();

    final eyePaint = Paint()
      ..color = cutoutColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    canvas.drawPath(leftEye, eyePaint);
    canvas.drawPath(rightEye, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _PhantomMaskPainter oldDelegate) =>
      oldDelegate.maskColor != maskColor ||
      oldDelegate.cutoutColor != cutoutColor;
}

/// P5R Phantom Thieves micro badge (obsidian black + iconic Joker domino mask
/// + crisp white calling-card border), mirroring [SeesArmbandBadge] in P3R.
class PhantomMaskBadge extends StatelessWidget {
  const PhantomMaskBadge({super.key, this.label = 'PHANTOM'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D12),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: Colors.white.withOpacity(0.85),
            width: 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ExcludeSemantics(
              child: PhantomMaskIcon(
                width: 17,
                height: 10,
                maskColor: Colors.white,
                cutoutColor: Color(0xFFE61B2E),
              ),
            ),
            const SizedBox(width: 4.5),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 9.5,
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.7,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section header styled with a subtle Persona signature mark:
/// - P3R: crisp diagonal cerulean slash ticks.
/// - P5R: mini crimson 5-point star + subtle slanted ink underline accent.
class PersonaSectionHeading extends StatelessWidget {
  const PersonaSectionHeading({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isP5 = tokens.preset == PersonaThemePreset.shibuya;

    return Row(
      children: [
        ExcludeSemantics(
          child: isP5
              ? PersonaStarIcon(
                  size: 16,
                  color: tokens.accent,
                  outlineColor: tokens.ink,
                )
              : CustomPaint(
                  size: const Size(12, 16),
                  painter: _P3RSlashMarkerPainter(
                    accent: tokens.accent,
                    soft: tokens.accentSecondary,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: textTheme.titleMedium?.copyWith(
              color: tokens.ink,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _P3RSlashMarkerPainter extends CustomPainter {
  const _P3RSlashMarkerPainter({required this.accent, required this.soft});

  final Color accent;
  final Color soft;

  @override
  void paint(Canvas canvas, Size size) {
    final p1 = Path()
      ..moveTo(5, 1)
      ..lineTo(9, 1)
      ..lineTo(5, size.height - 1)
      ..lineTo(1, size.height - 1)
      ..close();
    canvas.drawPath(p1, Paint()..color = accent);

    final p2 = Path()
      ..moveTo(10.5, 4)
      ..lineTo(12.5, 4)
      ..lineTo(9.5, size.height - 2)
      ..lineTo(7.5, size.height - 2)
      ..close();
    canvas.drawPath(p2, Paint()..color = soft);
  }

  @override
  bool shouldRepaint(covariant _P3RSlashMarkerPainter oldDelegate) =>
      oldDelegate.accent != accent || oldDelegate.soft != soft;
}

/// GPU-composited Persona diagonal curtain driven by separate enter/exit
/// animations so theme rebuild work finishes completely during the covered
/// pause before frame 0 of the exit slide begins.
class PersonaThemeSlashOverlay extends StatelessWidget {
  const PersonaThemeSlashOverlay({
    super.key,
    required this.visible,
    required this.enterAnimation,
    required this.exitAnimation,
    required this.targetPreset,
  });

  final bool visible;
  final Animation<double> enterAnimation;
  final Animation<double> exitAnimation;
  final PersonaThemePreset targetPreset;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();

    final screen = MediaQuery.sizeOf(context);
    final skew = screen.height * 0.22;
    final panelWidth = screen.width + skew * 2.2;
    final travelDistance = screen.width + skew * 2.25;
    final isP5 = targetPreset == PersonaThemePreset.shibuya;

    final staticCurtain = RepaintBoundary(
      child: SizedBox(
        width: panelWidth,
        height: screen.height,
        child: CustomPaint(
          painter: _StaticPersonaCurtainPainter(
            isP5: isP5,
            skew: skew,
          ),
        ),
      ),
    );

    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: Listenable.merge([enterAnimation, exitAnimation]),
          child: staticCurtain,
          builder: (context, child) {
            final enterP = Curves.easeOutQuart.transform(enterAnimation.value);
            final exitP = Curves.easeInOutCubic.transform(exitAnimation.value);
            final dx = (-travelDistance * (1.0 - enterP)) +
                (travelDistance * exitP);

            return OverflowBox(
              alignment: Alignment.center,
              minWidth: panelWidth,
              maxWidth: panelWidth,
              minHeight: screen.height,
              maxHeight: screen.height,
              child: Transform.translate(
                offset: Offset(dx, 0),
                child: child,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Painted ONCE per theme toggle and cached as a GPU layer by [RepaintBoundary].
class _StaticPersonaCurtainPainter extends CustomPainter {
  const _StaticPersonaCurtainPainter({
    required this.isP5,
    required this.skew,
  });

  final bool isP5;
  final double skew;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final Color baseFill =
        isP5 ? const Color(0xFF19191E) : const Color(0xFF122347);
    final Color primaryBlade =
        isP5 ? const Color(0xFFC81E2B) : const Color(0xFF1A68E8);
    final Color lightBlade =
        isP5 ? const Color(0xFFFAF6EE) : const Color(0xFF7DD3FC);

    // Parallelogram spans full viewport cleanly when centered at dx = 0.
    final leftTop = skew;
    final rightTop = w;
    final rightBottom = w - skew;
    const leftBottom = 0.0;

    final body = Path()
      ..moveTo(leftTop, 0)
      ..lineTo(rightTop, 0)
      ..lineTo(rightBottom, h)
      ..lineTo(leftBottom, h)
      ..close();
    canvas.drawPath(body, Paint()..color = baseFill);

    // Leading right-edge Persona blade + thin highlight stripe.
    const bladeW = 28.0;
    final frontBlade = Path()
      ..moveTo(rightTop - bladeW, 0)
      ..lineTo(rightTop, 0)
      ..lineTo(rightBottom, h)
      ..lineTo(rightBottom - bladeW, h)
      ..close();
    canvas.drawPath(frontBlade, Paint()..color = primaryBlade);

    final frontHighlight = Path()
      ..moveTo(rightTop - bladeW - 7, 0)
      ..lineTo(rightTop - bladeW - 1, 0)
      ..lineTo(rightBottom - bladeW - 1, h)
      ..lineTo(rightBottom - bladeW - 7, h)
      ..close();
    canvas.drawPath(frontHighlight, Paint()..color = lightBlade);

    // Trailing left-edge Persona blade + thin highlight stripe (always present, no pop-in!).
    final backBlade = Path()
      ..moveTo(leftTop, 0)
      ..lineTo(leftTop + bladeW, 0)
      ..lineTo(leftBottom + bladeW, h)
      ..lineTo(leftBottom, h)
      ..close();
    canvas.drawPath(backBlade, Paint()..color = primaryBlade);

    final backHighlight = Path()
      ..moveTo(leftTop + bladeW + 1, 0)
      ..lineTo(leftTop + bladeW + 7, 0)
      ..lineTo(leftBottom + bladeW + 7, h)
      ..lineTo(leftBottom + bladeW + 1, h)
      ..close();
    canvas.drawPath(backHighlight, Paint()..color = lightBlade);

    // Centered Persona motif (zero Path.combine, pure fast canvas primitives).
    final center = Offset(w * 0.5, h * 0.48);
    if (isP5) {
      _drawPersonaStar(
        canvas,
        center,
        46,
        Paint()..color = primaryBlade,
        tilt: -0.22,
      );
      _drawPersonaStar(
        canvas,
        center,
        22,
        Paint()..color = lightBlade,
        tilt: -0.22,
      );
      _drawPersonaStar(
        canvas,
        center + const Offset(58, -42),
        14,
        Paint()..color = lightBlade,
        tilt: 0.25,
      );
      _drawPersonaStar(
        canvas,
        center + const Offset(-56, 44),
        12,
        Paint()..color = primaryBlade,
        tilt: -0.35,
      );
    } else {
      const ringR = 54.0;
      canvas.drawCircle(
        center,
        ringR,
        Paint()
          ..color = lightBlade.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
      );
      canvas.drawCircle(
        center,
        ringR * 0.72,
        Paint()
          ..color = primaryBlade
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0,
      );
      final tickPaint = Paint()
        ..color = lightBlade.withOpacity(0.8)
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;
      for (var i = 0; i < 12; i++) {
        final a = i * math.pi * 2 / 12;
        canvas.drawLine(
          Offset(
            center.dx + math.cos(a) * (ringR - 8),
            center.dy + math.sin(a) * (ringR - 8),
          ),
          Offset(
            center.dx + math.cos(a) * ringR,
            center.dy + math.sin(a) * ringR,
          ),
          tickPaint,
        );
      }
      // Crescent drawn via two simple circles (no expensive Path.combine).
      canvas.drawCircle(
        center,
        22,
        Paint()..color = const Color(0xFFFAF7F0),
      );
      canvas.drawCircle(
        center + const Offset(9, -4),
        19,
        Paint()..color = baseFill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaticPersonaCurtainPainter oldDelegate) =>
      oldDelegate.isP5 != isP5 || oldDelegate.skew != skew;
}
