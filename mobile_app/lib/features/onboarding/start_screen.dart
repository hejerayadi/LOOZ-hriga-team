// The first screen when nobody is logged in (the design's "language"
// screen): the almond blossom photo, the logo and the "عربي | FR" switch
// (the language is remembered on the phone), a welcome, and two big
// buttons: "إنشاء حساب" (sign up) and "تسجيل الدخول" (sign in).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/locale.dart';
import '../../core/navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/app_icon.dart';
import '../../shared/widgets/css_box.dart';
import '../../shared/widgets/looz_header.dart';
import '../../shared/widgets/symbol_text.dart';
import 'phone_screen.dart';

class StartScreen extends StatelessWidget {
  const StartScreen({super.key});

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
                        // The logo and "عربي | FR".
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
                        // The design's two big buttons (green, then white).
                        _StartButton(
                          icon: AppIcon.userPlus,
                          label: l10n.createAccount,
                          color: AppColors.lightGreen,
                          onTap: () => openScreen(
                            context,
                            const PhoneScreen(signUp: true),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _StartButton(
                          icon: AppIcon.logIn,
                          label: l10n.signIn,
                          color: AppColors.white,
                          onTap: () => openScreen(context, const PhoneScreen()),
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

/// A big pill of the start screen: an icon, the word, an arrow.
class _StartButton extends StatelessWidget {
  const _StartButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final AppIcon icon;
  final String label;
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
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              LoozIcon(icon, size: 28),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: AppTextStyles.languageButton)),
              // Towards the next screen: ← in Arabic, → in French.
              SymbolText(
                Directionality.of(context) == TextDirection.rtl ? '←' : '→',
                style: AppTextStyles.languageButton,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
