// Connection to Supabase (our online database + login system).
//
// The 2 keys are NOT written in the code: they come from the .env file,
// passed when starting the app:  flutter run --dart-define-from-file=.env
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey =
      String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');

  /// false = the app was started without the .env file.
  static bool get hasKeys =>
      url.isNotEmpty && publishableKey.isNotEmpty && !url.contains('YOUR-PROJECT');

  /// Connects to Supabase. Call it once, before runApp().
  static Future<void> init() {
    return Supabase.initialize(url: url, publishableKey: publishableKey);
  }
}

/// Shortcut used everywhere: `supabase.from('trees')`, `supabase.auth`...
SupabaseClient get supabase => Supabase.instance.client;
