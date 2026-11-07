// Subscription plans: the ONE place in the app that answers
// "can this user use feature X?".
//
// Same rules as the database (supabase/migrations/004_subscription_plans.sql),
// which also blocks the data itself. Plans, from small to big:
//   free       (Gratuit)   community, AI assistant (10 questions/day), regional alerts
//   essential  (Essentiel) + land/soil setup, drawing, 3D map, AI layout, photo diagnosis
//   connected  (Connecté)  + IoT nodes and live zone data, zone alerts, AI predictions
import 'package:flutter/foundation.dart';

/// The 3 plans. The order matters: free < essential < connected.
enum Plan { free, essential, connected }

/// Every feature that depends on the plan, with the smallest plan that has it.
enum Feature {
  community(Plan.free),
  assistant(Plan.free), // free: limited, see assistantDailyLimit()
  regionalAlerts(Plan.free),
  landSetup(Plan.essential),
  orchardDrawing(Plan.essential),
  orchard3d(Plan.essential),
  aiLayout(Plan.essential),
  photoDiagnosis(Plan.essential),
  treeAlerts(Plan.essential), // alerts from photo diagnoses
  liveZoneData(Plan.connected), // IoT nodes + live zone data
  zoneAlerts(Plan.connected),
  aiPredictions(Plan.connected); // irrigation, harvest

  const Feature(this.minPlan);

  /// The smallest plan that has this feature.
  final Plan minPlan;
}

/// The plan of the logged-in user, read from Supabase (user_plan()) at the
/// login (see core/session.dart). Free until a paid pack is paid.
/// (The developer switch in the Profile tab changes it, in debug builds.)
/// Screens listen to it, so they update as soon as it changes.
final ValueNotifier<Plan> currentPlan = ValueNotifier(Plan.free);

// The prices of the packs are in the database (table plan_prices: 15 DT /
// 30 days for Essential, 8 DT per sensor / 30 days for Connected), read by
// lib/data/payment_service.dart. Change them in Supabase > Table Editor.

/// Can the user (or the given plan) use this feature?
bool canUse(Feature feature, [Plan? plan]) =>
    (plan ?? currentPlan.value).index >= feature.minPlan.index;

/// AI assistant questions per day on the free plan.
const int freeAssistantQuestionsPerDay = 10;

/// Questions per day allowed by the plan (null = no limit).
int? assistantDailyLimit([Plan? plan]) =>
    (plan ?? currentPlan.value) == Plan.free
    ? freeAssistantQuestionsPerDay
    : null;
