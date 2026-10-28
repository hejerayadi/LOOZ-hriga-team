// Decides which screen to show: Login (not logged in) or the app (logged in).
// It listens to Supabase, so it switches by itself after login / logout.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app.dart';
import '../../core/supabase_config.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Supabase remembers the login, so the user stays connected
        // even after closing the app.
        final session = snapshot.data?.session ?? supabase.auth.currentSession;
        return session == null ? const LoginPage() : const MainShell();
      },
    );
  }
}
