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

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'{name}، انتبه: تنبيه في منطقتك'**
  String homeSubtitleAlert(String name);

  /// No description provided for @goodDayToWater.
  ///
  /// In ar, this message translates to:
  /// **'يوم مناسب للسقي'**
  String get goodDayToWater;

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

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا إجابة بعد} =1{إجابة واحدة} =2{إجابتان} few{{count} إجابات} other{{count} إجابة}}'**
  String answers(int count);

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'الإجابات'**
  String get communityAnswersTitle;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'اكتب إجابتك هنا'**
  String get writeAnswerHint;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد إجابات بعد. كن أول من يجيب'**
  String get noAnswersYet;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'مثال: أوراق اللوز صفراء، ماذا أفعل؟'**
  String get writePostHint;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'انشر في المجتمع'**
  String get newPostTitle;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'سؤال أو نصيحة، مع صورة إن أردت'**
  String get newPostSubtitle;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'انشر'**
  String get publish;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'جاري النشر…'**
  String get publishing;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'التقط صورة'**
  String get takePhoto;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'اختر من الصور'**
  String get choosePhoto;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'تغيير'**
  String get changePhoto;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'إزالة'**
  String get removePhoto;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'جاري تحضير الصورة…'**
  String get preparingPhoto;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'جاري رفع الصورة…'**
  String get uploadingPhoto;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'الصورة كبيرة جدًا (أكثر من 5 ميغابايت). اختر صورة أخرى.'**
  String get photoTooBig;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'هذا الملف ليس صورة (JPG أو PNG أو WebP).'**
  String get photoWrongType;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'لم تُرفع الصورة. حاول مرة أخرى.'**
  String get uploadFailed;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'لم تسمح للوز باستخدام الكاميرا. اسمح بذلك من إعدادات الهاتف.'**
  String get cameraDenied;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'لم تسمح للوز بالوصول إلى صورك. اسمح بذلك من إعدادات الهاتف.'**
  String get galleryDenied;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد كاميرا على هذا الجهاز.'**
  String get noCamera;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر عرض الصورة'**
  String get photoUnavailable;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'صورة المنشور'**
  String get a11yPostPhoto;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد حذف إجابتك؟'**
  String get deleteAnswerQuestion;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد حذف سؤالك؟ ستُحذف إجاباته أيضًا.'**
  String get deletePostQuestion;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get deleteAction;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get cancelAction;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'اكتب شيئًا أولًا'**
  String get textEmpty;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'النص طويل جدًا: {max} حرف على الأكثر'**
  String textTooLong(String max);

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'لا تستعمل الرمزين < و >'**
  String get textBadCharacters;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'تمهّل قليلًا، حاول بعد دقيقة'**
  String get tooFast;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'هذا السؤال لم يعد موجودًا'**
  String get postGone;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكنك حذف هذا'**
  String get cantDelete;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'فلاح'**
  String get farmerFallbackName;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحميل…'**
  String get loading;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'قريبًا'**
  String get soon;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'{count} / {max}'**
  String charCount(int count, int max);

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'الآن'**
  String get timeJustNow;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منذ دقيقة} =2{منذ دقيقتين} few{منذ {count} دقائق} other{منذ {count} دقيقة}}'**
  String timeMinutesAgo(int count);

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منذ ساعة} =2{منذ ساعتين} few{منذ {count} ساعات} other{منذ {count} ساعة}}'**
  String timeHoursAgo(int count);

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منذ يوم} =2{منذ يومين} few{منذ {count} أيام} many{منذ {count} يومًا} other{منذ {count} يوم}}'**
  String timeDaysAgo(int count);

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'صفاقس'**
  String get regionSfax;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'القيروان'**
  String get regionKairouan;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'سيدي بوزيد'**
  String get regionSidiBouzid;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'قفصة'**
  String get regionGafsa;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'القصرين'**
  String get regionKasserine;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'المهدية'**
  String get regionMahdia;

  /// APP-ONLY. Community.
  ///
  /// In ar, this message translates to:
  /// **'زغوان'**
  String get regionZaghouan;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'إنشاء حساب'**
  String get createAccount;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدخول'**
  String get signIn;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد حساب بهذا الرقم.'**
  String get errorNoAccount;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'هذا الرقم لديه حساب بالفعل.'**
  String get accountExists;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا من جديد'**
  String get welcomeBack;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'معلوماتك'**
  String get infoTitle;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'أسئلة قليلة فقط'**
  String get infoSubtitle;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'فلاح'**
  String get roleFarmer;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'مهندس فلاحي أو مرشد'**
  String get roleExpert;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'من أنت؟'**
  String get roleTitle;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'اختر ما يناسبك'**
  String get roleSubtitle;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'عندي بستان لوز'**
  String get roleFarmerHint;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'أنصح الفلاحين في المجتمع'**
  String get roleExpertHint;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'الولاية'**
  String get governorate;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'اختر ولايتك'**
  String get chooseGovernorate;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'عدد أشجار اللوز (اختياري)'**
  String get almondTreesOptional;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'المساحة بالهكتار (اختياري)'**
  String get areaOptional;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'السقي (اختياري)'**
  String get irrigationOptional;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'مسقي'**
  String get irrigated;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'بعلي'**
  String get rainfed;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'المؤسسة (اختياري)'**
  String get organisationOptional;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقمًا صحيحًا'**
  String get numberInvalid;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'ستظهر شارة «◆ خبير موثّق» بعد أن نتحقق من حسابك.'**
  String get expertPendingNote;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'{price} د.ت / {period}'**
  String priceForDays(String price, String period);

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم} =2{يومان} few{{count} أيام} many{{count} يومًا} other{{count} يوم}}'**
  String daysCount(int count);

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'وضع تجريبي'**
  String get demoMode;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'رقم البطاقة'**
  String get cardNumber;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get cardExpiry;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'رمز الأمان'**
  String get cardCode;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'الاسم على البطاقة'**
  String get cardName;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'16 رقمًا'**
  String get cardNumberInvalid;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ غير صحيح (شهر/سنة)'**
  String get cardExpiryInvalid;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'3 أرقام'**
  String get cardCodeInvalid;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'جاري التحقق من الدفع…'**
  String get checkingPayment;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'تم الدفع!'**
  String get paidTitle;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'باقتك مفعّلة حتى {date}'**
  String paidUntil(String date);

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'لم يكتمل الدفع'**
  String get notPaidTitle;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'ستبقى على الخطة المجانية، ويمكنك الدفع لاحقًا من «حسابي».'**
  String get notPaidText;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'متابعة مجانًا'**
  String get continueFree;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'الدفع غير متاح الآن.'**
  String get paymentNotAvailable;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'محاولات دفع كثيرة. حاول بعد ساعة.'**
  String get tooManyPayments;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'حتى {date}'**
  String planUntil(String date);

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'تونس'**
  String get regionTunis;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'أريانة'**
  String get regionAriana;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'بن عروس'**
  String get regionBenArous;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'منوبة'**
  String get regionManouba;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'نابل'**
  String get regionNabeul;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'بنزرت'**
  String get regionBizerte;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'باجة'**
  String get regionBeja;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'جندوبة'**
  String get regionJendouba;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'الكاف'**
  String get regionKef;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'سليانة'**
  String get regionSiliana;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'سوسة'**
  String get regionSousse;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'المنستير'**
  String get regionMonastir;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'قابس'**
  String get regionGabes;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'مدنين'**
  String get regionMedenine;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'تطاوين'**
  String get regionTataouine;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'توزر'**
  String get regionTozeur;

  /// APP-ONLY. Sign up / payment.
  ///
  /// In ar, this message translates to:
  /// **'قبلي'**
  String get regionKebili;

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

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'لوز'**
  String get voiceName;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'لحظة…'**
  String get voiceConnecting;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'يسمع…'**
  String get voiceListening;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'يفكّر…'**
  String get voiceThinking;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'يحكي…'**
  String get voiceSpeaking;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على لوز لتقاطعه'**
  String get voiceTapToInterrupt;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'ينظر في بستانك…'**
  String get voiceLookingOrchard;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'أنت'**
  String get voiceYou;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'توقّف'**
  String get voiceStop;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'انتهت المحادثة'**
  String get voiceEnded;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'تكلّم من جديد'**
  String get voiceTalkAgain;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم يبق وقت اليوم} =1{بقيت دقيقة واحدة اليوم} =2{بقيت دقيقتان اليوم} few{بقيت {count} دقائق اليوم} many{بقيت {count} دقيقة اليوم} other{بقيت {count} دقيقة اليوم}}'**
  String voiceMinutesLeft(int count);

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'انتهى وقتك مع لوز اليوم. ارجع غدًا.'**
  String get voiceLimitReached;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'لوز مشغول اليوم. حاول لاحقًا.'**
  String get voiceBusy;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'المساعد متوقف الآن.'**
  String get voiceOff;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'لوز لا يجيب الآن.'**
  String get voiceUnavailable;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'اسمح باستعمال الميكروفون لتتكلّم مع لوز.'**
  String get voiceMicNeeded;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'قبل أن تتكلّم'**
  String get voiceConsentTitle;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'صوتك يُرسل إلى غوغل ليفهمه لوز ويجيبك. لوز لا يسجّل صوتك ولا يحفظ كلامك. نحفظ فقط مدّة المحادثة.'**
  String get voiceConsentBody;

  /// APP-ONLY. Voice assistant. Shown only while the Gemini key is on Google's free tier (app_settings.voice_google_free_tier).
  ///
  /// In ar, this message translates to:
  /// **'وقد تستعمله غوغل لتحسين خدماتها.'**
  String get voiceConsentFreeTier;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'موافق'**
  String get voiceConsentAccept;

  /// APP-ONLY. Voice assistant.
  ///
  /// In ar, this message translates to:
  /// **'لا، شكرًا'**
  String get voiceConsentRefuse;

  /// APP-ONLY. Voice assistant. The strict rule: never pesticide names or doses.
  ///
  /// In ar, this message translates to:
  /// **'لوز يمكن أن يخطئ. للأدوية اسأل خبيرًا.'**
  String get voiceAdvice;

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

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'تجريبي'**
  String get betaTag;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'ورقة لوز واحدة'**
  String get photoTipOneLeaf;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'من قريب'**
  String get photoTipClose;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'في الضوء'**
  String get photoTipLight;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا يمكنك إرسال صور أخرى اليوم} =1{يمكنك إرسال صورة واحدة اليوم} =2{يمكنك إرسال صورتين اليوم} few{يمكنك إرسال {count} صور اليوم} many{يمكنك إرسال {count} صورة اليوم} other{يمكنك إرسال {count} صورة اليوم}}'**
  String photosLeftToday(int count);

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'تُرسل الصورة للفحص، وتُحفظ في حسابك فقط.'**
  String get photoPrivacyNote;

  /// APP-ONLY. Photo diagnosis: under the camera button when the model is Gemini (app_settings.diagnosis_model = gemini:...); its backups: another Gemini key, then Groq.
  ///
  /// In ar, this message translates to:
  /// **'تُرسل الصورة إلى خدمة ذكاء اصطناعي (غوغل أو مزوّد آخر) لفحصها، وتُحفظ في حسابك.'**
  String get photoPrivacyNoteAi;

  /// APP-ONLY. Photo diagnosis: added after photoPrivacyNoteGoogle while app_settings.diagnosis_google_free_tier is true (Google free tier).
  ///
  /// In ar, this message translates to:
  /// **'وقد تستعملها غوغل لتحسين خدماتها.'**
  String get photoGoogleFreeTier;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'على الأرجح'**
  String get verdictLikely;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'غير متأكد'**
  String get verdictUnsure;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'ثقوب في الأوراق'**
  String get diseaseShotHole;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'تجعّد الأوراق'**
  String get diseaseLeafCurl;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'بقع على الأوراق'**
  String get diseaseLeafSpot;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'الأماكن المريضة مُعلَّمة على الصورة'**
  String get spotsMarked;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'هذا ليس تشخيصًا نهائيًا. اطلب رأي خبير.'**
  String get notFinalDiagnosis;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد هذه الأمراض الثلاثة.'**
  String get notFoundTitle;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'صوّر الورقة من قريب، في الضوء.'**
  String get notFoundTip;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'هذا لا يعني أن الشجرة سليمة.'**
  String get notFoundNotHealthy;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'نبحث فقط عن: ثقوب، تجعّد، بقع.'**
  String get weLookFor;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'صوّر ورقة أخرى'**
  String get takeAnotherPhoto;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'صوّرت ورقة لوز. التطبيق يقول: {disease} ({certainty}). هل هذا صحيح؟'**
  String expertQuestionFound(String disease, String certainty);

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'صوّرت ورقة لوز ولم يجد التطبيق شيئًا. ما رأيك؟'**
  String get expertQuestionNothing;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'اجمع الأوراق المريضة والساقطة، وأبعدها عن البستان.'**
  String get adviceShotHole1;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'اسقِ عند الجذع، لا فوق الأوراق.'**
  String get adviceShotHole2;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'اسأل خبيرًا عن العلاج قبل المطر القادم.'**
  String get adviceShotHole3;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'انزع الأوراق المجعّدة وأبعدها عن البستان.'**
  String get adviceLeafCurl1;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'راقب الأوراق الجديدة: الحرّ يوقف المرض غالبًا.'**
  String get adviceLeafCurl2;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'اسأل خبيرًا: الوقاية تكون في الشتاء، قبل تفتّح البراعم.'**
  String get adviceLeafCurl3;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'اجمع الأوراق المصابة والساقطة تحت الشجرة.'**
  String get adviceLeafSpot1;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'في الشتاء، قلّم ليدخل الهواء والشمس.'**
  String get adviceLeafSpot2;

  /// APP-ONLY. Photo diagnosis. DRAFT advice: to validate by an agronomist (no pesticide names, no doses).
  ///
  /// In ar, this message translates to:
  /// **'اسأل خبيرًا ليعرف نوع البقع.'**
  String get adviceLeafSpot3;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'تحتاج إلى الإنترنت'**
  String get needInternet;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{أرسلت اليوم صورة واحدة. هذا هو الحد. عُد غدًا.} =2{أرسلت اليوم صورتين. هذا هو الحد. عُد غدًا.} few{أرسلت اليوم {count} صور. هذا هو الحد. عُد غدًا.} many{أرسلت اليوم {count} صورة. هذا هو الحد. عُد غدًا.} other{أرسلت اليوم {count} صورة. هذا هو الحد. عُد غدًا.}}'**
  String limitReached(int count);

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'الفحص مشغول اليوم. حاول غدًا أو اسأل خبيرًا.'**
  String get diagnosisBusy;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'الفحص غير متوفر الآن. اسأل خبيرًا.'**
  String get diagnosisUnavailable;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'لم نستطع قراءة الصورة. صوّر من جديد.'**
  String get photoUnreadable;

  /// APP-ONLY. Photo diagnosis.
  ///
  /// In ar, this message translates to:
  /// **'سؤالك في المجتمع'**
  String get questionPublished;

  /// No description provided for @whatToDo.
  ///
  /// In ar, this message translates to:
  /// **'ماذا أفعل؟'**
  String get whatToDo;

  /// No description provided for @askAnExpert.
  ///
  /// In ar, this message translates to:
  /// **'اسأل خبيرًا'**
  String get askAnExpert;

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

  /// No description provided for @treeName.
  ///
  /// In ar, this message translates to:
  /// **'الشجرة A-18'**
  String get treeName;

  /// No description provided for @wellDone.
  ///
  /// In ar, this message translates to:
  /// **'أحسنت!'**
  String get wellDone;

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

  /// No description provided for @meToo.
  ///
  /// In ar, this message translates to:
  /// **'أنا أيضًا'**
  String get meToo;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'لا تنبيه اليوم'**
  String get alertsNoneSubtitle;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'في منطقتك · {region}'**
  String alertsInRegion(String region);

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'في منطقتك'**
  String get alertsInRegionPlain;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'لا تنبيه في منطقتك. كل شيء هادئ.'**
  String get noAlertsInRegion;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'جديد'**
  String get alertNew;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'تنبيهات حسّاسات بستانك'**
  String get sensorAlertsSoon;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات على الهاتف'**
  String get phoneNotificationsSoon;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{تنبيه جديد} =2{تنبيهان جديدان} few{{count} تنبيهات جديدة} many{{count} تنبيهًا جديدًا} other{{count} تنبيه جديد}}'**
  String a11yNewAlerts(int count);

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'خطر'**
  String get severityDanger;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'انتباه'**
  String get severityWarning;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'معلومة'**
  String get severityInfo;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'صقيع'**
  String get kindFrost;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'موجة حرّ'**
  String get kindHeat;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'جفاف'**
  String get kindDrought;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'مرض'**
  String get kindDisease;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'آفات'**
  String get kindPest;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'رياح قوية'**
  String get kindWind;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'أمطار غزيرة'**
  String get kindRain;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'صالح حتى {date} على الساعة {time}'**
  String alertValidUntil(String date, String time);

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'صالح حتى إشعار آخر'**
  String get alertNoEnd;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'كن أول من يقول: أنا أيضًا'**
  String get meTooFirst;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{فلاح واحد قال: أنا أيضًا} =2{فلاحان قالا: أنا أيضًا} few{{count} فلاحين قالوا: أنا أيضًا} many{{count} فلاحًا قالوا: أنا أيضًا} other{{count} فلاح قالوا: أنا أيضًا}}'**
  String meTooSaid(int count);

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get takeBack;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'قمت بما يلزم.'**
  String get alertDoneText;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'انتهى هذا التنبيه.'**
  String get alertGone;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'رجوع إلى التنبيهات'**
  String get backToAlerts;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'كل شيء بخير'**
  String get homeAllGood;

  /// APP-ONLY. Alerts.
  ///
  /// In ar, this message translates to:
  /// **'لا تنبيه في منطقتك'**
  String get homeNoAlert;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'إبلاغ'**
  String get report;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'أبلغت'**
  String get reportedTag;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'لماذا تبلّغ؟'**
  String get reportWhy;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'إعلان أو إزعاج'**
  String get reportSpam;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'كلام مسيء'**
  String get reportInsult;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'نصيحة خاطئة أو خطيرة'**
  String get reportWrongAdvice;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'سبب آخر'**
  String get reportOther;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'شكرًا. سيراجعه فريق لوز.'**
  String get reportThanks;

  /// APP-ONLY. Community report.
  ///
  /// In ar, this message translates to:
  /// **'بلغت الحد اليوم. حاول غدًا.'**
  String get reportLimit;

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

  /// APP-ONLY. The letters of zones A to T, separated by spaces. Arabic: the ABJAD order (20), not أ ب ت ث (letters that differ only by dots are hard for weak readers).
  ///
  /// In ar, this message translates to:
  /// **'أ ب ج د ه و ز ح ط ي ك ل م ن س ع ف ص ق ر'**
  String get zoneLetters;

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
  /// **'توقّع السقي والحصاد'**
  String get packPredictions;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'بريميوم'**
  String get planPaid;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'{price} د.ت للمنطقة / {period}'**
  String pricePerZoneForDays(String price, String period);

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'{price} د.ت'**
  String dinarsAmount(String price);

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{منطقة واحدة} =2{منطقتان} few{{count} مناطق} many{{count} منطقة} other{{count} منطقة}}'**
  String zonesCount(int count);

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'كل منطقة من بستانك فيها حسّاس لوز واحد، نركّبه لك.'**
  String get packZoneNote;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'المساعد والحديث بالصوت'**
  String get packVoiceAssistant;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'ارسم بستانك أولًا.'**
  String get noDrawingYet;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'ارسم بستانك'**
  String get designerTitle;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'ثلاث خطوات بسيطة'**
  String get designerSubtitle;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'ارسم حدود بستانك'**
  String get designerStepOutline;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'قسّمه إلى مناطق'**
  String get designerStepZones;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'شاهد السعر وادفع'**
  String get designerStepPay;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الرسم'**
  String get startDrawing;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'جدّد باقتك'**
  String get renewPack;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'أشجار صغيرة'**
  String get zoneTypeYoungTrees;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'أشجار كبيرة'**
  String get zoneTypeOldTrees;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'تربة رملية'**
  String get zoneTypeSandySoil;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'مسقية'**
  String get zoneTypeIrrigated;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'بعلية'**
  String get zoneTypeRainfed;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get zoneTypeOther;

  /// APP-ONLY. Two packs / orchard.
  ///
  /// In ar, this message translates to:
  /// **'في انتظار التركيب'**
  String get nodeWaiting;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {step} من {total}'**
  String designerStepOf(int step, int total);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get next;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'رجوع'**
  String get back;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'أكمل الرسم'**
  String get continueDrawing;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ من جديد'**
  String get drawAgain;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'هل تمسح رسمك وتبدأ من جديد؟'**
  String get drawAgainQuestion;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'امسح'**
  String get eraseAction;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'رسمك محفوظ. أكمل من حيث توقّفت.'**
  String get draftSaved;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'بإصبعك، على شبكة'**
  String get drawWithFinger;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'على صورة القمر الصناعي'**
  String get satelliteMode;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'من صورة'**
  String get sketchMode;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'ارسم بستانك على ورقة وصوّرها'**
  String get sketchModeHint;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'صوّر رسمة بستانك'**
  String get sketchTitle;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'قلم أسود غليظ'**
  String get sketchTipPen;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'ورقة بيضاء'**
  String get sketchTipPaper;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'صوّر من فوق'**
  String get sketchTipAbove;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'الورقة كاملة في الصورة'**
  String get sketchTipWhole;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'الصورة تبقى في هاتفك، لا نرسلها.'**
  String get sketchPrivacy;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'نبحث عن حدود البستان…'**
  String get sketchLooking;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'لم نجد حدود البستان في الصورة.'**
  String get sketchNotFound;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'ارسم الحدود بخط واضح ومغلق، أو حدّد الزوايا بنفسك.'**
  String get sketchNotFoundHelp;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'حدّد الزوايا على الصورة'**
  String get sketchTapCorners;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'صورة أخرى'**
  String get sketchOtherPhoto;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'ارسم بيدك'**
  String get sketchDrawByHand;

  /// APP-ONLY. Orchard designer, from a photo of a sketch.
  ///
  /// In ar, this message translates to:
  /// **'وجدنا حدود بستانك. حرّك النقاط إذا لزم.'**
  String get sketchFoundHint;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'رسم البستان'**
  String get a11yOrchardDrawing;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'قلم'**
  String get toolPen;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'نقاط'**
  String get toolCorners;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get toolUndo;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'إعادة'**
  String get toolRedo;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'امسح'**
  String get toolErase;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'ارسم حدود بستانك بإصبعك'**
  String get hintPen;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على زوايا بستانك، واحدة بعد واحدة'**
  String get hintCorners;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على النقطة الأولى لإغلاق الشكل'**
  String get hintClose;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'اسحب نقطة لتحريكها'**
  String get hintMove;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'خطّان يتقاطعان. حرّك نقطة.'**
  String get problemCrossing;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'الشكل صغير جدًا. ارسم أكبر.'**
  String get problemTooSmall;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'مقاس بستانك تقريبًا'**
  String get sizeTitle;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'العرض: من الغرب إلى الشرق'**
  String get widthLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'الطول: من الشمال إلى الجنوب'**
  String get lengthLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'{value} م'**
  String metres(String value);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'{value} هكتار'**
  String hectaresValue(String value);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'اكتب رقمًا من {min} إلى {max}'**
  String sizeInvalid(int min, int max);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'المربّع = {value} م'**
  String gridSquare(String value);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'الشمال'**
  String get north;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'المساحة'**
  String get areaLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'العرض'**
  String get widthShort;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'الطول'**
  String get lengthShort;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'قسّم بستانك إلى مناطق'**
  String get zonesTitle;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'في كل منطقة حسّاس واحد'**
  String get zonesSubtitle;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'أعطي عدد المناطق والأشجار'**
  String get methodAuto;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'نقسّمه لك حسب الأشجار'**
  String get methodAutoHint;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'أرسم خطوط التقسيم بنفسي'**
  String get methodDraw;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'تسحب خطًا عبر البستان'**
  String get methodDrawHint;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'غيّر الطريقة'**
  String get changeMethod;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'عدد المناطق'**
  String get zonesHowMany;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'أقل'**
  String get fewer;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'أكثر'**
  String get more;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'الأشجار'**
  String get treesLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'اسحب خطًا من طرف إلى طرف'**
  String get hintCut;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'الخط لم يقسم أي منطقة.'**
  String get cutMissed;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'{max} منطقة على الأكثر'**
  String tooManyZones(int max);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'منطقة صغيرة جدًا. غيّر الأشجار.'**
  String get zoneTooSmall;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل المناطق'**
  String get zoneDetailsTitle;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'اضغط على منطقة لتغييرها'**
  String get zoneDetailsSubtitle;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'اسم المنطقة (اختياري)'**
  String get zoneNameOptional;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get zoneTypeLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'اللون'**
  String get zoneColorLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'شجرة واحدة على الأقل'**
  String get treesAtLeastOne;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'راجع بستانك'**
  String get reviewTitle;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'ثم ادفع، ونبني بستانك'**
  String get reviewSubtitle;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'المناطق'**
  String get zonesLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'الحسّاسات'**
  String get sensorsLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{حسّاس واحد} =2{حسّاسان} few{{count} حسّاسات} many{{count} حسّاسًا} other{{count} حسّاس}}'**
  String sensorsCount(int count);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'السعر'**
  String get priceLabel;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'بستانك {area} هكتار: يلزمه {sensors} على الأقل.'**
  String areaMinimum(String area, String sensors);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'قسّمه إلى {zones} بنفس السعر.'**
  String areaMinimumTip(String zones);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'ادفع وابنِ بستاني'**
  String get payAndBuild;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'ابنِ بستاني'**
  String get buildMyOrchard;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'باقتك تكفي هذا البستان.'**
  String get packCovers;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'عدّل المناطق'**
  String get editZones;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'بستانك كبير جدًا. اتصل بنا.'**
  String get orchardTooBig;

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'ثم {price}'**
  String thenPrice(String price);

  /// APP-ONLY. Orchard designer.
  ///
  /// In ar, this message translates to:
  /// **'جاري بناء بستانك…'**
  String get buildingOrchard;

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

  /// APP-ONLY. 3D / zone panel: the prediction says the trees of the zone are fine.
  ///
  /// In ar, this message translates to:
  /// **'بخير'**
  String get mlStateOk;

  /// APP-ONLY. Prediction (stress model): water deficit.
  ///
  /// In ar, this message translates to:
  /// **'نقص الماء'**
  String get mlStateWaterDeficit;

  /// APP-ONLY. Prediction: waterlogged soil.
  ///
  /// In ar, this message translates to:
  /// **'ماء زائد'**
  String get mlStateWaterlogging;

  /// APP-ONLY. Prediction: heat stress.
  ///
  /// In ar, this message translates to:
  /// **'حرارة شديدة'**
  String get mlStateHeat;

  /// APP-ONLY. Prediction (stress model): frost damage at bloom / small nuts.
  ///
  /// In ar, this message translates to:
  /// **'ضرر البرد'**
  String get mlStateFrostDamage;

  /// APP-ONLY. Prediction: root-zone problem (salt, roots).
  ///
  /// In ar, this message translates to:
  /// **'مشكل في الجذور'**
  String get mlStateRootzone;

  /// APP-ONLY. Prediction (frost model): frost tonight.
  ///
  /// In ar, this message translates to:
  /// **'خطر صقيع الليلة'**
  String get mlStateFrostRisk;

  /// APP-ONLY. Frost model: no frost tonight.
  ///
  /// In ar, this message translates to:
  /// **'لا صقيع الليلة'**
  String get mlStateNoFrost;

  /// APP-ONLY. The sensor box of the zone gives wrong readings.
  ///
  /// In ar, this message translates to:
  /// **'مشكل في الحسّاس'**
  String get mlStateSensorProblem;

  /// APP-ONLY. Not enough readings yet for a prediction.
  ///
  /// In ar, this message translates to:
  /// **'قراءات غير كافية'**
  String get mlStateNotEnoughData;

  /// APP-ONLY. Nothing received from the box for a while.
  ///
  /// In ar, this message translates to:
  /// **'الحسّاس غير متصل'**
  String get mlStateOffline;

  /// APP-ONLY. Zone panel: the line of the frost model.
  ///
  /// In ar, this message translates to:
  /// **'الليلة'**
  String get mlTonight;

  /// APP-ONLY. Zone panel: the line of the stress model.
  ///
  /// In ar, this message translates to:
  /// **'الأشجار'**
  String get mlTrees;

  /// APP-ONLY. Zone panel: the main reasons (SHAP) as bars.
  ///
  /// In ar, this message translates to:
  /// **'لماذا؟'**
  String get mlWhy;

  /// APP-ONLY. Zone panel. {time} = "منذ 5 دقائق".
  ///
  /// In ar, this message translates to:
  /// **'آخر تحديث: {time}'**
  String mlUpdated(String time);

  /// APP-ONLY. Zone panel: the latest readings of the box.
  ///
  /// In ar, this message translates to:
  /// **'آخر القراءات'**
  String get mlReadings;

  /// APP-ONLY. A reading (soil moisture).
  ///
  /// In ar, this message translates to:
  /// **'ماء التربة'**
  String get mlSoilWater;

  /// APP-ONLY. A reading (soil temperature).
  ///
  /// In ar, this message translates to:
  /// **'حرارة التربة'**
  String get mlSoilTemp;

  /// APP-ONLY. A reading (air temperature).
  ///
  /// In ar, this message translates to:
  /// **'حرارة الهواء'**
  String get mlAirTemp;

  /// APP-ONLY. A reading (air humidity).
  ///
  /// In ar, this message translates to:
  /// **'رطوبة الهواء'**
  String get mlHumidity;

  /// APP-ONLY. Zone panel, not enough data.
  ///
  /// In ar, this message translates to:
  /// **'نحتاج يومًا من القراءات قبل أن نتوقّع. ارجع بعد قليل.'**
  String get mlNotEnoughDataText;

  /// APP-ONLY. Zone panel, sensor problem.
  ///
  /// In ar, this message translates to:
  /// **'حسّاس هذه المنطقة يعطي قراءات غير صحيحة. لا نتوقّع حتى يرجع يخدم.'**
  String get mlSensorProblemText;

  /// APP-ONLY. Zone panel, box offline.
  ///
  /// In ar, this message translates to:
  /// **'لم يصلنا شيء من حسّاس هذه المنطقة منذ مدة.'**
  String get mlOfflineText;

  /// APP-ONLY. Zone panel, box not installed.
  ///
  /// In ar, this message translates to:
  /// **'سيأتي فريق لوز لتركيب الحسّاس.'**
  String get mlWaitingText;

  /// APP-ONLY. Explanation made from the codes when Groq gave no text.
  ///
  /// In ar, this message translates to:
  /// **'في {zone}: {state}. السبب: {reasons}.'**
  String mlTemplateText(String zone, String state, String reasons);

  /// APP-ONLY. Added to the template when the model is unsure.
  ///
  /// In ar, this message translates to:
  /// **'موش متأكدين: شوف الشجر بنفسك.'**
  String get mlTemplateUnsure;

  /// APP-ONLY. Alerts tab, "بستاني" section, no problem.
  ///
  /// In ar, this message translates to:
  /// **'كل مناطقك بخير.'**
  String get mlAllZonesFine;

  /// APP-ONLY. Alerts tab, no prediction yet.
  ///
  /// In ar, this message translates to:
  /// **'ننتظر قراءات حسّاساتك.'**
  String get mlNoPredictionYet;

  /// APP-ONLY. In-app notification: tap to open the zone.
  ///
  /// In ar, this message translates to:
  /// **'اضغط لترى المنطقة'**
  String get mlToastOpen;

  /// APP-ONLY. Title of a card / notification.
  ///
  /// In ar, this message translates to:
  /// **'{zone}: {state}'**
  String mlZoneOf(String zone, String state);

  /// APP-ONLY. "ماذا أفعل؟" of the template (stress model, state none).
  ///
  /// In ar, this message translates to:
  /// **'كمّل كيف العادة وشوف الشجر كل نهار.'**
  String get mlActionNone;

  /// APP-ONLY. "ماذا أفعل؟" of the template (stress model, state water_deficit).
  ///
  /// In ar, this message translates to:
  /// **'شوف خط السقي في المنطقة هاذي واسقي كان التربة ناشفة.'**
  String get mlActionWaterDeficit;

  /// APP-ONLY. "ماذا أفعل؟" of the template (stress model, state waterlogging).
  ///
  /// In ar, this message translates to:
  /// **'وقّف السقي في المنطقة هاذي وشوف كان الماء واقف.'**
  String get mlActionWaterlogging;

  /// APP-ONLY. "ماذا أفعل؟" of the template (stress model, state heat).
  ///
  /// In ar, this message translates to:
  /// **'اسقي في الصباح بكري ولا العشية، موش في القايلة.'**
  String get mlActionHeat;

  /// APP-ONLY. "ماذا أفعل؟" of the template (stress model, state frost).
  ///
  /// In ar, this message translates to:
  /// **'امشي شوف النوّار والثمار الصغار في المنطقة هاذي.'**
  String get mlActionFrostDamage;

  /// APP-ONLY. "ماذا أفعل؟" of the template (stress model, state rootzone).
  ///
  /// In ar, this message translates to:
  /// **'اسأل خبير على الجذور وملوحة الماء.'**
  String get mlActionRootzone;

  /// APP-ONLY. "ماذا أفعل؟" of the template (frost model, state frost_risk).
  ///
  /// In ar, this message translates to:
  /// **'امشي للمنطقة هاذي الليلة وحضّر الحماية اللي تستعمل فيها عادة.'**
  String get mlActionFrostRisk;

  /// APP-ONLY. "ماذا أفعل؟" of the template (frost model, state no_frost).
  ///
  /// In ar, this message translates to:
  /// **'ما تعمل شي خاص، شوف الشجر كيف العادة.'**
  String get mlActionNoFrost;

  /// APP-ONLY. A main reason of a prediction (factor soil_water, low).
  ///
  /// In ar, this message translates to:
  /// **'ماء قليل في التربة'**
  String get mlFactorSoilWaterLow;

  /// APP-ONLY. A main reason of a prediction (factor soil_water, high).
  ///
  /// In ar, this message translates to:
  /// **'التربة فيها برشا ماء'**
  String get mlFactorSoilWaterHigh;

  /// APP-ONLY. A main reason of a prediction (factor soil_drying, low).
  ///
  /// In ar, this message translates to:
  /// **'التربة تنشف بشوية'**
  String get mlFactorSoilDryingLow;

  /// APP-ONLY. A main reason of a prediction (factor soil_drying, high).
  ///
  /// In ar, this message translates to:
  /// **'التربة تنشف بسرعة'**
  String get mlFactorSoilDryingHigh;

  /// APP-ONLY. A main reason of a prediction (factor soil_too_wet, low).
  ///
  /// In ar, this message translates to:
  /// **'التربة موش مشبعة بالماء'**
  String get mlFactorSoilTooWetLow;

  /// APP-ONLY. A main reason of a prediction (factor soil_too_wet, high).
  ///
  /// In ar, this message translates to:
  /// **'التربة مشبعة بالماء'**
  String get mlFactorSoilTooWetHigh;

  /// APP-ONLY. A main reason of a prediction (factor watering, low).
  ///
  /// In ar, this message translates to:
  /// **'ما جاش ماء للتربة من مدة'**
  String get mlFactorWateringLow;

  /// APP-ONLY. A main reason of a prediction (factor watering, high).
  ///
  /// In ar, this message translates to:
  /// **'جا ماء للتربة (سقي ولا مطر)'**
  String get mlFactorWateringHigh;

  /// APP-ONLY. A main reason of a prediction (factor tree_water_need, low).
  ///
  /// In ar, this message translates to:
  /// **'الشجر يحتاج شوية ماء في الوقت هذا'**
  String get mlFactorTreeWaterNeedLow;

  /// APP-ONLY. A main reason of a prediction (factor tree_water_need, high).
  ///
  /// In ar, this message translates to:
  /// **'الشجر يحتاج برشا ماء في الوقت هذا'**
  String get mlFactorTreeWaterNeedHigh;

  /// APP-ONLY. A main reason of a prediction (factor air_heat, low).
  ///
  /// In ar, this message translates to:
  /// **'النهار موش سخون'**
  String get mlFactorAirHeatLow;

  /// APP-ONLY. A main reason of a prediction (factor air_heat, high).
  ///
  /// In ar, this message translates to:
  /// **'سخانة قوية في النهار'**
  String get mlFactorAirHeatHigh;

  /// APP-ONLY. A main reason of a prediction (factor night_cold, low).
  ///
  /// In ar, this message translates to:
  /// **'الليل اللي فات كان بارد'**
  String get mlFactorNightColdLow;

  /// APP-ONLY. A main reason of a prediction (factor night_cold, high).
  ///
  /// In ar, this message translates to:
  /// **'الليل اللي فات ما كانش بارد'**
  String get mlFactorNightColdHigh;

  /// APP-ONLY. A main reason of a prediction (factor evening_temp, low).
  ///
  /// In ar, this message translates to:
  /// **'الحرارة توّا منخفضة'**
  String get mlFactorEveningTempLow;

  /// APP-ONLY. A main reason of a prediction (factor evening_temp, high).
  ///
  /// In ar, this message translates to:
  /// **'الحرارة توّا موش منخفضة'**
  String get mlFactorEveningTempHigh;

  /// APP-ONLY. A main reason of a prediction (factor cooling_fast, low).
  ///
  /// In ar, this message translates to:
  /// **'الحرارة تهبط بشوية'**
  String get mlFactorCoolingFastLow;

  /// APP-ONLY. A main reason of a prediction (factor cooling_fast, high).
  ///
  /// In ar, this message translates to:
  /// **'الحرارة تهبط بسرعة'**
  String get mlFactorCoolingFastHigh;

  /// APP-ONLY. A main reason of a prediction (factor night_low_expected, low).
  ///
  /// In ar, this message translates to:
  /// **'الليلة تنجم تبرد برشا'**
  String get mlFactorNightLowExpectedLow;

  /// APP-ONLY. A main reason of a prediction (factor night_low_expected, high).
  ///
  /// In ar, this message translates to:
  /// **'الليلة ما تبردش برشا'**
  String get mlFactorNightLowExpectedHigh;

  /// APP-ONLY. A main reason of a prediction (factor dew_point, low).
  ///
  /// In ar, this message translates to:
  /// **'الهواء ناشف (نقطة الندى منخفضة)'**
  String get mlFactorDewPointLow;

  /// APP-ONLY. A main reason of a prediction (factor dew_point, high).
  ///
  /// In ar, this message translates to:
  /// **'الهواء فيه رطوبة (نقطة الندى عالية)'**
  String get mlFactorDewPointHigh;

  /// APP-ONLY. A main reason of a prediction (factor air_humidity, low).
  ///
  /// In ar, this message translates to:
  /// **'رطوبة الهواء منخفضة'**
  String get mlFactorAirHumidityLow;

  /// APP-ONLY. A main reason of a prediction (factor air_humidity, high).
  ///
  /// In ar, this message translates to:
  /// **'رطوبة الهواء عالية'**
  String get mlFactorAirHumidityHigh;

  /// APP-ONLY. A main reason of a prediction (factor air_dryness, low).
  ///
  /// In ar, this message translates to:
  /// **'الهواء موش ناشف'**
  String get mlFactorAirDrynessLow;

  /// APP-ONLY. A main reason of a prediction (factor air_dryness, high).
  ///
  /// In ar, this message translates to:
  /// **'الهواء ناشف وسخون'**
  String get mlFactorAirDrynessHigh;

  /// APP-ONLY. A main reason of a prediction (factor clear_sky, low).
  ///
  /// In ar, this message translates to:
  /// **'السماء موش صافية'**
  String get mlFactorClearSkyLow;

  /// APP-ONLY. A main reason of a prediction (factor clear_sky, high).
  ///
  /// In ar, this message translates to:
  /// **'السماء صافية: السخانة تهرب في الليل'**
  String get mlFactorClearSkyHigh;

  /// APP-ONLY. A main reason of a prediction (factor sunlight, low).
  ///
  /// In ar, this message translates to:
  /// **'شمس قليلة'**
  String get mlFactorSunlightLow;

  /// APP-ONLY. A main reason of a prediction (factor sunlight, high).
  ///
  /// In ar, this message translates to:
  /// **'شمس قوية'**
  String get mlFactorSunlightHigh;

  /// APP-ONLY. A main reason of a prediction (factor soil_temp, low).
  ///
  /// In ar, this message translates to:
  /// **'التربة باردة'**
  String get mlFactorSoilTempLow;

  /// APP-ONLY. A main reason of a prediction (factor soil_temp, high).
  ///
  /// In ar, this message translates to:
  /// **'التربة سخونة'**
  String get mlFactorSoilTempHigh;

  /// APP-ONLY. A main reason of a prediction (factor tree_sounds, low).
  ///
  /// In ar, this message translates to:
  /// **'جذع الشجرة هادئ'**
  String get mlFactorTreeSoundsLow;

  /// APP-ONLY. A main reason of a prediction (factor tree_sounds, high).
  ///
  /// In ar, this message translates to:
  /// **'جذع الشجرة يعطي إشارات عطش'**
  String get mlFactorTreeSoundsHigh;

  /// APP-ONLY. A main reason of a prediction (factor zone_place, low).
  ///
  /// In ar, this message translates to:
  /// **'المنطقة في بقعة منخفضة (البرد يتجمع فيها)'**
  String get mlFactorZonePlaceLow;

  /// APP-ONLY. A main reason of a prediction (factor zone_place, high).
  ///
  /// In ar, this message translates to:
  /// **'المنطقة في بقعة عالية'**
  String get mlFactorZonePlaceHigh;

  /// APP-ONLY. A main reason of a prediction (factor ground_cover, low).
  ///
  /// In ar, this message translates to:
  /// **'الشجر صغير وما يغطيش الأرض'**
  String get mlFactorGroundCoverLow;

  /// APP-ONLY. A main reason of a prediction (factor ground_cover, high).
  ///
  /// In ar, this message translates to:
  /// **'الشجر كبير ويغطي الأرض'**
  String get mlFactorGroundCoverHigh;

  /// APP-ONLY. A main reason of a prediction (factor season_stage, same).
  ///
  /// In ar, this message translates to:
  /// **'وقت العام ومرحلة الشجر'**
  String get mlFactorSeasonStage;

  /// APP-ONLY. A main reason of a prediction (factor soil_type, same).
  ///
  /// In ar, this message translates to:
  /// **'نوع التربة'**
  String get mlFactorSoilType;

  /// APP-ONLY. A main reason of a prediction (factor irrigation_type, same).
  ///
  /// In ar, this message translates to:
  /// **'طريقة السقي وملوحة الماء'**
  String get mlFactorIrrigationType;

  /// APP-ONLY. A main reason of a prediction (factor other_zones, same).
  ///
  /// In ar, this message translates to:
  /// **'مقارنة بالمناطق الأخرى متاعك'**
  String get mlFactorOtherZones;

  /// APP-ONLY. A main reason of a prediction (factor data_quality, same).
  ///
  /// In ar, this message translates to:
  /// **'بعض القراءات ناقصة'**
  String get mlFactorDataQuality;

  /// APP-ONLY. Between two reasons of the template text (Arabic comma).
  ///
  /// In ar, this message translates to:
  /// **'، '**
  String get mlListSeparator;
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
