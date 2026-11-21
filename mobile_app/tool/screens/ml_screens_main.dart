// SCREENSHOTS ONLY (not part of the app): the real screens of the ML module
// with the fakes of the tests (no Supabase, no internet) and the demo orchard.
//   flutter build web -t tool/screens/ml_screens_main.dart --output <folder>
// URL parameters: lang=ar|fr, tab=orchard|alerts, focus=<zone id> (opens its
// panel), banner=1 (a new frost risk arrives after 3 s, like Supabase Realtime).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/navigation.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/alerts_service.dart';
import 'package:looz_mobile/data/community_service.dart';
import 'package:looz_mobile/data/ml_service.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/features/orchard_3d/orchard_live_store.dart';

import '../../test/fake_alerts_service.dart';
import '../../test/fake_auth_service.dart';
import '../../test/fake_community_service.dart';
import '../../test/fake_ml_service.dart';
import '../../test/fake_orchard_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final q = Uri.base.queryParameters;
  final lang = q['lang'] == 'fr' ? 'fr' : 'ar';
  appLocale.value = Locale(lang);
  currentPlan.value = Plan.paid;
  final auth = FakeAuthService();
  authService = auth;
  currentUser.value = lang == 'ar'
      ? auth.addUser('+21622777001', firstName: 'محمد', lastName: 'بن سالم', language: 'ar')
      : auth.addUser('+21622777001', firstName: 'Mohamed', lastName: 'Ben Salem', language: 'fr');
  communityService = FakeCommunityService.sample(lang);
  alertsService = FakeAlertsService();
  orchardService = FakeOrchardService(demoOrchard());

  // The demo orchard on a frost night in bloom: zone A frost risk (Groq texts),
  // zone B short of water, zone C offline, zone D waiting for its box.
  final base = sampleLive();
  final live = OrchardLive(
    nodes: base.nodes,
    predictions: {
      ...base.predictions,
      'node-A': {
        'frost': prediction(
          'node-A', 'frost', 'frost_risk',
          likely: false,
          factors: const [
            MlFactor(code: 'cooling_fast', level: 'high', share: 0.38),
            MlFactor(code: 'dew_point', level: 'low', share: 0.34),
            MlFactor(code: 'zone_place', level: 'low', share: 0.28),
          ],
          textAr: 'موش متأكدين، أما الليلة تنجم تجي صقيع في المنطقة أ. الحرارة تهبط بسرعة والهواء ناشف، والمنطقة في بقعة منخفضة.',
          textFr: 'Nous ne sommes pas sûrs, mais il peut geler cette nuit en Zone A. La température baisse vite, l\'air est sec et la zone est dans un creux.',
          actionAr: 'امشي للمنطقة هاذي الليلة وحضّر الحماية اللي تستعمل فيها عادة.',
          actionFr: 'Allez voir la zone ce soir et préparez la protection que vous utilisez d\'habitude.',
        ),
        'stress': base.predictions['node-A']!['stress']!,
      },
    },
    notifications: [
      notification('n-1', 'node-B', 'stress', 'water_deficit', minutesAgo: 40),
    ],
  );
  final ml = FakeMlService(live);
  mlService = ml;
  currentTab.value = q['tab'] == 'alerts' ? AppTab.alerts : AppTab.orchard;
  runApp(const LoozApp(home: MainShell()));
  if (q['focus'] != null) {
    Timer(const Duration(seconds: 4), () => focusZone.value = q['focus']);
  }
  if (q['banner'] == '1') {
    Timer(const Duration(seconds: 3), () {
      ml.push(OrchardLive(
        nodes: live.nodes,
        predictions: live.predictions,
        notifications: [
          notification('n-9', 'node-A', 'frost', 'frost_risk', danger: true, minutesAgo: 0),
          ...live.notifications,
        ],
      ));
    });
  }
}
