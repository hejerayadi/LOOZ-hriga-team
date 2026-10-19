// ALL the interface texts of the app, in one place.
//
// Today: French only. Later, to add Arabic, we can replace this class
// with Flutter's official translation system (flutter_localizations + .arb files)
// and keep the same names (tabHome, camera, ...).
import '../enums.dart';

class AppStrings {
  // General
  static const appName = 'Looz';

  // Bottom navigation tabs
  static const tabHome = 'Mon verger';
  static const tabCommunity = 'Communauté';
  static const tabAlerts = 'Alertes';
  static const tabProfile = 'Profil';

  // Camera
  static const camera = 'Photo';
  static const cameraSoon = 'Caméra — bientôt';

  // AI assistant
  static const assistant = 'Assistant';
  static const assistantHint = 'Votre question…';
  static const send = 'Envoyer';
  static const assistantFakeReply = 'Je regarde… Réponse bientôt !';

  // Home
  static const trees = 'Arbres';
  static const health = 'Santé';
  static const weather = 'Météo';
  static const humidity = 'Humidité';
  static const myTrees = 'Mes arbres';

  // 3D orchard
  static const orchard3d = 'Verger 3D';
  // The texts inside the 3D scene are in assets/orchard_3d/index.html (TXT).

  // Community
  static const farmer = 'Agriculteur';
  static const expert = 'Expert';

  // Profile
  static const free = 'Gratuit';
  static const premium = 'Premium';

  /// Text for a status level (health or urgency).
  static String level(StatusLevel level) {
    switch (level) {
      case StatusLevel.good:
        return 'Bonne';
      case StatusLevel.warning:
        return 'Moyenne';
      case StatusLevel.danger:
        return 'Mauvaise';
    }
  }

  /// Text for a user role.
  static String role(UserRole role) {
    switch (role) {
      case UserRole.farmer:
        return farmer;
      case UserRole.expert:
        return expert;
    }
  }
}
