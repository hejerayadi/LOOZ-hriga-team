// SCREENSHOTS ONLY (not part of the app): the orchard designer's "من صورة"
// with the fakes of the tests (no Supabase, no internet) but the REAL photo
// picker and the REAL image processing (sketch_detect.dart) in the browser.
//   flutter build web -t tool/screens/sketch_screens_main.dart --output <folder>
// URL parameter: lang=ar|fr.
import 'package:flutter/material.dart';
import 'package:looz_mobile/app.dart';
import 'package:looz_mobile/core/locale.dart';
import 'package:looz_mobile/core/plans.dart';
import 'package:looz_mobile/core/session.dart';
import 'package:looz_mobile/data/orchard_service.dart';
import 'package:looz_mobile/data/payment_service.dart';
import 'package:looz_mobile/features/orchard_designer/designer_start_screen.dart';

import '../../test/fake_auth_service.dart';
import '../../test/fake_orchard_service.dart';
import '../../test/fake_payment_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final lang = Uri.base.queryParameters['lang'] == 'fr' ? 'fr' : 'ar';
  appLocale.value = Locale(lang);
  currentPlan.value = Plan.paid;
  final auth = FakeAuthService();
  authService = auth;
  currentUser.value = lang == 'ar'
      ? auth.addUser(
          '+21622999005',
          firstName: 'سلمى',
          lastName: 'الشرفي',
          language: 'ar',
        )
      : auth.addUser(
          '+21622999005',
          firstName: 'Salma',
          lastName: 'Cherfi',
          language: 'fr',
        );
  orchardService = FakeOrchardService();
  paymentService = FakePaymentService(auth: auth);
  // Like the video: during the sign-up (Paid chosen), no tab bar.
  runApp(const LoozApp(home: DesignerStartScreen(signUp: true)));
}
