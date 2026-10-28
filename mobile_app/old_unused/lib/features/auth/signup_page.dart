// Sign-up screen: name, e-mail, password, and farmer / expert.
//
// We send the name and role to Supabase as "metadata". The database
// trigger (handle_new_user in looz_policies.sql) reads them and creates
// the row in the "profiles" table by itself.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/enums.dart';
import '../../core/locale.dart';
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
      showMessage(context, context.l10n.authFillAllFields);
      return;
    }
    if (password.length < 6) {
      showMessage(context, context.l10n.authPasswordTooShort);
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
        showMessage(context, context.l10n.authCheckEmail);
      }
      // If already logged in, AuthGate (under this page) now shows the app.
      Navigator.of(context).pop();
    } on AuthException catch (e) {
      if (mounted) showMessage(context, e.message);
    } catch (_) {
      if (mounted) showMessage(context, context.l10n.somethingWrong);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: context.l10n.authSignup,
      children: [
        AuthField(
          controller: _name,
          label: context.l10n.authName,
          icon: Icons.person,
        ),
        AuthField(
          controller: _email,
          label: context.l10n.authEmail,
          icon: Icons.email,
          keyboardType: TextInputType.emailAddress,
        ),
        AuthField(
          controller: _password,
          label: context.l10n.authPassword,
          icon: Icons.lock,
          obscure: true,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.authIAm,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        SegmentedButton<UserRole>(
          segments: [
            ButtonSegment(
              value: UserRole.farmer,
              label: Text(context.l10n.authFarmer),
              icon: const Icon(Icons.agriculture),
            ),
            ButtonSegment(
              value: UserRole.expert,
              label: Text(context.l10n.authExpert),
              icon: const Icon(Icons.school),
            ),
          ],
          selected: {_role},
          onSelectionChanged: (selection) =>
              setState(() => _role = selection.first),
        ),
        const SizedBox(height: 24),
        AuthButton(
          text: context.l10n.authSignup,
          loading: _loading,
          onPressed: _signup,
        ),
      ],
    );
  }
}
