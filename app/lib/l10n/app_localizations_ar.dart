// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'سند';

  @override
  String get appTagline => 'سجلات الرعاية بكل سهولة';

  @override
  String get commonSave => 'حفظ';

  @override
  String get commonCancel => 'إلغاء';

  @override
  String get commonRetry => 'حاول مرة أخرى';

  @override
  String get commonEdit => 'تعديل';

  @override
  String get commonClose => 'إغلاق';

  @override
  String get commonConfirm => 'تأكيد';

  @override
  String get commonSearch => 'بحث';

  @override
  String get commonAdd => 'إضافة';

  @override
  String get commonClear => 'مسح';

  @override
  String get commonApply => 'تطبيق';

  @override
  String get commonAll => 'الكل';

  @override
  String get commonOptional => 'اختياري';

  @override
  String get commonActive => 'نشط';

  @override
  String get commonInactive => 'غير نشط';

  @override
  String get commonDeactivate => 'إيقاف';

  @override
  String get commonActivate => 'تفعيل';

  @override
  String get commonNotSet => 'غير محدد';

  @override
  String get commonUnspecified => 'غير محدد';

  @override
  String get commonLoadMore => 'عرض المزيد';

  @override
  String get commonBack => 'رجوع';

  @override
  String get commonDone => 'تم';

  @override
  String get commonContinue => 'متابعة';

  @override
  String get commonYes => 'نعم';

  @override
  String get commonNo => 'لا';

  @override
  String get commonCopied => 'تم النسخ';

  @override
  String get commonToday => 'اليوم';

  @override
  String get commonYesterday => 'أمس';

  @override
  String currencyAmount(String amount) {
    return '$amount ج.م';
  }

  @override
  String get egp => 'ج.م';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navCustomers => 'العملاء';

  @override
  String get navRecords => 'السجلات';

  @override
  String get navMore => 'المزيد';

  @override
  String get greetingMorning => 'صباح الخير';

  @override
  String get greetingEvening => 'مساء الخير';

  @override
  String get dashboardSearchHint => 'ابحث عن عميل برقم التليفون';

  @override
  String get quickActions => 'إجراءات سريعة';

  @override
  String get actionAddCustomer => 'إضافة عميل';

  @override
  String get actionSearchCustomer => 'بحث عن عميل';

  @override
  String get actionAddRecord => 'إضافة سجل خدمة';

  @override
  String get actionExport => 'تصدير إلى Excel';

  @override
  String get todayOverview => 'ملخص اليوم';

  @override
  String get statTodayServices => 'خدمات اليوم';

  @override
  String get statTodayRevenue => 'إيراد اليوم';

  @override
  String get statCash => 'نقدي';

  @override
  String get statElectronic => 'إلكتروني';

  @override
  String get statTotalCustomers => 'العملاء';

  @override
  String get statTotalRecords => 'سجلات الخدمة';

  @override
  String get statActiveNurses => 'ممرضون نشطون';

  @override
  String get statActiveServices => 'خدمات نشطة';

  @override
  String get statMonthRevenue => 'هذا الشهر';

  @override
  String get businessOverview => 'نظرة عامة';

  @override
  String needsReviewBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عميل مستورد يحتاجون مراجعة',
      few: '$count عملاء مستوردين يحتاجون مراجعة',
      two: 'عميلان مستوردان يحتاجان مراجعة',
      one: 'عميل مستورد يحتاج مراجعة',
    );
    return '$_temp0';
  }

  @override
  String get customersTitle => 'العملاء';

  @override
  String get customersSearchHint => 'رقم التليفون أو الاسم';

  @override
  String get customersNeedsReview => 'تحتاج مراجعة';

  @override
  String get customersEmptyTitle => 'لا يوجد عملاء بعد';

  @override
  String get customersEmptyBody => 'أضف أول عميل أو استورد بيانات Excel الحالية.';

  @override
  String get searchTitle => 'بحث عن عميل';

  @override
  String get searchForRecordTitle => 'اختر العميل';

  @override
  String get searchHint => 'أدخل رقم التليفون';

  @override
  String get searchByNameHint => 'رقم التليفون أو اسم العميل';

  @override
  String get searchTypeMore => 'اكتب 3 أرقام على الأقل من رقم التليفون، أو الاسم.';

  @override
  String get searchNotFoundTitle => 'العميل غير موجود';

  @override
  String searchNotFoundBody(String query) {
    return 'لا يوجد عميل يطابق “$query”.';
  }

  @override
  String get searchAddNew => 'إضافة عميل جديد';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $count عميل',
      few: 'تم العثور على $count عملاء',
      two: 'تم العثور على عميلين',
      one: 'تم العثور على عميل واحد',
    );
    return '$_temp0';
  }

  @override
  String get searchSelectHint => 'تأكد من الاسم ورقم التليفون ثم اضغط للمتابعة.';

  @override
  String customerVisits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count زيارة',
      few: '$count زيارات',
      two: 'زيارتان',
      one: 'زيارة واحدة',
      zero: 'لا زيارات',
    );
    return '$_temp0';
  }

  @override
  String customerLastVisit(String date) {
    return 'آخر زيارة $date';
  }

  @override
  String get customerArchived => 'مؤرشف';

  @override
  String get customerNoPhone => 'بدون رقم تليفون';

  @override
  String get addCustomerTitle => 'إضافة عميل';

  @override
  String get editCustomerTitle => 'تعديل بيانات العميل';

  @override
  String get fieldFullName => 'الاسم بالكامل';

  @override
  String get fieldPhone => 'رقم التليفون';

  @override
  String get fieldPhoneHelper => 'رقم مصري، مثل 01012345678';

  @override
  String get fieldAddress => 'العنوان';

  @override
  String get fieldArea => 'المنطقة';

  @override
  String get fieldAreaHint => 'اختر المنطقة';

  @override
  String get fieldNotes => 'ملاحظات';

  @override
  String get saveCustomer => 'حفظ العميل';

  @override
  String get customerExistsTitle => 'رقم التليفون مسجل بالفعل';

  @override
  String get customerExistsBody => 'هذا الرقم مسجل لعميل موجود. استخدم هذا العميل بدلًا من إنشاء عميل مكرر.';

  @override
  String get customerExistsArchived => 'هذا العميل مؤرشف. يمكن للمسؤول استعادته.';

  @override
  String get viewCustomer => 'عرض العميل';

  @override
  String get customerSavedTitle => 'تم حفظ العميل';

  @override
  String customerSavedBody(String name) {
    return 'تمت إضافة $name إلى سند.';
  }

  @override
  String get backToHome => 'العودة للرئيسية';

  @override
  String get customerUpdated => 'تم تحديث بيانات العميل.';

  @override
  String get profileTitle => 'ملف العميل';

  @override
  String get profileInfo => 'بيانات العميل';

  @override
  String get profileHistory => 'سجل الخدمات';

  @override
  String get profileTotalSpent => 'إجمالي المدفوع';

  @override
  String get profileVisits => 'الزيارات';

  @override
  String get profileLastVisit => 'آخر زيارة';

  @override
  String get profileAddRecord => 'إضافة سجل جديد';

  @override
  String get profileNoHistoryTitle => 'لا توجد سجلات خدمة بعد';

  @override
  String get profileNoHistoryBody => 'ستظهر هنا السجلات التي تضيفها لهذا العميل.';

  @override
  String get profileNeedsReview => 'تم استيراده بدون رقم تليفون صحيح. عدّل بيانات العميل لإضافته.';

  @override
  String get archiveCustomer => 'أرشفة العميل';

  @override
  String get restoreCustomer => 'استعادة العميل';

  @override
  String archiveCustomerConfirm(String name) {
    return 'أرشفة $name؟ سيتم الاحتفاظ بالسجل لكن لن يظهر في البحث.';
  }

  @override
  String get customerArchivedDone => 'تمت أرشفة العميل.';

  @override
  String get customerRestoredDone => 'تمت استعادة العميل.';

  @override
  String get copyPhone => 'نسخ رقم التليفون';

  @override
  String get areaPickerTitle => 'اختر المنطقة';

  @override
  String get areaPickerSearch => 'ابحث في المناطق';

  @override
  String get areaAddNew => 'إضافة منطقة جديدة';

  @override
  String areaAddNamed(String name) {
    return 'إضافة “$name”';
  }

  @override
  String get areaNewTitle => 'منطقة جديدة';

  @override
  String get areaName => 'اسم المنطقة';

  @override
  String areaCreated(String name) {
    return 'تمت إضافة منطقة “$name”.';
  }

  @override
  String areaExisting(String name) {
    return '“$name” موجودة بالفعل وتم اختيارها.';
  }

  @override
  String get recordsTitle => 'السجلات';

  @override
  String get recordsSearchHint => 'اسم العميل أو التليفون';

  @override
  String get recordsFilters => 'التصفية';

  @override
  String get recordsSort => 'الترتيب';

  @override
  String get sortNewest => 'الأحدث أولًا';

  @override
  String get sortOldest => 'الأقدم أولًا';

  @override
  String get sortPriceHigh => 'الأعلى سعرًا';

  @override
  String get sortPriceLow => 'الأقل سعرًا';

  @override
  String recordsTotals(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجل',
      few: '$count سجلات',
      two: 'سجلان',
      one: 'سجل واحد',
    );
    return '$_temp0 · $amount';
  }

  @override
  String get recordsEmptyTitle => 'لا توجد سجلات';

  @override
  String get recordsEmptyBody => 'جرّب تغيير التصفية أو البحث.';

  @override
  String get recordsNoneYetBody => 'ستظهر سجلات الخدمة هنا بعد إضافتها.';

  @override
  String get filterDate => 'التاريخ';

  @override
  String get filterAnyDate => 'أي تاريخ';

  @override
  String get filterThisWeek => 'هذا الأسبوع';

  @override
  String get filterThisMonth => 'هذا الشهر';

  @override
  String get filterLastMonth => 'الشهر الماضي';

  @override
  String get filterCustomRange => 'فترة مخصصة';

  @override
  String get filterNurse => 'الممرض';

  @override
  String get filterService => 'الخدمة';

  @override
  String get filterArea => 'المنطقة';

  @override
  String get filterPayment => 'طريقة الدفع';

  @override
  String get filterAny => 'الكل';

  @override
  String get filterClearAll => 'مسح الكل';

  @override
  String get filterShowResults => 'عرض النتائج';

  @override
  String get addRecordTitle => 'سجل خدمة جديد';

  @override
  String get editRecordTitle => 'تعديل السجل';

  @override
  String get recordFor => 'سجل لـ';

  @override
  String get fieldNurse => 'الممرض';

  @override
  String get fieldNurseHint => 'اختر الممرض';

  @override
  String get fieldService => 'الخدمة';

  @override
  String get fieldServiceHint => 'اختر الخدمة';

  @override
  String get fieldPrice => 'السعر';

  @override
  String get fieldPriceHelper => 'المبلغ المدفوع فعليًا لهذه الزيارة';

  @override
  String fieldPriceDefault(String amount) {
    return 'السعر الافتراضي: $amount';
  }

  @override
  String get fieldPaymentMethod => 'طريقة الدفع';

  @override
  String get paymentCash => 'نقدي';

  @override
  String get paymentElectronic => 'إلكتروني';

  @override
  String get paymentUnspecified => 'غير مسجل';

  @override
  String get fieldDate => 'التاريخ';

  @override
  String get fieldTime => 'الوقت';

  @override
  String get fieldPatientName => 'اسم المريض';

  @override
  String get fieldPatientHelper => 'فقط إذا كانت الخدمة لشخص آخر (مثل أحد أفراد الأسرة)';

  @override
  String get saveRecord => 'حفظ السجل';

  @override
  String get recordSaved => 'تم حفظ السجل.';

  @override
  String get recordUpdated => 'تم تحديث السجل.';

  @override
  String get draftRestored => 'تمت استعادة البيانات غير المحفوظة.';

  @override
  String get discardDraft => 'تجاهل';

  @override
  String get recordDetailsTitle => 'تفاصيل السجل';

  @override
  String get recordCustomer => 'العميل';

  @override
  String get recordService => 'الخدمة';

  @override
  String get recordPayment => 'الدفع';

  @override
  String get recordWhen => 'التاريخ والوقت';

  @override
  String get recordAddressAtVisit => 'العنوان وقت الزيارة';

  @override
  String get recordAreaAtVisit => 'المنطقة وقت الزيارة';

  @override
  String get recordPatient => 'المريض';

  @override
  String get recordCreatedAt => 'تاريخ الإنشاء';

  @override
  String get recordLegacyRef => 'رقم الصف في Excel';

  @override
  String get recordImported => 'مستورد من Excel';

  @override
  String get recordNoTime => 'الوقت غير مسجل';

  @override
  String get archiveRecord => 'أرشفة السجل';

  @override
  String get archiveRecordConfirm => 'أرشفة هذا السجل؟ سيتم إخفاؤه من السجل والإجماليات مع الاحتفاظ به للمراجعة.';

  @override
  String get recordArchived => 'تمت أرشفة السجل.';

  @override
  String get openCustomer => 'فتح ملف العميل';

  @override
  String nurseLabel(String name) {
    return 'الممرض: $name';
  }

  @override
  String get nursesTitle => 'الممرضون';

  @override
  String get nursesEmpty => 'لا يوجد ممرضون بعد. أضف الممرضين الذين يقدمون الخدمات.';

  @override
  String get addNurse => 'إضافة ممرض';

  @override
  String get editNurse => 'تعديل بيانات الممرض';

  @override
  String get nurseName => 'الاسم';

  @override
  String get nurseSaved => 'تم حفظ الممرض.';

  @override
  String get servicesTitle => 'الخدمات';

  @override
  String get servicesEmpty => 'لا توجد خدمات بعد. أضف الخدمات التي تقدمها.';

  @override
  String get addService => 'إضافة خدمة';

  @override
  String get editService => 'تعديل الخدمة';

  @override
  String get serviceName => 'اسم الخدمة';

  @override
  String get serviceDefaultPrice => 'السعر الافتراضي';

  @override
  String get serviceDefaultPriceHelper => 'اتركه فارغًا إذا كان السعر متغيرًا. تغييره لا يؤثر على السجلات السابقة.';

  @override
  String get serviceVariablePrice => 'سعر متغير';

  @override
  String get serviceSaved => 'تم حفظ الخدمة.';

  @override
  String get areasTitle => 'المناطق';

  @override
  String get areasEmpty => 'لا توجد مناطق بعد.';

  @override
  String get addArea => 'إضافة منطقة';

  @override
  String get editArea => 'تعديل المنطقة';

  @override
  String get areaSaved => 'تم حفظ المنطقة.';

  @override
  String get showInactive => 'إظهار غير النشط';

  @override
  String get statusActiveHelper => 'العناصر غير النشطة تبقى في السجل لكن لا يمكن اختيارها للسجلات الجديدة.';

  @override
  String deactivateConfirm(String name) {
    return 'إيقاف “$name”؟ سيبقى في السجلات السابقة لكن لن يمكن اختياره.';
  }

  @override
  String get pickerNoResults => 'لا توجد نتائج';

  @override
  String pickerAddNamed(String name) {
    return 'إضافة “$name”';
  }

  @override
  String get pickerSearch => 'بحث';

  @override
  String get moreTitle => 'المزيد';

  @override
  String get moreManage => 'الإدارة';

  @override
  String get moreData => 'البيانات';

  @override
  String get importTitle => 'استيراد من Excel';

  @override
  String get exportTitle => 'تصدير إلى Excel';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get languageSystem => 'لغة الجهاز';

  @override
  String get settingsAbout => 'عن سند';

  @override
  String settingsVersion(String version) {
    return 'الإصدار $version';
  }

  @override
  String get settingsPrivacy =>
      'تُخزَّن بياناتك على هذا الهاتف. إذا ربطت جدول Google، يكتب سند البيانات في هذا الجدول على Google Drive الخاص بك، ولا يراها أحد غيرك إلا إذا شاركت الجدول.';

  @override
  String get importIntro =>
      'انقل السجلات الموجودة من ملف Excel إلى سند. لن يتم حفظ أي شيء قبل مراجعة المعاينة والتأكيد.';

  @override
  String get importChooseFile => 'اختر ملف Excel';

  @override
  String get importReading => 'جارٍ قراءة الملف…';

  @override
  String get importStepFile => 'الملف';

  @override
  String get importStepColumns => 'الأعمدة';

  @override
  String get importStepPreview => 'المعاينة';

  @override
  String get importSheet => 'الورقة';

  @override
  String get importColumnsTitle => 'راجع ربط الأعمدة';

  @override
  String get importColumnsBody => 'قام سند بربط هذه الأعمدة تلقائيًا. صحّح أي ربط خاطئ قبل المتابعة.';

  @override
  String get importNotMapped => 'غير موجود';

  @override
  String importHeaderRow(int row) {
    return 'تم العثور على العناوين في الصف $row';
  }

  @override
  String get importBuildPreview => 'إنشاء المعاينة';

  @override
  String importMissingRequired(String fields) {
    return 'اربط الأعمدة المطلوبة: $fields';
  }

  @override
  String get importPreviewTitle => 'راجع قبل الاستيراد';

  @override
  String get importRecords => 'سجلات سيتم استيرادها';

  @override
  String get importSkipped => 'صفوف سيتم تخطيها';

  @override
  String get importNewCustomers => 'عملاء جدد';

  @override
  String get importMatchedCustomers => 'عملاء موجودون';

  @override
  String get importNewAreas => 'مناطق جديدة';

  @override
  String get importNewNurses => 'ممرضون جدد';

  @override
  String get importNewServices => 'خدمات جديدة';

  @override
  String get importRevenue => 'إجمالي المبالغ';

  @override
  String get importDateRange => 'الفترة';

  @override
  String importNoPayment(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجل بدون طريقة دفع في الملف وسيتم تمييزها بـ “غير مسجل”.',
      one: 'سجل واحد بدون طريقة دفع في الملف وسيتم تمييزه بـ “غير مسجل”.',
    );
    return '$_temp0';
  }

  @override
  String importReviewCustomers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عميل بدون رقم تليفون صحيح وسيتم تمييزهم للمراجعة.',
      one: 'عميل واحد بدون رقم تليفون صحيح وسيتم تمييزه للمراجعة.',
    );
    return '$_temp0';
  }

  @override
  String get importAlreadyImported =>
      'تم استيراد بيانات من قبل. إذا كان هذا الملف نسخة مصححة من نفس الملف، تراجع عن الاستيراد السابق أولًا لتجنب التكرار.';

  @override
  String get importWarnings => 'تنبيهات (سيتم استيراد الصفوف)';

  @override
  String get importErrors => 'مشكلات (سيتم تخطي الصفوف)';

  @override
  String get importEntities => 'الأسماء الموجودة في الملف';

  @override
  String get importNew => 'جديد';

  @override
  String importRowsLabel(String rows) {
    return 'الصفوف: $rows';
  }

  @override
  String importConfirm(int count) {
    return 'استيراد $count سجل';
  }

  @override
  String get importConfirmTitle => 'بدء الاستيراد؟';

  @override
  String get importConfirmBody =>
      'يتم الاستيراد كعملية واحدة: إما أن يُحفظ كل شيء أو لا شيء. يمكنك التراجع عنه لاحقًا من سجل الاستيراد.';

  @override
  String get importRunning => 'جارٍ الاستيراد…';

  @override
  String get importDoneTitle => 'اكتمل الاستيراد';

  @override
  String importDoneBody(int records, int customers, int matched) {
    return 'تم استيراد $records سجل، وإنشاء $customers عميل جديد، ومطابقة $matched عميل موجود.';
  }

  @override
  String get importHistory => 'سجل الاستيراد';

  @override
  String get importHistoryEmpty => 'لا توجد عمليات استيراد بعد.';

  @override
  String get importRolledBack => 'تم التراجع';

  @override
  String get importRollback => 'تراجع';

  @override
  String importRollbackConfirm(String file) {
    return 'التراجع عن “$file”؟ سيتم حذف السجلات التي أنشأها هذا الاستيراد. العملاء أو الأسماء التي استُخدمت بعده ستبقى.';
  }

  @override
  String get importRollbackDone => 'تم التراجع عن الاستيراد.';

  @override
  String importBatchSummary(int count, String date) {
    return '$count سجل · $date';
  }

  @override
  String get importStartOver => 'اختيار ملف آخر';

  @override
  String get importUnspecifiedName => 'غير محدد';

  @override
  String importShowRows(String rows) {
    return 'الصفوف $rows';
  }

  @override
  String get importField_legacyRef => 'رقم السجل';

  @override
  String get importField_serviceDate => 'تاريخ الخدمة';

  @override
  String get importField_serviceTime => 'وقت الخدمة';

  @override
  String get importField_customerName => 'اسم العميل';

  @override
  String get importField_phone => 'التليفون';

  @override
  String get importField_address => 'العنوان';

  @override
  String get importField_area => 'المنطقة';

  @override
  String get importField_nurse => 'الممرض';

  @override
  String get importField_service => 'الخدمة';

  @override
  String get importField_price => 'السعر';

  @override
  String get importField_paymentMethod => 'طريقة الدفع';

  @override
  String get importField_patientName => 'المريض (إن اختلف)';

  @override
  String get importField_notes => 'ملاحظات';

  @override
  String get importField_status => 'الحالة (للمرجع فقط)';

  @override
  String get importIssue_datemissing => 'التاريخ غير موجود';

  @override
  String get importIssue_dateinvalid => 'تاريخ غير مقروء';

  @override
  String get importIssue_pricemissing => 'السعر غير موجود';

  @override
  String get importIssue_priceinvalid => 'سعر غير مقروء';

  @override
  String get importIssue_customermissing => 'لا يوجد اسم أو تليفون للعميل';

  @override
  String get importIssue_dateambiguous => 'تم افتراض ترتيب اليوم ثم الشهر';

  @override
  String get importIssue_timemissing => 'لا يوجد وقت — تم الاستيراد بدون وقت';

  @override
  String get importIssue_timeinvalid => 'وقت غير مقروء — تم الاستيراد بدون وقت';

  @override
  String get importIssue_timeambiguous => 'غير معروف صباحًا أم مساءً — تم الاستيراد بدون وقت';

  @override
  String get importIssue_phoneinvalid => 'رقم غير صحيح أو غير موجود — تم تمييز العميل للمراجعة';

  @override
  String get importIssue_phoneshared => 'نفس الرقم باسم مختلف — تم حفظه كاسم المريض';

  @override
  String get importIssue_nursemissing => 'لا يوجد ممرض — تم تعيينه “غير محدد”';

  @override
  String get importIssue_servicemissing => 'لا توجد خدمة — تم تعيينها “غير محدد”';

  @override
  String get importIssue_areamissing => 'لا توجد منطقة — تم تعيينها “غير محدد”';

  @override
  String get importIssue_pricecleaned => 'السعر مكتوب كنص — تم استخراج الرقم';

  @override
  String get importIssue_paymentunknown => 'طريقة دفع غير معروفة';

  @override
  String get importIssue_customerdetailschanged => 'العنوان/المنطقة يختلف عن زيارات أخرى — تم حفظه في هذا السجل';

  @override
  String get exportIntro => 'أنشئ ملف Excel منسقًا للإدارة أو المحاسبة أو النسخ الاحتياطي.';

  @override
  String get exportPeriod => 'فترة السجلات';

  @override
  String get exportAllTime => 'كل الفترات';

  @override
  String get exportSheets => 'الأوراق المطلوبة';

  @override
  String get exportSheetRecords => 'السجلات (مع بيانات العميل)';

  @override
  String get exportSheetCustomers => 'العملاء';

  @override
  String get exportSheetNurses => 'الممرضون';

  @override
  String get exportSheetServices => 'الخدمات';

  @override
  String get exportSheetAreas => 'المناطق';

  @override
  String get exportCreate => 'إنشاء ملف Excel';

  @override
  String get exportWorking => 'جارٍ تجهيز الملف…';

  @override
  String get exportReady => 'الملف جاهز';

  @override
  String exportReadyBody(int count, String file) {
    return 'تم تصدير $count سجل إلى $file.';
  }

  @override
  String get exportShare => 'مشاركة / حفظ الملف';

  @override
  String get exportSheetTotal => 'الإجمالي';

  @override
  String get exportRecordId => 'رقم السجل';

  @override
  String get validationRequired => 'هذا الحقل مطلوب.';

  @override
  String get validationTooLong => 'النص طويل جدًا.';

  @override
  String get validationInvalidPhone => 'أدخل رقم تليفون مصري صحيح، مثل 01012345678.';

  @override
  String get validationInvalidPrice => 'أدخل مبلغًا صحيحًا.';

  @override
  String get validationNegativePrice => 'لا يمكن أن يكون السعر بالسالب.';

  @override
  String get validationPriceTooHigh => 'هذا المبلغ كبير جدًا.';

  @override
  String get validationFutureDate => 'لا يمكن أن يكون التاريخ في المستقبل.';

  @override
  String get failureNetwork =>
      'لا يوجد اتصال بالإنترنت. بياناتك محفوظة على الهاتف، وسيتم تحديث الجدول عند عودة الاتصال.';

  @override
  String get failureDuplicatePhone => 'رقم التليفون مسجل بالفعل.';

  @override
  String get failureDuplicateName => 'هذا الاسم موجود بالفعل.';

  @override
  String get failureDuplicateFile => 'تم استيراد هذا الملف من قبل.';

  @override
  String get failureDuplicate => 'هذه القيمة موجودة بالفعل.';

  @override
  String get failureValidation => 'برجاء مراجعة الحقول المحددة.';

  @override
  String get failureNotFound => 'هذا العنصر لم يعد موجودًا.';

  @override
  String get failureUnexpected => 'حدث خطأ ما. حاول مرة أخرى.';

  @override
  String get failureFileUnreadable => 'تعذرت قراءة الملف. تأكد أنه ملف Excel بصيغة ‎.xlsx‎.';

  @override
  String get failureFileNoSheets => 'الملف لا يحتوي على أوراق.';

  @override
  String get failureFileHeaderNotFound =>
      'لم يتم العثور على ورقة بأعمدة معروفة (التاريخ، اسم العميل أو التليفون، السعر).';

  @override
  String get failureFileEmpty => 'لا يوجد ما يمكن استيراده أو تصديره.';

  @override
  String get failureFileWrite => 'تعذر إنشاء ملف Excel.';

  @override
  String get failureRuleNurseInactive => 'هذا الممرض لم يعد نشطًا. اختر ممرضًا آخر.';

  @override
  String get failureRuleServiceInactive => 'هذه الخدمة لم تعد نشطة. اختر خدمة أخرى.';

  @override
  String get failureRuleCustomerArchived => 'هذا العميل مؤرشف.';

  @override
  String get failureRuleAlreadyImported => 'تم استيراد هذا الملف من قبل.';

  @override
  String get failureRuleBatchNotFound => 'تم التراجع عن هذا الاستيراد بالفعل.';

  @override
  String get failureRuleInUse => 'هذا العنصر مستخدم ولا يمكن حذفه.';

  @override
  String get moreApp => 'التطبيق';

  @override
  String get failureServer => 'حدث خطأ في Google Drive. حاول مرة أخرى.';

  @override
  String get sheetTitle => 'جدول Google';

  @override
  String get sheetIntro =>
      'احتفظ بكل بياناتك في جدول Google الخاص بك على Google Drive. يحمّل سند كل البيانات من الجدول مرة واحدة، ثم يكتب فيه كل زيارة أو عميل أو ممرض أو خدمة أو منطقة جديدة أو معدّلة بعد ثوانٍ. تبقى أوراقك ومعادلاتك الأخرى (الداشبورد، الملخص الشهري، المصروفات) تعمل كما هي. مجاني، ولا يحتاج تسجيل دخول Google داخل التطبيق.';

  @override
  String get sheetSetupTitle => 'إعداد الجدول (مرة واحدة، حوالي 5 دقائق، على الكمبيوتر)';

  @override
  String get sheetStep1 =>
      'ارفع ملف Excel إلى Google Drive وافتحه بـ Google Sheets، ثم ملف ← حفظ كجداول بيانات Google. (أو أنشئ جدول Google جديداً فارغاً.)';

  @override
  String get sheetStep2 =>
      'في الجدول: الإضافات ← Apps Script. احذف الموجود، والصق نص سند البرمجي (زر النسخ بالأسفل، أو الملف tools/google-sheets/Code.gs في المشروع)، ثم اضغط حفظ.';

  @override
  String get sheetStep3 =>
      'نشر (Deploy) ← نشر جديد ← Web app. التنفيذ باسم: أنا (Me). من يمكنه الوصول: أي شخص (Anyone). انشر، ثم Authorize access ← حسابك ← Advanced ← Go to … (إنه نصك البرمجي) ← Allow.';

  @override
  String get sheetStep4 => 'انسخ رابط الـ Web app والصقه بالأسفل. احتفظ به سراً: فهو يعمل ككلمة مرور.';

  @override
  String get sheetCopyScript => 'نسخ نص سند البرمجي';

  @override
  String get sheetScriptCopied => 'تم نسخ النص البرمجي';

  @override
  String get sheetLinkLabel => 'رابط الـ Web app';

  @override
  String get sheetCodeNeeded => 'هذا الجدول مربوط بهاتف آخر. افتح في الجدول قائمة سند ← رمز الربط، واكتب الرمز هنا.';

  @override
  String get sheetCodeLabel => 'رمز الربط';

  @override
  String get sheetConnect => 'ربط';

  @override
  String get sheetFound => 'وجد سند هذه البيانات في الجدول:';

  @override
  String get sheetLoad => 'تحميل بيانات الجدول';

  @override
  String get sheetPhoneHasData => 'يوجد بيانات على هذا الهاتف بالفعل. اختر أي البيانات تحتفظ بها.';

  @override
  String get sheetUseSheetData => 'استخدام بيانات الجدول';

  @override
  String get sheetKeepPhoneData => 'الاحتفاظ ببيانات الهاتف وإضافتها إلى الجدول';

  @override
  String get sheetReplaceConfirm =>
      'سيتم استبدال البيانات على هذا الهاتف (العملاء، السجلات، الممرضون، الخدمات، المناطق) ببيانات الجدول. لن يتغير الجدول.';

  @override
  String get sheetKeepConfirm =>
      'سيُكتب كل ما على هذا الهاتف في الجدول بجانب الموجود فيه. اختر هذا فقط إذا لم تكن بيانات الهاتف موجودة في الجدول، وإلا ستظهر الزيارات مرتين.';

  @override
  String get sheetLoaded => 'تم تحميل البيانات من جدول Google';

  @override
  String get sheetUpToDate => 'الجدول محدّث';

  @override
  String sheetWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تغيير في انتظار الكتابة',
      few: '$count تغييرات في انتظار الكتابة',
      two: 'تغييران في انتظار الكتابة',
      one: 'تغيير واحد في انتظار الكتابة',
    );
    return '$_temp0';
  }

  @override
  String get sheetUpdating => 'جارٍ تحديث الجدول…';

  @override
  String get sheetReading => 'جارٍ قراءة الجدول…';

  @override
  String get sheetNotUpdated => 'تعذّر تحديث الجدول';

  @override
  String get sheetName => 'الجدول';

  @override
  String get sheetLastUpdate => 'آخر تحديث';

  @override
  String get sheetNever => 'لم يتم بعد';

  @override
  String get sheetWritesTo => 'يكتب في';

  @override
  String get sheetUpdateNow => 'تحديث الآن';

  @override
  String get sheetReload => 'تحميل كل البيانات من الجدول مرة أخرى';

  @override
  String get sheetDisconnect => 'فصل الجدول';

  @override
  String get sheetDisconnectConfirm =>
      'سيتوقف سند عن الكتابة في هذا الجدول. يبقى الجدول والبيانات على هذا الهاتف كما هي.';

  @override
  String get sheetOneWay =>
      'سند يكتب في الجدول، ولا يقرأ التعديلات التي تتم مباشرة في الجدول. بعد التعديل يدوياً في الجدول، استخدم \"تحميل كل البيانات من الجدول مرة أخرى\" لنقل هذه التعديلات إلى الهاتف.';

  @override
  String get sheetBannerConnect => 'احتفظ ببياناتك في جدول Google الخاص بك';

  @override
  String get sheetBannerFailed => 'تعذّر تحديث جدول Google';

  @override
  String get sheetBannerAction => 'فتح';

  @override
  String get importField_sanadId => 'معرف سند (يُحتفظ به)';

  @override
  String get failureSheetInvalidLink =>
      'هذا ليس رابط Web app لسند. انسخ الرابط الذي يظهر بعد نشر ← نشر جديد (يبدأ بـ https://script.google.com/macros/ وينتهي بـ /exec).';

  @override
  String get failureSheetDevLink =>
      'هذا رابط تجريبي (ينتهي بـ /dev). استخدم نشر ← نشر جديد وانسخ رابط الـ Web app المنتهي بـ /exec.';

  @override
  String get failureSheetAccessDenied =>
      'طلبت Google تسجيل الدخول. في Apps Script افتح نشر ← إدارة عمليات النشر ← تعديل، واجعل \"من يمكنه الوصول\" أي شخص (Anyone)، ثم انشر مرة أخرى.';

  @override
  String get failureSheetNotPaired => 'تم تغيير رمز الربط في الجدول. اربط مرة أخرى بالرمز الجديد.';

  @override
  String failureSheetMissing(String name) {
    return 'لم يتم العثور على الورقة \"$name\" في الجدول. اربط مرة أخرى ليجد سند أوراقك.';
  }

  @override
  String get failureSheetScript => 'أبلغ نص سند البرمجي في الجدول عن خطأ. تأكد أنه أحدث إصدار.';
}
