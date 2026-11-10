// Subscription plans: the ONE place in the app that answers
// "can this user use feature X?".
//
// Same rules as the database (supabase/migrations/011_two_packs_orchard_designer.sql),
// which also blocks the data itself. Two packs (migration 011):
//   free  (مجاني / Gratuit)    community, regional alerts. Never pays.
//   paid  (بريميوم / Premium)  + the 3D orchard, predictions, photo diagnosis,
//                               the assistant and the voice chat.
//                               8 DT per zone (node) for 30 days.
import 'package:flutter/foundation.dart';

/// The 2 packs. The order matters: free < paid.
enum Plan { free, paid }

/// The pack named by the database. The old names of migration 004
/// ('essential', 'connected') are the paid pack now.
Plan planFromName(Object? name) =>
    const {'paid', 'essential', 'connected'}.contains(name)
    ? Plan.paid
    : Plan.free;

/// Every feature that depends on the plan, with the smallest plan that has it.
enum Feature {
  community(Plan.free),
  regionalAlerts(Plan.free),
  assistant(Plan.paid), // the assistant bar, the voice chat, "تكلّم"
  orchard3d(Plan.paid), // "بستاني ★", the map
  photoDiagnosis(Plan.paid), // the camera (CV)
  treeAlerts(Plan.paid), // alerts from photo diagnoses
  liveZoneData(Plan.paid), // the sensor nodes of the zones
  zoneAlerts(Plan.paid),
  aiPredictions(Plan.paid); // irrigation, harvest

  const Feature(this.minPlan);

  /// The smallest plan that has this feature.
  final Plan minPlan;
}

/// The plan of the logged-in user, read from Supabase (user_plan()) at the
/// login (see core/session.dart). Free until the paid pack is paid.
/// (The developer switch in the Profile tab changes it, in debug builds.)
/// Screens listen to it, so they update as soon as it changes.
final ValueNotifier<Plan> currentPlan = ValueNotifier(Plan.free);

// The price of the paid pack is in the database (table plan_prices: 8 DT per
// zone / 30 days), read by lib/data/payment_service.dart. Change it in
// Supabase > Table Editor.

/// Can the user (or the given plan) use this feature?
bool canUse(Feature feature, [Plan? plan]) =>
    (plan ?? currentPlan.value).index >= feature.minPlan.index;
