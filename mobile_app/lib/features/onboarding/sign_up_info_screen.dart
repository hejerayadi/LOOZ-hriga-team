// Sign-up, after "من أنت؟" (role_screen.dart): "معلوماتك". Few questions,
// big boxes, an icon next to each one (many farmers read with difficulty):
//   first name, last name, governorate (required), then optional: a
//   farmer's almond trees, area and watering, or an expert's organisation.
// Then: a farmer chooses his pack; an expert goes to welcome (the Free
// features: he shares his knowledge in the community).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/governorates.dart';
import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/plans.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';
import '../../core/validators.dart';
import '../../data/auth_service.dart';
import '../../data/user_profile.dart';
import '../../shared/widgets/action_button.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/blob.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_background.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/screen_title.dart';
import 'auth_messages.dart';
import 'pack_screen.dart';
import 'welcome_screen.dart';

class SignUpInfoScreen extends StatefulWidget {
  const SignUpInfoScreen({super.key, required this.role});

  /// Chosen on the screen before: farmer or expert (saved here).
  final UserRole role;

  @override
  State<SignUpInfoScreen> createState() => _SignUpInfoScreenState();
}

class _SignUpInfoScreenState extends State<SignUpInfoScreen> {
  // Filled with what is saved when the user comes back to this screen.
  late final UserProfile? _saved = currentUser.value;
  late final _first = TextEditingController(text: _saved?.firstName);
  late final _last = TextEditingController(text: _saved?.lastName);
  late String? _governorate = _saved?.governorate;
  late final _trees = TextEditingController(
    text: _saved?.almondTrees?.toString(),
  );
  late final _area = TextEditingController(
    text: _saved?.orchardAreaHa?.toString(),
  );
  late Irrigation? _irrigation = _saved?.irrigation;
  late final _organisation = TextEditingController(text: _saved?.organisation);

  NameProblem? _firstProblem;
  NameProblem? _lastProblem;
  bool _governorateMissing = false;
  bool _treesWrong = false;
  bool _areaWrong = false;
  AuthFailure? _failure;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_first, _last, _trees, _area, _organisation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _chooseGovernorate() async {
    final code = await chooseGovernorate(context, _governorate);
    if (code != null) {
      setState(() {
        _governorate = code;
        _governorateMissing = false;
      });
    }
  }

  Future<void> _save() async {
    if (_busy) return;
    final governorate = _governorate;
    // The orchard boxes are only a farmer's (hidden for an expert).
    final farmer = widget.role == UserRole.farmer;
    setState(() {
      _firstProblem = checkName(_first.text);
      _lastProblem = checkName(_last.text);
      _governorateMissing = governorate == null;
      _treesWrong =
          farmer &&
          _trees.text.trim().isNotEmpty &&
          parseAlmondTrees(_trees.text) == null;
      _areaWrong =
          farmer &&
          _area.text.trim().isNotEmpty &&
          parseOrchardArea(_area.text) == null;
      _failure = null;
    });
    if (_firstProblem != null ||
        _lastProblem != null ||
        governorate == null ||
        _treesWrong ||
        _areaWrong) {
      return;
    }
    setState(() => _busy = true);
    try {
      updateUser(
        await authService.saveSignUpInfo(
          SignUpInfo(
            role: widget.role,
            firstName: _first.text,
            lastName: _last.text,
            governorate: governorate,
            // An expert: no orchard (even if typed before choosing expert).
            almondTrees: farmer ? parseAlmondTrees(_trees.text) : null,
            orchardAreaHa: farmer ? parseOrchardArea(_area.text) : null,
            irrigation: farmer ? _irrigation : null,
            organisation: farmer ? null : _organisation.text.trim(),
          ),
        ),
      );
      if (!farmer) {
        // No pack for an expert: the Free features, then welcome.
        updateUser(await authService.choosePlan(Plan.free));
        if (mounted) replaceAllWith(context, const WelcomeScreen());
      } else if (mounted) {
        openScreen(context, const PackScreen());
      }
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
    final firstProblem = _firstProblem;
    final lastProblem = _lastProblem;
    final farmer = widget.role == UserRole.farmer;
    final digits = [
      FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹]')),
      LengthLimitingTextInputFormatter(6),
    ];
    return Scaffold(
      body: LoozBackground(
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
              title: l10n.infoTitle,
              subtitle: l10n.infoSubtitle,
              top: 64,
            ),
            // The name and the governorate (required).
            _InfoField(
              icon: AppIcon.user,
              label: l10n.firstName,
              controller: _first,
              error: firstProblem == null
                  ? null
                  : nameProblemMessage(l10n, firstProblem),
              keyboardType: TextInputType.name,
              autofillHint: AutofillHints.givenName,
              formatters: [LengthLimitingTextInputFormatter(nameMaxLength)],
              onChanged: () => setState(() => _firstProblem = null),
            ),
            const SizedBox(height: 18),
            _InfoField(
              icon: AppIcon.user,
              label: l10n.lastName,
              controller: _last,
              error: lastProblem == null
                  ? null
                  : nameProblemMessage(l10n, lastProblem),
              keyboardType: TextInputType.name,
              autofillHint: AutofillHints.familyName,
              formatters: [LengthLimitingTextInputFormatter(nameMaxLength)],
              onChanged: () => setState(() => _lastProblem = null),
            ),
            const SizedBox(height: 18),
            _Label(l10n.governorate),
            _ChoiceBox(
              icon: AppIcon.map,
              text: governorateName(l10n, _governorate),
              hint: l10n.chooseGovernorate,
              wrong: _governorateMissing,
              onTap: _chooseGovernorate,
            ),
            if (_governorateMissing) _ErrorText(l10n.nameRequired),
            const SizedBox(height: 18),
            // 3. Optional: an expert's organisation, or a farmer's orchard.
            if (!farmer)
              _InfoField(
                icon: AppIcon.people,
                label: l10n.organisationOptional,
                controller: _organisation,
                keyboardType: TextInputType.text,
                formatters: [
                  FilteringTextInputFormatter.deny(RegExp('[<>]')),
                  LengthLimitingTextInputFormatter(100),
                ],
              )
            else ...[
              _InfoField(
                icon: AppIcon.tree,
                label: l10n.almondTreesOptional,
                controller: _trees,
                error: _treesWrong ? l10n.numberInvalid : null,
                keyboardType: TextInputType.number,
                formatters: digits,
                numbers: true,
                onChanged: () => setState(() => _treesWrong = false),
              ),
              const SizedBox(height: 18),
              _InfoField(
                icon: AppIcon.leaf,
                label: l10n.areaOptional,
                controller: _area,
                error: _areaWrong ? l10n.numberInvalid : null,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                formatters: [
                  FilteringTextInputFormatter.allow(RegExp('[0-9٠-٩۰-۹.,]')),
                  LengthLimitingTextInputFormatter(8),
                ],
                numbers: true,
                onChanged: () => setState(() => _areaWrong = false),
              ),
              const SizedBox(height: 18),
              _Label(l10n.irrigationOptional),
              Row(
                children: [
                  for (final (i, value) in Irrigation.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _RoleCard(
                        icon: AppIcon.drop,
                        label: value == Irrigation.irrigated
                            ? l10n.irrigated
                            : l10n.rainfed,
                        selected: _irrigation == value,
                        compact: true,
                        // Tapped again: not given.
                        onTap: () => setState(
                          () =>
                              _irrigation = _irrigation == value ? null : value,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
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
    );
  }
}

/// The 24 governorates in a white sheet at the bottom, in big rows (in the
/// order of their names). Returns the code chosen (null = closed).
Future<String?> chooseGovernorate(BuildContext context, String? current) {
  final l10n = context.l10n;
  final names = {
    for (final code in governorates) code: governorateName(l10n, code)!,
  };
  final codes = [...governorates]
    ..sort((a, b) => names[a]!.compareTo(names[b]!));
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    elevation: 0,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: CssBox(
          height: MediaQuery.sizeOf(context).height * 0.75,
          color: AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          shadows: AppShadows.card,
          clip: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 10),
                child: Row(
                  children: [
                    const IconBlob(icon: AppIcon.map, size: 46, iconSize: 24),
                    const SizedBox(width: 12),
                    Text(
                      l10n.chooseGovernorate,
                      style: AppTextStyles.of(20, FontWeight.w800),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                  children: [
                    for (final code in codes)
                      Semantics(
                        button: true,
                        selected: code == current,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          onTap: () => Navigator.of(context).pop(code),
                          child: Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: code == current
                                  ? AppColors.mintWhite
                                  : null,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    names[code]!,
                                    style: AppTextStyles.of(
                                      20,
                                      FontWeight.w700,
                                    ),
                                  ),
                                ),
                                if (code == current)
                                  const LoozIcon(AppIcon.check, size: 24),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// The name of a question, above its box.
class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 8, bottom: 8),
    child: Text(text, style: AppTextStyles.cardTitle),
  );
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(start: 8, top: 6),
    child: Text(
      text,
      style: AppTextStyles.of(
        15,
        FontWeight.w700,
      ).copyWith(color: AppColors.danger),
    ),
  );
}

/// A white card to choose (the watering): an icon blob and a word; the
/// chosen one pale green with a green border (like the packs).
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final AppIcon icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Smaller, two in a row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          minHeight: compact ? 70 : 80,
          color: selected ? AppColors.mintWhite : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          shadows: AppShadows.card,
          // Always 2 px, so the card does not move when it is chosen.
          border: Border.all(
            color: selected ? AppColors.midGreen : AppColors.white,
            width: 2,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 16,
            vertical: 10,
          ),
          child: Row(
            children: [
              IconBlob(
                icon: icon,
                size: compact ? 44 : 54,
                iconSize: compact ? 22 : 28,
              ),
              SizedBox(width: compact ? 10 : 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.of(compact ? 18 : 20, FontWeight.w700),
                ),
              ),
              if (selected) const LoozIcon(AppIcon.check, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// A white box that opens a list (the governorate): an icon, the choice (or
/// a pale hint), an arrow.
class _ChoiceBox extends StatelessWidget {
  const _ChoiceBox({
    required this.icon,
    required this.text,
    required this.hint,
    required this.wrong,
    required this.onTap,
  });

  final AppIcon icon;
  final String? text;
  final String hint;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = this.text;
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
            border: Border.all(
              color: wrong ? AppColors.danger : AppColors.white,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              LoozIcon(icon, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text ?? hint,
                  style: AppTextStyles.of(22, FontWeight.w700).copyWith(
                    color: text == null ? AppColors.textMuted : AppColors.green,
                  ),
                ),
              ),
              const LoozIcon(AppIcon.arrow, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// The name of the box above it, the white box with its icon (like the
/// phone number's), and what is wrong under it.
class _InfoField extends StatefulWidget {
  const _InfoField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.keyboardType,
    required this.formatters,
    this.error,
    this.autofillHint,
    this.numbers = false,
    this.onChanged,
  });

  final AppIcon icon;
  final String label;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final List<TextInputFormatter> formatters;

  /// What is wrong (null = nothing).
  final String? error;
  final String? autofillHint;

  /// Numbers: written left to right (also in Arabic).
  final bool numbers;

  final VoidCallback? onChanged;

  @override
  State<_InfoField> createState() => _InfoFieldState();
}

class _InfoFieldState extends State<_InfoField> {
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
    final error = widget.error;
    final hint = widget.autofillHint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Label(widget.label),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: AppShadows.card,
            // A green line while typing (and a dark one when it is wrong).
            border: Border.all(
              color: error != null
                  ? AppColors.danger
                  : _focus.hasFocus
                  ? AppColors.leaf
                  : AppColors.white,
              width: 2,
            ),
          ),
          child: Row(
            children: [
              LoozIcon(widget.icon, size: 28),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  style: AppTextStyles.of(22, FontWeight.w700),
                  cursorColor: AppColors.green,
                  textDirection: widget.numbers ? TextDirection.ltr : null,
                  textAlign: TextAlign.start,
                  // The box draws its own line: none of the theme inside it
                  // (not even while typing).
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    contentPadding: EdgeInsets.zero,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  textCapitalization: widget.numbers
                      ? TextCapitalization.none
                      : TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  keyboardType: widget.keyboardType,
                  autofillHints: hint == null ? null : [hint],
                  inputFormatters: widget.formatters,
                  onChanged: (_) {
                    if (widget.error != null) widget.onChanged?.call();
                  },
                ),
              ),
            ],
          ),
        ),
        if (error != null) _ErrorText(error),
      ],
    );
  }
}
