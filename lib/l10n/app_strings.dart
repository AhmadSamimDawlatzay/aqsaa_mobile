import '../api/api_client.dart';
import '../auth/session_store.dart';
import 'app_language.dart';

abstract final class AppStrings {
  static AppLanguage _language = AppLanguage.pashto;
  static void setLanguage(AppLanguage value) => _language = value;
  static String _s(String en, String ps, String fa, String ar) =>
      switch (_language) {
        AppLanguage.pashto => ps,
        AppLanguage.dari => fa,
        AppLanguage.arabic => ar,
        AppLanguage.english => en,
      };

  static String get appName => 'Aqsaa';
  static String get welcome => _s(
    'Welcome to Aqsaa',
    'اقصی ته ښه راغلاست',
    'به اقصی خوش آمدید',
    'مرحبًا بك في أقصى',
  );
  static String get subtitle => _s(
    'Your institution, connected.',
    'ستاسو ښوونیز مرکز، له تاسو سره نښتی.',
    'مرکز آموزشی شما، در دسترس شما.',
    'مؤسستك التعليمية متصلة.',
  );
  static String get loading => _s(
    'Connecting to your institution…',
    'له ښوونیز مرکز سره نښلول کېږي…',
    'در حال اتصال به مرکز آموزشی…',
    'جارٍ الاتصال بالمؤسسة…',
  );
  static String get connected =>
      _s('Connected', 'ونښلول شو', 'متصل شد', 'متصل');
  static String get empty => _s(
    'The API is connected, but no institution is configured yet.',
    'API وصل دی، خو ښوونیز مرکز لا نه دی تنظیم شوی.',
    'API متصل است، اما مرکز آموزشی تنظیم نشده است.',
    'واجهة API متصلة، لكن المؤسسة غير مهيأة.',
  );
  static String get failed => _s(
    'Unable to connect',
    'اړیکه ټینګه نه شوه',
    'اتصال برقرار نشد',
    'تعذر الاتصال',
  );
  static String get retry =>
      _s('Retry', 'بیا هڅه', 'تلاش دوباره', 'إعادة المحاولة');
  static String get refresh => _s('Refresh', 'تازه کول', 'تازه‌سازی', 'تحديث');
  static String get logo => _s(
    'Institution logo',
    'د ښوونیز مرکز نښان',
    'نشان مرکز آموزشی',
    'شعار المؤسسة',
  );
  static String get logoFallback => _s(
    'Institution logo unavailable',
    'نښان نشته',
    'نشان موجود نیست',
    'الشعار غير متاح',
  );
  static String get login => _s('Log in', 'ننوتل', 'ورود', 'تسجيل الدخول');
  static String get loginHeading => _s(
    'Sign in to your account',
    'خپل حساب ته ننوځئ',
    'به حساب خود وارد شوید',
    'سجّل الدخول إلى حسابك',
  );
  static String get loginSubtitle => _s(
    'Use your institution account to continue.',
    'د دوام لپاره د ښوونیز مرکز حساب وکاروئ.',
    'برای ادامه از حساب مرکز آموزشی استفاده کنید.',
    'استخدم حساب المؤسسة للمتابعة.',
  );
  static String get logout => _s('Log out', 'وتل', 'خروج', 'تسجيل الخروج');
  static String get email =>
      _s('Email', 'برېښنالیک', 'ایمیل', 'البريد الإلكتروني');
  static String get password =>
      _s('Password', 'پټنوم', 'رمز عبور', 'كلمة المرور');
  static String get showPassword => _s(
    'Show password',
    'پټنوم ښکاره کړئ',
    'نمایش رمز عبور',
    'إظهار كلمة المرور',
  );
  static String get hidePassword => _s(
    'Hide password',
    'پټنوم پټ کړئ',
    'پنهان کردن رمز عبور',
    'إخفاء كلمة المرور',
  );
  static String get requiredField => _s(
    'This field is required.',
    'دا ځای اړین دی.',
    'این بخش الزامی است.',
    'هذا الحقل مطلوب.',
  );
  static String get invalidEmail => _s(
    'Enter a valid email address.',
    'سم برېښنالیک ولیکئ.',
    'یک ایمیل معتبر وارد کنید.',
    'أدخل بريدًا إلكترونيًا صالحًا.',
  );
  static String get passwordTooLong => _s(
    'Password must be at most 255 characters.',
    'پټنوم باید تر ۲۵۵ تورو زیات نه وي.',
    'رمز عبور نباید بیشتر از ۲۵۵ نویسه باشد.',
    'يجب ألا تتجاوز كلمة المرور ٢٥٥ حرفًا.',
  );
  static String get back => _s(
    'Back to welcome',
    'ښه راغلاست ته ستنېدل',
    'بازگشت به خوش‌آمدید',
    'العودة إلى الترحيب',
  );
  static String get checkingSession => _s(
    'Verifying your session…',
    'ستاسو ناسته کتل کېږي…',
    'در حال بررسی نشست شما…',
    'جارٍ التحقق من جلستك…',
  );
  static String get signingOut =>
      _s('Signing out…', 'وتل روان دي…', 'در حال خروج…', 'جارٍ تسجيل الخروج…');
  static String get accountHeading => _s('Account', 'حساب', 'حساب', 'الحساب');
  static String get accountSubtitle => _s(
    'Your profile and sign-out options.',
    'ستاسو پېژندپاڼه او د وتلو اختیارونه.',
    'مشخصات و گزینه‌های خروج شما.',
    'ملفك الشخصي وخيارات تسجيل الخروج.',
  );
  static String get accountTab => accountHeading;
  static String get childrenTab =>
      _s('Children', 'ماشومان', 'فرزندان', 'الأبناء');
  static String get profileSection =>
      _s('Profile', 'پېژندپاڼه', 'مشخصات', 'الملف الشخصي');
  static String get institutionSection =>
      _s('Institution', 'ښوونیز مرکز', 'مرکز آموزشی', 'المؤسسة');
  static String get name => _s('Name', 'نوم', 'نام', 'الاسم');
  static String get academicInformation => _s(
    'Academic information',
    'ښوونیز معلومات',
    'معلومات آموزشی',
    'المعلومات الدراسية',
  );
  static String get attendanceHeading =>
      _s('Attendance', 'حاضري', 'حاضری', 'الحضور');
  static String get summaryPeriod =>
      _s('Summary period', 'د لنډیز موده', 'دوره خلاصه', 'فترة الملخص');
  static String get allAvailableDates => _s(
    'All available dates',
    'ټولې شته نېټې',
    'همه تاریخ‌های موجود',
    'كل التواريخ المتاحة',
  );
  static String get editSummaryPeriod => _s(
    'Edit summary period',
    'د لنډیز موده بدله کړئ',
    'تغییر دوره خلاصه',
    'تعديل فترة الملخص',
  );
  static String get attendanceHistoryAllDates => _s(
    'Attendance history — all dates',
    'د حاضرۍ تاریخچه — ټولې نېټې',
    'تاریخچه حاضری — همه تاریخ‌ها',
    'سجل الحضور — كل التواريخ',
  );
  static String get summaryUnavailable => _s(
    'Summary is unavailable for this period.',
    'د دې مودې لنډیز نشته.',
    'خلاصه این دوره موجود نیست.',
    'ملخص هذه الفترة غير متاح.',
  );
  static String get myChildren =>
      _s('My Children', 'زما ماشومان', 'فرزندان من', 'أبنائي');
  static String get noChildrenTitle => _s(
    'No linked students',
    'تړلي زده کوونکي نشته',
    'شاگرد پیوندشده‌ای نیست',
    'لا يوجد طلاب مرتبطون',
  );
  static String get loadingChildren => _s(
    'Loading your children…',
    'ستاسو ماشومان راوړل کېږي…',
    'در حال دریافت فرزندان شما…',
    'جارٍ تحميل الأبناء…',
  );
  static String get errorHeading => _s(
    'Something went wrong',
    'ستونزه رامنځته شوه',
    'مشکلی رخ داد',
    'حدث خطأ',
  );
  static String get childDetailsTitle =>
      _s('Child details', 'د ماشوم معلومات', 'معلومات فرزند', 'تفاصيل الابن');
  static String get viewAttendance =>
      _s('View attendance', 'حاضري وګورئ', 'مشاهده حاضری', 'عرض الحضور');
  static String get chooseSummaryPeriod => _s(
    'Choose summary period',
    'د لنډیز موده وټاکئ',
    'دوره خلاصه را انتخاب کنید',
    'اختر فترة الملخص',
  );
  static String get noAttendanceTitle => _s(
    'No attendance yet',
    'حاضري لا نشته',
    'هنوز حاضری نیست',
    'لا يوجد حضور بعد',
  );
  static String get noChildren => _s(
    'No students are linked to your account. Contact your institution administrator.',
    'ستاسو له حساب سره زده کوونکی نه دی تړل شوی. له ادارې سره اړیکه ونیسئ.',
    'هیچ شاگردی به حساب شما پیوند نشده است. با اداره تماس بگیرید.',
    'لا يوجد طالب مرتبط بحسابك. تواصل مع الإدارة.',
  );
  static String get childAccessRevoked => _s(
    'Access to this student is no longer available. Return to My Children or contact the institution.',
    'دې زده کوونکي ته لاسرسی نور نشته. د ماشومانو پاڼې ته ستانه شئ یا له ادارې سره اړیکه ونیسئ.',
    'دسترسی به این شاگرد دیگر موجود نیست. به فرزندان من برگردید یا با اداره تماس بگیرید.',
    'لم يعد الوصول إلى هذا الطالب متاحًا. ارجع إلى أبنائي أو تواصل مع الإدارة.',
  );
  static String get noPlacement => _s(
    'No current class placement is available.',
    'اوسنی ټولګی نشته.',
    'صنف فعلی موجود نیست.',
    'لا يوجد صف حالي.',
  );
  static String get noAttendance => _s(
    'No attendance records are available.',
    'د حاضرۍ معلومات نشته.',
    'سوابق حاضری موجود نیست.',
    'لا توجد سجلات حضور.',
  );
  static String get previous => _s('Previous', 'مخکینی', 'قبلی', 'السابق');
  static String get next => _s('Next', 'بل', 'بعدی', 'التالي');
  static String get attendanceSummary =>
      _s('Attendance summary', 'د حاضرۍ لنډیز', 'خلاصه حاضری', 'ملخص الحضور');
  static String get present => _s('Present', 'حاضر', 'حاضر', 'حاضر');
  static String get absent => _s('Absent', 'غایب', 'غایب', 'غائب');
  static String get late => _s('Late', 'ناوخته', 'ناوقت', 'متأخر');
  static String get excused => _s('Excused', 'معذور', 'معذور', 'بعذر');
  static String get filterDates => _s(
    'Filter summary by dates',
    'لنډیز د نېټو له مخې وټاکئ',
    'خلاصه بر اساس تاریخ',
    'تصفية الملخص بالتاريخ',
  );
  static String get nextAttendancePage =>
      _s('More attendance', 'نور حاضري', 'حاضری بیشتر', 'المزيد من الحضور');
  static String get unrecordedNotAbsent => _s(
    'Unrecorded days are not counted as absent.',
    'نه ثبت شوې ورځې غیابت نه ګڼل کېږي.',
    'روزهای ثبت‌نشده غیابت حساب نمی‌شوند.',
    'الأيام غير المسجلة لا تُحسب غيابًا.',
  );
  static String get filteredSummary => _s(
    'Filtered totals',
    'ټاکل شوی لنډیز',
    'خلاصه انتخاب‌شده',
    'الملخص المحدد',
  );
  static String get noCapabilities => _s(
    'No supported access is assigned to this account. Contact the institution.',
    'دې حساب ته ملاتړ شوی لاسرسی نه دی ورکړل شوی. له ادارې سره اړیکه ونیسئ.',
    'دسترسی پشتیبانی‌شده‌ای به این حساب داده نشده است. با اداره تماس بگیرید.',
    'لا توجد صلاحية مدعومة لهذا الحساب. تواصل مع الإدارة.',
  );
  static String get logoutUnconfirmed => _s(
    'Server logout was not confirmed. Your session is kept so you can retry.',
    'له سرور څخه وتل تایید نه شول. ستاسو ناسته د بیا هڅې لپاره ساتل شوې.',
    'خروج از سرور تأیید نشد. نشست شما برای تلاش دوباره نگه‌داری شد.',
    'لم يؤكد الخادم تسجيل الخروج. حُفظت جلستك لإعادة المحاولة.',
  );
  static String get invalidSession => _s(
    'Your session is no longer valid. Please log in again.',
    'ستاسو ناسته نوره سمه نه ده. بیا ننوځئ.',
    'نشست شما دیگر معتبر نیست. دوباره وارد شوید.',
    'جلستك لم تعد صالحة. سجّل الدخول مرة أخرى.',
  );
  static String get language => _s('Language', 'ژبه', 'زبان', 'اللغة');
  static String get selectLanguage =>
      _s('Select language', 'ژبه وټاکئ', 'انتخاب زبان', 'اختر اللغة');

  static String roleLabel(String value) {
    final key = value.trim().toLowerCase().replaceAll('-', '_');
    return switch (key) {
      'guardian' || 'parent' => _s('Guardian', 'سرپرست', 'سرپرست', 'ولي الأمر'),
      'teacher' => _s('Teacher', 'ښوونکی', 'استاد', 'معلم'),
      'student' => _s('Student', 'زده کوونکی', 'شاگرد', 'طالب'),
      'administrator' ||
      'admin' ||
      'super_admin' => _s('Administrator', 'اداره کوونکی', 'مدیر', 'مسؤول'),
      _ => value.replaceAll('_', ' '),
    };
  }

  static List<String> get translationCoverage => [
    welcome,
    subtitle,
    loading,
    connected,
    empty,
    failed,
    retry,
    refresh,
    logo,
    logoFallback,
    login,
    loginHeading,
    loginSubtitle,
    logout,
    email,
    password,
    showPassword,
    hidePassword,
    requiredField,
    invalidEmail,
    passwordTooLong,
    back,
    checkingSession,
    signingOut,
    accountHeading,
    accountSubtitle,
    childrenTab,
    profileSection,
    institutionSection,
    name,
    academicInformation,
    attendanceHeading,
    summaryPeriod,
    allAvailableDates,
    editSummaryPeriod,
    attendanceHistoryAllDates,
    summaryUnavailable,
    myChildren,
    noChildrenTitle,
    loadingChildren,
    errorHeading,
    childDetailsTitle,
    viewAttendance,
    chooseSummaryPeriod,
    noAttendanceTitle,
    noChildren,
    childAccessRevoked,
    noPlacement,
    noAttendance,
    previous,
    next,
    attendanceSummary,
    present,
    absent,
    late,
    excused,
    filterDates,
    nextAttendancePage,
    unrecordedNotAbsent,
    filteredSummary,
    noCapabilities,
    logoutUnconfirmed,
    invalidSession,
    language,
    selectLanguage,
    roleLabel('guardian'),
    roleLabel('teacher'),
    ...placementLabels.values,
  ];

  static String studentNumber(String v) =>
      '${_s('Student number', 'د زده کوونکي شمېره', 'شماره شاگرد', 'رقم الطالب')}: $v';
  static String branchValue(String v) => '${placementLabels['branch']}: $v';
  static String academicYearValue(String v) =>
      '${placementLabels['academic_year']}: $v';
  static String recordedDays(int v) =>
      '${_s('Recorded days', 'ثبت شوې ورځې', 'روزهای ثبت‌شده', 'الأيام المسجلة')}: $v';
  static String greeting(String v) =>
      '${_s('Welcome', 'ښه راغلاست', 'خوش آمدید', 'مرحبًا')}، ${v.trim().split(' ').first}';
  static String roles(List<String> roles) => roles.isEmpty
      ? _s(
          'No roles assigned',
          'دنده نه ده ټاکل شوې',
          'نقشی تعیین نشده',
          'لا توجد أدوار',
        )
      : '${_s('Roles', 'دندې', 'نقش‌ها', 'الأدوار')}: ${roles.join(', ')}';
  static Map<String, String> get placementLabels => {
    'class': _s('Class', 'ټولګی', 'صنف', 'الصف'),
    'section': _s('Section', 'شعبه', 'بخش', 'الشعبة'),
    'program': _s('Program', 'پروګرام', 'برنامه', 'البرنامج'),
    'level': _s('Level', 'کچه', 'سطح', 'المستوى'),
    'academic_year': _s(
      'Academic year',
      'ښوونیز کال',
      'سال تعلیمی',
      'العام الدراسي',
    ),
    'branch': _s('Branch', 'څانګه', 'شعبه', 'الفرع'),
    'status': _s(
      'Enrollment status',
      'د نوم‌لیکنې حالت',
      'حالت ثبت‌نام',
      'حالة التسجيل',
    ),
    'enrolled_at': _s(
      'Enrolled on',
      'د نوم‌لیکنې نېټه',
      'تاریخ ثبت‌نام',
      'تاريخ التسجيل',
    ),
  };
  static String enrollmentStatus(String v) => switch (v.toLowerCase()) {
    'active' => _s('Active', 'فعال', 'فعال', 'نشط'),
    'completed' => _s('Completed', 'بشپړ شوی', 'تکمیل‌شده', 'مكتمل'),
    'cancelled' => _s('Cancelled', 'لغوه شوی', 'لغوشده', 'ملغى'),
    'withdrawn' => _s('Withdrawn', 'وتلی', 'منصرف‌شده', 'منسحب'),
    _ => v.replaceAll('_', ' '),
  };
  static String attendanceStatus(String v) => switch (v.toLowerCase()) {
    'present' => present,
    'absent' => absent,
    'late' => late,
    'excused' => excused,
    _ => v.replaceAll('_', ' '),
  };
  static String fieldError(String field) => field == 'email'
      ? _s(
          'Check the email address.',
          'برېښنالیک وګورئ.',
          'ایمیل را بررسی کنید.',
          'تحقق من البريد الإلكتروني.',
        )
      : field == 'password'
      ? _s(
          'Check the password.',
          'پټنوم وګورئ.',
          'رمز عبور را بررسی کنید.',
          'تحقق من كلمة المرور.',
        )
      : _s(
          'The server rejected a login field.',
          'سرور د ننوتلو یو ځای ونه مانه.',
          'سرور یکی از بخش‌های ورود را نپذیرفت.',
          'رفض الخادم أحد حقول الدخول.',
        );

  static String error(Object? error) {
    if (error is SessionStorageException) {
      return _s(
        'Secure storage is unavailable. Unlock your device and retry.',
        'خوندي زېرمه نشته. وسیله خلاصه او بیا هڅه وکړئ.',
        'ذخیره امن در دسترس نیست. دستگاه را باز کرده و دوباره تلاش کنید.',
        'التخزين الآمن غير متاح. افتح جهازك وحاول مجددًا.',
      );
    }
    if (error is! ApiException) {
      return _s(
        'Something went wrong. Please try again.',
        'ستونزه رامنځته شوه. بیا هڅه وکړئ.',
        'مشکلی رخ داد. دوباره تلاش کنید.',
        'حدث خطأ. حاول مرة أخرى.',
      );
    }
    return switch (error.failure) {
      ApiFailure.invalidCredentials => _s(
        'The email or password is incorrect, or the account is inactive.',
        'برېښنالیک یا پټنوم ناسم دی، یا حساب غیر فعال دی.',
        'ایمیل یا رمز عبور نادرست است، یا حساب غیرفعال است.',
        'البريد الإلكتروني أو كلمة المرور غير صحيحة، أو الحساب غير نشط.',
      ),
      ApiFailure.validation => _s(
        'The server could not validate the submitted fields.',
        'سرور لېږل شوي معلومات ونه منل.',
        'سرور معلومات ارسال‌شده را نپذیرفت.',
        'تعذر على الخادم التحقق من الحقول.',
      ),
      ApiFailure.unauthorized => invalidSession,
      ApiFailure.forbidden => _s(
        'This account cannot access this resource. Your session was kept.',
        'دا حساب دې برخې ته لاسرسی نه لري. ناسته ساتل شوې.',
        'این حساب اجازه دسترسی به این بخش را ندارد. نشست حفظ شد.',
        'هذا الحساب غير مسموح له بالوصول. حُفظت الجلسة.',
      ),
      ApiFailure.rateLimited => _s(
        'Too many attempts. Wait a minute, then try again.',
        'ډېرې هڅې وشوې. یوه دقیقه وروسته بیا هڅه وکړئ.',
        'تلاش‌های زیاد. یک دقیقه بعد دوباره تلاش کنید.',
        'محاولات كثيرة. انتظر دقيقة ثم حاول مجددًا.',
      ),
      ApiFailure.redirect => _s(
        'The API returned a redirect. Check the API URL.',
        'API بل ادرس ته ولېږه. د API ادرس وګورئ.',
        'API به نشانی دیگری فرستاد. نشانی API را بررسی کنید.',
        'أعادت API توجيه الطلب. تحقق من عنوان API.',
      ),
      ApiFailure.configuration => 'API_BASE_URL: HTTPS … /api/v1',
      ApiFailure.network => _s(
        'Check your internet connection and try again.',
        'انټرنېټ وګورئ او بیا هڅه وکړئ.',
        'اتصال اینترنت را بررسی کرده و دوباره تلاش کنید.',
        'تحقق من اتصال الإنترنت وحاول مجددًا.',
      ),
      ApiFailure.timeout => _s(
        'The server took too long to respond. Try again.',
        'سرور ډېر وخت ونیو. بیا هڅه وکړئ.',
        'پاسخ سرور طول کشید. دوباره تلاش کنید.',
        'استغرق الخادم وقتًا طويلًا. حاول مجددًا.',
      ),
      ApiFailure.http =>
        '${_s('Server error', 'د سرور تېروتنه', 'خطای سرور', 'خطأ من الخادم')}: HTTP ${error.statusCode}.',
      ApiFailure.contentType =>
        '${_s('The server did not return JSON', 'سرور JSON معلومات ورنه کړل', 'سرور JSON برنگرداند', 'لم يُرجع الخادم JSON')} (${error.statusCode}).',
      ApiFailure.contract => _s(
        'The response does not match the mobile API v1 contract.',
        'ځواب د موبایل API v1 له جوړښت سره سمون نه لري.',
        'پاسخ با قرارداد API موبایل v1 سازگار نیست.',
        'الاستجابة لا تطابق عقد API المحمول v1.',
      ),
    };
  }
}
