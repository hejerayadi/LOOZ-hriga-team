// The root of the app: theme, languages, and the main screen with 5 tabs.
import 'package:flutter/material.dart';

import 'core/locale.dart';
import 'core/navigation.dart';
import 'core/theme/app_theme.dart';
import 'features/alerts/alerts_page.dart';
import 'features/community/community_page.dart';
import 'features/home/home_page.dart';
import 'features/onboarding/sign_up_flow.dart';
import 'features/orchard_3d/orchard_tab.dart';
import 'features/profile/profile_page.dart';
import 'shared/widgets/looz_background.dart';
import 'shared/widgets/shell.dart';

/// MaterialApp = the app "shell": title, theme, language and first screen.
/// The first screen: Home when the user is logged in (the session is kept),
/// otherwise the choice of the language, then the login.
class LoozApp extends StatelessWidget {
  const LoozApp({super.key, this.home = const StartScreen()});

  /// The first screen (tests can start somewhere else).
  final Widget home;

  @override
  Widget build(BuildContext context) {
    // Rebuilds the app when the language changes. Arabic = right to left:
    // the layout mirrors by itself.
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, _) => MaterialApp(
        onGenerateTitle: (context) => context.l10n.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: home,
      ),
    );
  }
}

/// Shown instead of the app when the Supabase keys are missing
/// (the app was started without the .env file).
class MissingKeysApp extends StatelessWidget {
  const MissingKeysApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: appLocale.value,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.missingKeys,
                textAlign: TextAlign.center,
                style: AppTextStyles.of(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The main screen: the 5 tabs, with the assistant bar and the tab bar
/// floating at the bottom.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // A tab is built the first time it is shown (so the 3D orchard only
  // starts when the user opens it), then kept alive.
  final Set<AppTab> _opened = {};

  Widget _page(AppTab tab) {
    switch (tab) {
      case AppTab.home:
        return const HomePage();
      case AppTab.community:
        return const CommunityPage();
      case AppTab.orchard:
        return const OrchardTab();
      case AppTab.alerts:
        return const AlertsPage();
      case AppTab.profile:
        return const ProfilePage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppTab>(
      valueListenable: currentTab,
      builder: (context, tab, _) {
        _opened.add(tab);
        return Scaffold(
          body: LoozBackground(
            child: Stack(
              children: [
                // IndexedStack keeps every opened page alive, so the scroll
                // position is not lost when switching tabs.
                IndexedStack(
                  index: tab.index,
                  children: [
                    for (final t in AppTab.values)
                      _opened.contains(t) ? _page(t) : const SizedBox.shrink(),
                  ],
                ),
                Positioned.fill(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: orchardPanelOpen,
                    builder: (context, panelOpen, _) => ShellBars(
                      selected: tab,
                      showAssistant: !(tab == AppTab.orchard && panelOpen),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
