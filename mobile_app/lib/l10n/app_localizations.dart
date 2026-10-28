import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('fr'),
  ];

  /// No description provided for @tabHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get tabHome;

  /// No description provided for @tabCommunity.
  ///
  /// In ar, this message translates to:
  /// **'المجتمع'**
  String get tabCommunity;

  /// No description provided for @tabOrchard.
  ///
  /// In ar, this message translates to:
  /// **'بستاني ★'**
  String get tabOrchard;

  /// No description provided for @tabAlerts.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get tabAlerts;

  /// No description provided for @tabProfile.
  ///
  /// In ar, this message translates to:
  /// **'حسابي'**
  String get tabProfile;

  /// No description provided for @askAssistant.
  ///
  /// In ar, this message translates to:
  /// **'اسأل المساعد'**
  String get askAssistant;

  /// No description provided for @welcomeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أهلًا بك في لوز'**
  String get welcomeTitle;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'بستانك معك، كل يوم'**
  String get welcomeSubtitle;

  /// No description provided for @phoneTitle.
  ///
  /// In ar, this message translates to:
  /// **'رقم هاتفك'**
  String get phoneTitle;

  /// No description provided for @phoneSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سنرسل رمزًا قصيرًا'**
  String get phoneSubtitle;

  /// No description provided for @sendCode.
  ///
  /// In ar, this message translates to:
  /// **'إرسال الرمز'**
  String get sendCode;

  /// No description provided for @codeTitle.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز'**
  String get codeTitle;

  /// No description provided for @codeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'أرسلناه إلى هاتفك'**
  String get codeSubtitle;

  /// No description provided for @confirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get confirm;

  /// No description provided for @welcomeUser.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا يا {name}'**
  String welcomeUser(String name);

  /// No description provided for @orchardReady.
  ///
  /// In ar, this message translates to:
  /// **'بستانك جاهز'**
  String get orchardReady;

  /// No description provided for @start.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ'**
  String get start;

  /// No description provided for @homeTitle.
  ///
  /// In ar, this message translates to:
  /// **'صباح الخير'**
  String get homeTitle;

  /// No description provided for @homeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'{name}، أشجارك بخير اليوم'**
  String homeSubtitle(String name);

  /// No description provided for @goodDayToWater.
  ///
  /// In ar, this message translates to:
  /// **'يوم مناسب للسقي'**
  String get goodDayToWater;

  /// No description provided for @drySoil.
  ///
  /// In ar, this message translates to:
  /// **'التربة جافة'**
  String get drySoil;

  /// No description provided for @waterToday.
  ///
  /// In ar, this message translates to:
  /// **'اسقِ اليوم'**
  String get waterToday;

  /// No description provided for @quickAsk.
  ///
  /// In ar, this message translates to:
  /// **'اسأل'**
  String get quickAsk;

  /// No description provided for @quickJournal.
  ///
  /// In ar, this message translates to:
  /// **'دفتر'**
  String get quickJournal;

  /// No description provided for @quickMap.
  ///
  /// In ar, this message translates to:
  /// **'خريطة'**
  String get quickMap;

  /// No description provided for @communityTitle.
  ///
  /// In ar, this message translates to:
  /// **'المجتمع'**
  String get communityTitle;

  /// No description provided for @communitySubtitle.
  ///
  /// In ar, this message translates to:
  /// **'من فلاحي تونس'**
  String get communitySubtitle;

  /// No description provided for @almondBlossoms.
  ///
  /// In ar, this message translates to:
  /// **'أزهار اللوز'**
  String get almondBlossoms;

  /// No description provided for @isThisFlowerHealthy.
  ///
  /// In ar, this message translates to:
  /// **'هل هذه الزهرة سليمة؟'**
  String get isThisFlowerHealthy;

  /// No description provided for @answers.
  ///
  /// In ar, this message translates to:
  /// **'{count} إجابة'**
  String answers(String count);

  /// No description provided for @verifiedExpert.
  ///
  /// In ar, this message translates to:
  /// **'خبير موثّق'**
  String get verifiedExpert;

  /// No description provided for @tipOfTheDay.
  ///
  /// In ar, this message translates to:
  /// **'نصيحة اليوم: اسقِ صباحًا'**
  String get tipOfTheDay;

  /// No description provided for @askAQuestion.
  ///
  /// In ar, this message translates to:
  /// **'اسأل سؤالًا'**
  String get askAQuestion;

  /// No description provided for @askTitle.
  ///
  /// In ar, this message translates to:
  /// **'اسأل سؤالًا'**
  String get askTitle;

  /// No description provided for @askSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'اختر الأسهل لك'**
  String get askSubtitle;

  /// No description provided for @speak.
  ///
  /// In ar, this message translates to:
  /// **'تكلّم'**
  String get speak;

  /// No description provided for @speakHint.
  ///
  /// In ar, this message translates to:
  /// **'اضغط وقل سؤالك'**
  String get speakHint;

  /// No description provided for @photo.
  ///
  /// In ar, this message translates to:
  /// **'صورة'**
  String get photo;

  /// No description provided for @text.
  ///
  /// In ar, this message translates to:
  /// **'كتابة'**
  String get text;

  /// No description provided for @send.
  ///
  /// In ar, this message translates to:
  /// **'أرسل'**
  String get send;

  /// No description provided for @tipsTitle.
  ///
  /// In ar, this message translates to:
  /// **'مكتبة النصائح'**
  String get tipsTitle;

  /// No description provided for @tipWaterBeforeSun.
  ///
  /// In ar, this message translates to:
  /// **'اسقِ قبل اشتداد الشمس'**
  String get tipWaterBeforeSun;

  /// No description provided for @tipCheckLeaves.
  ///
  /// In ar, this message translates to:
  /// **'افحص الأوراق كل أسبوع'**
  String get tipCheckLeaves;

  /// No description provided for @tipPhotoInsects.
  ///
  /// In ar, this message translates to:
  /// **'صوّر أي حشرة غريبة'**
  String get tipPhotoInsects;

  /// No description provided for @photographLeaf.
  ///
  /// In ar, this message translates to:
  /// **'صوّر الورقة'**
  String get photographLeaf;

  /// No description provided for @looking.
  ///
  /// In ar, this message translates to:
  /// **'جاري النظر…'**
  String get looking;

  /// No description provided for @resultTitle.
  ///
  /// In ar, this message translates to:
  /// **'وجدت شيئًا'**
  String get resultTitle;

  /// No description provided for @maybeAphids.
  ///
  /// In ar, this message translates to:
  /// **'قد تكون حشرة المنّ'**
  String get maybeAphids;

  /// No description provided for @whatIsIt.
  ///
  /// In ar, this message translates to:
  /// **'ما هي؟'**
  String get whatIsIt;

  /// No description provided for @smallInsect.
  ///
  /// In ar, this message translates to:
  /// **'حشرة صغيرة'**
  String get smallInsect;

  /// No description provided for @why.
  ///
  /// In ar, this message translates to:
  /// **'لماذا؟'**
  String get why;

  /// No description provided for @warmWeather.
  ///
  /// In ar, this message translates to:
  /// **'جو دافئ'**
  String get warmWeather;

  /// No description provided for @whatToDo.
  ///
  /// In ar, this message translates to:
  /// **'ماذا أفعل؟'**
  String get whatToDo;

  /// No description provided for @rinseLeaf.
  ///
  /// In ar, this message translates to:
  /// **'اغسل الورقة'**
  String get rinseLeaf;

  /// No description provided for @askAnExpert.
  ///
  /// In ar, this message translates to:
  /// **'اسأل خبيرًا'**
  String get askAnExpert;

  /// No description provided for @listening.
  ///
  /// In ar, this message translates to:
  /// **'أنا أسمعك'**
  String get listening;

  /// No description provided for @speakFreely.
  ///
  /// In ar, this message translates to:
  /// **'تكلّم براحتك…'**
  String get speakFreely;

  /// No description provided for @alertsTitle.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get alertsTitle;

  /// No description provided for @alertsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'{count} تحتاج انتباهك'**
  String alertsSubtitle(String count);

  /// No description provided for @treeThirsty.
  ///
  /// In ar, this message translates to:
  /// **'الشجرة {tree} عطشى'**
  String treeThirsty(String tree);

  /// No description provided for @actNow.
  ///
  /// In ar, this message translates to:
  /// **'تحرّك الآن'**
  String get actNow;

  /// No description provided for @insectNearby.
  ///
  /// In ar, this message translates to:
  /// **'حشرة قريبة'**
  String get insectNearby;

  /// No description provided for @watchLeaves.
  ///
  /// In ar, this message translates to:
  /// **'راقب الأوراق'**
  String get watchLeaves;

  /// No description provided for @restIsFine.
  ///
  /// In ar, this message translates to:
  /// **'باقي البستان بخير'**
  String get restIsFine;

  /// No description provided for @allGood.
  ///
  /// In ar, this message translates to:
  /// **'كل شيء جيد'**
  String get allGood;

  /// No description provided for @treeName.
  ///
  /// In ar, this message translates to:
  /// **'الشجرة A-18'**
  String get treeName;

  /// No description provided for @needsWater.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج ماء'**
  String get needsWater;

  /// No description provided for @wellDone.
  ///
  /// In ar, this message translates to:
  /// **'أحسنت!'**
  String get wellDone;

  /// No description provided for @treeHappy.
  ///
  /// In ar, this message translates to:
  /// **'الشجرة سعيدة الآن'**
  String get treeHappy;

  /// No description provided for @waterLiters.
  ///
  /// In ar, this message translates to:
  /// **'اسقِ {liters} لترًا'**
  String waterLiters(String liters);

  /// No description provided for @noRainDays.
  ///
  /// In ar, this message translates to:
  /// **'لم تمطر منذ {days} أيام'**
  String noRainDays(String days);

  /// No description provided for @done.
  ///
  /// In ar, this message translates to:
  /// **'تمّ'**
  String get done;

  /// No description provided for @regionalTitle.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه في منطقتك'**
  String get regionalTitle;

  /// No description provided for @aphidsNearby.
  ///
  /// In ar, this message translates to:
  /// **'حشرة المنّ قريبة'**
  String get aphidsNearby;

  /// No description provided for @checkYourLeaves.
  ///
  /// In ar, this message translates to:
  /// **'افحص أوراقك اليوم'**
  String get checkYourLeaves;

  /// No description provided for @farmersReported.
  ///
  /// In ar, this message translates to:
  /// **'فلاحًا أبلغوا عنها'**
  String get farmersReported;

  /// No description provided for @meToo.
  ///
  /// In ar, this message translates to:
  /// **'أنا أراه أيضًا'**
  String get meToo;

  /// No description provided for @myOrchard.
  ///
  /// In ar, this message translates to:
  /// **'بستاني'**
  String get myOrchard;

  /// No description provided for @orchardInPocket.
  ///
  /// In ar, this message translates to:
  /// **'بستانك في جيبك'**
  String get orchardInPocket;

  /// No description provided for @benefitTreeMap.
  ///
  /// In ar, this message translates to:
  /// **'خريطة كل شجرة'**
  String get benefitTreeMap;

  /// No description provided for @benefitSmartWatering.
  ///
  /// In ar, this message translates to:
  /// **'سقي ذكي'**
  String get benefitSmartWatering;

  /// No description provided for @benefitEarlyAlert.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه مبكر'**
  String get benefitEarlyAlert;

  /// No description provided for @startPremium.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بريميوم'**
  String get startPremium;

  /// No description provided for @notNow.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get notNow;

  /// No description provided for @premiumTitle.
  ///
  /// In ar, this message translates to:
  /// **'LOOZ بريميوم'**
  String get premiumTitle;

  /// No description provided for @free.
  ///
  /// In ar, this message translates to:
  /// **'مجاني'**
  String get free;

  /// No description provided for @assistant.
  ///
  /// In ar, this message translates to:
  /// **'المساعد'**
  String get assistant;

  /// No description provided for @orchardMap.
  ///
  /// In ar, this message translates to:
  /// **'خريطة البستان'**
  String get orchardMap;

  /// No description provided for @smartAlerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات ذكية'**
  String get smartAlerts;

  /// No description provided for @currency.
  ///
  /// In ar, this message translates to:
  /// **'د.ت'**
  String get currency;

  /// No description provided for @month.
  ///
  /// In ar, this message translates to:
  /// **'شهر'**
  String get month;

  /// No description provided for @cancelAnytime.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء في أي وقت'**
  String get cancelAnytime;

  /// No description provided for @paymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'الدفع'**
  String get paymentTitle;

  /// No description provided for @paymentSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'خطوة واحدة فقط'**
  String get paymentSubtitle;

  /// No description provided for @pricePerMonth.
  ///
  /// In ar, this message translates to:
  /// **'د.ت / شهر'**
  String get pricePerMonth;

  /// No description provided for @scanTitle.
  ///
  /// In ar, this message translates to:
  /// **'امسح الرمز'**
  String get scanTitle;

  /// No description provided for @scanSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا في بريميوم'**
  String get scanSubtitle;

  /// No description provided for @onOrchardDevice.
  ///
  /// In ar, this message translates to:
  /// **'على جهاز البستان'**
  String get onOrchardDevice;

  /// No description provided for @openMap.
  ///
  /// In ar, this message translates to:
  /// **'فتح الخريطة'**
  String get openMap;

  /// No description provided for @treeCount.
  ///
  /// In ar, this message translates to:
  /// **'{count} شجرة'**
  String treeCount(String count);

  /// No description provided for @look.
  ///
  /// In ar, this message translates to:
  /// **'راقب'**
  String get look;

  /// No description provided for @journalTitle.
  ///
  /// In ar, this message translates to:
  /// **'دفتر البستان'**
  String get journalTitle;

  /// No description provided for @journalSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ماذا فعلت اليوم؟'**
  String get journalSubtitle;

  /// No description provided for @dictateNote.
  ///
  /// In ar, this message translates to:
  /// **'سجّل بصوتك'**
  String get dictateNote;

  /// No description provided for @watering.
  ///
  /// In ar, this message translates to:
  /// **'سقي'**
  String get watering;

  /// No description provided for @treatment.
  ///
  /// In ar, this message translates to:
  /// **'علاج'**
  String get treatment;

  /// No description provided for @pruning.
  ///
  /// In ar, this message translates to:
  /// **'تقليم'**
  String get pruning;

  /// No description provided for @harvest.
  ///
  /// In ar, this message translates to:
  /// **'حصاد'**
  String get harvest;

  /// No description provided for @save.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get save;

  /// No description provided for @myPlan.
  ///
  /// In ar, this message translates to:
  /// **'خطتي'**
  String get myPlan;

  /// No description provided for @becomeExpert.
  ///
  /// In ar, this message translates to:
  /// **'كن خبيرًا'**
  String get becomeExpert;

  /// No description provided for @appStates.
  ///
  /// In ar, this message translates to:
  /// **'حالات التطبيق'**
  String get appStates;

  /// No description provided for @sendLater.
  ///
  /// In ar, this message translates to:
  /// **'سيُرسل لاحقًا'**
  String get sendLater;

  /// No description provided for @noInternet.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد إنترنت'**
  String get noInternet;

  /// No description provided for @tryAgain.
  ///
  /// In ar, this message translates to:
  /// **'حاول مرة أخرى'**
  String get tryAgain;

  /// No description provided for @askFirstQuestion.
  ///
  /// In ar, this message translates to:
  /// **'اسأل سؤالك الأول'**
  String get askFirstQuestion;

  /// Language button (same in both languages).
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get langArabic;

  /// Language button (same in both languages).
  ///
  /// In ar, this message translates to:
  /// **'Français'**
  String get langFrench;

  /// Language switch (same in both languages).
  ///
  /// In ar, this message translates to:
  /// **'عربي'**
  String get langPillArabic;

  /// Language switch (same in both languages).
  ///
  /// In ar, this message translates to:
  /// **'FR'**
  String get langPillFrench;

  /// Plan card title (same in both languages).
  ///
  /// In ar, this message translates to:
  /// **'★ Premium'**
  String get premiumName;

  /// APP-ONLY. Brand name.
  ///
  /// In ar, this message translates to:
  /// **'LOOZ'**
  String get appName;

  /// APP-ONLY. 3D orchard zones.
  ///
  /// In ar, this message translates to:
  /// **'المنطقة {letter}'**
  String zoneName(String letter);

  /// APP-ONLY. Plan name (test switch).
  ///
  /// In ar, this message translates to:
  /// **'أساسي'**
  String get planEssential;

  /// APP-ONLY. Plan name (test switch).
  ///
  /// In ar, this message translates to:
  /// **'متصل'**
  String get planConnected;

  /// APP-ONLY. Debug builds only.
  ///
  /// In ar, this message translates to:
  /// **'وضع التجربة: تغيير الخطة'**
  String get devPlanSwitch;

  /// APP-ONLY. Screen reader label.
  ///
  /// In ar, this message translates to:
  /// **'الكاميرا'**
  String get a11yCamera;

  /// APP-ONLY. Screen reader label.
  ///
  /// In ar, this message translates to:
  /// **'استمع'**
  String get a11yReadAloud;

  /// APP-ONLY. Screen reader label.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get a11yClose;

  /// APP-ONLY. Screen reader label.
  ///
  /// In ar, this message translates to:
  /// **'تشغيل'**
  String get a11yPlay;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'جاري الإرسال…'**
  String get sending;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحقق…'**
  String get checking;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'أعد إرسال الرمز'**
  String get resendCode;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'أرسلنا رمزًا جديدًا'**
  String get codeResent;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'ما اسمك؟'**
  String get nameTitle;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'ليتعرّف عليك المجتمع'**
  String get nameSubtitle;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get firstName;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'اللقب'**
  String get lastName;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'متابعة'**
  String get continueLabel;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'جاري الحفظ…'**
  String get saving;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'هذه الخانة مطلوبة'**
  String get nameRequired;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'{max} حرفًا على الأكثر'**
  String nameTooLong(String max);

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'استعمل الحروف فقط'**
  String get nameBadCharacters;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'اختر باقتك'**
  String get packTitle;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ مجانًا أو اختر المزيد'**
  String get packSubtitle;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'بدون دفع'**
  String get packNoPayment;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'المساعد: {count} أسئلة في اليوم'**
  String packAssistantLimit(String count);

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات منطقتك'**
  String get packRegionalAlerts;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'كل ما في الباقة المجانية'**
  String get packAllOfFree;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'كل ما في الباقة الأساسية'**
  String get packAllOfEssential;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'المساعد بلا حدود'**
  String get packUnlimitedAssistant;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'بستانك ثلاثي الأبعاد'**
  String get pack3dOrchard;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'تشخيص الأوراق بالصورة'**
  String get packPhotoDiagnosis;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'حسّاسات البستان مباشرة'**
  String get packLiveSensors;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'توقّع السقي والحصاد'**
  String get packPredictions;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'متى تدفع؟'**
  String get payChoiceTitle;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'اختر ما يناسبك'**
  String get payChoiceSubtitle;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'ادفع الآن'**
  String get payNow;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'ادفع لاحقًا'**
  String get payLater;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'حتى الدفع، تستعمل الباقة المجانية'**
  String get payPendingNote;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الخروج'**
  String get logOut;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد إنترنت. تحقّق من الاتصال وحاول مرة أخرى.'**
  String get errorNoInternet;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح أو انتهت صلاحيته.'**
  String get errorWrongCode;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. انتظر دقيقة ثم حاول مرة أخرى.'**
  String get errorTooManyTries;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرقم لا يمكنه استقبال الرموز بعد.'**
  String get errorCannotReceiveCode;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف غير صحيح.'**
  String get errorInvalidPhone;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرقم مستعمل في حساب آخر.'**
  String get errorPhoneTaken;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'الاسم غير مقبول. استعمل الحروف فقط.'**
  String get errorInvalidName;

  /// APP-ONLY. Sign up / sign in.
  ///
  /// In ar, this message translates to:
  /// **'انتهت الجلسة. سجّل الدخول من جديد.'**
  String get errorSessionExpired;

  /// APP-ONLY. Error message.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ. حاول مرة أخرى.'**
  String get somethingWrong;

  /// APP-ONLY. Developer message.
  ///
  /// In ar, this message translates to:
  /// **'مفاتيح Supabase غير موجودة.\n\nاملأ ملف mobile_app/.env ثم شغّل:\nflutter run --dart-define-from-file=.env'**
  String get missingKeys;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
