// Runs before every test file (Flutter's own rule for this file name): the
// live orchard (ML predictions, migration 019) never reaches the real
// Supabase in the tests. Each test can put its own fake (useMl in
// test_helpers.dart).
import 'dart:async';

import 'package:looz_mobile/data/ml_service.dart';

import 'fake_ml_service.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  mlService = FakeMlService(const OrchardLive());
  await testMain();
}
