// The designer's steps share ONE session: the latest draft (what was
// saved), and whether it is the sign-up. Going back and forth between the
// steps keeps what was done (each step saves the draft and updates it here).
import 'package:flutter/material.dart';

import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../data/orchard_design.dart';
import '../../data/orchard_service.dart';
import 'geometry.dart';
import 'outline_screen.dart';
import 'review_screen.dart';
import 'zone_details_screen.dart';
import 'zones_screen.dart';

class DesignSession {
  DesignSession({required this.design, this.signUp = false});

  /// The latest draft (saved after every step).
  OrchardDesign design;

  /// true = during the sign-up (no tab bar, "متابعة مجانًا").
  final bool signUp;

  /// Saves [next] as the draft (in the database), then keeps it.
  Future<void> save(OrchardDesign next) async {
    await orchardService.saveDesign(next);
    design = next;
  }

  /// The trees of the whole orchard: what the farmer said at the sign-up,
  /// or about one tree every 7 m.
  int get totalTrees =>
      currentUser.value?.almondTrees ??
      estimateTrees(polygonArea(design.outline), spacing: design.spacing);
}

/// Opens the designer where [session]'s draft stopped. The steps before it
/// are under it, so "back" goes through them:
///   nothing drawn → the outline; outline only → the zones;
///   zones made → their details; the review reached → the review.
void openDesigner(BuildContext context, DesignSession session) {
  final design = session.design;
  openScreen(context, OutlineScreen(session: session));
  if (design.outline.length < 3) return;
  openScreen(context, ZonesScreen(session: session));
  if (design.zones.isEmpty) return;
  openScreen(context, ZoneDetailsScreen(session: session));
  if (design.step != DesignStep.review) return;
  openScreen(context, ReviewScreen(session: session));
}

/// The same corners (to the centimetre)?
bool samePoints(List<OrchardPoint> a, List<OrchardPoint> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i].x - b[i].x).abs() > 0.005 || (a[i].z - b[i].z).abs() > 0.005) {
      return false;
    }
  }
  return true;
}
