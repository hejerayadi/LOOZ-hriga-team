// First screen: the almond blossom photo, a welcome, and the choice of the
// language (Arabic or French). Then the phone number screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/symbol_text.dart';
import 'phone_screen.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  void _choose(BuildContext context, String languageCode) {
    setLanguage(languageCode);
    openScreen(context, const PhoneScreen());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final system = MediaQuery.paddingOf(context);
    final white = AppTextStyles.headline.copyWith(color: AppColors.white);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light, // white status bar icons on the photo
      child: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/almond_blossoms.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppGradients.photoVeil),
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.page,
                      system.top + 32,
                      AppSpacing.page,
                      system.bottom + 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const LoozHeader(white: true),
                        const Spacer(),
                        const SizedBox(height: 28),
                        SymbolText(
                          '✿',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.of(76).copyWith(
                            height: 1,
                            color: AppColors.lightGreen,
                            shadows: [
                              Shadow(
                                color: const Color(0x330F3D2B),
                                offset: const Offset(0, 8),
                                blurRadius: cssShadow(
                                  0,
                                  0,
                                  10,
                                  const Color(0x00000000),
                                ).blurRadius,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          l10n.welcomeTitle,
                          textAlign: TextAlign.center,
                          style: white,
                        ),
                        const SizedBox(height: 6),
                        Opacity(
                          opacity: 0.7,
                          child: Text(
                            l10n.welcomeSubtitle,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.subtitle.copyWith(
                              color: AppColors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // The language names and arrows are the same in both
                        // languages (like in the design).
                        _LanguageButton(
                          label: l10n.langArabic,
                          arrow: '←',
                          color: AppColors.lightGreen,
                          onTap: () => _choose(context, 'ar'),
                        ),
                        const SizedBox(height: 16),
                        _LanguageButton(
                          label: l10n.langFrench,
                          arrow: '→',
                          color: AppColors.white,
                          onTap: () => _choose(context, 'fr'),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.arrow,
    required this.color,
    required this.onTap,
  });

  final String label;
  final String arrow;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: CssBox(
          height: 68,
          color: color,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          shadows: AppShadows.languageButton,
          highlight: AppHighlights.button,
          highlightColor: AppHighlights.buttonColor,
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: Text(label, style: AppTextStyles.languageButton)),
              SymbolText(arrow, style: AppTextStyles.languageButton),
            ],
          ),
        ),
      ),
    );
  }
}
