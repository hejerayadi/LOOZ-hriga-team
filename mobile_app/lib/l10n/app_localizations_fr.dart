// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get tabHome => 'Accueil';

  @override
  String get tabCommunity => 'Communauté';

  @override
  String get tabOrchard => 'Verger ★';

  @override
  String get tabAlerts => 'Alertes';

  @override
  String get tabProfile => 'Profil';

  @override
  String get askAssistant => 'Demander';

  @override
  String get welcomeTitle => 'Bienvenue sur LOOZ';

  @override
  String get welcomeSubtitle => 'Votre verger, chaque jour';

  @override
  String get phoneTitle => 'Votre téléphone';

  @override
  String get phoneSubtitle => 'Nous envoyons un code';

  @override
  String get sendCode => 'Envoyer le code';

  @override
  String get codeTitle => 'Entrez le code';

  @override
  String get codeSubtitle => 'Envoyé sur votre téléphone';

  @override
  String get confirm => 'Confirmer';

  @override
  String welcomeUser(String name) {
    return 'Bienvenue $name';
  }

  @override
  String get orchardReady => 'Votre verger est prêt';

  @override
  String get start => 'Commencer';

  @override
  String get homeTitle => 'Bonjour';

  @override
  String homeSubtitle(String name) {
    return '$name, vos arbres vont bien';
  }

  @override
  String homeSubtitleAlert(String name) {
    return '$name, attention : une alerte dans votre région';
  }

  @override
  String get goodDayToWater => 'Bon jour pour arroser';

  @override
  String get quickAsk => 'Question';

  @override
  String get quickJournal => 'Journal';

  @override
  String get quickMap => 'Carte';

  @override
  String get communityTitle => 'Communauté';

  @override
  String get communitySubtitle => 'Des agriculteurs tunisiens';

  @override
  String get almondBlossoms => 'Fleurs d\'amandier';

  @override
  String get verifiedExpert => 'Expert vérifié';

  @override
  String get tipOfTheDay => 'Conseil : arrosez le matin';

  @override
  String get askAQuestion => 'Poser une question';

  @override
  String answers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count réponses',
      one: '1 réponse',
      zero: 'Aucune réponse',
    );
    return '$_temp0';
  }

  @override
  String get communityAnswersTitle => 'Réponses';

  @override
  String get writeAnswerHint => 'Écrivez votre réponse ici';

  @override
  String get noAnswersYet =>
      'Pas encore de réponse. Soyez le premier à répondre';

  @override
  String get writePostHint => 'Exemple : les feuilles jaunissent, que faire ?';

  @override
  String get newPostTitle => 'Publier dans la communauté';

  @override
  String get newPostSubtitle =>
      'Une question ou un conseil, avec une photo si vous voulez';

  @override
  String get publish => 'Publier';

  @override
  String get publishing => 'Publication…';

  @override
  String get takePhoto => 'Prendre une photo';

  @override
  String get choosePhoto => 'Choisir une photo';

  @override
  String get changePhoto => 'Changer';

  @override
  String get removePhoto => 'Retirer';

  @override
  String get preparingPhoto => 'Préparation de la photo…';

  @override
  String get uploadingPhoto => 'Envoi de la photo…';

  @override
  String get photoTooBig =>
      'Photo trop lourde (plus de 5 Mo). Choisissez-en une autre.';

  @override
  String get photoWrongType =>
      'Ce fichier n\'est pas une photo (JPG, PNG ou WebP).';

  @override
  String get uploadFailed => 'La photo n\'a pas été envoyée. Réessayez.';

  @override
  String get cameraDenied =>
      'Looz n\'a pas accès à l\'appareil photo. Autorisez-le dans les réglages du téléphone.';

  @override
  String get galleryDenied =>
      'Looz n\'a pas accès à vos photos. Autorisez-le dans les réglages du téléphone.';

  @override
  String get noCamera => 'Pas d\'appareil photo sur cet appareil.';

  @override
  String get photoUnavailable => 'Photo indisponible';

  @override
  String get a11yPostPhoto => 'Photo de la publication';

  @override
  String get deleteAnswerQuestion => 'Supprimer votre réponse ?';

  @override
  String get deletePostQuestion =>
      'Supprimer votre question ? Ses réponses seront aussi supprimées.';

  @override
  String get deleteAction => 'Supprimer';

  @override
  String get cancelAction => 'Annuler';

  @override
  String get textEmpty => 'Écrivez d\'abord quelque chose';

  @override
  String textTooLong(String max) {
    return 'Texte trop long : $max caractères au maximum';
  }

  @override
  String get textBadCharacters => 'N\'utilisez pas les signes < et >';

  @override
  String get tooFast => 'Doucement, réessayez dans une minute';

  @override
  String get postGone => 'Cette question n\'existe plus';

  @override
  String get cantDelete => 'Vous ne pouvez pas supprimer ceci';

  @override
  String get farmerFallbackName => 'Agriculteur';

  @override
  String get loading => 'Chargement…';

  @override
  String get soon => 'Bientôt';

  @override
  String charCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String get timeJustNow => 'À l\'instant';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count h',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'il y a 1 jour',
    );
    return '$_temp0';
  }

  @override
  String get regionSfax => 'Sfax';

  @override
  String get regionKairouan => 'Kairouan';

  @override
  String get regionSidiBouzid => 'Sidi Bouzid';

  @override
  String get regionGafsa => 'Gafsa';

  @override
  String get regionKasserine => 'Kasserine';

  @override
  String get regionMahdia => 'Mahdia';

  @override
  String get regionZaghouan => 'Zaghouan';

  @override
  String get createAccount => 'Créer un compte';

  @override
  String get signIn => 'Se connecter';

  @override
  String get errorNoAccount => 'Aucun compte avec ce numéro.';

  @override
  String get accountExists => 'Ce numéro a déjà un compte.';

  @override
  String get welcomeBack => 'Content de vous revoir';

  @override
  String get infoTitle => 'Vos informations';

  @override
  String get infoSubtitle => 'Juste quelques questions';

  @override
  String get roleFarmer => 'Agriculteur';

  @override
  String get roleExpert => 'Agronome ou conseiller';

  @override
  String get roleTitle => 'Qui êtes-vous ?';

  @override
  String get roleSubtitle => 'Choisissez ce qui vous correspond';

  @override
  String get roleFarmerHint => 'J\'ai un verger d\'amandiers';

  @override
  String get roleExpertHint => 'Je conseille les agriculteurs';

  @override
  String get governorate => 'Gouvernorat';

  @override
  String get chooseGovernorate => 'Choisissez votre gouvernorat';

  @override
  String get almondTreesOptional => 'Nombre d\'amandiers (facultatif)';

  @override
  String get areaOptional => 'Surface en hectares (facultatif)';

  @override
  String get irrigationOptional => 'Arrosage (facultatif)';

  @override
  String get irrigated => 'Irrigué';

  @override
  String get rainfed => 'Pluvial';

  @override
  String get organisationOptional => 'Organisme (facultatif)';

  @override
  String get numberInvalid => 'Écrivez un nombre valide';

  @override
  String get expertPendingNote =>
      'Le badge « ◆ Expert vérifié » apparaîtra après la vérification de votre compte.';

  @override
  String priceForDays(String price, String period) {
    return '$price DT / $period';
  }

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count jours',
      one: '1 jour',
    );
    return '$_temp0';
  }

  @override
  String get demoMode => 'Mode démo';

  @override
  String get cardNumber => 'Numéro de carte';

  @override
  String get cardExpiry => 'Expiration';

  @override
  String get cardCode => 'Code CVV';

  @override
  String get cardName => 'Nom sur la carte';

  @override
  String get cardNumberInvalid => '16 chiffres';

  @override
  String get cardExpiryInvalid => 'Date invalide (MM/AA)';

  @override
  String get cardCodeInvalid => '3 chiffres';

  @override
  String get checkingPayment => 'Vérification du paiement…';

  @override
  String get paidTitle => 'Paiement reçu !';

  @override
  String paidUntil(String date) {
    return 'Votre pack est actif jusqu\'au $date';
  }

  @override
  String get notPaidTitle => 'Le paiement n\'a pas abouti';

  @override
  String get notPaidText =>
      'Vous restez sur le plan gratuit ; vous pourrez payer plus tard depuis « Profil ».';

  @override
  String get continueFree => 'Continuer gratuitement';

  @override
  String get paymentNotAvailable =>
      'Le paiement n\'est pas disponible pour le moment.';

  @override
  String get tooManyPayments =>
      'Trop d\'essais de paiement. Réessayez dans une heure.';

  @override
  String planUntil(String date) {
    return 'jusqu\'au $date';
  }

  @override
  String get regionTunis => 'Tunis';

  @override
  String get regionAriana => 'Ariana';

  @override
  String get regionBenArous => 'Ben Arous';

  @override
  String get regionManouba => 'Manouba';

  @override
  String get regionNabeul => 'Nabeul';

  @override
  String get regionBizerte => 'Bizerte';

  @override
  String get regionBeja => 'Béja';

  @override
  String get regionJendouba => 'Jendouba';

  @override
  String get regionKef => 'Le Kef';

  @override
  String get regionSiliana => 'Siliana';

  @override
  String get regionSousse => 'Sousse';

  @override
  String get regionMonastir => 'Monastir';

  @override
  String get regionGabes => 'Gabès';

  @override
  String get regionMedenine => 'Médenine';

  @override
  String get regionTataouine => 'Tataouine';

  @override
  String get regionTozeur => 'Tozeur';

  @override
  String get regionKebili => 'Kébili';

  @override
  String get askTitle => 'Votre question';

  @override
  String get askSubtitle => 'Choisissez le plus simple';

  @override
  String get speak => 'Parler';

  @override
  String get speakHint => 'Appuyez et parlez';

  @override
  String get voiceName => 'Looz';

  @override
  String get voiceConnecting => 'Un instant…';

  @override
  String get voiceListening => 'Il écoute…';

  @override
  String get voiceThinking => 'Il réfléchit…';

  @override
  String get voiceSpeaking => 'Il parle…';

  @override
  String get voiceTapToInterrupt => 'Touchez Looz pour l\'interrompre';

  @override
  String get voiceLookingOrchard => 'Il regarde votre verger…';

  @override
  String get voiceYou => 'Vous';

  @override
  String get voiceStop => 'Arrêter';

  @override
  String get voiceEnded => 'Conversation terminée';

  @override
  String get voiceTalkAgain => 'Parler encore';

  @override
  String voiceMinutesLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count minutes aujourd\'hui',
      one: 'Encore 1 minute aujourd\'hui',
      zero: 'Plus de temps aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get voiceLimitReached =>
      'Votre temps avec Looz est fini pour aujourd\'hui. Revenez demain.';

  @override
  String get voiceBusy =>
      'Looz est très occupé aujourd\'hui. Réessayez plus tard.';

  @override
  String get voiceOff => 'L\'assistant est arrêté pour le moment.';

  @override
  String get voiceUnavailable => 'Looz ne répond pas pour le moment.';

  @override
  String get voiceMicNeeded => 'Autorisez le micro pour parler à Looz.';

  @override
  String get voiceConsentTitle => 'Avant de parler';

  @override
  String get voiceConsentBody =>
      'Votre voix est envoyée à Google pour que Looz comprenne et réponde. Looz n\'enregistre pas votre voix et ne garde pas vos paroles. Nous gardons seulement la durée de la conversation.';

  @override
  String get voiceConsentFreeTier =>
      'Google peut aussi l\'utiliser pour améliorer ses services.';

  @override
  String get voiceConsentAccept => 'J\'accepte';

  @override
  String get voiceConsentRefuse => 'Non merci';

  @override
  String get voiceAdvice =>
      'Looz peut se tromper. Pour les traitements, demandez à un expert.';

  @override
  String get photo => 'Photo';

  @override
  String get text => 'Texte';

  @override
  String get send => 'Envoyer';

  @override
  String get tipsTitle => 'Bibliothèque';

  @override
  String get tipWaterBeforeSun => 'Arrosez avant le soleil';

  @override
  String get tipCheckLeaves => 'Vérifiez les feuilles';

  @override
  String get tipPhotoInsects => 'Photographiez les insectes';

  @override
  String get photographLeaf => 'Photographiez la feuille';

  @override
  String get looking => 'Je regarde…';

  @override
  String get betaTag => 'Bêta';

  @override
  String get photoTipOneLeaf => 'Une seule feuille d\'amandier';

  @override
  String get photoTipClose => 'De près';

  @override
  String get photoTipLight => 'À la lumière';

  @override
  String photosLeftToday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Encore $count photos aujourd\'hui',
      one: 'Encore 1 photo aujourd\'hui',
      zero: 'Plus de photo aujourd\'hui',
    );
    return '$_temp0';
  }

  @override
  String get photoPrivacyNote =>
      'La photo est envoyée pour l\'examen et gardée dans votre compte seulement.';

  @override
  String get photoPrivacyNoteAi =>
      'La photo est envoyée à un service d\'IA (Google ou un autre fournisseur) pour l\'examen, et gardée dans votre compte.';

  @override
  String get photoGoogleFreeTier =>
      'Google peut aussi l\'utiliser pour améliorer ses services.';

  @override
  String get verdictLikely => 'Probablement';

  @override
  String get verdictUnsure => 'Pas sûr';

  @override
  String get diseaseShotHole => 'Criblure (trous dans les feuilles)';

  @override
  String get diseaseLeafCurl => 'Cloque (feuilles frisées)';

  @override
  String get diseaseLeafSpot => 'Taches sur les feuilles';

  @override
  String get spotsMarked => 'Les zones malades sont marquées sur la photo';

  @override
  String get notFinalDiagnosis =>
      'Ce n\'est pas un diagnostic final. Demandez l\'avis d\'un expert.';

  @override
  String get notFoundTitle => 'Nous n\'avons pas trouvé ces 3 maladies.';

  @override
  String get notFoundTip => 'Photographiez la feuille de près, à la lumière.';

  @override
  String get notFoundNotHealthy =>
      'Cela ne veut pas dire que l\'arbre est sain.';

  @override
  String get weLookFor =>
      'Nous cherchons seulement : trous, feuilles frisées, taches.';

  @override
  String get takeAnotherPhoto => 'Photographier une autre feuille';

  @override
  String expertQuestionFound(String disease, String certainty) {
    return 'J\'ai photographié une feuille d\'amandier. L\'application dit : $disease ($certainty). Est-ce juste ?';
  }

  @override
  String get expertQuestionNothing =>
      'J\'ai photographié une feuille d\'amandier et l\'application n\'a rien trouvé. Qu\'en pensez-vous ?';

  @override
  String get adviceShotHole1 =>
      'Ramassez les feuilles malades et tombées, loin du verger.';

  @override
  String get adviceShotHole2 => 'Arrosez au pied, pas sur les feuilles.';

  @override
  String get adviceShotHole3 =>
      'Demandez à un expert le traitement avant la prochaine pluie.';

  @override
  String get adviceLeafCurl1 => 'Enlevez les feuilles frisées, loin du verger.';

  @override
  String get adviceLeafCurl2 =>
      'Surveillez les nouvelles feuilles : la chaleur arrête souvent la maladie.';

  @override
  String get adviceLeafCurl3 =>
      'Demandez à un expert : la prévention se fait en hiver, avant le débourrement.';

  @override
  String get adviceLeafSpot1 =>
      'Ramassez les feuilles touchées et tombées sous l\'arbre.';

  @override
  String get adviceLeafSpot2 =>
      'En hiver, taillez pour faire entrer l\'air et le soleil.';

  @override
  String get adviceLeafSpot3 =>
      'Demandez à un expert quel type de taches c\'est.';

  @override
  String get needInternet => 'Connexion Internet nécessaire';

  @override
  String limitReached(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Vous avez envoyé $count photos aujourd\'hui : c\'est la limite. Revenez demain.',
      one: 'Vous avez envoyé 1 photo aujourd\'hui : c\'est la limite. Revenez demain.',
    );
    return '$_temp0';
  }

  @override
  String get diagnosisBusy =>
      'L\'examen est saturé aujourd\'hui. Réessayez demain ou demandez à un expert.';

  @override
  String get diagnosisUnavailable =>
      'L\'examen n\'est pas disponible. Demandez à un expert.';

  @override
  String get photoUnreadable => 'Photo illisible. Reprenez la photo.';

  @override
  String get questionPublished => 'Votre question est dans la communauté';

  @override
  String get whatToDo => 'Que faire ?';

  @override
  String get askAnExpert => 'Demander à un expert';

  @override
  String get alertsTitle => 'Alertes';

  @override
  String alertsSubtitle(String count) {
    return '$count demandent votre attention';
  }

  @override
  String get treeName => 'Arbre A-18';

  @override
  String get wellDone => 'Bravo !';

  @override
  String get done => 'Fait';

  @override
  String get regionalTitle => 'Alerte régionale';

  @override
  String get meToo => 'Moi aussi';

  @override
  String get alertsNoneSubtitle => 'Aucune alerte aujourd\'hui';

  @override
  String alertsInRegion(String region) {
    return 'Dans votre région · $region';
  }

  @override
  String get alertsInRegionPlain => 'Dans votre région';

  @override
  String get noAlertsInRegion =>
      'Aucune alerte dans votre région. Tout est calme.';

  @override
  String get alertNew => 'Nouveau';

  @override
  String get sensorAlertsSoon => 'Les alertes des capteurs de votre verger';

  @override
  String get phoneNotificationsSoon => 'Les notifications sur le téléphone';

  @override
  String a11yNewAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles alertes',
      one: '1 nouvelle alerte',
    );
    return '$_temp0';
  }

  @override
  String get severityDanger => 'Danger';

  @override
  String get severityWarning => 'Vigilance';

  @override
  String get severityInfo => 'Information';

  @override
  String get kindFrost => 'Gel';

  @override
  String get kindHeat => 'Vague de chaleur';

  @override
  String get kindDrought => 'Sécheresse';

  @override
  String get kindDisease => 'Maladie';

  @override
  String get kindPest => 'Ravageurs';

  @override
  String get kindWind => 'Vent fort';

  @override
  String get kindRain => 'Fortes pluies';

  @override
  String alertValidUntil(String date, String time) {
    return 'Valable jusqu\'au $date à $time';
  }

  @override
  String get alertNoEnd => 'Valable jusqu\'à nouvel ordre';

  @override
  String get meTooFirst => 'Soyez le premier à dire « Moi aussi »';

  @override
  String meTooSaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count agriculteurs ont dit « Moi aussi »',
      one: '1 agriculteur a dit « Moi aussi »',
    );
    return '$_temp0';
  }

  @override
  String get takeBack => 'Annuler';

  @override
  String get alertDoneText => 'Vous avez fait le nécessaire.';

  @override
  String get alertGone => 'Cette alerte est terminée.';

  @override
  String get backToAlerts => 'Retour aux alertes';

  @override
  String get homeAllGood => 'Tout va bien';

  @override
  String get homeNoAlert => 'Aucune alerte dans votre région';

  @override
  String get report => 'Signaler';

  @override
  String get reportedTag => 'Signalé';

  @override
  String get reportWhy => 'Pourquoi signaler ?';

  @override
  String get reportSpam => 'Publicité ou spam';

  @override
  String get reportInsult => 'Propos insultants';

  @override
  String get reportWrongAdvice => 'Conseil faux ou dangereux';

  @override
  String get reportOther => 'Autre raison';

  @override
  String get reportThanks => 'Merci. L\'équipe LOOZ va vérifier.';

  @override
  String get reportLimit =>
      'Limite atteinte pour aujourd\'hui. Réessayez demain.';

  @override
  String get myOrchard => 'Mon verger';

  @override
  String get orchardInPocket => 'Votre verger en poche';

  @override
  String get benefitTreeMap => 'Carte des arbres';

  @override
  String get benefitSmartWatering => 'Arrosage intelligent';

  @override
  String get benefitEarlyAlert => 'Alerte précoce';

  @override
  String get startPremium => 'Démarrer Premium';

  @override
  String get notNow => 'Pas maintenant';

  @override
  String get premiumTitle => 'LOOZ Premium';

  @override
  String get free => 'Gratuit';

  @override
  String get assistant => 'Assistant';

  @override
  String get orchardMap => 'Carte du verger';

  @override
  String get smartAlerts => 'Alertes intelligentes';

  @override
  String get currency => 'DT';

  @override
  String get month => 'mois';

  @override
  String get cancelAnytime => 'Annulation à tout moment';

  @override
  String get paymentTitle => 'Paiement';

  @override
  String get paymentSubtitle => 'Une seule étape';

  @override
  String get pricePerMonth => 'DT / mois';

  @override
  String get scanTitle => 'Scanner le code';

  @override
  String get scanSubtitle => 'Bienvenue dans Premium';

  @override
  String get onOrchardDevice => 'Sur l\'appareil du verger';

  @override
  String get openMap => 'Ouvrir la carte';

  @override
  String treeCount(String count) {
    return '$count arbres';
  }

  @override
  String get look => 'Voir';

  @override
  String get journalTitle => 'Journal du verger';

  @override
  String get journalSubtitle => 'Qu\'avez-vous fait ?';

  @override
  String get dictateNote => 'Dictez votre note';

  @override
  String get watering => 'Arrosage';

  @override
  String get treatment => 'Traitement';

  @override
  String get pruning => 'Taille';

  @override
  String get harvest => 'Récolte';

  @override
  String get save => 'Enregistrer';

  @override
  String get myPlan => 'Mon plan';

  @override
  String get becomeExpert => 'Devenir expert';

  @override
  String get appStates => 'États de l\'app';

  @override
  String get sendLater => 'Envoi plus tard';

  @override
  String get noInternet => 'Pas d\'internet';

  @override
  String get tryAgain => 'Réessayer';

  @override
  String get askFirstQuestion => 'Posez votre question';

  @override
  String get langPillArabic => 'عربي';

  @override
  String get langPillFrench => 'FR';

  @override
  String get premiumName => '★ Premium';

  @override
  String get appName => 'LOOZ';

  @override
  String zoneName(String letter) {
    return 'Zone $letter';
  }

  @override
  String get zoneLetters => 'A B C D E F G H I J K L M N O P Q R S T';

  @override
  String get devPlanSwitch => 'Mode test : changer d\'offre';

  @override
  String get a11yCamera => 'Caméra';

  @override
  String get a11yReadAloud => 'Écouter';

  @override
  String get a11yClose => 'Fermer';

  @override
  String get a11yPlay => 'Lire';

  @override
  String get sending => 'Envoi…';

  @override
  String get checking => 'Vérification…';

  @override
  String get resendCode => 'Renvoyer le code';

  @override
  String get codeResent => 'Nouveau code envoyé';

  @override
  String get firstName => 'Prénom';

  @override
  String get lastName => 'Nom';

  @override
  String get continueLabel => 'Continuer';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get nameRequired => 'Ce champ est obligatoire';

  @override
  String nameTooLong(String max) {
    return '$max lettres maximum';
  }

  @override
  String get nameBadCharacters => 'Utilisez seulement des lettres';

  @override
  String get packTitle => 'Choisissez votre offre';

  @override
  String get packSubtitle => 'Gratuite ou plus complète';

  @override
  String get packNoPayment => 'Sans paiement';

  @override
  String get packRegionalAlerts => 'Alertes de votre région';

  @override
  String get packAllOfFree => 'Toute l\'offre gratuite';

  @override
  String get pack3dOrchard => 'Votre verger en 3D';

  @override
  String get packPhotoDiagnosis => 'Diagnostic des feuilles par photo';

  @override
  String get packPredictions => 'Prévisions d\'arrosage et de récolte';

  @override
  String get planPaid => 'Premium';

  @override
  String pricePerZoneForDays(String price, String period) {
    return '$price DT par zone / $period';
  }

  @override
  String dinarsAmount(String price) {
    return '$price DT';
  }

  @override
  String zonesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zones',
      one: '1 zone',
    );
    return '$_temp0';
  }

  @override
  String get packZoneNote =>
      'Chaque zone de votre verger a un capteur LOOZ, installé par nos soins.';

  @override
  String get packVoiceAssistant => 'L\'assistant et la discussion vocale';

  @override
  String get noDrawingYet => 'Dessinez d\'abord votre verger.';

  @override
  String get designerTitle => 'Dessinez votre verger';

  @override
  String get designerSubtitle => 'Trois étapes simples';

  @override
  String get designerStepOutline => 'Dessinez le contour de votre verger';

  @override
  String get designerStepZones => 'Divisez-le en zones';

  @override
  String get designerStepPay => 'Voyez le prix et payez';

  @override
  String get startDrawing => 'Commencer le dessin';

  @override
  String get renewPack => 'Renouveler mon pack';

  @override
  String get zoneTypeYoungTrees => 'Jeunes arbres';

  @override
  String get zoneTypeOldTrees => 'Vieux arbres';

  @override
  String get zoneTypeSandySoil => 'Sol sableux';

  @override
  String get zoneTypeIrrigated => 'Irriguée';

  @override
  String get zoneTypeRainfed => 'Pluviale';

  @override
  String get zoneTypeOther => 'Autre';

  @override
  String get nodeWaiting => 'En attente d\'installation';

  @override
  String designerStepOf(int step, int total) {
    return 'Étape $step sur $total';
  }

  @override
  String get next => 'Suivant';

  @override
  String get back => 'Retour';

  @override
  String get continueDrawing => 'Continuer le dessin';

  @override
  String get drawAgain => 'Recommencer';

  @override
  String get drawAgainQuestion => 'Effacer votre dessin et recommencer ?';

  @override
  String get eraseAction => 'Effacer';

  @override
  String get draftSaved =>
      'Votre dessin est enregistré. Reprenez où vous étiez.';

  @override
  String get drawWithFinger => 'Au doigt, sur une grille';

  @override
  String get satelliteMode => 'Sur l\'image satellite';

  @override
  String get a11yOrchardDrawing => 'Dessin du verger';

  @override
  String get toolPen => 'Crayon';

  @override
  String get toolCorners => 'Points';

  @override
  String get toolUndo => 'Annuler';

  @override
  String get toolRedo => 'Rétablir';

  @override
  String get toolErase => 'Effacer';

  @override
  String get hintPen => 'Tracez le contour avec le doigt';

  @override
  String get hintCorners => 'Touchez les coins du verger, un par un';

  @override
  String get hintClose => 'Touchez le premier point pour fermer';

  @override
  String get hintMove => 'Glissez un point pour le déplacer';

  @override
  String get problemCrossing => 'Deux côtés se croisent. Déplacez un point.';

  @override
  String get problemTooSmall => 'Forme trop petite. Dessinez plus grand.';

  @override
  String get sizeTitle => 'Taille approximative du verger';

  @override
  String get widthLabel => 'Largeur : d\'ouest en est';

  @override
  String get lengthLabel => 'Longueur : du nord au sud';

  @override
  String metres(String value) {
    return '$value m';
  }

  @override
  String hectaresValue(String value) {
    return '$value ha';
  }

  @override
  String sizeInvalid(int min, int max) {
    return 'Écrivez un nombre de $min à $max';
  }

  @override
  String gridSquare(String value) {
    return 'Carré = $value m';
  }

  @override
  String get north => 'Nord';

  @override
  String get areaLabel => 'Surface';

  @override
  String get widthShort => 'Largeur';

  @override
  String get lengthShort => 'Longueur';

  @override
  String get zonesTitle => 'Divisez votre verger en zones';

  @override
  String get zonesSubtitle => 'Un capteur dans chaque zone';

  @override
  String get methodAuto => 'Je donne les zones et les arbres';

  @override
  String get methodAutoHint => 'Nous divisons selon les arbres';

  @override
  String get methodDraw => 'Je trace les limites moi-même';

  @override
  String get methodDrawHint => 'Vous tracez une ligne sur le verger';

  @override
  String get changeMethod => 'Changer de méthode';

  @override
  String get zonesHowMany => 'Nombre de zones';

  @override
  String get fewer => 'Moins';

  @override
  String get more => 'Plus';

  @override
  String get treesLabel => 'Arbres';

  @override
  String get hintCut => 'Tracez une ligne d\'un bord à l\'autre';

  @override
  String get cutMissed => 'La ligne ne coupe aucune zone.';

  @override
  String tooManyZones(int max) {
    return '$max zones au maximum';
  }

  @override
  String get zoneTooSmall => 'Une zone est trop petite. Changez les arbres.';

  @override
  String get zoneDetailsTitle => 'Vos zones';

  @override
  String get zoneDetailsSubtitle => 'Touchez une zone pour la modifier';

  @override
  String get zoneNameOptional => 'Nom de la zone (facultatif)';

  @override
  String get zoneTypeLabel => 'Type';

  @override
  String get zoneColorLabel => 'Couleur';

  @override
  String get treesAtLeastOne => 'Au moins 1 arbre';

  @override
  String get reviewTitle => 'Vérifiez votre verger';

  @override
  String get reviewSubtitle => 'Puis payez, nous créons votre verger';

  @override
  String get zonesLabel => 'Zones';

  @override
  String get sensorsLabel => 'Capteurs';

  @override
  String sensorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count capteurs',
      one: '1 capteur',
    );
    return '$_temp0';
  }

  @override
  String get priceLabel => 'Prix';

  @override
  String areaMinimum(String area, String sensors) {
    return 'Votre verger fait $area ha : il faut au moins $sensors.';
  }

  @override
  String areaMinimumTip(String zones) {
    return 'Divisez-le en $zones pour le même prix.';
  }

  @override
  String get payAndBuild => 'Payer et créer mon verger';

  @override
  String get buildMyOrchard => 'Créer mon verger';

  @override
  String get packCovers => 'Votre pack couvre ce verger.';

  @override
  String get editZones => 'Modifier les zones';

  @override
  String get orchardTooBig => 'Verger très grand. Contactez-nous.';

  @override
  String thenPrice(String price) {
    return 'Puis $price';
  }

  @override
  String get buildingOrchard => 'Création de votre verger…';

  @override
  String get logOut => 'Se déconnecter';

  @override
  String get errorNoInternet =>
      'Pas d\'internet. Vérifiez la connexion et réessayez.';

  @override
  String get errorWrongCode => 'Code incorrect ou expiré.';

  @override
  String get errorTooManyTries =>
      'Trop d\'essais. Attendez une minute et réessayez.';

  @override
  String get errorCannotReceiveCode =>
      'Ce numéro ne peut pas encore recevoir de code.';

  @override
  String get errorInvalidPhone => 'Numéro de téléphone invalide.';

  @override
  String get errorPhoneTaken =>
      'Ce numéro est déjà utilisé par un autre compte.';

  @override
  String get errorInvalidName => 'Nom refusé. Utilisez seulement des lettres.';

  @override
  String get errorSessionExpired => 'Session expirée. Reconnectez-vous.';

  @override
  String get somethingWrong => 'Une erreur est survenue. Réessayez.';

  @override
  String get missingKeys =>
      'Clés Supabase manquantes.\n\nRemplissez mobile_app/.env puis lancez :\nflutter run --dart-define-from-file=.env';

  @override
  String get mlStateOk => 'Tout va bien';

  @override
  String get mlStateWaterDeficit => 'Manque d\'eau';

  @override
  String get mlStateWaterlogging => 'Trop d\'eau';

  @override
  String get mlStateHeat => 'Forte chaleur';

  @override
  String get mlStateFrostDamage => 'Dégâts du froid';

  @override
  String get mlStateRootzone => 'Problème de racines';

  @override
  String get mlStateFrostRisk => 'Risque de gel cette nuit';

  @override
  String get mlStateNoFrost => 'Pas de gel cette nuit';

  @override
  String get mlStateSensorProblem => 'Problème de capteur';

  @override
  String get mlStateNotEnoughData => 'Pas assez de données';

  @override
  String get mlStateOffline => 'Capteur hors ligne';

  @override
  String get mlTonight => 'Cette nuit';

  @override
  String get mlTrees => 'Les arbres';

  @override
  String get mlWhy => 'Pourquoi ?';

  @override
  String mlUpdated(String time) {
    return 'Mise à jour : $time';
  }

  @override
  String get mlReadings => 'Dernières mesures';

  @override
  String get mlSoilWater => 'Eau du sol';

  @override
  String get mlSoilTemp => 'Sol';

  @override
  String get mlAirTemp => 'Air';

  @override
  String get mlHumidity => 'Humidité de l\'air';

  @override
  String get mlNotEnoughDataText =>
      'Il faut un jour de mesures avant une prévision. Revenez un peu plus tard.';

  @override
  String get mlSensorProblemText =>
      'Le capteur de cette zone donne de mauvaises mesures. Pas de prévision tant qu\'il ne remarche pas.';

  @override
  String get mlOfflineText =>
      'Rien n\'est arrivé du capteur de cette zone depuis un moment.';

  @override
  String get mlWaitingText => 'L\'équipe Looz viendra installer le capteur.';

  @override
  String mlTemplateText(String zone, String state, String reasons) {
    return '$zone : $state. Pourquoi : $reasons.';
  }

  @override
  String get mlTemplateUnsure =>
      'Nous ne sommes pas sûrs : regardez les arbres vous-même.';

  @override
  String get mlAllZonesFine => 'Toutes vos zones vont bien.';

  @override
  String get mlNoPredictionYet => 'Nous attendons les mesures de vos capteurs.';

  @override
  String get mlToastOpen => 'Touchez pour voir la zone';

  @override
  String mlZoneOf(String zone, String state) {
    return '$zone : $state';
  }

  @override
  String get mlActionNone =>
      'Continuez comme d\'habitude et regardez les arbres chaque jour.';

  @override
  String get mlActionWaterDeficit =>
      'Vérifiez la ligne d\'irrigation de la zone et arrosez si le sol est sec.';

  @override
  String get mlActionWaterlogging =>
      'Arrêtez d\'arroser cette zone et regardez si l\'eau stagne.';

  @override
  String get mlActionHeat => 'Arrosez tôt le matin ou le soir, pas à midi.';

  @override
  String get mlActionFrostDamage =>
      'Allez voir les fleurs et les petits fruits de cette zone.';

  @override
  String get mlActionRootzone =>
      'Demandez à un expert pour les racines et le sel de l\'eau.';

  @override
  String get mlActionFrostRisk =>
      'Allez voir la zone ce soir et préparez la protection que vous utilisez d\'habitude.';

  @override
  String get mlActionNoFrost =>
      'Rien de spécial, regardez les arbres comme d\'habitude.';

  @override
  String get mlFactorSoilWaterLow => 'Peu d\'eau dans le sol';

  @override
  String get mlFactorSoilWaterHigh => 'Beaucoup d\'eau dans le sol';

  @override
  String get mlFactorSoilDryingLow => 'Le sol sèche lentement';

  @override
  String get mlFactorSoilDryingHigh => 'Le sol sèche vite';

  @override
  String get mlFactorSoilTooWetLow => 'Le sol n\'est pas gorgé d\'eau';

  @override
  String get mlFactorSoilTooWetHigh => 'Le sol est gorgé d\'eau';

  @override
  String get mlFactorWateringLow =>
      'Pas d\'eau arrivée au sol depuis un moment';

  @override
  String get mlFactorWateringHigh =>
      'De l\'eau est arrivée (arrosage ou pluie)';

  @override
  String get mlFactorTreeWaterNeedLow =>
      'Les arbres ont peu besoin d\'eau en ce moment';

  @override
  String get mlFactorTreeWaterNeedHigh =>
      'Les arbres ont besoin de beaucoup d\'eau en ce moment';

  @override
  String get mlFactorAirHeatLow => 'La journée n\'est pas chaude';

  @override
  String get mlFactorAirHeatHigh => 'Forte chaleur la journée';

  @override
  String get mlFactorNightColdLow => 'La nuit dernière était froide';

  @override
  String get mlFactorNightColdHigh => 'La nuit dernière n\'était pas froide';

  @override
  String get mlFactorEveningTempLow => 'Il fait froid maintenant';

  @override
  String get mlFactorEveningTempHigh => 'Il ne fait pas froid maintenant';

  @override
  String get mlFactorCoolingFastLow => 'La température baisse lentement';

  @override
  String get mlFactorCoolingFastHigh => 'La température baisse vite';

  @override
  String get mlFactorNightLowExpectedLow => 'La nuit peut devenir très froide';

  @override
  String get mlFactorNightLowExpectedHigh =>
      'La nuit ne devrait pas être très froide';

  @override
  String get mlFactorDewPointLow => 'L\'air est sec (point de rosée bas)';

  @override
  String get mlFactorDewPointHigh => 'L\'air est humide (point de rosée haut)';

  @override
  String get mlFactorAirHumidityLow => 'L\'air est peu humide';

  @override
  String get mlFactorAirHumidityHigh => 'L\'air est très humide';

  @override
  String get mlFactorAirDrynessLow => 'L\'air n\'est pas sec';

  @override
  String get mlFactorAirDrynessHigh => 'L\'air est sec et chaud';

  @override
  String get mlFactorClearSkyLow => 'Le ciel n\'est pas dégagé';

  @override
  String get mlFactorClearSkyHigh =>
      'Ciel clair : la chaleur s\'échappe la nuit';

  @override
  String get mlFactorSunlightLow => 'Peu de soleil';

  @override
  String get mlFactorSunlightHigh => 'Beaucoup de soleil';

  @override
  String get mlFactorSoilTempLow => 'Le sol est froid';

  @override
  String get mlFactorSoilTempHigh => 'Le sol est chaud';

  @override
  String get mlFactorTreeSoundsLow => 'Le tronc est calme';

  @override
  String get mlFactorTreeSoundsHigh => 'Le tronc donne des signes de soif';

  @override
  String get mlFactorZonePlaceLow =>
      'La zone est dans un creux (le froid s\'y accumule)';

  @override
  String get mlFactorZonePlaceHigh => 'La zone est en hauteur';

  @override
  String get mlFactorGroundCoverLow => 'Petits arbres qui couvrent peu le sol';

  @override
  String get mlFactorGroundCoverHigh => 'Grands arbres qui couvrent le sol';

  @override
  String get mlFactorSeasonStage => 'La saison et le stade des arbres';

  @override
  String get mlFactorSoilType => 'Le type de sol';

  @override
  String get mlFactorIrrigationType =>
      'Le mode d\'arrosage et le sel de l\'eau';

  @override
  String get mlFactorOtherZones => 'Comparé à vos autres zones';

  @override
  String get mlFactorDataQuality => 'Certaines mesures manquent';

  @override
  String get mlListSeparator => ', ';
}
