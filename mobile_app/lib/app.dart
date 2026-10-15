// The root of the app: theme + bottom navigation with 4 tabs.
import 'package:flutter/material.dart';

import 'core/strings/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/alerts/alerts_page.dart';
import 'features/community/community_page.dart';
import 'features/home/home_page.dart';
import 'features/profile/profile_page.dart';

/// MaterialApp = the app "shell": title, theme and first screen.
class LoozApp extends StatelessWidget {
  const LoozApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const MainShell(),
    );
  }
}

/// The main screen with the bottom navigation bar.
/// It remembers which tab is selected (that's why it is "Stateful").
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Index of the selected tab (0 = Home).
  int _currentIndex = 0;

  // The 4 pages, in the same order as the tabs below.
  static const List<Widget> _pages = [
    HomePage(),
    CommunityPage(),
    AlertsPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps every page alive, so the scroll position
      // is not lost when switching tabs.
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.park_outlined),
            selectedIcon: Icon(Icons.park),
            label: AppStrings.tabHome,
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: AppStrings.tabCommunity,
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_outlined),
            selectedIcon: Icon(Icons.notifications),
            label: AppStrings.tabAlerts,
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: AppStrings.tabProfile,
          ),
        ],
      ),
    );
  }
}
