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
  String get goodDayToWater => 'يوم مناسب للسقي';

  @override
  String get drySoil => 'التربة جافة';

  @override
  String get waterToday => 'اسقِ اليوم';

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
  String treeThirsty(String tree) {
    return 'الشجرة $tree عطشى';
  }

  @override
  String get actNow => 'تحرّك الآن';

  @override
  String get insectNearby => 'حشرة قريبة';

  @override
  String get watchLeaves => 'راقب الأوراق';

  @override
  String get restIsFine => 'باقي البستان بخير';

  @override
  String get allGood => 'كل شيء جيد';

  @override
  String get treeName => 'الشجرة A-18';

  @override
  String get needsWater => 'تحتاج ماء';

  @override
  String get wellDone => 'أحسنت!';

  @override
  String get treeHappy => 'الشجرة سعيدة الآن';

  @override
  String waterLiters(String liters) {
    return 'اسقِ $liters لترًا';
  }

  @override
  String noRainDays(String days) {
    return 'لم تمطر منذ $days أيام';
  }

  @override
  String get done => 'تمّ';

  @override
  String get regionalTitle => 'تنبيه في منطقتك';

  @override
  String get aphidsNearby => 'حشرة المنّ قريبة';

  @override
  String get checkYourLeaves => 'افحص أوراقك اليوم';

  @override
  String get farmersReported => 'فلاحًا أبلغوا عنها';

  @override
  String get meToo => 'أنا أراه أيضًا';

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
  String get langArabic => 'العربية';

  @override
  String get langFrench => 'Français';

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
  String get planEssential => 'أساسي';

  @override
  String get planConnected => 'متصل';

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
  String get nameTitle => 'ما اسمك؟';

  @override
  String get nameSubtitle => 'ليتعرّف عليك المجتمع';

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
  String packAssistantLimit(String count) {
    return 'المساعد: $count أسئلة في اليوم';
  }

  @override
  String get packRegionalAlerts => 'تنبيهات منطقتك';

  @override
  String get packAllOfFree => 'كل ما في الباقة المجانية';

  @override
  String get packAllOfEssential => 'كل ما في الباقة الأساسية';

  @override
  String get packUnlimitedAssistant => 'المساعد بلا حدود';

  @override
  String get pack3dOrchard => 'بستانك ثلاثي الأبعاد';

  @override
  String get packPhotoDiagnosis => 'تشخيص الأوراق بالصورة';

  @override
  String get packLiveSensors => 'حسّاسات البستان مباشرة';

  @override
  String get packPredictions => 'توقّع السقي والحصاد';

  @override
  String get payChoiceTitle => 'متى تدفع؟';

  @override
  String get payChoiceSubtitle => 'اختر ما يناسبك';

  @override
  String get payNow => 'ادفع الآن';

  @override
  String get payLater => 'ادفع لاحقًا';

  @override
  String get payPendingNote => 'حتى الدفع، تستعمل الباقة المجانية';

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
