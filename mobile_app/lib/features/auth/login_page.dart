// Login screen: e-mail + password.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/strings/app_strings.dart';
import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';
import 'auth_widgets.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  // true while waiting for Supabase (the button shows a spinner).
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      showMessage(context, AppStrings.fillAllFields);
      return;
    }

    setState(() => _loading = true);
    try {
      await supabase.auth.signInWithPassword(email: email, password: password);
      // Nothing else to do: AuthGate sees the login and opens the app.
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, AppStrings.somethingWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      children: [
        const Icon(Icons.park, size: 96, color: AppColors.olive),
        Text(
          AppStrings.appName,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        const SizedBox(height: 32),
        AuthField(
          controller: _email,
          label: AppStrings.email,
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        AuthField(
          controller: _password,
          label: AppStrings.password,
          icon: Icons.lock,
          obscure: true,
        ),
        const SizedBox(height: 16),
        AuthButton(text: AppStrings.login, loading: _loading, onPressed: _login),
        const SizedBox(height: 16),
        TextButton(
          onPressed: _loading
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignupPage()),
                  ),
          child: const Text(AppStrings.noAccount, style: TextStyle(fontSize: 18)),
        ),
      ],
    );
  }
}
