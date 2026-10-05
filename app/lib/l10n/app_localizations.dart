import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

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
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

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
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('ar'), Locale('en')];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Sanad'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In en, this message translates to:
  /// **'Care records, made simple'**
  String get appTagline;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonRetry;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// No description provided for @commonAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get commonOptional;

  /// No description provided for @commonActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get commonActive;

  /// No description provided for @commonInactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get commonInactive;

  /// No description provided for @commonDeactivate.
  ///
  /// In en, this message translates to:
  /// **'Deactivate'**
  String get commonDeactivate;

  /// No description provided for @commonActivate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get commonActivate;

  /// No description provided for @commonNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get commonNotSet;

  /// No description provided for @commonUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get commonUnspecified;

  /// No description provided for @commonLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get commonLoadMore;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// No description provided for @commonContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get commonContinue;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get commonCopied;

  /// No description provided for @commonToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get commonToday;

  /// No description provided for @commonYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get commonYesterday;

  /// No description provided for @currencyAmount.
  ///
  /// In en, this message translates to:
  /// **'{amount} EGP'**
  String currencyAmount(String amount);

  /// No description provided for @egp.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get egp;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get navCustomers;

  /// No description provided for @navRecords.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get navRecords;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @greetingMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get greetingMorning;

  /// No description provided for @greetingEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get greetingEvening;

  /// No description provided for @dashboardSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search customer by phone number'**
  String get dashboardSearchHint;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick actions'**
  String get quickActions;

  /// No description provided for @actionAddCustomer.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get actionAddCustomer;

  /// No description provided for @actionSearchCustomer.
  ///
  /// In en, this message translates to:
  /// **'Search customer'**
  String get actionSearchCustomer;

  /// No description provided for @actionAddRecord.
  ///
  /// In en, this message translates to:
  /// **'Add service record'**
  String get actionAddRecord;

  /// No description provided for @actionExport.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get actionExport;

  /// No description provided for @todayOverview.
  ///
  /// In en, this message translates to:
  /// **'Today\'s overview'**
  String get todayOverview;

  /// No description provided for @statTodayServices.
  ///
  /// In en, this message translates to:
  /// **'Today\'s services'**
  String get statTodayServices;

  /// No description provided for @statTodayRevenue.
  ///
  /// In en, this message translates to:
  /// **'Today\'s revenue'**
  String get statTodayRevenue;

  /// No description provided for @statCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get statCash;

  /// No description provided for @statElectronic.
  ///
  /// In en, this message translates to:
  /// **'Electronic'**
  String get statElectronic;

  /// No description provided for @statTotalCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get statTotalCustomers;

  /// No description provided for @statTotalRecords.
  ///
  /// In en, this message translates to:
  /// **'Service records'**
  String get statTotalRecords;

  /// No description provided for @statActiveNurses.
  ///
  /// In en, this message translates to:
  /// **'Active nurses'**
  String get statActiveNurses;

  /// No description provided for @statActiveServices.
  ///
  /// In en, this message translates to:
  /// **'Active services'**
  String get statActiveServices;

  /// No description provided for @statMonthRevenue.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get statMonthRevenue;

  /// No description provided for @businessOverview.
  ///
  /// In en, this message translates to:
  /// **'Business overview'**
  String get businessOverview;

  /// No description provided for @needsReviewBanner.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 imported customer needs review} other{{count} imported customers need review}}'**
  String needsReviewBanner(int count);

  /// No description provided for @customersTitle.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customersTitle;

  /// No description provided for @customersSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number or name'**
  String get customersSearchHint;

  /// No description provided for @customersNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Needs review'**
  String get customersNeedsReview;

  /// No description provided for @customersEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No customers yet'**
  String get customersEmptyTitle;

  /// No description provided for @customersEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Add your first customer or import your existing Excel data.'**
  String get customersEmptyBody;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search customer'**
  String get searchTitle;

  /// No description provided for @searchForRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Select customer'**
  String get searchForRecordTitle;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get searchHint;

  /// No description provided for @searchByNameHint.
  ///
  /// In en, this message translates to:
  /// **'Phone number or customer name'**
  String get searchByNameHint;

  /// No description provided for @searchTypeMore.
  ///
  /// In en, this message translates to:
  /// **'Type at least 3 digits of the phone number, or a name.'**
  String get searchTypeMore;

  /// No description provided for @searchNotFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer not found'**
  String get searchNotFoundTitle;

  /// No description provided for @searchNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'No customer matches “{query}”.'**
  String searchNotFoundBody(String query);

  /// No description provided for @searchAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add new customer'**
  String get searchAddNew;

  /// No description provided for @searchResults.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 customer found} other{{count} customers found}}'**
  String searchResults(int count);

  /// No description provided for @searchSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Check the name and phone, then tap to continue.'**
  String get searchSelectHint;

  /// No description provided for @customerVisits.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No visits} =1{1 visit} other{{count} visits}}'**
  String customerVisits(int count);

  /// No description provided for @customerLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit {date}'**
  String customerLastVisit(String date);

  /// No description provided for @customerArchived.
  ///
  /// In en, this message translates to:
  /// **'Archived'**
  String get customerArchived;

  /// No description provided for @customerNoPhone.
  ///
  /// In en, this message translates to:
  /// **'No phone number'**
  String get customerNoPhone;

  /// No description provided for @addCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Add customer'**
  String get addCustomerTitle;

  /// No description provided for @editCustomerTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit customer'**
  String get editCustomerTitle;

  /// No description provided for @fieldFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fieldFullName;

  /// No description provided for @fieldPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get fieldPhone;

  /// No description provided for @fieldPhoneHelper.
  ///
  /// In en, this message translates to:
  /// **'Egyptian number, e.g. 01012345678'**
  String get fieldPhoneHelper;

  /// No description provided for @fieldAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get fieldAddress;

  /// No description provided for @fieldArea.
  ///
  /// In en, this message translates to:
  /// **'Living area'**
  String get fieldArea;

  /// No description provided for @fieldAreaHint.
  ///
  /// In en, this message translates to:
  /// **'Select area'**
  String get fieldAreaHint;

  /// No description provided for @fieldNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get fieldNotes;

  /// No description provided for @saveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Save customer'**
  String get saveCustomer;

  /// No description provided for @customerExistsTitle.
  ///
  /// In en, this message translates to:
  /// **'Phone number already registered'**
  String get customerExistsTitle;

  /// No description provided for @customerExistsBody.
  ///
  /// In en, this message translates to:
  /// **'This phone number belongs to an existing customer. Use that customer instead of creating a duplicate.'**
  String get customerExistsBody;

  /// No description provided for @customerExistsArchived.
  ///
  /// In en, this message translates to:
  /// **'This customer is archived. An administrator can restore them.'**
  String get customerExistsArchived;

  /// No description provided for @viewCustomer.
  ///
  /// In en, this message translates to:
  /// **'View customer'**
  String get viewCustomer;

  /// No description provided for @customerSavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer saved'**
  String get customerSavedTitle;

  /// No description provided for @customerSavedBody.
  ///
  /// In en, this message translates to:
  /// **'{name} has been added to Sanad.'**
  String customerSavedBody(String name);

  /// No description provided for @backToHome.
  ///
  /// In en, this message translates to:
  /// **'Back to home'**
  String get backToHome;

  /// No description provided for @customerUpdated.
  ///
  /// In en, this message translates to:
  /// **'Customer details updated.'**
  String get customerUpdated;

  /// No description provided for @profileTitle.
  ///
  /// In en, this message translates to:
  /// **'Customer profile'**
  String get profileTitle;

  /// No description provided for @profileInfo.
  ///
  /// In en, this message translates to:
  /// **'Customer information'**
  String get profileInfo;

  /// No description provided for @profileHistory.
  ///
  /// In en, this message translates to:
  /// **'Service history'**
  String get profileHistory;

  /// No description provided for @profileTotalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total paid'**
  String get profileTotalSpent;

  /// No description provided for @profileVisits.
  ///
  /// In en, this message translates to:
  /// **'Visits'**
  String get profileVisits;

  /// No description provided for @profileLastVisit.
  ///
  /// In en, this message translates to:
  /// **'Last visit'**
  String get profileLastVisit;

  /// No description provided for @profileAddRecord.
  ///
  /// In en, this message translates to:
  /// **'Add new record'**
  String get profileAddRecord;

  /// No description provided for @profileNoHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'No service records yet'**
  String get profileNoHistoryTitle;

  /// No description provided for @profileNoHistoryBody.
  ///
  /// In en, this message translates to:
  /// **'Records you add for this customer will appear here.'**
  String get profileNoHistoryBody;

  /// No description provided for @profileNeedsReview.
  ///
  /// In en, this message translates to:
  /// **'Imported without a valid phone number. Edit the customer to add one.'**
  String get profileNeedsReview;

  /// No description provided for @archiveCustomer.
  ///
  /// In en, this message translates to:
  /// **'Archive customer'**
  String get archiveCustomer;

  /// No description provided for @restoreCustomer.
  ///
  /// In en, this message translates to:
  /// **'Restore customer'**
  String get restoreCustomer;

  /// No description provided for @archiveCustomerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Archive {name}? Their history is kept, but they will no longer appear in searches.'**
  String archiveCustomerConfirm(String name);

  /// No description provided for @customerArchivedDone.
  ///
  /// In en, this message translates to:
  /// **'Customer archived.'**
  String get customerArchivedDone;

  /// No description provided for @customerRestoredDone.
  ///
  /// In en, this message translates to:
  /// **'Customer restored.'**
  String get customerRestoredDone;

  /// No description provided for @copyPhone.
  ///
  /// In en, this message translates to:
  /// **'Copy phone number'**
  String get copyPhone;

  /// No description provided for @areaPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Select area'**
  String get areaPickerTitle;

  /// No description provided for @areaPickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search areas'**
  String get areaPickerSearch;

  /// No description provided for @areaAddNew.
  ///
  /// In en, this message translates to:
  /// **'Add new area'**
  String get areaAddNew;

  /// No description provided for @areaAddNamed.
  ///
  /// In en, this message translates to:
  /// **'Add “{name}”'**
  String areaAddNamed(String name);

  /// No description provided for @areaNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New area'**
  String get areaNewTitle;

  /// No description provided for @areaName.
  ///
  /// In en, this message translates to:
  /// **'Area name'**
  String get areaName;

  /// No description provided for @areaCreated.
  ///
  /// In en, this message translates to:
  /// **'Area “{name}” added.'**
  String areaCreated(String name);

  /// No description provided for @areaExisting.
  ///
  /// In en, this message translates to:
  /// **'“{name}” already exists and was selected.'**
  String areaExisting(String name);

  /// No description provided for @recordsTitle.
  ///
  /// In en, this message translates to:
  /// **'Records'**
  String get recordsTitle;

  /// No description provided for @recordsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Customer name or phone'**
  String get recordsSearchHint;

  /// No description provided for @recordsFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get recordsFilters;

  /// No description provided for @recordsSort.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get recordsSort;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldest;

  /// No description provided for @sortPriceHigh.
  ///
  /// In en, this message translates to:
  /// **'Highest price'**
  String get sortPriceHigh;

  /// No description provided for @sortPriceLow.
  ///
  /// In en, this message translates to:
  /// **'Lowest price'**
  String get sortPriceLow;

  /// No description provided for @recordsTotals.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record} other{{count} records}} · {amount}'**
  String recordsTotals(int count, String amount);

  /// No description provided for @recordsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No records found'**
  String get recordsEmptyTitle;

  /// No description provided for @recordsEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Try changing the filters or search.'**
  String get recordsEmptyBody;

  /// No description provided for @recordsNoneYetBody.
  ///
  /// In en, this message translates to:
  /// **'Service records will appear here once you add them.'**
  String get recordsNoneYetBody;

  /// No description provided for @filterDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get filterDate;

  /// No description provided for @filterAnyDate.
  ///
  /// In en, this message translates to:
  /// **'Any date'**
  String get filterAnyDate;

  /// No description provided for @filterThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get filterThisWeek;

  /// No description provided for @filterThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get filterThisMonth;

  /// No description provided for @filterLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get filterLastMonth;

  /// No description provided for @filterCustomRange.
  ///
  /// In en, this message translates to:
  /// **'Custom range'**
  String get filterCustomRange;

  /// No description provided for @filterNurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get filterNurse;

  /// No description provided for @filterService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get filterService;

  /// No description provided for @filterArea.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get filterArea;

  /// No description provided for @filterPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get filterPayment;

  /// No description provided for @filterAny.
  ///
  /// In en, this message translates to:
  /// **'Any'**
  String get filterAny;

  /// No description provided for @filterClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get filterClearAll;

  /// No description provided for @filterShowResults.
  ///
  /// In en, this message translates to:
  /// **'Show results'**
  String get filterShowResults;

  /// No description provided for @addRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'New service record'**
  String get addRecordTitle;

  /// No description provided for @editRecordTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit record'**
  String get editRecordTitle;

  /// No description provided for @recordFor.
  ///
  /// In en, this message translates to:
  /// **'Record for'**
  String get recordFor;

  /// No description provided for @fieldNurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get fieldNurse;

  /// No description provided for @fieldNurseHint.
  ///
  /// In en, this message translates to:
  /// **'Select nurse'**
  String get fieldNurseHint;

  /// No description provided for @fieldService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get fieldService;

  /// No description provided for @fieldServiceHint.
  ///
  /// In en, this message translates to:
  /// **'Select service'**
  String get fieldServiceHint;

  /// No description provided for @fieldPrice.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get fieldPrice;

  /// No description provided for @fieldPriceHelper.
  ///
  /// In en, this message translates to:
  /// **'The amount actually charged for this visit'**
  String get fieldPriceHelper;

  /// No description provided for @fieldPriceDefault.
  ///
  /// In en, this message translates to:
  /// **'Default price: {amount}'**
  String fieldPriceDefault(String amount);

  /// No description provided for @fieldPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get fieldPaymentMethod;

  /// No description provided for @paymentCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentCash;

  /// No description provided for @paymentElectronic.
  ///
  /// In en, this message translates to:
  /// **'Electronic'**
  String get paymentElectronic;

  /// No description provided for @paymentUnspecified.
  ///
  /// In en, this message translates to:
  /// **'Not recorded'**
  String get paymentUnspecified;

  /// No description provided for @fieldDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get fieldDate;

  /// No description provided for @fieldTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get fieldTime;

  /// No description provided for @fieldPatientName.
  ///
  /// In en, this message translates to:
  /// **'Patient name'**
  String get fieldPatientName;

  /// No description provided for @fieldPatientHelper.
  ///
  /// In en, this message translates to:
  /// **'Only if the service was for someone else (e.g. a family member)'**
  String get fieldPatientHelper;

  /// No description provided for @saveRecord.
  ///
  /// In en, this message translates to:
  /// **'Save record'**
  String get saveRecord;

  /// No description provided for @recordSaved.
  ///
  /// In en, this message translates to:
  /// **'Record saved.'**
  String get recordSaved;

  /// No description provided for @recordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Record updated.'**
  String get recordUpdated;

  /// No description provided for @draftRestored.
  ///
  /// In en, this message translates to:
  /// **'Your unsaved entry was restored.'**
  String get draftRestored;

  /// No description provided for @discardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discardDraft;

  /// No description provided for @recordDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Record details'**
  String get recordDetailsTitle;

  /// No description provided for @recordCustomer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get recordCustomer;

  /// No description provided for @recordService.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get recordService;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get recordPayment;

  /// No description provided for @recordWhen.
  ///
  /// In en, this message translates to:
  /// **'Date & time'**
  String get recordWhen;

  /// No description provided for @recordAddressAtVisit.
  ///
  /// In en, this message translates to:
  /// **'Address at time of visit'**
  String get recordAddressAtVisit;

  /// No description provided for @recordAreaAtVisit.
  ///
  /// In en, this message translates to:
  /// **'Area at time of visit'**
  String get recordAreaAtVisit;

  /// No description provided for @recordPatient.
  ///
  /// In en, this message translates to:
  /// **'Patient'**
  String get recordPatient;

  /// No description provided for @recordCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get recordCreatedAt;

  /// No description provided for @recordLegacyRef.
  ///
  /// In en, this message translates to:
  /// **'Excel row no.'**
  String get recordLegacyRef;

  /// No description provided for @recordImported.
  ///
  /// In en, this message translates to:
  /// **'Imported from Excel'**
  String get recordImported;

  /// No description provided for @recordNoTime.
  ///
  /// In en, this message translates to:
  /// **'Time not recorded'**
  String get recordNoTime;

  /// No description provided for @archiveRecord.
  ///
  /// In en, this message translates to:
  /// **'Archive record'**
  String get archiveRecord;

  /// No description provided for @archiveRecordConfirm.
  ///
  /// In en, this message translates to:
  /// **'Archive this record? It will be hidden from history and totals but kept for audit.'**
  String get archiveRecordConfirm;

  /// No description provided for @recordArchived.
  ///
  /// In en, this message translates to:
  /// **'Record archived.'**
  String get recordArchived;

  /// No description provided for @openCustomer.
  ///
  /// In en, this message translates to:
  /// **'Open customer'**
  String get openCustomer;

  /// No description provided for @nurseLabel.
  ///
  /// In en, this message translates to:
  /// **'Nurse: {name}'**
  String nurseLabel(String name);

  /// No description provided for @nursesTitle.
  ///
  /// In en, this message translates to:
  /// **'Nurses'**
  String get nursesTitle;

  /// No description provided for @nursesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No nurses yet. Add the nurses who provide services.'**
  String get nursesEmpty;

  /// No description provided for @addNurse.
  ///
  /// In en, this message translates to:
  /// **'Add nurse'**
  String get addNurse;

  /// No description provided for @editNurse.
  ///
  /// In en, this message translates to:
  /// **'Edit nurse'**
  String get editNurse;

  /// No description provided for @nurseName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nurseName;

  /// No description provided for @nurseSaved.
  ///
  /// In en, this message translates to:
  /// **'Nurse saved.'**
  String get nurseSaved;

  /// No description provided for @servicesTitle.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get servicesTitle;

  /// No description provided for @servicesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No services yet. Add the services you provide.'**
  String get servicesEmpty;

  /// No description provided for @addService.
  ///
  /// In en, this message translates to:
  /// **'Add service'**
  String get addService;

  /// No description provided for @editService.
  ///
  /// In en, this message translates to:
  /// **'Edit service'**
  String get editService;

  /// No description provided for @serviceName.
  ///
  /// In en, this message translates to:
  /// **'Service name'**
  String get serviceName;

  /// No description provided for @serviceDefaultPrice.
  ///
  /// In en, this message translates to:
  /// **'Default price'**
  String get serviceDefaultPrice;

  /// No description provided for @serviceDefaultPriceHelper.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if the price varies. Changing it never affects past records.'**
  String get serviceDefaultPriceHelper;

  /// No description provided for @serviceVariablePrice.
  ///
  /// In en, this message translates to:
  /// **'Variable price'**
  String get serviceVariablePrice;

  /// No description provided for @serviceSaved.
  ///
  /// In en, this message translates to:
  /// **'Service saved.'**
  String get serviceSaved;

  /// No description provided for @areasTitle.
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get areasTitle;

  /// No description provided for @areasEmpty.
  ///
  /// In en, this message translates to:
  /// **'No areas yet.'**
  String get areasEmpty;

  /// No description provided for @addArea.
  ///
  /// In en, this message translates to:
  /// **'Add area'**
  String get addArea;

  /// No description provided for @editArea.
  ///
  /// In en, this message translates to:
  /// **'Edit area'**
  String get editArea;

  /// No description provided for @areaSaved.
  ///
  /// In en, this message translates to:
  /// **'Area saved.'**
  String get areaSaved;

  /// No description provided for @showInactive.
  ///
  /// In en, this message translates to:
  /// **'Show inactive'**
  String get showInactive;

  /// No description provided for @statusActiveHelper.
  ///
  /// In en, this message translates to:
  /// **'Inactive items stay in history but cannot be chosen for new records.'**
  String get statusActiveHelper;

  /// No description provided for @deactivateConfirm.
  ///
  /// In en, this message translates to:
  /// **'Deactivate “{name}”? It stays in past records but can no longer be selected.'**
  String deactivateConfirm(String name);

  /// No description provided for @pickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matches'**
  String get pickerNoResults;

  /// No description provided for @pickerAddNamed.
  ///
  /// In en, this message translates to:
  /// **'Add “{name}”'**
  String pickerAddNamed(String name);

  /// No description provided for @pickerSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get pickerSearch;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @moreManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get moreManage;

  /// No description provided for @moreData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get moreData;

  /// No description provided for @importTitle.
  ///
  /// In en, this message translates to:
  /// **'Import from Excel'**
  String get importTitle;

  /// No description provided for @exportTitle.
  ///
  /// In en, this message translates to:
  /// **'Export to Excel'**
  String get exportTitle;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Sanad'**
  String get settingsAbout;

  /// No description provided for @settingsVersion.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored only on this phone. If you connect Google Drive, a backup is kept in your own Drive, visible only to you until you share it.'**
  String get settingsPrivacy;

  /// No description provided for @importIntro.
  ///
  /// In en, this message translates to:
  /// **'Bring existing records from an Excel workbook into Sanad. Nothing is saved until you review the preview and confirm.'**
  String get importIntro;

  /// No description provided for @importChooseFile.
  ///
  /// In en, this message translates to:
  /// **'Choose Excel file'**
  String get importChooseFile;

  /// No description provided for @importReading.
  ///
  /// In en, this message translates to:
  /// **'Reading workbook…'**
  String get importReading;

  /// No description provided for @importStepFile.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get importStepFile;

  /// No description provided for @importStepColumns.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get importStepColumns;

  /// No description provided for @importStepPreview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get importStepPreview;

  /// No description provided for @importSheet.
  ///
  /// In en, this message translates to:
  /// **'Sheet'**
  String get importSheet;

  /// No description provided for @importColumnsTitle.
  ///
  /// In en, this message translates to:
  /// **'Check column mapping'**
  String get importColumnsTitle;

  /// No description provided for @importColumnsBody.
  ///
  /// In en, this message translates to:
  /// **'Sanad matched these columns automatically. Fix any that are wrong before continuing.'**
  String get importColumnsBody;

  /// No description provided for @importNotMapped.
  ///
  /// In en, this message translates to:
  /// **'Not in file'**
  String get importNotMapped;

  /// No description provided for @importHeaderRow.
  ///
  /// In en, this message translates to:
  /// **'Header found on row {row}'**
  String importHeaderRow(int row);

  /// No description provided for @importBuildPreview.
  ///
  /// In en, this message translates to:
  /// **'Build preview'**
  String get importBuildPreview;

  /// No description provided for @importMissingRequired.
  ///
  /// In en, this message translates to:
  /// **'Map the required columns: {fields}'**
  String importMissingRequired(String fields);

  /// No description provided for @importPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review before importing'**
  String get importPreviewTitle;

  /// No description provided for @importRecords.
  ///
  /// In en, this message translates to:
  /// **'Records to import'**
  String get importRecords;

  /// No description provided for @importSkipped.
  ///
  /// In en, this message translates to:
  /// **'Rows skipped'**
  String get importSkipped;

  /// No description provided for @importNewCustomers.
  ///
  /// In en, this message translates to:
  /// **'New customers'**
  String get importNewCustomers;

  /// No description provided for @importMatchedCustomers.
  ///
  /// In en, this message translates to:
  /// **'Existing customers'**
  String get importMatchedCustomers;

  /// No description provided for @importNewAreas.
  ///
  /// In en, this message translates to:
  /// **'New areas'**
  String get importNewAreas;

  /// No description provided for @importNewNurses.
  ///
  /// In en, this message translates to:
  /// **'New nurses'**
  String get importNewNurses;

  /// No description provided for @importNewServices.
  ///
  /// In en, this message translates to:
  /// **'New services'**
  String get importNewServices;

  /// No description provided for @importRevenue.
  ///
  /// In en, this message translates to:
  /// **'Total amount'**
  String get importRevenue;

  /// No description provided for @importDateRange.
  ///
  /// In en, this message translates to:
  /// **'Dates'**
  String get importDateRange;

  /// No description provided for @importNoPayment.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 record has no payment method in the file. It will be marked “Not recorded”.} other{{count} records have no payment method in the file. They will be marked “Not recorded”.}}'**
  String importNoPayment(int count);

  /// No description provided for @importReviewCustomers.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 customer has no valid phone number and will be flagged for review.} other{{count} customers have no valid phone number and will be flagged for review.}}'**
  String importReviewCustomers(int count);

  /// No description provided for @importAlreadyImported.
  ///
  /// In en, this message translates to:
  /// **'Data has been imported before. If this is a corrected version of the same file, roll back the earlier import first to avoid duplicates.'**
  String get importAlreadyImported;

  /// No description provided for @importWarnings.
  ///
  /// In en, this message translates to:
  /// **'Warnings (rows are imported)'**
  String get importWarnings;

  /// No description provided for @importErrors.
  ///
  /// In en, this message translates to:
  /// **'Problems (rows are skipped)'**
  String get importErrors;

  /// No description provided for @importEntities.
  ///
  /// In en, this message translates to:
  /// **'Names found in the file'**
  String get importEntities;

  /// No description provided for @importNew.
  ///
  /// In en, this message translates to:
  /// **'new'**
  String get importNew;

  /// No description provided for @importRowsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rows: {rows}'**
  String importRowsLabel(String rows);

  /// No description provided for @importConfirm.
  ///
  /// In en, this message translates to:
  /// **'Import {count} records'**
  String importConfirm(int count);

  /// No description provided for @importConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Start import?'**
  String get importConfirmTitle;

  /// No description provided for @importConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'The import runs as a single transaction: either everything is saved or nothing is. You can roll it back later from the import history.'**
  String get importConfirmBody;

  /// No description provided for @importRunning.
  ///
  /// In en, this message translates to:
  /// **'Importing…'**
  String get importRunning;

  /// No description provided for @importDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Import complete'**
  String get importDoneTitle;

  /// No description provided for @importDoneBody.
  ///
  /// In en, this message translates to:
  /// **'{records} records imported, {customers} new customers created, {matched} existing customers matched.'**
  String importDoneBody(int records, int customers, int matched);

  /// No description provided for @importHistory.
  ///
  /// In en, this message translates to:
  /// **'Import history'**
  String get importHistory;

  /// No description provided for @importHistoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No imports yet.'**
  String get importHistoryEmpty;

  /// No description provided for @importRolledBack.
  ///
  /// In en, this message translates to:
  /// **'Rolled back'**
  String get importRolledBack;

  /// No description provided for @importRollback.
  ///
  /// In en, this message translates to:
  /// **'Roll back'**
  String get importRollback;

  /// No description provided for @importRollbackConfirm.
  ///
  /// In en, this message translates to:
  /// **'Roll back “{file}”? Records created by this import are removed. Customers or names that were used afterwards are kept.'**
  String importRollbackConfirm(String file);

  /// No description provided for @importRollbackDone.
  ///
  /// In en, this message translates to:
  /// **'Import rolled back.'**
  String get importRollbackDone;

  /// No description provided for @importBatchSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} records · {date}'**
  String importBatchSummary(int count, String date);

  /// No description provided for @importStartOver.
  ///
  /// In en, this message translates to:
  /// **'Choose another file'**
  String get importStartOver;

  /// No description provided for @importUnspecifiedName.
  ///
  /// In en, this message translates to:
  /// **'Unspecified'**
  String get importUnspecifiedName;

  /// No description provided for @importShowRows.
  ///
  /// In en, this message translates to:
  /// **'Rows {rows}'**
  String importShowRows(String rows);

  /// No description provided for @importField_legacyRef.
  ///
  /// In en, this message translates to:
  /// **'Record no.'**
  String get importField_legacyRef;

  /// No description provided for @importField_serviceDate.
  ///
  /// In en, this message translates to:
  /// **'Service date'**
  String get importField_serviceDate;

  /// No description provided for @importField_serviceTime.
  ///
  /// In en, this message translates to:
  /// **'Service time'**
  String get importField_serviceTime;

  /// No description provided for @importField_customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer name'**
  String get importField_customerName;

  /// No description provided for @importField_phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get importField_phone;

  /// No description provided for @importField_address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get importField_address;

  /// No description provided for @importField_area.
  ///
  /// In en, this message translates to:
  /// **'Area'**
  String get importField_area;

  /// No description provided for @importField_nurse.
  ///
  /// In en, this message translates to:
  /// **'Nurse'**
  String get importField_nurse;

  /// No description provided for @importField_service.
  ///
  /// In en, this message translates to:
  /// **'Service'**
  String get importField_service;

  /// No description provided for @importField_price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get importField_price;

  /// No description provided for @importField_paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment method'**
  String get importField_paymentMethod;

  /// No description provided for @importField_patientName.
  ///
  /// In en, this message translates to:
  /// **'Patient (if different)'**
  String get importField_patientName;

  /// No description provided for @importField_notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get importField_notes;

  /// No description provided for @importField_status.
  ///
  /// In en, this message translates to:
  /// **'Status (kept for reference)'**
  String get importField_status;

  /// No description provided for @importIssue_datemissing.
  ///
  /// In en, this message translates to:
  /// **'Missing date'**
  String get importIssue_datemissing;

  /// No description provided for @importIssue_dateinvalid.
  ///
  /// In en, this message translates to:
  /// **'Unreadable date'**
  String get importIssue_dateinvalid;

  /// No description provided for @importIssue_pricemissing.
  ///
  /// In en, this message translates to:
  /// **'Missing price'**
  String get importIssue_pricemissing;

  /// No description provided for @importIssue_priceinvalid.
  ///
  /// In en, this message translates to:
  /// **'Unreadable price'**
  String get importIssue_priceinvalid;

  /// No description provided for @importIssue_customermissing.
  ///
  /// In en, this message translates to:
  /// **'No customer name or phone'**
  String get importIssue_customermissing;

  /// No description provided for @importIssue_dateambiguous.
  ///
  /// In en, this message translates to:
  /// **'Day/month order assumed (day first)'**
  String get importIssue_dateambiguous;

  /// No description provided for @importIssue_timemissing.
  ///
  /// In en, this message translates to:
  /// **'No time — imported without a time'**
  String get importIssue_timemissing;

  /// No description provided for @importIssue_timeinvalid.
  ///
  /// In en, this message translates to:
  /// **'Unreadable time — imported without a time'**
  String get importIssue_timeinvalid;

  /// No description provided for @importIssue_timeambiguous.
  ///
  /// In en, this message translates to:
  /// **'AM/PM unknown — imported without a time'**
  String get importIssue_timeambiguous;

  /// No description provided for @importIssue_phoneinvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid or missing phone — customer flagged for review'**
  String get importIssue_phoneinvalid;

  /// No description provided for @importIssue_phoneshared.
  ///
  /// In en, this message translates to:
  /// **'Same phone, different name — kept as patient name'**
  String get importIssue_phoneshared;

  /// No description provided for @importIssue_nursemissing.
  ///
  /// In en, this message translates to:
  /// **'No nurse — set to “Unspecified”'**
  String get importIssue_nursemissing;

  /// No description provided for @importIssue_servicemissing.
  ///
  /// In en, this message translates to:
  /// **'No service — set to “Unspecified”'**
  String get importIssue_servicemissing;

  /// No description provided for @importIssue_areamissing.
  ///
  /// In en, this message translates to:
  /// **'No area — set to “Unspecified”'**
  String get importIssue_areamissing;

  /// No description provided for @importIssue_pricecleaned.
  ///
  /// In en, this message translates to:
  /// **'Price written as text — number extracted'**
  String get importIssue_pricecleaned;

  /// No description provided for @importIssue_paymentunknown.
  ///
  /// In en, this message translates to:
  /// **'Unrecognised payment method'**
  String get importIssue_paymentunknown;

  /// No description provided for @importIssue_customerdetailschanged.
  ///
  /// In en, this message translates to:
  /// **'Address/area differs from other visits — kept on this record'**
  String get importIssue_customerdetailschanged;

  /// No description provided for @exportIntro.
  ///
  /// In en, this message translates to:
  /// **'Create a formatted Excel workbook for administration, accounting or backup.'**
  String get exportIntro;

  /// No description provided for @exportPeriod.
  ///
  /// In en, this message translates to:
  /// **'Records period'**
  String get exportPeriod;

  /// No description provided for @exportAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get exportAllTime;

  /// No description provided for @exportSheets.
  ///
  /// In en, this message translates to:
  /// **'Sheets to include'**
  String get exportSheets;

  /// No description provided for @exportSheetRecords.
  ///
  /// In en, this message translates to:
  /// **'Records (with customer details)'**
  String get exportSheetRecords;

  /// No description provided for @exportSheetCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get exportSheetCustomers;

  /// No description provided for @exportSheetNurses.
  ///
  /// In en, this message translates to:
  /// **'Nurses'**
  String get exportSheetNurses;

  /// No description provided for @exportSheetServices.
  ///
  /// In en, this message translates to:
  /// **'Services'**
  String get exportSheetServices;

  /// No description provided for @exportSheetAreas.
  ///
  /// In en, this message translates to:
  /// **'Areas'**
  String get exportSheetAreas;

  /// No description provided for @exportCreate.
  ///
  /// In en, this message translates to:
  /// **'Create Excel file'**
  String get exportCreate;

  /// No description provided for @exportWorking.
  ///
  /// In en, this message translates to:
  /// **'Preparing workbook…'**
  String get exportWorking;

  /// No description provided for @exportReady.
  ///
  /// In en, this message translates to:
  /// **'Workbook ready'**
  String get exportReady;

  /// No description provided for @exportReadyBody.
  ///
  /// In en, this message translates to:
  /// **'{count} records exported to {file}.'**
  String exportReadyBody(int count, String file);

  /// No description provided for @exportShare.
  ///
  /// In en, this message translates to:
  /// **'Share / save file'**
  String get exportShare;

  /// No description provided for @exportSheetTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get exportSheetTotal;

  /// No description provided for @exportRecordId.
  ///
  /// In en, this message translates to:
  /// **'Record ID'**
  String get exportRecordId;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required.'**
  String get validationRequired;

  /// No description provided for @validationTooLong.
  ///
  /// In en, this message translates to:
  /// **'This is too long.'**
  String get validationTooLong;

  /// No description provided for @validationInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid Egyptian phone number, e.g. 01012345678.'**
  String get validationInvalidPhone;

  /// No description provided for @validationInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount.'**
  String get validationInvalidPrice;

  /// No description provided for @validationNegativePrice.
  ///
  /// In en, this message translates to:
  /// **'The price cannot be negative.'**
  String get validationNegativePrice;

  /// No description provided for @validationPriceTooHigh.
  ///
  /// In en, this message translates to:
  /// **'This amount is too high.'**
  String get validationPriceTooHigh;

  /// No description provided for @validationFutureDate.
  ///
  /// In en, this message translates to:
  /// **'The date cannot be in the future.'**
  String get validationFutureDate;

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Your data is safe on this phone; the backup will run when you are back online.'**
  String get failureNetwork;

  /// No description provided for @failureDuplicatePhone.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already registered.'**
  String get failureDuplicatePhone;

  /// No description provided for @failureDuplicateName.
  ///
  /// In en, this message translates to:
  /// **'This name already exists.'**
  String get failureDuplicateName;

  /// No description provided for @failureDuplicateFile.
  ///
  /// In en, this message translates to:
  /// **'This file has already been imported.'**
  String get failureDuplicateFile;

  /// No description provided for @failureDuplicate.
  ///
  /// In en, this message translates to:
  /// **'This value already exists.'**
  String get failureDuplicate;

  /// No description provided for @failureValidation.
  ///
  /// In en, this message translates to:
  /// **'Please check the highlighted fields.'**
  String get failureValidation;

  /// No description provided for @failureNotFound.
  ///
  /// In en, this message translates to:
  /// **'This item no longer exists.'**
  String get failureNotFound;

  /// No description provided for @failureUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get failureUnexpected;

  /// No description provided for @failureFileUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This file could not be read. Make sure it is an Excel (.xlsx) file.'**
  String get failureFileUnreadable;

  /// No description provided for @failureFileNoSheets.
  ///
  /// In en, this message translates to:
  /// **'The workbook has no sheets.'**
  String get failureFileNoSheets;

  /// No description provided for @failureFileHeaderNotFound.
  ///
  /// In en, this message translates to:
  /// **'No sheet with recognisable columns (date, customer name or phone, price) was found.'**
  String get failureFileHeaderNotFound;

  /// No description provided for @failureFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to import or export.'**
  String get failureFileEmpty;

  /// No description provided for @failureFileWrite.
  ///
  /// In en, this message translates to:
  /// **'The Excel file could not be created.'**
  String get failureFileWrite;

  /// No description provided for @failureRuleNurseInactive.
  ///
  /// In en, this message translates to:
  /// **'This nurse is no longer active. Choose another nurse.'**
  String get failureRuleNurseInactive;

  /// No description provided for @failureRuleServiceInactive.
  ///
  /// In en, this message translates to:
  /// **'This service is no longer active. Choose another service.'**
  String get failureRuleServiceInactive;

  /// No description provided for @failureRuleCustomerArchived.
  ///
  /// In en, this message translates to:
  /// **'This customer is archived.'**
  String get failureRuleCustomerArchived;

  /// No description provided for @failureRuleAlreadyImported.
  ///
  /// In en, this message translates to:
  /// **'This file has already been imported.'**
  String get failureRuleAlreadyImported;

  /// No description provided for @failureRuleBatchNotFound.
  ///
  /// In en, this message translates to:
  /// **'This import was already rolled back.'**
  String get failureRuleBatchNotFound;

  /// No description provided for @failureRuleInUse.
  ///
  /// In en, this message translates to:
  /// **'This item is in use and cannot be removed.'**
  String get failureRuleInUse;

  /// No description provided for @moreApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get moreApp;

  /// No description provided for @failureServer.
  ///
  /// In en, this message translates to:
  /// **'Google Drive answered with an error. Please try again.'**
  String get failureServer;

  /// No description provided for @failureFileNotABackup.
  ///
  /// In en, this message translates to:
  /// **'This file is not a Sanad backup.'**
  String get failureFileNotABackup;

  /// No description provided for @failureBackupCanceled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was canceled.'**
  String get failureBackupCanceled;

  /// No description provided for @failureBackupNotAuthorized.
  ///
  /// In en, this message translates to:
  /// **'Sanad no longer has access to Google Drive. Connect again.'**
  String get failureBackupNotAuthorized;

  /// No description provided for @failureBackupNotConfigured.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not set up for this copy of the app yet. See \"Google Drive setup\" in the deployment guide.'**
  String get failureBackupNotConfigured;

  /// No description provided for @failureBackupNoBackup.
  ///
  /// In en, this message translates to:
  /// **'No Sanad backup was found in this Google Drive.'**
  String get failureBackupNoBackup;

  /// No description provided for @backupTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Drive backup'**
  String get backupTitle;

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'Your data is stored on this phone. Connect Google Drive to keep a copy in your own Drive: Sanad.xlsx (all sheets, ready to open and share) and a full backup to restore on a new phone. After every change the copy is updated automatically.'**
  String get backupIntro;

  /// No description provided for @backupConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Drive'**
  String get backupConnect;

  /// No description provided for @backupAccount.
  ///
  /// In en, this message translates to:
  /// **'Google account'**
  String get backupAccount;

  /// No description provided for @backupLast.
  ///
  /// In en, this message translates to:
  /// **'Last backup'**
  String get backupLast;

  /// No description provided for @backupNever.
  ///
  /// In en, this message translates to:
  /// **'Not backed up yet'**
  String get backupNever;

  /// No description provided for @backupUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Everything is backed up'**
  String get backupUpToDate;

  /// No description provided for @backupPendingChanges.
  ///
  /// In en, this message translates to:
  /// **'Changes waiting to be backed up'**
  String get backupPendingChanges;

  /// No description provided for @backupNotUpToDate.
  ///
  /// In en, this message translates to:
  /// **'The last backup did not complete'**
  String get backupNotUpToDate;

  /// No description provided for @backupInProgress.
  ///
  /// In en, this message translates to:
  /// **'Backing up…'**
  String get backupInProgress;

  /// No description provided for @backupRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring…'**
  String get backupRestoring;

  /// No description provided for @backupNow.
  ///
  /// In en, this message translates to:
  /// **'Back up now'**
  String get backupNow;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from Google Drive'**
  String get backupRestore;

  /// No description provided for @backupRestoreConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the data on this phone?'**
  String get backupRestoreConfirmTitle;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In en, this message translates to:
  /// **'All customers, records, nurses, services and areas on this phone will be replaced by the backup in Google Drive.'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestored.
  ///
  /// In en, this message translates to:
  /// **'Data restored from Google Drive'**
  String get backupRestored;

  /// No description provided for @backupFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'A backup is already in this Google Drive'**
  String get backupFoundTitle;

  /// No description provided for @backupFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Sanad found a backup from {date}. Restore it to this phone, or keep this phone\'s data and replace the backup.'**
  String backupFoundBody(String date);

  /// No description provided for @backupKeepDevice.
  ///
  /// In en, this message translates to:
  /// **'Keep this phone\'s data'**
  String get backupKeepDevice;

  /// No description provided for @backupKeepDeviceConfirm.
  ///
  /// In en, this message translates to:
  /// **'The backup in Google Drive will be replaced by the data on this phone. Earlier versions stay in the file\'s version history in Drive.'**
  String get backupKeepDeviceConfirm;

  /// No description provided for @backupDisconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Google Drive'**
  String get backupDisconnect;

  /// No description provided for @backupDisconnectConfirm.
  ///
  /// In en, this message translates to:
  /// **'Automatic backups will stop. Files already in Google Drive stay there.'**
  String get backupDisconnectConfirm;

  /// No description provided for @backupWhere.
  ///
  /// In en, this message translates to:
  /// **'Files are in Google Drive › Sanad. Open Sanad.xlsx there to view it or share it with others. Drive keeps earlier versions of each file.'**
  String get backupWhere;

  /// No description provided for @backupUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Google Drive backup works in the Android app. Here, use Export to Excel to save a copy.'**
  String get backupUnsupported;

  /// No description provided for @backupBannerConnect.
  ///
  /// In en, this message translates to:
  /// **'Back up your data to Google Drive'**
  String get backupBannerConnect;

  /// No description provided for @backupBannerFailed.
  ///
  /// In en, this message translates to:
  /// **'The Google Drive backup did not complete'**
  String get backupBannerFailed;

  /// No description provided for @backupBannerAction.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get backupBannerAction;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
