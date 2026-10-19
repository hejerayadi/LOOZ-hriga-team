// Sign-up screen: name, e-mail, password, and farmer / expert.
//
// We send the name and role to Supabase as "metadata". The database
// trigger (handle_new_user in looz_policies.sql) reads them and creates
// the row in the "profiles" table by itself.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/enums.dart';
import '../../core/strings/app_strings.dart';
import '../../core/supabase_config.dart';
import 'auth_widgets.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _role = UserRole.farmer;
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      showMessage(context, AppStrings.fillAllFields);
      return;
    }
    if (password.length < 6) {
      showMessage(context, AppStrings.passwordTooShort);
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await supabase.auth.signUp(
        email: email,
        password: password,
        // 'farmer' or 'expert' (same words as the database).
        data: {'name': name, 'role': _role.name},
      );
      if (!mounted) return;
      if (response.session == null) {
        // Supabase asks to confirm the e-mail first: go back to Login.
        showMessage(context, AppStrings.checkEmail);
      }
      // If already logged in, AuthGate (under this page) now shows the app.
      Navigator.of(context).pop();
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
      title: AppStrings.signup,
      children: [
        AuthField(controller: _name, label: AppStrings.name, icon: Icons.person),
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
        const SizedBox(height: 8),
        Text(AppStrings.iAm, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(
              value: UserRole.farmer,
              label: Text(AppStrings.farmer),
              icon: Icon(Icons.agriculture),
            ),
            ButtonSegment(
              value: UserRole.expert,
              label: Text(AppStrings.expert),
              icon: Icon(Icons.school),
            ),
          ],
          selected: {_role},
          onSelectionChanged: (selection) =>
              setState(() => _role = selection.first),
        ),
        const SizedBox(height: 24),
        AuthButton(
          text: AppStrings.signup,
          loading: _loading,
          onPressed: _signup,
        ),
      ],
    );
  }
}
