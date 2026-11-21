// The words, colours and icons of the live state of a zone (predictions of
// migration 019), in ONE place for the 3D, the zone panel, the alerts tab and
// the in-app notifications. Codes only come from the database: every text is
// in the ARB files.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/theme/app_theme.dart';
import '../../data/ml_service.dart';
import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_icon.dart';

String zoneStateName(AppLocalizations l10n, ZoneState state) => switch (state) {
  ZoneState.ok => l10n.mlStateOk,
  ZoneState.waterDeficit => l10n.mlStateWaterDeficit,
  ZoneState.waterlogging => l10n.mlStateWaterlogging,
  ZoneState.heat => l10n.mlStateHeat,
  ZoneState.frostDamage => l10n.mlStateFrostDamage,
  ZoneState.rootzone => l10n.mlStateRootzone,
  ZoneState.frostRisk => l10n.mlStateFrostRisk,
  ZoneState.sensorProblem => l10n.mlStateSensorProblem,
  ZoneState.notEnoughData => l10n.mlStateNotEnoughData,
  ZoneState.offline => l10n.mlStateOffline,
  ZoneState.waiting => l10n.nodeWaiting,
};

AppIcon zoneStateIcon(ZoneState state) => switch (state) {
  ZoneState.ok => AppIcon.check,
  ZoneState.waterDeficit => AppIcon.drop,
  ZoneState.waterlogging => AppIcon.rain,
  ZoneState.heat => AppIcon.thermo,
  ZoneState.frostDamage => AppIcon.snow,
  ZoneState.rootzone => AppIcon.tree,
  ZoneState.frostRisk => AppIcon.snow,
  ZoneState.sensorProblem => AppIcon.warning,
  ZoneState.notEnoughData => AppIcon.clock,
  ZoneState.offline => AppIcon.wifi,
  ZoneState.waiting => AppIcon.clock,
};

/// The colour of a state: the design's 3 greens (fine / watch / act now),
/// blue for the cold of a frost night, grey without a prediction.
Color zoneStateColor(ZoneState state) => switch (state) {
  ZoneState.ok => AppColors.good,
  ZoneState.waterDeficit ||
  ZoneState.waterlogging ||
  ZoneState.rootzone => AppColors.warning,
  ZoneState.heat || ZoneState.frostDamage => AppColors.danger,
  ZoneState.frostRisk => AppColors.info,
  _ => AppColors.noData,
};

/// The face of a card.
StatusLevel zoneStateLevel(ZoneState state) => switch (state) {
  ZoneState.ok => StatusLevel.good,
  ZoneState.heat ||
  ZoneState.frostDamage ||
  ZoneState.frostRisk => StatusLevel.danger,
  _ => StatusLevel.warning,
};

/// A main reason in farmer words (never the feature name).
String factorText(AppLocalizations l10n, MlFactor f) {
  final high = f.level != 'low';
  return switch (f.code) {
    'soil_water' => high ? l10n.mlFactorSoilWaterHigh : l10n.mlFactorSoilWaterLow,
    'soil_drying' => high ? l10n.mlFactorSoilDryingHigh : l10n.mlFactorSoilDryingLow,
    'soil_too_wet' => high ? l10n.mlFactorSoilTooWetHigh : l10n.mlFactorSoilTooWetLow,
    'watering' => high ? l10n.mlFactorWateringHigh : l10n.mlFactorWateringLow,
    'tree_water_need' =>
      high ? l10n.mlFactorTreeWaterNeedHigh : l10n.mlFactorTreeWaterNeedLow,
    'air_heat' => high ? l10n.mlFactorAirHeatHigh : l10n.mlFactorAirHeatLow,
    'night_cold' => high ? l10n.mlFactorNightColdHigh : l10n.mlFactorNightColdLow,
    'evening_temp' =>
      high ? l10n.mlFactorEveningTempHigh : l10n.mlFactorEveningTempLow,
    'cooling_fast' =>
      high ? l10n.mlFactorCoolingFastHigh : l10n.mlFactorCoolingFastLow,
    'night_low_expected' =>
      high ? l10n.mlFactorNightLowExpectedHigh : l10n.mlFactorNightLowExpectedLow,
    'dew_point' => high ? l10n.mlFactorDewPointHigh : l10n.mlFactorDewPointLow,
    'air_humidity' =>
      high ? l10n.mlFactorAirHumidityHigh : l10n.mlFactorAirHumidityLow,
    'air_dryness' => high ? l10n.mlFactorAirDrynessHigh : l10n.mlFactorAirDrynessLow,
    'clear_sky' => high ? l10n.mlFactorClearSkyHigh : l10n.mlFactorClearSkyLow,
    'sunlight' => high ? l10n.mlFactorSunlightHigh : l10n.mlFactorSunlightLow,
    'soil_temp' => high ? l10n.mlFactorSoilTempHigh : l10n.mlFactorSoilTempLow,
    'tree_sounds' => high ? l10n.mlFactorTreeSoundsHigh : l10n.mlFactorTreeSoundsLow,
    'zone_place' => high ? l10n.mlFactorZonePlaceHigh : l10n.mlFactorZonePlaceLow,
    'ground_cover' =>
      high ? l10n.mlFactorGroundCoverHigh : l10n.mlFactorGroundCoverLow,
    'season_stage' => l10n.mlFactorSeasonStage,
    'soil_type' => l10n.mlFactorSoilType,
    'irrigation_type' => l10n.mlFactorIrrigationType,
    'other_zones' => l10n.mlFactorOtherZones,
    _ => l10n.mlFactorDataQuality,
  };
}

/// "ماذا أفعل؟" of the template (when Groq gave no text).
String templateAction(AppLocalizations l10n, MlPrediction p) =>
    switch (p.state) {
      'water_deficit' => l10n.mlActionWaterDeficit,
      'waterlogging' => l10n.mlActionWaterlogging,
      'heat' => l10n.mlActionHeat,
      'frost' => l10n.mlActionFrostDamage,
      'rootzone' => l10n.mlActionRootzone,
      'frost_risk' => l10n.mlActionFrostRisk,
      'no_frost' => l10n.mlActionNoFrost,
      _ => l10n.mlActionNone,
    };

/// The explanation: Groq's text, else a simple one made from the codes.
String explanationOf(
  AppLocalizations l10n,
  MlPrediction p,
  String zoneName,
  String language,
) {
  final groq = p.explanation(language);
  if (groq != null && groq.isNotEmpty) return groq;
  final state = p.model == 'frost' && p.state == 'no_frost'
      ? l10n.mlStateNoFrost
      : zoneStateName(l10n, zoneStateOf(p.state) ?? ZoneState.ok);
  final reasons = [for (final f in p.factors.take(2)) factorText(l10n, f)];
  final text = l10n.mlTemplateText(
    zoneName,
    state,
    reasons.join(l10n.mlListSeparator),
  );
  return p.likely ? text : '$text ${l10n.mlTemplateUnsure}';
}

/// The action: Groq's sentence, else the template's.
String actionOf(AppLocalizations l10n, MlPrediction p, String language) {
  final groq = p.action(language);
  return groq != null && groq.isNotEmpty ? groq : templateAction(l10n, p);
}

/// "منذ 3 دقائق" / "il y a 3 minutes".
String timeAgo(AppLocalizations l10n, DateTime time, [DateTime? now]) {
  final d = (now ?? DateTime.now()).difference(time);
  if (d.inMinutes < 60) return l10n.timeMinutesAgo(d.inMinutes < 1 ? 1 : d.inMinutes);
  if (d.inHours < 24) return l10n.timeHoursAgo(d.inHours);
  return l10n.timeDaysAgo(d.inDays);
}
