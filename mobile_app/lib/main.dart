// Entry point of the Looz mobile app.
// Flutter starts here: runApp() draws the root widget on the screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  // Needed before doing any work (like Supabase) before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // Dark status bar icons (the pages are light).
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);

  // The login is a demo for now, so the app also runs without the keys.
  // With the keys, Supabase is ready for the real login and data later.
  if (SupabaseConfig.hasKeys) await SupabaseConfig.init();
  runApp(const LoozApp());
}
