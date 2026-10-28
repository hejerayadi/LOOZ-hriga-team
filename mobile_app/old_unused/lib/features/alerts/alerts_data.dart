// FAKE alerts for the "Alertes" page. Edit freely.
import 'package:flutter/material.dart';

import '../../core/enums.dart';
import '../../core/plans.dart';

/// Where an alert comes from (same as alerts.type in the database).
enum AlertKind {
  /// Sent by an admin to a whole region (free plan).
  regional(Feature.regionalAlerts),

  /// From a zone's node sensors ("Connecté" plan).
  zone(Feature.zoneAlerts),

  /// About one tree: ONLY from a photo diagnosis, never from sensors
  /// (there is no sensor data per tree). "Essentiel" plan.
  tree(Feature.treeAlerts);

  const AlertKind(this.feature);

  /// The feature (and so the plan) needed to see this kind of alert.
  final Feature feature;
}

/// One alert. `urgency` gives the color: danger = red, warning = orange,
/// good = green (just information).
class Alert {
  const Alert({
    required this.kind,
    required this.icon,
    required this.title,
    required this.detail,
    required this.urgency,
  });

  final AlertKind kind;
  final IconData icon;
  final String title;
  final String detail;
  final StatusLevel urgency;
}

const List<Alert> fakeAlerts = [
  Alert(
    kind: AlertKind.zone,
    icon: Icons.water_drop,
    title: 'Sol sec',
    detail: 'Zone B · Humidité 14%',
    urgency: StatusLevel.danger,
  ),
  Alert(
    kind: AlertKind.tree,
    icon: Icons.coronavirus,
    title: 'Risque maladie',
    detail: 'Arbre 4 · Photo : tavelure',
    urgency: StatusLevel.danger,
  ),
  Alert(
    kind: AlertKind.regional,
    icon: Icons.thermostat,
    title: 'Forte chaleur',
    detail: 'Demain · 38°C',
    urgency: StatusLevel.warning,
  ),
  Alert(
    kind: AlertKind.zone,
    icon: Icons.check_circle,
    title: 'Arrosage fait',
    detail: 'Zone D · 06:30',
    urgency: StatusLevel.good,
  ),
];
