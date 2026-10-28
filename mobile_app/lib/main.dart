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

  // The login needs Supabase: without the keys, a help message.
  if (!SupabaseConfig.hasKeys) {
    runApp(const MissingKeysApp());
    return;
  }
  // Also reads the session saved on the phone (the user stays logged in).
  await SupabaseConfig.init();
  runApp(const LoozApp());
}
