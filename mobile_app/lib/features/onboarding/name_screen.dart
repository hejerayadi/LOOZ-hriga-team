// Sign-up, new user: the first name and the last name (both required).
// Same look as the phone screen: the big title, white boxes, the button.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/auth_service.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import 'auth_messages.dart';
import 'pack_screen.dart';

class NameScreen extends StatefulWidget {
  const NameScreen({super.key});

  @override
  State<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends State<NameScreen> {
  // Filled with the saved name when the user comes back to this screen.
  late final _first = TextEditingController(
    text: currentUser.value?.firstName,
  );
  late final _last = TextEditingController(text: currentUser.value?.lastName);
  NameProblem? _firstProblem;
  NameProblem? _lastProblem;
  AuthFailure? _failure;
  bool _busy = false;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final firstProblem = checkName(_first.text);
    final lastProblem = checkName(_last.text);
    setState(() {
      _firstProblem = firstProblem;
      _lastProblem = lastProblem;
      _failure = null;
    });
    if (firstProblem != null || lastProblem != null) return;
    setState(() => _busy = true);
    try {
      updateUser(await authService.saveName(_first.text, _last.text));
      if (mounted) openScreen(context, const PackScreen());
    } catch (error) {
      if (mounted) setState(() => _failure = failureOf(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = MediaQuery.paddingOf(context);
    final failure = _failure;
    return Scaffold(
      body: LoozBackground(
        child: AutofillGroup(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pageSide(context, shrink: false),
              system.top + 28,
              AppSpacing.pageSide(context, shrink: false),
              system.bottom + 30,
            ),
            children: [
              const LoozHeader(),
              ScreenTitle(
                title: l10n.nameTitle,
                subtitle: l10n.nameSubtitle,
                top: 64,
              ),
              const SizedBox(height: 10),
              _NameField(
                label: l10n.firstName,
                controller: _first,
                problem: _firstProblem,
                autofillHint: AutofillHints.givenName,
                last: false,
                onChanged: () => setState(() => _firstProblem = null),
                onSubmitted: _save,
              ),
              const SizedBox(height: 18),
              _NameField(
                label: l10n.lastName,
                controller: _last,
                problem: _lastProblem,
                autofillHint: AutofillHints.familyName,
                last: true,
                onChanged: () => setState(() => _lastProblem = null),
                onSubmitted: _save,
              ),
              if (failure != null) ...[
                const SizedBox(height: 16),
                AuthNote.failure(failure),
              ],
              const SizedBox(height: 28),
              ActionButton(
                label: _busy ? l10n.saving : l10n.continueLabel,
                onPressed: _busy ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The name of the box above it, the white box (like the phone number's),
/// and what is wrong under it.
class _NameField extends StatefulWidget {
  const _NameField({
    required this.label,
    required this.controller,
    required this.problem,
    required this.autofillHint,
    required this.last,
    required this.onChanged,
    required this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final NameProblem? problem;
  final String autofillHint;

  /// true = the last box: the keyboard's button sends the form.
  final bool last;

  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  State<_NameField> createState() => _NameFieldState();
}

class _NameFieldState extends State<_NameField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final problem = widget.problem;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
          child: Text(widget.label, style: AppTextStyles.cardTitle),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 74,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
            // A green line while typing (and a dark one when it is wrong).
            border: Border.all(
              color: problem != null
                  ? AppColors.danger
                  : _focus.hasFocus
                  ? AppColors.leaf
                  : AppColors.white,
              width: 2,
            ),
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            style: AppTextStyles.of(22, FontWeight.w700),
            cursorColor: AppColors.green,
            decoration: InputDecoration.collapsed(
              hintText: null,
              filled: false,
              border: InputBorder.none,
            ),
            textCapitalization: TextCapitalization.words,
            textInputAction: widget.last
                ? TextInputAction.done
                : TextInputAction.next,
            keyboardType: TextInputType.name,
            autofillHints: [widget.autofillHint],
            inputFormatters: [
              LengthLimitingTextInputFormatter(nameMaxLength),
            ],
            onChanged: (_) {
              if (widget.problem != null) widget.onChanged();
            },
            onSubmitted: (_) {
              if (widget.last) widget.onSubmitted();
            },
          ),
        ),
        if (problem != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
            child: Text(
              nameProblemMessage(context.l10n, problem),
              style: AppTextStyles.of(15, FontWeight.w700)
                  .copyWith(color: AppColors.danger),
            ),
          ),
      ],
    );
  }
}
