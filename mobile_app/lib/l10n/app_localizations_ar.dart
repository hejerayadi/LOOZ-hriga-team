// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get tabHome => 'الرئيسية';

  @override
  String get tabCommunity => 'المجتمع';

  @override
  String get tabOrchard => 'بستاني ★';

  @override
  String get tabAlerts => 'التنبيهات';

  @override
  String get tabProfile => 'حسابي';

  @override
  String get askAssistant => 'اسأل المساعد';

  @override
  String get welcomeTitle => 'أهلًا بك في لوز';

  @override
  String get welcomeSubtitle => 'بستانك معك، كل يوم';

  @override
  String get phoneTitle => 'رقم هاتفك';

  @override
  String get phoneSubtitle => 'سنرسل رمزًا قصيرًا';

  @override
  String get sendCode => 'إرسال الرمز';

  @override
  String get codeTitle => 'أدخل الرمز';

  @override
  String get codeSubtitle => 'أرسلناه إلى هاتفك';

  @override
  String get confirm => 'تأكيد';

  @override
  String welcomeUser(String name) {
    return 'مرحبًا يا $name';
  }

  @override
  String get orchardReady => 'بستانك جاهز';

  @override
  String get start => 'ابدأ';

  @override
  String get homeTitle => 'صباح الخير';

  @override
  String homeSubtitle(String name) {
    return '$name، أشجارك بخير اليوم';
  }

  @override
  String homeSubtitleAlert(String name) {
    return '$name، انتبه: تنبيه في منطقتك';
  }

  @override
  String get goodDayToWater => 'يوم مناسب للسقي';

  @override
  String get quickAsk => 'اسأل';

  @override
  String get quickJournal => 'دفتر';

  @override
  String get quickMap => 'خريطة';

  @override
  String get communityTitle => 'المجتمع';

  @override
  String get communitySubtitle => 'من فلاحي تونس';

  @override
  String get almondBlossoms => 'أزهار اللوز';

  @override
  String get verifiedExpert => 'خبير موثّق';

  @override
  String get tipOfTheDay => 'نصيحة اليوم: اسقِ صباحًا';

  @override
  String get askAQuestion => 'اسأل سؤالًا';

  @override
  String answers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count إجابة',
      few: '$count إجابات',
      two: 'إجابتان',
      one: 'إجابة واحدة',
      zero: 'لا إجابة بعد',
    );
    return '$_temp0';
  }

  @override
  String get communityAnswersTitle => 'الإجابات';

  @override
  String get writeAnswerHint => 'اكتب إجابتك هنا';

  @override
  String get noAnswersYet => 'لا توجد إجابات بعد. كن أول من يجيب';

  @override
  String get writePostHint => 'مثال: أوراق اللوز صفراء، ماذا أفعل؟';

  @override
  String get newPostTitle => 'انشر في المجتمع';

  @override
  String get newPostSubtitle => 'سؤال أو نصيحة، مع صورة إن أردت';

  @override
  String get publish => 'انشر';

  @override
  String get publishing => 'جاري النشر…';

  @override
  String get takePhoto => 'التقط صورة';

  @override
  String get choosePhoto => 'اختر من الصور';

  @override
  String get changePhoto => 'تغيير';

  @override
  String get removePhoto => 'إزالة';

  @override
  String get preparingPhoto => 'جاري تحضير الصورة…';

  @override
  String get uploadingPhoto => 'جاري رفع الصورة…';

  @override
  String get photoTooBig =>
      'الصورة كبيرة جدًا (أكثر من 5 ميغابايت). اختر صورة أخرى.';

  @override
  String get photoWrongType => 'هذا الملف ليس صورة (JPG أو PNG أو WebP).';

  @override
  String get uploadFailed => 'لم تُرفع الصورة. حاول مرة أخرى.';

  @override
  String get cameraDenied =>
      'لم تسمح للوز باستخدام الكاميرا. اسمح بذلك من إعدادات الهاتف.';

  @override
  String get galleryDenied =>
      'لم تسمح للوز بالوصول إلى صورك. اسمح بذلك من إعدادات الهاتف.';

  @override
  String get noCamera => 'لا توجد كاميرا على هذا الجهاز.';

  @override
  String get photoUnavailable => 'تعذّر عرض الصورة';

  @override
  String get a11yPostPhoto => 'صورة المنشور';

  @override
  String get deleteAnswerQuestion => 'هل تريد حذف إجابتك؟';

  @override
  String get deletePostQuestion => 'هل تريد حذف سؤالك؟ ستُحذف إجاباته أيضًا.';

  @override
  String get deleteAction => 'حذف';

  @override
  String get cancelAction => 'إلغاء';

  @override
  String get textEmpty => 'اكتب شيئًا أولًا';

  @override
  String textTooLong(String max) {
    return 'النص طويل جدًا: $max حرف على الأكثر';
  }

  @override
  String get textBadCharacters => 'لا تستعمل الرمزين < و >';

  @override
  String get tooFast => 'تمهّل قليلًا، حاول بعد دقيقة';

  @override
  String get postGone => 'هذا السؤال لم يعد موجودًا';

  @override
  String get cantDelete => 'لا يمكنك حذف هذا';

  @override
  String get farmerFallbackName => 'فلاح';

  @override
  String get loading => 'جاري التحميل…';

  @override
  String get soon => 'قريبًا';

  @override
  String charCount(int count, int max) {
    return '$count / $max';
  }

  @override
  String get timeJustNow => 'الآن';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count دقيقة',
      few: 'منذ $count دقائق',
      two: 'منذ دقيقتين',
      one: 'منذ دقيقة',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count ساعة',
      few: 'منذ $count ساعات',
      two: 'منذ ساعتين',
      one: 'منذ ساعة',
    );
    return '$_temp0';
  }

  @override
  String timeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'منذ $count يوم',
      many: 'منذ $count يومًا',
      few: 'منذ $count أيام',
      two: 'منذ يومين',
      one: 'منذ يوم',
    );
    return '$_temp0';
  }

  @override
  String get regionSfax => 'صفاقس';

  @override
  String get regionKairouan => 'القيروان';

  @override
  String get regionSidiBouzid => 'سيدي بوزيد';

  @override
  String get regionGafsa => 'قفصة';

  @override
  String get regionKasserine => 'القصرين';

  @override
  String get regionMahdia => 'المهدية';

  @override
  String get regionZaghouan => 'زغوان';

  @override
  String get createAccount => 'إنشاء حساب';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get errorNoAccount => 'لا يوجد حساب بهذا الرقم.';

  @override
  String get accountExists => 'هذا الرقم لديه حساب بالفعل.';

  @override
  String get welcomeBack => 'مرحبًا من جديد';

  @override
  String get infoTitle => 'معلوماتك';

  @override
  String get infoSubtitle => 'أسئلة قليلة فقط';

  @override
  String get roleFarmer => 'فلاح';

  @override
  String get roleExpert => 'مهندس فلاحي أو مرشد';

  @override
  String get roleTitle => 'من أنت؟';

  @override
  String get roleSubtitle => 'اختر ما يناسبك';

  @override
  String get roleFarmerHint => 'عندي بستان لوز';

  @override
  String get roleExpertHint => 'أنصح الفلاحين في المجتمع';

  @override
  String get governorate => 'الولاية';

  @override
  String get chooseGovernorate => 'اختر ولايتك';

  @override
  String get almondTreesOptional => 'عدد أشجار اللوز (اختياري)';

  @override
  String get areaOptional => 'المساحة بالهكتار (اختياري)';

  @override
  String get irrigationOptional => 'السقي (اختياري)';

  @override
  String get irrigated => 'مسقي';

  @override
  String get rainfed => 'بعلي';

  @override
  String get organisationOptional => 'المؤسسة (اختياري)';

  @override
  String get numberInvalid => 'اكتب رقمًا صحيحًا';

  @override
  String get expertPendingNote =>
      'ستظهر شارة «◆ خبير موثّق» بعد أن نتحقق من حسابك.';

  @override
  String priceForDays(String price, String period) {
    return '$price د.ت / $period';
  }

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يوم',
      many: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم',
    );
    return '$_temp0';
  }

  @override
  String get demoMode => 'وضع تجريبي';

  @override
  String get cardNumber => 'رقم البطاقة';

  @override
  String get cardExpiry => 'تاريخ الانتهاء';

  @override
  String get cardCode => 'رمز الأمان';

  @override
  String get cardName => 'الاسم على البطاقة';

  @override
  String get cardNumberInvalid => '16 رقمًا';

  @override
  String get cardExpiryInvalid => 'تاريخ غير صحيح (شهر/سنة)';

  @override
  String get cardCodeInvalid => '3 أرقام';

  @override
  String get checkingPayment => 'جاري التحقق من الدفع…';

  @override
  String get paidTitle => 'تم الدفع!';

  @override
  String paidUntil(String date) {
    return 'باقتك مفعّلة حتى $date';
  }

  @override
  String get notPaidTitle => 'لم يكتمل الدفع';

  @override
  String get notPaidText =>
      'ستبقى على الخطة المجانية، ويمكنك الدفع لاحقًا من «حسابي».';

  @override
  String get continueFree => 'متابعة مجانًا';

  @override
  String get paymentNotAvailable => 'الدفع غير متاح الآن.';

  @override
  String get tooManyPayments => 'محاولات دفع كثيرة. حاول بعد ساعة.';

  @override
  String planUntil(String date) {
    return 'حتى $date';
  }

  @override
  String get regionTunis => 'تونس';

  @override
  String get regionAriana => 'أريانة';

  @override
  String get regionBenArous => 'بن عروس';

  @override
  String get regionManouba => 'منوبة';

  @override
  String get regionNabeul => 'نابل';

  @override
  String get regionBizerte => 'بنزرت';

  @override
  String get regionBeja => 'باجة';

  @override
  String get regionJendouba => 'جندوبة';

  @override
  String get regionKef => 'الكاف';

  @override
  String get regionSiliana => 'سليانة';

  @override
  String get regionSousse => 'سوسة';

  @override
  String get regionMonastir => 'المنستير';

  @override
  String get regionGabes => 'قابس';

  @override
  String get regionMedenine => 'مدنين';

  @override
  String get regionTataouine => 'تطاوين';

  @override
  String get regionTozeur => 'توزر';

  @override
  String get regionKebili => 'قبلي';

  @override
  String get askTitle => 'اسأل سؤالًا';

  @override
  String get askSubtitle => 'اختر الأسهل لك';

  @override
  String get speak => 'تكلّم';

  @override
  String get speakHint => 'اضغط وقل سؤالك';

  @override
  String get photo => 'صورة';

  @override
  String get text => 'كتابة';

  @override
  String get send => 'أرسل';

  @override
  String get tipsTitle => 'مكتبة النصائح';

  @override
  String get tipWaterBeforeSun => 'اسقِ قبل اشتداد الشمس';

  @override
  String get tipCheckLeaves => 'افحص الأوراق كل أسبوع';

  @override
  String get tipPhotoInsects => 'صوّر أي حشرة غريبة';

  @override
  String get photographLeaf => 'صوّر الورقة';

  @override
  String get looking => 'جاري النظر…';

  @override
  String get resultTitle => 'وجدت شيئًا';

  @override
  String get maybeAphids => 'قد تكون حشرة المنّ';

  @override
  String get whatIsIt => 'ما هي؟';

  @override
  String get smallInsect => 'حشرة صغيرة';

  @override
  String get why => 'لماذا؟';

  @override
  String get warmWeather => 'جو دافئ';

  @override
  String get whatToDo => 'ماذا أفعل؟';

  @override
  String get rinseLeaf => 'اغسل الورقة';

  @override
  String get askAnExpert => 'اسأل خبيرًا';

  @override
  String get listening => 'أنا أسمعك';

  @override
  String get speakFreely => 'تكلّم براحتك…';

  @override
  String get alertsTitle => 'التنبيهات';

  @override
  String alertsSubtitle(String count) {
    return '$count تحتاج انتباهك';
  }

  @override
  String get treeName => 'الشجرة A-18';

  @override
  String get wellDone => 'أحسنت!';

  @override
  String get done => 'تمّ';

  @override
  String get regionalTitle => 'تنبيه في منطقتك';

  @override
  String get meToo => 'أنا أيضًا';

  @override
  String get alertsNoneSubtitle => 'لا تنبيه اليوم';

  @override
  String alertsInRegion(String region) {
    return 'في منطقتك · $region';
  }

  @override
  String get alertsInRegionPlain => 'في منطقتك';

  @override
  String get noAlertsInRegion => 'لا تنبيه في منطقتك. كل شيء هادئ.';

  @override
  String get alertNew => 'جديد';

  @override
  String get sensorAlertsSoon => 'تنبيهات حسّاسات بستانك';

  @override
  String get phoneNotificationsSoon => 'الإشعارات على الهاتف';

  @override
  String a11yNewAlerts(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تنبيه جديد',
      many: '$count تنبيهًا جديدًا',
      few: '$count تنبيهات جديدة',
      two: 'تنبيهان جديدان',
      one: 'تنبيه جديد',
    );
    return '$_temp0';
  }

  @override
  String get severityDanger => 'خطر';

  @override
  String get severityWarning => 'انتباه';

  @override
  String get severityInfo => 'معلومة';

  @override
  String get kindFrost => 'صقيع';

  @override
  String get kindHeat => 'موجة حرّ';

  @override
  String get kindDrought => 'جفاف';

  @override
  String get kindDisease => 'مرض';

  @override
  String get kindPest => 'آفات';

  @override
  String get kindWind => 'رياح قوية';

  @override
  String get kindRain => 'أمطار غزيرة';

  @override
  String alertValidUntil(String date, String time) {
    return 'صالح حتى $date على الساعة $time';
  }

  @override
  String get alertNoEnd => 'صالح حتى إشعار آخر';

  @override
  String get meTooFirst => 'كن أول من يقول: أنا أيضًا';

  @override
  String meTooSaid(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فلاح قالوا: أنا أيضًا',
      many: '$count فلاحًا قالوا: أنا أيضًا',
      few: '$count فلاحين قالوا: أنا أيضًا',
      two: 'فلاحان قالا: أنا أيضًا',
      one: 'فلاح واحد قال: أنا أيضًا',
    );
    return '$_temp0';
  }

  @override
  String get takeBack => 'تراجع';

  @override
  String get alertDoneText => 'قمت بما يلزم.';

  @override
  String get alertGone => 'انتهى هذا التنبيه.';

  @override
  String get backToAlerts => 'رجوع إلى التنبيهات';

  @override
  String get homeAllGood => 'كل شيء بخير';

  @override
  String get homeNoAlert => 'لا تنبيه في منطقتك';

  @override
  String get report => 'إبلاغ';

  @override
  String get reportedTag => 'أبلغت';

  @override
  String get reportWhy => 'لماذا تبلّغ؟';

  @override
  String get reportSpam => 'إعلان أو إزعاج';

  @override
  String get reportInsult => 'كلام مسيء';

  @override
  String get reportWrongAdvice => 'نصيحة خاطئة أو خطيرة';

  @override
  String get reportOther => 'سبب آخر';

  @override
  String get reportThanks => 'شكرًا. سيراجعه فريق لوز.';

  @override
  String get reportLimit => 'بلغت الحد اليوم. حاول غدًا.';

  @override
  String get myOrchard => 'بستاني';

  @override
  String get orchardInPocket => 'بستانك في جيبك';

  @override
  String get benefitTreeMap => 'خريطة كل شجرة';

  @override
  String get benefitSmartWatering => 'سقي ذكي';

  @override
  String get benefitEarlyAlert => 'تنبيه مبكر';

  @override
  String get startPremium => 'ابدأ بريميوم';

  @override
  String get notNow => 'ليس الآن';

  @override
  String get premiumTitle => 'LOOZ بريميوم';

  @override
  String get free => 'مجاني';

  @override
  String get assistant => 'المساعد';

  @override
  String get orchardMap => 'خريطة البستان';

  @override
  String get smartAlerts => 'تنبيهات ذكية';

  @override
  String get currency => 'د.ت';

  @override
  String get month => 'شهر';

  @override
  String get cancelAnytime => 'إلغاء في أي وقت';

  @override
  String get paymentTitle => 'الدفع';

  @override
  String get paymentSubtitle => 'خطوة واحدة فقط';

  @override
  String get pricePerMonth => 'د.ت / شهر';

  @override
  String get scanTitle => 'امسح الرمز';

  @override
  String get scanSubtitle => 'مرحبًا في بريميوم';

  @override
  String get onOrchardDevice => 'على جهاز البستان';

  @override
  String get openMap => 'فتح الخريطة';

  @override
  String treeCount(String count) {
    return '$count شجرة';
  }

  @override
  String get look => 'راقب';

  @override
  String get journalTitle => 'دفتر البستان';

  @override
  String get journalSubtitle => 'ماذا فعلت اليوم؟';

  @override
  String get dictateNote => 'سجّل بصوتك';

  @override
  String get watering => 'سقي';

  @override
  String get treatment => 'علاج';

  @override
  String get pruning => 'تقليم';

  @override
  String get harvest => 'حصاد';

  @override
  String get save => 'حفظ';

  @override
  String get myPlan => 'خطتي';

  @override
  String get becomeExpert => 'كن خبيرًا';

  @override
  String get appStates => 'حالات التطبيق';

  @override
  String get sendLater => 'سيُرسل لاحقًا';

  @override
  String get noInternet => 'لا يوجد إنترنت';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get askFirstQuestion => 'اسأل سؤالك الأول';

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
    return 'المنطقة $letter';
  }

  @override
  String get devPlanSwitch => 'وضع التجربة: تغيير الخطة';

  @override
  String get a11yCamera => 'الكاميرا';

  @override
  String get a11yReadAloud => 'استمع';

  @override
  String get a11yClose => 'إغلاق';

  @override
  String get a11yPlay => 'تشغيل';

  @override
  String get sending => 'جاري الإرسال…';

  @override
  String get checking => 'جاري التحقق…';

  @override
  String get resendCode => 'أعد إرسال الرمز';

  @override
  String get codeResent => 'أرسلنا رمزًا جديدًا';

  @override
  String get firstName => 'الاسم';

  @override
  String get lastName => 'اللقب';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get saving => 'جاري الحفظ…';

  @override
  String get nameRequired => 'هذه الخانة مطلوبة';

  @override
  String nameTooLong(String max) {
    return '$max حرفًا على الأكثر';
  }

  @override
  String get nameBadCharacters => 'استعمل الحروف فقط';

  @override
  String get packTitle => 'اختر باقتك';

  @override
  String get packSubtitle => 'ابدأ مجانًا أو اختر المزيد';

  @override
  String get packNoPayment => 'بدون دفع';

  @override
  String get packRegionalAlerts => 'تنبيهات منطقتك';

  @override
  String get packAllOfFree => 'كل ما في الباقة المجانية';

  @override
  String get pack3dOrchard => 'بستانك ثلاثي الأبعاد';

  @override
  String get packPhotoDiagnosis => 'تشخيص الأوراق بالصورة';

  @override
  String get packPredictions => 'توقّع السقي والحصاد';

  @override
  String get planPaid => 'بريميوم';

  @override
  String pricePerZoneForDays(String price, String period) {
    return '$price د.ت للمنطقة / $period';
  }

  @override
  String dinarsAmount(String price) {
    return '$price د.ت';
  }

  @override
  String zonesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count منطقة',
      many: '$count منطقة',
      few: '$count مناطق',
      two: 'منطقتان',
      one: 'منطقة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get packZoneNote =>
      'كل منطقة من بستانك فيها حسّاس لوز واحد، نركّبه لك.';

  @override
  String get packVoiceAssistant => 'المساعد والحديث بالصوت';

  @override
  String get noDrawingYet => 'ارسم بستانك أولًا.';

  @override
  String get designerTitle => 'ارسم بستانك';

  @override
  String get designerSubtitle => 'ثلاث خطوات بسيطة';

  @override
  String get designerStepOutline => 'ارسم حدود بستانك';

  @override
  String get designerStepZones => 'قسّمه إلى مناطق';

  @override
  String get designerStepPay => 'شاهد السعر وادفع';

  @override
  String get startDrawing => 'ابدأ الرسم';

  @override
  String get renewPack => 'جدّد باقتك';

  @override
  String get zoneTypeYoungTrees => 'أشجار صغيرة';

  @override
  String get zoneTypeOldTrees => 'أشجار كبيرة';

  @override
  String get zoneTypeSandySoil => 'تربة رملية';

  @override
  String get zoneTypeIrrigated => 'مسقية';

  @override
  String get zoneTypeRainfed => 'بعلية';

  @override
  String get zoneTypeOther => 'أخرى';

  @override
  String get nodeWaiting => 'في انتظار التركيب';

  @override
  String designerStepOf(int step, int total) {
    return 'الخطوة $step من $total';
  }

  @override
  String get next => 'التالي';

  @override
  String get back => 'رجوع';

  @override
  String get continueDrawing => 'أكمل الرسم';

  @override
  String get drawAgain => 'ابدأ من جديد';

  @override
  String get drawAgainQuestion => 'هل تمسح رسمك وتبدأ من جديد؟';

  @override
  String get eraseAction => 'امسح';

  @override
  String get draftSaved => 'رسمك محفوظ. أكمل من حيث توقّفت.';

  @override
  String get drawWithFinger => 'بإصبعك، على شبكة';

  @override
  String get satelliteMode => 'على صورة القمر الصناعي';

  @override
  String get a11yOrchardDrawing => 'رسم البستان';

  @override
  String get toolPen => 'قلم';

  @override
  String get toolCorners => 'نقاط';

  @override
  String get toolUndo => 'تراجع';

  @override
  String get toolRedo => 'إعادة';

  @override
  String get toolErase => 'امسح';

  @override
  String get hintPen => 'ارسم حدود بستانك بإصبعك';

  @override
  String get hintCorners => 'اضغط على زوايا بستانك، واحدة بعد واحدة';

  @override
  String get hintClose => 'اضغط على النقطة الأولى لإغلاق الشكل';

  @override
  String get hintMove => 'اسحب نقطة لتحريكها';

  @override
  String get problemCrossing => 'خطّان يتقاطعان. حرّك نقطة.';

  @override
  String get problemTooSmall => 'الشكل صغير جدًا. ارسم أكبر.';

  @override
  String get sizeTitle => 'مقاس بستانك تقريبًا';

  @override
  String get widthLabel => 'العرض: من الغرب إلى الشرق';

  @override
  String get lengthLabel => 'الطول: من الشمال إلى الجنوب';

  @override
  String metres(String value) {
    return '$value م';
  }

  @override
  String hectaresValue(String value) {
    return '$value هكتار';
  }

  @override
  String sizeInvalid(int min, int max) {
    return 'اكتب رقمًا من $min إلى $max';
  }

  @override
  String gridSquare(String value) {
    return 'المربّع = $value م';
  }

  @override
  String get north => 'الشمال';

  @override
  String get areaLabel => 'المساحة';

  @override
  String get widthShort => 'العرض';

  @override
  String get lengthShort => 'الطول';

  @override
  String get zonesTitle => 'قسّم بستانك إلى مناطق';

  @override
  String get zonesSubtitle => 'في كل منطقة حسّاس واحد';

  @override
  String get methodAuto => 'أعطي عدد المناطق والأشجار';

  @override
  String get methodAutoHint => 'نقسّمه لك حسب الأشجار';

  @override
  String get methodDraw => 'أرسم خطوط التقسيم بنفسي';

  @override
  String get methodDrawHint => 'تسحب خطًا عبر البستان';

  @override
  String get changeMethod => 'غيّر الطريقة';

  @override
  String get zonesHowMany => 'عدد المناطق';

  @override
  String get fewer => 'أقل';

  @override
  String get more => 'أكثر';

  @override
  String get treesLabel => 'الأشجار';

  @override
  String get hintCut => 'اسحب خطًا من طرف إلى طرف';

  @override
  String get cutMissed => 'الخط لم يقسم أي منطقة.';

  @override
  String tooManyZones(int max) {
    return '$max منطقة على الأكثر';
  }

  @override
  String get zoneTooSmall => 'منطقة صغيرة جدًا. غيّر الأشجار.';

  @override
  String get zoneDetailsTitle => 'تفاصيل المناطق';

  @override
  String get zoneDetailsSubtitle => 'اضغط على منطقة لتغييرها';

  @override
  String get zoneNameOptional => 'اسم المنطقة (اختياري)';

  @override
  String get zoneTypeLabel => 'النوع';

  @override
  String get zoneColorLabel => 'اللون';

  @override
  String get treesAtLeastOne => 'شجرة واحدة على الأقل';

  @override
  String get reviewTitle => 'راجع بستانك';

  @override
  String get reviewSubtitle => 'ثم ادفع، ونبني بستانك';

  @override
  String get zonesLabel => 'المناطق';

  @override
  String get sensorsLabel => 'الحسّاسات';

  @override
  String sensorsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count حسّاس',
      many: '$count حسّاسًا',
      few: '$count حسّاسات',
      two: 'حسّاسان',
      one: 'حسّاس واحد',
    );
    return '$_temp0';
  }

  @override
  String get priceLabel => 'السعر';

  @override
  String areaMinimum(String area, String sensors) {
    return 'بستانك $area هكتار: يلزمه $sensors على الأقل.';
  }

  @override
  String areaMinimumTip(String zones) {
    return 'قسّمه إلى $zones بنفس السعر.';
  }

  @override
  String get payAndBuild => 'ادفع وابنِ بستاني';

  @override
  String get buildMyOrchard => 'ابنِ بستاني';

  @override
  String get packCovers => 'باقتك تكفي هذا البستان.';

  @override
  String get editZones => 'عدّل المناطق';

  @override
  String get orchardTooBig => 'بستانك كبير جدًا. اتصل بنا.';

  @override
  String thenPrice(String price) {
    return 'ثم $price';
  }

  @override
  String get buildingOrchard => 'جاري بناء بستانك…';

  @override
  String get logOut => 'تسجيل الخروج';

  @override
  String get errorNoInternet =>
      'لا يوجد إنترنت. تحقّق من الاتصال وحاول مرة أخرى.';

  @override
  String get errorWrongCode => 'الرمز غير صحيح أو انتهت صلاحيته.';

  @override
  String get errorTooManyTries =>
      'محاولات كثيرة. انتظر دقيقة ثم حاول مرة أخرى.';

  @override
  String get errorCannotReceiveCode => 'هذا الرقم لا يمكنه استقبال الرموز بعد.';

  @override
  String get errorInvalidPhone => 'رقم الهاتف غير صحيح.';

  @override
  String get errorPhoneTaken => 'هذا الرقم مستعمل في حساب آخر.';

  @override
  String get errorInvalidName => 'الاسم غير مقبول. استعمل الحروف فقط.';

  @override
  String get errorSessionExpired => 'انتهت الجلسة. سجّل الدخول من جديد.';

  @override
  String get somethingWrong => 'حدث خطأ. حاول مرة أخرى.';

  @override
  String get missingKeys =>
      'مفاتيح Supabase غير موجودة.\n\nاملأ ملف mobile_app/.env ثم شغّل:\nflutter run --dart-define-from-file=.env';
}
