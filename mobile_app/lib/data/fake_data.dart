// All the FAKE data of the demo, in one place (the values shown in the
// design). Replace them with real data from the database later.
// (The login and the farmer's name are real: see lib/data/auth_service.dart.)
import 'package:flutter/foundation.dart';

import '../core/enums.dart';

// ----- Home -----

/// Today's temperature (°C).
const fakeTemperature = 24;

/// The alert shown on Home ("التربة جافة"): to watch.
const fakeHomeAlertLevel = StatusLevel.warning;

// ----- Community -----
// Real now: the questions and answers come from the database
// (lib/data/community_service.dart).

// ----- Alerts -----

/// Alerts that need the farmer's attention.
const fakeAlertCount = 3;

/// The thirsty tree ("الشجرة 18 عطشى").
const fakeThirstyTree = 18;

/// Liters of water to give it, and days without rain.
const fakeWaterLiters = 20;
const fakeDaysWithoutRain = 8;

/// true once the farmer tapped "تمّ" on the alert (kept while the app runs).
final ValueNotifier<bool> fakeTreeWatered = ValueNotifier(false);

/// Farmers who reported the insect in the region.
const fakeFarmersReported = 34;

// ----- The orchard map -----

/// Number of trees.
const fakeTreeCount = 48;

/// The 9 trees drawn on the map, and their health.
const fakeMapTrees = [
  StatusLevel.good,
  StatusLevel.good,
  StatusLevel.warning,
  StatusLevel.good,
  StatusLevel.danger,
  StatusLevel.good,
  StatusLevel.warning,
  StatusLevel.good,
  StatusLevel.good,
];

/// The selected tree (A-18): soil moisture (%) and temperature (°C).
const fakeTreeMoisture = 62;
const fakeTreeTemperature = 24;

// ----- Photo diagnosis -----

/// How sure the AI is: 3 dots out of 4 ("● ● ● ○").
const fakeConfidence = 3;

/// How long "جاري النظر…" stays on screen.
const fakeThinkingTime = Duration(milliseconds: 1400);
