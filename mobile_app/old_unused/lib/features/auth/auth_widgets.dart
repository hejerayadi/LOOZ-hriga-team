// Small pieces shared by the Login and Sign-up screens.
import 'package:flutter/material.dart';

/// Shows a short message at the bottom of the screen.
void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text, style: const TextStyle(fontSize: 16))),
  );
}

/// The frame of the 2 screens: centered, scrollable, not too wide.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, this.title, required this.children});

  /// Shown in the top bar (null = no top bar, like on Login).
  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: title == null ? null : AppBar(title: Text(title!)),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A big text field with an icon.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;

  /// true = hide the text (passwords).
  final bool obscure;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

/// The big main button. Shows a spinner while `loading` is true.
class AuthButton extends StatelessWidget {
  const AuthButton({
    super.key,
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  final String text;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      child: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 3),
            )
          : Text(text),
    );
  }
}
