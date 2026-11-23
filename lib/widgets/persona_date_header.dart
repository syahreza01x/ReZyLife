import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/finance_models.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'persona_motifs.dart';

/// Top ReZyLife bar pairing our theme-specific Japanese stationery emblem
/// (`p3r_emblem.png` / `p5r_emblem.png`) with an authentic Persona calendar HUD:
/// - Tatsumi (P3R): crisp cerulean date slash + live lunar phase icon.
/// - Shibuya (P5R): tilted sumi-ink cutout date block + crimson month ribbon.
class PersonaDateHeader extends StatelessWidget {
  const PersonaDateHeader({
    super.key,
    required this.now,
    required this.preset,
    required this.onTogglePreset,
    this.autoCaptureActive = false,
    this.onOpenAutoCapture,
  });

  final DateTime now;
  final PersonaThemePreset preset;
  final VoidCallback onTogglePreset;
  final bool autoCaptureActive;
  final VoidCallback? onOpenAutoCapture;

  @override
  Widget build(BuildContext context) {
    final tokens = ReZyTokens.of(context);
    final textTheme = Theme.of(context).textTheme;
    final cal = personaCalendarFrom(now);
    final isP5 = preset == PersonaThemePreset.shibuya;

    final nextPresetLabel = isP5
        ? 'Ganti ke tema Persona 3 Reload'
        : 'Ganti ke tema Persona 5 Royal';

    final emblemPath = isP5
        ? 'assets/images/p5r_emblem.png'
        : 'assets/images/p3r_emblem.png';

    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(isP5 ? 12 : 24),
            border: Border.all(
              color: isP5 ? tokens.ink : tokens.accent.withOpacity(0.55),
              width: 1.4,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isP5 ? 10.5 : 22.5),
            child: Image.asset(
              emblemPath,
              gaplessPlayback: true,
              fit: BoxFit.cover,
              semanticLabel: isP5
                  ? 'Emblem ReZyLife tema Shibuya P5R'
                  : 'Emblem ReZyLife tema Tatsumi P3R',
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'ReZyLife',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleLarge?.copyWith(
                        color: tokens.ink,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (isP5)
                    Transform.rotate(
                      angle: -0.04,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: tokens.accent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'PERSONA',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 9.5,
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.accentSoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PERSONA',
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 9.5,
                          color: tokens.accent,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              if (isP5)
                _P5CalendarStrip(cal: cal, tokens: tokens)
              else
                _P3CalendarStrip(now: now, cal: cal, tokens: tokens),
            ],
          ),
        ),
        const SizedBox(width: 4),
        if (onOpenAutoCapture != null)
          Semantics(
            button: true,
            label: autoCaptureActive
                ? 'Auto-Catat Notifikasi aktif'
                : 'Atur Auto-Catat Notifikasi',
            child: Tooltip(
              message: 'Auto-Catat Notifikasi',
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpenAutoCapture!();
                },
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 44,
                  height: 48,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(
                          autoCaptureActive
                              ? Icons.notifications_active_rounded
                              : Icons.notifications_none_rounded,
                          size: 22,
                          color: autoCaptureActive
                              ? tokens.income
                              : tokens.inkMuted,
                        ),
                        if (autoCaptureActive)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: tokens.income,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: tokens.paperBg,
                                  width: 1.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        Semantics(
          button: true,
          label: nextPresetLabel,
          child: Tooltip(
            message: nextPresetLabel,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                onTogglePreset();
              },
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: isP5 ? tokens.accentSoft : tokens.accentSoft,
                      borderRadius: BorderRadius.circular(isP5 ? 10 : 14),
                      border: Border.all(
                        color: isP5
                            ? tokens.accent
                            : tokens.accent.withOpacity(0.45),
                        width: 1.3,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExcludeSemantics(
                          child: isP5
                              ? PersonaStarIcon(
                                  size: 15,
                                  color: tokens.accent,
                                  outlineColor: Colors.white,
                                )
                              : PersonaMoonPhaseIcon(
                                  date: now,
                                  size: 15,
                                  litColor: tokens.accent,
                                  shadowColor: tokens.surface,
                                  outlineColor: tokens.ink,
                                ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          tokens.presetCode,
                          style: textTheme.labelMedium?.copyWith(
                            color: isP5 ? Colors.white : tokens.ink,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _P3CalendarStrip extends StatelessWidget {
  const _P3CalendarStrip({
    required this.now,
    required this.cal,
    required this.tokens,
  });

  final DateTime now;
  final PersonaCalendarInfo cal;
  final ReZyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final phaseLabel = now.hour == 0 ? 'Dark Hour' : cal.phaseLabel;
    final monthNum = now.month.toString();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: PersonaMoonPhaseIcon(
            date: now,
            size: 14,
            litColor: tokens.accent,
            shadowColor: tokens.accentSoft,
            outlineColor: tokens.ink,
          ),
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$monthNum/${cal.dayNumber}',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.accent,
                    fontWeight: FontWeight.w800,
                    fontFeatures: kTabularFigures,
                  ),
                ),
                TextSpan(
                  text: ' · ${cal.weekdayShort} · $phaseLabel',
                  style: textTheme.labelSmall?.copyWith(
                    color: tokens.inkMuted,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _P5CalendarStrip extends StatelessWidget {
  const _P5CalendarStrip({
    required this.cal,
    required this.tokens,
  });

  final PersonaCalendarInfo cal;
  final ReZyTokens tokens;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform.rotate(
          angle: -0.05,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${cal.dayNumber} ${cal.monthShort}',
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10.5,
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontFeatures: kTabularFigures,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            '${cal.weekdayShort} · ${cal.phaseLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: tokens.inkMuted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
