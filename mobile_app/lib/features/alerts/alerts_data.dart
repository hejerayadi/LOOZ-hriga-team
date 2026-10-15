// FAKE alerts for the "Alertes" page. Edit freely.
import 'package:flutter/material.dart';

import '../../core/enums.dart';

/// One alert. `urgency` gives the color: danger = red, warning = orange,
/// good = green (just information).
class Alert {
  const Alert({
    required this.icon,
    required this.title,
    required this.detail,
    required this.urgency,
  });

  final IconData icon;
  final String title;
  final String detail;
  final StatusLevel urgency;
}

const List<Alert> fakeAlerts = [
  Alert(
    icon: Icons.water_drop,
    title: 'Sol sec',
    detail: 'Zone nord · Humidité 12%',
    urgency: StatusLevel.danger,
  ),
  Alert(
    icon: Icons.coronavirus,
    title: 'Risque maladie',
    detail: 'Arbre 12 · Taches suspectes',
    urgency: StatusLevel.danger,
  ),
  Alert(
    icon: Icons.thermostat,
    title: 'Forte chaleur',
    detail: 'Demain · 38°C',
    urgency: StatusLevel.warning,
  ),
  Alert(
    icon: Icons.check_circle,
    title: 'Arrosage fait',
    detail: 'Zone sud · 06:30',
    urgency: StatusLevel.good,
  ),
];
