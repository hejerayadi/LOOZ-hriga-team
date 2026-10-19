// ALL the interface texts of the app, in one place.
//
// Today: French only. Later, to add Arabic, we can replace this class
// with Flutter's official translation system (flutter_localizations + .arb files)
// and keep the same names (tabHome, camera, ...).
import '../enums.dart';
import '../plans.dart';

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
  static const logout = 'Se déconnecter';
  static const seePlans = 'Voir les offres';
  static const devPlan = 'Mode test : changer d\'offre';

  // Subscription plans
  static const plans = 'Les offres';
  static const yourPlan = 'Votre offre';
  static const everythingIn = 'Tout de l\'offre';
  static const contactUs = 'Contactez-nous';
  static const contactUsText =
      'Pour changer d\'offre, contactez-nous. Pas de paiement dans l\'application pour l\'instant.';
  static const ok = 'OK';
  static const lockedIn = 'Offre';
  static const assistantLimitReached = 'Plus de questions aujourd\'hui';
  static String assistantQuestionsLeft(int left) => left == 1
      ? 'Reste 1 question aujourd\'hui'
      : 'Reste $left questions aujourd\'hui';
  static const perDay = 'questions / jour';

  // Login / sign up
  static const login = 'Se connecter';
  static const signup = 'Créer un compte';
  static const noAccount = 'Pas de compte ? Créer un compte';
  static const name = 'Nom';
  static const email = 'E-mail';
  static const password = 'Mot de passe';
  static const iAm = 'Je suis :';
  static const fillAllFields = 'Remplissez tous les champs.';
  static const passwordTooShort = 'Mot de passe : 6 caractères minimum.';
  static const checkEmail =
      'Compte créé ! Ouvrez votre e-mail pour le confirmer, puis connectez-vous.';
  static const somethingWrong = 'Une erreur est survenue. Réessayez.';

  // Missing Supabase keys (developer message)
  static const missingKeys =
      'Clés Supabase manquantes.\n\n'
      'Remplissez mobile_app/.env puis lancez :\n'
      'flutter run --dart-define-from-file=.env';

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

  /// Name of a plan.
  static String plan(Plan plan) {
    switch (plan) {
      case Plan.free:
        return 'Gratuit';
      case Plan.essential:
        return 'Essentiel';
      case Plan.connected:
        return 'Connecté';
    }
  }

  /// Text of the big "upgrade" button.
  static String upgradeTo(Plan target) => 'Passer à ${plan(target)}';

  /// Short name of a feature.
  static String feature(Feature feature) {
    switch (feature) {
      case Feature.community:
        return 'Communauté';
      case Feature.assistant:
        return 'Assistant IA';
      case Feature.regionalAlerts:
        return 'Alertes de la région';
      case Feature.landSetup:
        return 'Mon terrain et mon sol';
      case Feature.orchardDrawing:
        return 'Dessin : parcelle, arbres, zones';
      case Feature.orchard3d:
        return orchard3d;
      case Feature.aiLayout:
        return 'Plantation par l\'IA';
      case Feature.photoDiagnosis:
        return 'Diagnostic photo';
      case Feature.treeAlerts:
        return 'Alertes des arbres';
      case Feature.liveZoneData:
        return 'Capteurs : données en direct';
      case Feature.zoneAlerts:
        return 'Alertes des zones';
      case Feature.aiPredictions:
        return 'Prévisions IA : arrosage, récolte';
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
