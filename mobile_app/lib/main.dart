// Entry point of the Looz mobile app.
// Flutter starts here: runApp() draws the root widget on the screen.
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase_config.dart';

Future<void> main() async {
  // Needed before doing any work (like Supabase) before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  // No keys = we can't connect: show a help message instead of the app.
  if (!SupabaseConfig.hasKeys) {
    runApp(const MissingKeysApp());
    return;
  }

  await SupabaseConfig.init();
  runApp(const LoozApp());
}
