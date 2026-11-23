import 'package:flutter/material.dart';

import '../models/finance_models.dart';

@immutable
class ReZyTokens extends ThemeExtension<ReZyTokens> {
  const ReZyTokens({
    required this.preset,
    required this.isDark,
    required this.paperBg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkMuted,
    required this.border,
    required this.accent,
    required this.accentSoft,
    required this.onAccent,
    required this.accentSecondary,
    required this.income,
    required this.incomeSoft,
    required this.expense,
    required this.expenseSoft,
    required this.transfer,
    required this.transferSoft,
    required this.stampSlantRadians,
    required this.presetCode,
    required this.presetLabel,
  });

  final PersonaThemePreset preset;
  final bool isDark;
  final Color paperBg;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkMuted;
  final Color border;
  final Color accent;
  final Color accentSoft;
  final Color onAccent;
  final Color accentSecondary;
  final Color income;
  final Color incomeSoft;
  final Color expense;
  final Color expenseSoft;
  final Color transfer;
  final Color transferSoft;
  final double stampSlantRadians;
  final String presetCode;
  final String presetLabel;

  /// Persona 3 Reload (S.E.E.S.) — crisp light white/ivory & cerulean blue.
  static const ReZyTokens tatsumi = ReZyTokens(
    preset: PersonaThemePreset.tatsumi,
    isDark: false,
    paperBg: Color(0xFFF6F9FF),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEAF1FC),
    ink: Color(0xFF0F1D3A),
    inkMuted: Color(0xFF475776), // > 7.0:1 contrast on light canvas
    border: Color(0xFFD2DDF0),
    accent: Color(0xFF1565F0), // P3R S.E.E.S. cerulean blue
    accentSoft: Color(0xFFDCEBFF),
    onAccent: Color(0xFFFFFFFF),
    accentSecondary: Color(0xFF38BDF8),
    income: Color(0xFF157A57),
    incomeSoft: Color(0xFFDEF3EB),
    expense: Color(0xFFC93B3B),
    expenseSoft: Color(0xFFFCE7E7),
    transfer: Color(0xFF4656A8),
    transferSoft: Color(0xFFEAEFFA),
    stampSlantRadians: 0.0,
    presetCode: 'P3R',
    presetLabel: 'S.E.E.S.',
  );

  /// Persona 5 Royal (Phantom) — sleek high-contrast dark obsidian, crimson & crisp white.
  static const ReZyTokens shibuya = ReZyTokens(
    preset: PersonaThemePreset.shibuya,
    isDark: true,
    paperBg: Color(0xFF101015),
    surface: Color(0xFF1A1A22),
    surfaceAlt: Color(0xFF252531),
    ink: Color(0xFFF5F3EE), // > 14:1 contrast on surface
    inkMuted: Color(0xFFB5B1C0), // > 7.6:1 contrast on surface
    border: Color(0xFF323243),
    accent: Color(0xFFE62434), // P5R velvet crimson
    accentSoft: Color(0xFF3A1620),
    onAccent: Color(0xFFFFFFFF),
    accentSecondary: Color(0xFFF5F3EE),
    income: Color(0xFF34D399),
    incomeSoft: Color(0xFF133129),
    expense: Color(0xFFFF5A67),
    expenseSoft: Color(0xFF3B1721),
    transfer: Color(0xFFFBBF24),
    transferSoft: Color(0xFF362A14),
    stampSlantRadians: -0.026,
    presetCode: 'P5R',
    presetLabel: 'ROYAL',
  );

  static ReZyTokens of(BuildContext context) =>
      Theme.of(context).extension<ReZyTokens>() ?? tatsumi;

  @override
  ReZyTokens copyWith({
    PersonaThemePreset? preset,
    bool? isDark,
    Color? paperBg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkMuted,
    Color? border,
    Color? accent,
    Color? accentSoft,
    Color? onAccent,
    Color? accentSecondary,
    Color? income,
    Color? incomeSoft,
    Color? expense,
    Color? expenseSoft,
    Color? transfer,
    Color? transferSoft,
    double? stampSlantRadians,
    String? presetCode,
    String? presetLabel,
  }) {
    return ReZyTokens(
      preset: preset ?? this.preset,
      isDark: isDark ?? this.isDark,
      paperBg: paperBg ?? this.paperBg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkMuted: inkMuted ?? this.inkMuted,
      border: border ?? this.border,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      onAccent: onAccent ?? this.onAccent,
      accentSecondary: accentSecondary ?? this.accentSecondary,
      income: income ?? this.income,
      incomeSoft: incomeSoft ?? this.incomeSoft,
      expense: expense ?? this.expense,
      expenseSoft: expenseSoft ?? this.expenseSoft,
      transfer: transfer ?? this.transfer,
      transferSoft: transferSoft ?? this.transferSoft,
      stampSlantRadians: stampSlantRadians ?? this.stampSlantRadians,
      presetCode: presetCode ?? this.presetCode,
      presetLabel: presetLabel ?? this.presetLabel,
    );
  }

  @override
  ReZyTokens lerp(ThemeExtension<ReZyTokens>? other, double t) {
    if (other is! ReZyTokens) return this;
    return ReZyTokens(
      preset: t < 0.5 ? preset : other.preset,
      isDark: t < 0.5 ? isDark : other.isDark,
      paperBg: Color.lerp(paperBg, other.paperBg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkMuted: Color.lerp(inkMuted, other.inkMuted, t)!,
      border: Color.lerp(border, other.border, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      accentSecondary: Color.lerp(accentSecondary, other.accentSecondary, t)!,
      income: Color.lerp(income, other.income, t)!,
      incomeSoft: Color.lerp(incomeSoft, other.incomeSoft, t)!,
      expense: Color.lerp(expense, other.expense, t)!,
      expenseSoft: Color.lerp(expenseSoft, other.expenseSoft, t)!,
      transfer: Color.lerp(transfer, other.transfer, t)!,
      transferSoft: Color.lerp(transferSoft, other.transferSoft, t)!,
      stampSlantRadians:
          stampSlantRadians + (other.stampSlantRadians - stampSlantRadians) * t,
      presetCode: t < 0.5 ? presetCode : other.presetCode,
      presetLabel: t < 0.5 ? presetLabel : other.presetLabel,
    );
  }
}

const List<FontFeature> kTabularFigures = [FontFeature.tabularFigures()];

ThemeData buildReZyTheme(PersonaThemePreset preset) {
  final tokens = preset == PersonaThemePreset.shibuya
      ? ReZyTokens.shibuya
      : ReZyTokens.tatsumi;

  final baseTheme = tokens.isDark
      ? ThemeData.dark(useMaterial3: true)
      : ThemeData.light(useMaterial3: true);

  final baseText = baseTheme.textTheme.apply(
    fontFamily: 'PlusJakartaSans',
    bodyColor: tokens.ink,
    displayColor: tokens.ink,
  );

  final textTheme = baseText.copyWith(
    displaySmall: baseText.displaySmall?.copyWith(
      fontSize: 32,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
      height: 1.15,
      fontFeatures: kTabularFigures,
    ),
    headlineMedium: baseText.headlineMedium?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      height: 1.25,
    ),
    titleLarge: baseText.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.2,
      height: 1.3,
    ),
    titleMedium: baseText.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w700,
      height: 1.35,
    ),
    bodyLarge: baseText.bodyLarge?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w500,
      height: 1.45,
    ),
    bodyMedium: baseText.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.45,
    ),
    bodySmall: baseText.bodySmall?.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      color: tokens.inkMuted,
      height: 1.4,
    ),
    labelLarge: baseText.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
    labelMedium: baseText.labelMedium?.copyWith(
      fontSize: 12.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    ),
    labelSmall: baseText.labelSmall?.copyWith(
      fontSize: 11.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
      color: tokens.inkMuted,
    ),
  );

  final colorScheme = ColorScheme(
    brightness: tokens.isDark ? Brightness.dark : Brightness.light,
    primary: tokens.accent,
    onPrimary: tokens.onAccent,
    primaryContainer: tokens.accentSoft,
    onPrimaryContainer: tokens.ink,
    secondary: tokens.ink,
    onSecondary: tokens.surface,
    secondaryContainer: tokens.surfaceAlt,
    onSecondaryContainer: tokens.ink,
    error: tokens.expense,
    onError: Colors.white,
    surface: tokens.surface,
    onSurface: tokens.ink,
    surfaceContainerHighest: tokens.surfaceAlt,
    onSurfaceVariant: tokens.inkMuted,
    outline: tokens.border,
    outlineVariant: tokens.border.withOpacity(0.65),
  );

  return ThemeData(
    useMaterial3: true,
    brightness: tokens.isDark ? Brightness.dark : Brightness.light,
    fontFamily: 'PlusJakartaSans',
    colorScheme: colorScheme,
    scaffoldBackgroundColor: tokens.paperBg,
    textTheme: textTheme,
    extensions: [tokens],
    dividerColor: tokens.border,
    splashColor: tokens.accent.withOpacity(0.10),
    highlightColor: tokens.accent.withOpacity(0.06),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: tokens.accent,
      selectionColor: tokens.accentSoft,
      selectionHandleColor: tokens.accent,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: tokens.paperBg,
      foregroundColor: tokens.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: tokens.paperBg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: tokens.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: tokens.border, width: 1.2),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: tokens.isDark ? tokens.surfaceAlt : tokens.ink,
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: tokens.isDark ? tokens.ink : tokens.surface,
      ),
      actionTextColor: tokens.isDark ? tokens.accent : tokens.accentSoft,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: tokens.isDark
            ? BorderSide(color: tokens.accent.withOpacity(0.5))
            : BorderSide.none,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: tokens.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
      labelStyle: textTheme.bodyMedium?.copyWith(color: tokens.inkMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.accent, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: tokens.expense, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: tokens.accent,
        foregroundColor: tokens.onAccent,
        minimumSize: const Size(48, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.ink,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: tokens.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: textTheme.labelLarge,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return textTheme.labelSmall?.copyWith(
          color: selected ? tokens.accent : tokens.inkMuted,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        );
      }),
    ),
  );
}
