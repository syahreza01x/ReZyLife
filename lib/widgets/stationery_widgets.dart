import 'package:flutter/material.dart';

import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'persona_motifs.dart';

/// Clean Japanese stationery surface with one declared border elevation and
/// theme-distinct Persona artwork:
/// - Tatsumi (P3R): layered cerulean water-glass shards + clock dial arc.
/// - Shibuya (P5R): pastel halftone dots + calling-card slash + 5-point stars.
class StationerySurface extends StatelessWidget {
  const StationerySurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.showPersonaRibbon = false,
    this.backgroundColor,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool showPersonaRibbon;
  final Color? backgroundColor;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final isP5 = tokens.preset == PersonaThemePreset.shibuya;
    final effectiveRadius = isP5 ? radius - 2 : radius;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? tokens.surface,
        borderRadius: BorderRadius.circular(effectiveRadius),
        border: Border.all(
          color: borderColor ??
              (isP5 && showPersonaRibbon
                  ? tokens.accent.withOpacity(0.55)
                  : tokens.border),
          width: isP5 && showPersonaRibbon ? 1.35 : 1.15,
        ),
        boxShadow: isP5 && showPersonaRibbon
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  offset: const Offset(0, 6),
                  blurRadius: 14,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(effectiveRadius - 1),
        child: Stack(
          children: [
            if (showPersonaRibbon)
              Positioned(
                top: 0,
                right: 0,
                child: ExcludeSemantics(
                  child: CustomPaint(
                    size: const Size(124, 78),
                    painter: PersonaHeroCornerPainter(
                      preset: tokens.preset,
                      accent: tokens.accent,
                      accentSoft: tokens.accentSoft,
                      ink: tokens.ink,
                    ),
                  ),
                ),
              ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Smoothly rolls integer Rupiah amounts while respecting reduced motion.
class AnimatedRupiah extends StatelessWidget {
  const AnimatedRupiah({
    super.key,
    required this.amount,
    required this.style,
    this.hidden = false,
    this.withSign = false,
    this.compact = false,
  });

  final int amount;
  final TextStyle? style;
  final bool hidden;
  final bool withSign;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final merged = (style ?? Theme.of(context).textTheme.titleLarge)?.copyWith(
      fontFeatures: kTabularFigures,
    );

    if (hidden) {
      return Text('Rp ••••••', style: merged);
    }

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    if (disableAnimations) {
      return Text(
        formatRupiah(amount, withSign: withSign, compact: compact),
        style: merged,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: amount.toDouble()),
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Text(
          formatRupiah(value.round(), withSign: withSign, compact: compact),
          style: merged,
        );
      },
    );
  }
}

/// Subtle stationery stamp badge. Applies a crisp -1.5° Persona 5 slant only
/// when the Shibuya preset is active, keeping all numbers & body copy straight.
class PersonaStamp extends StatelessWidget {
  const PersonaStamp({
    super.key,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.icon,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Icon(icon, size: 14, color: foregroundColor),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
          ),
        ],
      ),
    );

    if (disableAnimations) {
      return Transform.rotate(angle: tokens.stampSlantRadians, child: badge);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: tokens.stampSlantRadians),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      builder: (context, angle, child) =>
          Transform.rotate(angle: angle, child: child),
      child: badge,
    );
  }
}

/// Empty state pairing our generated Japanese gouache illustration framed with
/// a translucent theme-colored stationery washi-tape accent and teaching CTA.
class StationeryEmptyState extends StatelessWidget {
  const StationeryEmptyState({
    super.key,
    required this.assetPath,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String assetPath;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final isP5 = tokens.preset == PersonaThemePreset.shibuya;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Transform.rotate(
                  angle: isP5 ? -0.02 : 0.0,
                  child: Container(
                    padding: isP5 ? const EdgeInsets.all(6) : EdgeInsets.zero,
                    decoration: BoxDecoration(
                      color: isP5 ? const Color(0xFFFAF6EE) : null,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isP5
                            ? tokens.accent.withOpacity(0.7)
                            : tokens.border,
                        width: isP5 ? 1.4 : 1.0,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        assetPath,
                        width: 204,
                        height: 152,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: -8,
                  child: Transform.rotate(
                    angle: isP5 ? -0.05 : 0.03,
                    child: Container(
                      width: 68,
                      height: 18,
                      decoration: BoxDecoration(
                        color: tokens.accent.withOpacity(0.28),
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(
                          color: tokens.accent.withOpacity(0.35),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.titleLarge?.copyWith(color: tokens.ink),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shared stationery confirmation dialog before deleting any financial record.
Future<bool> confirmDeleteDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final tokens = ReZyTokens.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: tokens.paperBg,
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(backgroundColor: tokens.expense),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Renders a wallet's vector mark, using a crisp custom DANA wavy-ribbon emblem
/// for DANA instead of a generic QR icon.
class WalletIcon extends StatelessWidget {
  const WalletIcon({
    super.key,
    required this.wallet,
    required this.size,
    required this.color,
  });

  final Wallet wallet;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (wallet.iconKey == 'dana') {
      return Center(
        child: CustomPaint(
          size: Size.square(size),
          painter: _DanaMarkPainter(color: color),
        ),
      );
    }
    return Icon(wallet.icon, size: size, color: color);
  }
}

class _DanaMarkPainter extends CustomPainter {
  const _DanaMarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Signature DANA wavy banknote/ribbon emblem in a normalized 24x24 box.
    final path = Path()
      ..moveTo(w * 0.12, h * 0.36)
      ..cubicTo(w * 0.34, h * 0.18, w * 0.62, h * 0.44, w * 0.88, h * 0.27)
      ..quadraticBezierTo(w * 0.94, h * 0.24, w * 0.94, h * 0.33)
      ..lineTo(w * 0.94, h * 0.62)
      ..quadraticBezierTo(w * 0.94, h * 0.69, w * 0.88, h * 0.72)
      ..cubicTo(w * 0.62, h * 0.88, w * 0.34, h * 0.62, w * 0.12, h * 0.78)
      ..quadraticBezierTo(w * 0.06, h * 0.81, w * 0.06, h * 0.72)
      ..lineTo(w * 0.06, h * 0.44)
      ..quadraticBezierTo(w * 0.06, h * 0.39, w * 0.12, h * 0.36)
      ..close();

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _DanaMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}
