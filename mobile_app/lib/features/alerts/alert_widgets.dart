// The pieces of the alert screens, in the design's style: the card of a
// regional alert, the colours and icons of each severity and kind, the
// pills, the steps of "ماذا أفعل؟", the "قريبًا" rows.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/locale.dart';
import '../../core/theme/app_theme.dart';
import '../../data/alerts_service.dart';
import '../../shared/widgets/alert_card.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/soon_message.dart';
import '../../shared/widgets/text_link.dart';
import '../community/community_widgets.dart' show StateCard;

/// The face of the card: danger = sad, warning = worried, info = calm.
StatusLevel levelOf(AlertSeverity severity) => switch (severity) {
  AlertSeverity.danger => StatusLevel.danger,
  AlertSeverity.warning => StatusLevel.warning,
  AlertSeverity.info => StatusLevel.good,
};

/// The side bar and the pill: the design's dark / medium green, and blue
/// for an information.
Color severityColor(AlertSeverity severity) => switch (severity) {
  AlertSeverity.danger => AppColors.danger,
  AlertSeverity.warning => AppColors.warning,
  AlertSeverity.info => AppColors.info,
};

String severityName(AppLocalizations l10n, AlertSeverity severity) =>
    switch (severity) {
      AlertSeverity.danger => l10n.severityDanger,
      AlertSeverity.warning => l10n.severityWarning,
      AlertSeverity.info => l10n.severityInfo,
    };

AppIcon kindIcon(AlertKind kind) => switch (kind) {
  AlertKind.frost => AppIcon.snow,
  AlertKind.heat => AppIcon.thermo,
  AlertKind.drought => AppIcon.sun,
  AlertKind.disease => AppIcon.leaf,
  AlertKind.pest => AppIcon.bug,
  AlertKind.wind => AppIcon.wind,
  AlertKind.rain => AppIcon.rain,
};

String kindName(AppLocalizations l10n, AlertKind kind) => switch (kind) {
  AlertKind.frost => l10n.kindFrost,
  AlertKind.heat => l10n.kindHeat,
  AlertKind.drought => l10n.kindDrought,
  AlertKind.disease => l10n.kindDisease,
  AlertKind.pest => l10n.kindPest,
  AlertKind.wind => l10n.kindWind,
  AlertKind.rain => l10n.kindRain,
};

/// "صالح حتى 16/11 على الساعة 08:00" (the time of the phone), or "صالح حتى
/// إشعار آخر".
String alertValidity(AppLocalizations l10n, RegionalAlert alert) {
  final end = alert.endsAt?.toLocal();
  if (end == null) return l10n.alertNoEnd;
  String two(int n) => n.toString().padLeft(2, '0');
  return l10n.alertValidUntil(
    '${end.day}/${end.month}',
    '${two(end.hour)}:${two(end.minute)}',
  );
}

/// The message of a failed action, in the language of the app.
String alertsFailureMessage(AppLocalizations l10n, AlertsFailure failure) =>
    switch (failure) {
      AlertsFailure.noInternet => l10n.errorNoInternet,
      AlertsFailure.gone => l10n.alertGone,
      AlertsFailure.sessionExpired => l10n.errorSessionExpired,
      AlertsFailure.unknown => l10n.somethingWrong,
    };

/// A regional alert in a list: its face and side bar (severity), title,
/// the first step to do (or the severity), the icon of its kind, "جديد".
class RegionalAlertCard extends StatelessWidget {
  const RegionalAlertCard({super.key, required this.alert, this.onTap});

  final RegionalAlert alert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final language = Localizations.localeOf(context).languageCode;
    final steps = alert.adviceSteps(language);
    final card = AlertCard(
      level: levelOf(alert.severity),
      barColor: severityColor(alert.severity),
      title: alert.title(language),
      // (The card's text has no ✓: the Cairo font does not draw it.)
      text: alert.done
          ? l10n.done
          : steps.isNotEmpty
          ? steps.first
          : severityName(l10n, alert.severity),
      icon: kindIcon(alert.kind),
      tag: alert.unread ? l10n.alertNew : null,
      semanticLabel: severityName(l10n, alert.severity),
      onTap: onTap,
    );
    // A done alert: paler, at the end of the list.
    return alert.done ? Opacity(opacity: 0.6, child: card) : card;
  }
}

/// A small coloured pill: "خطر" (white on the severity colour) or the kind
/// ("صقيع", on white).
class AlertPill extends StatelessWidget {
  const AlertPill({super.key, required this.text, this.color});

  final String text;

  /// null = white with green text.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final color = this.color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.white60,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        text,
        style: AppTextStyles.of(
          15,
          FontWeight.w800,
        ).copyWith(color: color == null ? AppColors.green : AppColors.white),
      ),
    );
  }
}

/// The steps of "ماذا أفعل؟": a numbered circle and a short sentence each.
class AdviceSteps extends StatelessWidget {
  const AdviceSteps({super.key, required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, step) in steps.indexed) ...[
          if (i > 0) const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.mint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${i + 1}',
                  style: AppTextStyles.of(16, FontWeight.w800),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(step, style: AppTextStyles.of(18))),
            ],
          ),
        ],
      ],
    );
  }
}

/// A row "not ready yet": an icon, a text and the pill "قريبًا". Tapping it
/// says "قريبًا".
class SoonRow extends StatelessWidget {
  const SoonRow({super.key, required this.icon, required this.text});

  final AppIcon icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: () => showSoon(context),
        child: CssBox(
          minHeight: 72,
          color: AppColors.white78,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            children: [
              LoozIcon(icon),
              const SizedBox(width: 14),
              Expanded(child: Text(text, style: AppTextStyles.of(17))),
              const SizedBox(width: 10),
              AlertPill(text: context.l10n.soon, color: AppColors.midGreen),
            ],
          ),
        ),
      ),
    );
  }
}

/// The list could not be loaded: "لا يوجد إنترنت" (+ "حاول مرة أخرى") or
/// "حاول مرة أخرى". Both try again when tapped.
class AlertsFailureCard extends StatelessWidget {
  const AlertsFailureCard({
    super.key,
    required this.failure,
    required this.onRetry,
  });

  final AlertsFailure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (failure != AlertsFailure.noInternet) {
      return StateCard(
        icon: AppIcon.warning,
        text: l10n.tryAgain,
        color: AppColors.peach,
        onTap: onRetry,
        height: 150,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StateCard(
          icon: AppIcon.wifi,
          text: l10n.noInternet,
          color: AppColors.sky,
          onTap: onRetry,
          height: 150,
        ),
        TextLink(label: l10n.tryAgain, onTap: onRetry),
      ],
    );
  }
}

/// A section title of the tab ("في منطقتك · صفاقس", "بستاني").
class AlertsSectionTitle extends StatelessWidget {
  const AlertsSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
        header: true,
        child: Text(text, style: AppTextStyles.sectionTitle),
      ),
    );
  }
}
