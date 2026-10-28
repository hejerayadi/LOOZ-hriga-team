// The "عربي | FR" switch at the top of the screens. It changes the language
// of the whole app at once (and is saved in the profile when logged in).
// Like in the design, عربي stays on the left.
import 'package:flutter/material.dart';

import '../../core/locale.dart';
import '../../core/session.dart';
import '../../core/theme/app_theme.dart';

class LangPill extends StatelessWidget {
  const LangPill({super.key});

  @override
  Widget build(BuildContext context) {
    final current = Localizations.localeOf(context).languageCode;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.white82,
          border: Border.all(color: AppColors.white70),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: AppShadows.langPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The names of the languages are the same in both languages.
            _LangButton(
              label: context.l10n.langPillArabic,
              selected: current == 'ar',
              code: 'ar',
            ),
            _LangButton(
              label: context.l10n.langPillFrench,
              selected: current == 'fr',
              code: 'fr',
            ),
          ],
        ),
      ),
    );
  }
}

class _LangButton extends StatelessWidget {
  const _LangButton({
    required this.label,
    required this.selected,
    required this.code,
  });

  final String label;
  final bool selected;
  final String code;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: () => changeLanguage(code),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.green : null,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            label,
            style: AppTextStyles.langPill.copyWith(
              color: selected ? AppColors.white : AppColors.green,
            ),
          ),
        ),
      ),
    );
  }
}
