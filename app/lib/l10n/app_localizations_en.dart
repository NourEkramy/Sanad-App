// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Sanad';

  @override
  String get appTagline => 'Care records, made simple';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClose => 'Close';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonAll => 'All';

  @override
  String get commonOptional => 'Optional';

  @override
  String get commonActive => 'Active';

  @override
  String get commonInactive => 'Inactive';

  @override
  String get commonDeactivate => 'Deactivate';

  @override
  String get commonActivate => 'Activate';

  @override
  String get commonNotSet => 'Not set';

  @override
  String get commonUnspecified => 'Unspecified';

  @override
  String get commonLoadMore => 'Load more';

  @override
  String get commonBack => 'Back';

  @override
  String get commonDone => 'Done';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonCopied => 'Copied';

  @override
  String get commonToday => 'Today';

  @override
  String get commonYesterday => 'Yesterday';

  @override
  String currencyAmount(String amount) {
    return '$amount EGP';
  }

  @override
  String get egp => 'EGP';

  @override
  String get navHome => 'Home';

  @override
  String get navCustomers => 'Customers';

  @override
  String get navRecords => 'Records';

  @override
  String get navMore => 'More';

  @override
  String get loginTitle => 'Welcome back';

  @override
  String get loginSubtitle => 'Sign in with your work account to continue.';

  @override
  String get loginEmail => 'Email';

  @override
  String get loginPassword => 'Password';

  @override
  String get loginSubmit => 'Sign in';

  @override
  String get loginForgot => 'Forgot password?';

  @override
  String get loginSessionExpired => 'Your session has expired. Please sign in again.';

  @override
  String get loginShowPassword => 'Show password';

  @override
  String get loginHidePassword => 'Hide password';

  @override
  String get notConfiguredTitle => 'Sanad is not configured';

  @override
  String get notConfiguredBody =>
      'This build has no server address. Rebuild the app with SUPABASE_URL and SUPABASE_ANON_KEY (see docs/08-deployment.md).';

  @override
  String get forgotTitle => 'Reset password';

  @override
  String get forgotBody => 'Enter your work email and we will send you a link to choose a new password.';

  @override
  String get forgotSubmit => 'Send reset link';

  @override
  String forgotSent(String email) {
    return 'If an account exists for $email, a reset link is on its way.';
  }

  @override
  String get resetTitle => 'Choose a new password';

  @override
  String get resetBody => 'Enter a new password for your account. You will then sign in with it.';

  @override
  String get resetNewPassword => 'New password';

  @override
  String get resetConfirmPassword => 'Confirm new password';

  @override
  String get resetSubmit => 'Update password';

  @override
  String get resetDone => 'Password updated.';

  @override
  String get signOut => 'Sign out';

  @override
  String get signOutConfirm => 'Sign out of Sanad on this device?';

  @override
  String signOutPending(int count) {
    return 'There are $count records on this device that have not synced yet. They stay on this device and will sync after you sign in again.';
  }

  @override
  String greetingMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String greetingEvening(String name) {
    return 'Good evening, $name';
  }

  @override
  String get dashboardSearchHint => 'Search customer by phone number';

  @override
  String get quickActions => 'Quick actions';

  @override
  String get actionAddCustomer => 'Add customer';

  @override
  String get actionSearchCustomer => 'Search customer';

  @override
  String get actionAddRecord => 'Add service record';

  @override
  String get actionExport => 'Export to Excel';

  @override
  String get todayOverview => 'Today\'s overview';

  @override
  String get statTodayServices => 'Today\'s services';

  @override
  String get statTodayRevenue => 'Today\'s revenue';

  @override
  String get statCash => 'Cash';

  @override
  String get statElectronic => 'Electronic';

  @override
  String get statTotalCustomers => 'Customers';

  @override
  String get statTotalRecords => 'Service records';

  @override
  String get statActiveNurses => 'Active nurses';

  @override
  String get statActiveServices => 'Active services';

  @override
  String get statMonthRevenue => 'This month';

  @override
  String get businessOverview => 'Business overview';

  @override
  String pendingSyncBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records are waiting to sync',
      one: '1 record is waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncing => 'Syncing…';

  @override
  String get syncDone => 'All records are synced.';

  @override
  String needsReviewBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count imported customers need review',
      one: '1 imported customer needs review',
    );
    return '$_temp0';
  }

  @override
  String get offlineBanner => 'You are offline. New records are saved on this device and sync automatically.';

  @override
  String get customersTitle => 'Customers';

  @override
  String get customersSearchHint => 'Phone number or name';

  @override
  String get customersNeedsReview => 'Needs review';

  @override
  String get customersEmptyTitle => 'No customers yet';

  @override
  String get customersEmptyBody => 'Add your first customer or import your existing Excel data.';

  @override
  String get searchTitle => 'Search customer';

  @override
  String get searchForRecordTitle => 'Select customer';

  @override
  String get searchHint => 'Enter phone number';

  @override
  String get searchByNameHint => 'Phone number or customer name';

  @override
  String get searchTypeMore => 'Type at least 3 digits of the phone number, or a name.';

  @override
  String get searchNotFoundTitle => 'Customer not found';

  @override
  String searchNotFoundBody(String query) {
    return 'No customer matches “$query”.';
  }

  @override
  String get searchAddNew => 'Add new customer';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers found',
      one: '1 customer found',
    );
    return '$_temp0';
  }

  @override
  String get searchSelectHint => 'Check the name and phone, then tap to continue.';

  @override
  String customerVisits(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count visits',
      one: '1 visit',
      zero: 'No visits',
    );
    return '$_temp0';
  }

  @override
  String customerLastVisit(String date) {
    return 'Last visit $date';
  }

  @override
  String get customerArchived => 'Archived';

  @override
  String get customerNoPhone => 'No phone number';

  @override
  String get addCustomerTitle => 'Add customer';

  @override
  String get editCustomerTitle => 'Edit customer';

  @override
  String get fieldFullName => 'Full name';

  @override
  String get fieldPhone => 'Phone number';

  @override
  String get fieldPhoneHelper => 'Egyptian number, e.g. 01012345678';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldArea => 'Living area';

  @override
  String get fieldAreaHint => 'Select area';

  @override
  String get fieldNotes => 'Notes';

  @override
  String get saveCustomer => 'Save customer';

  @override
  String get customerExistsTitle => 'Phone number already registered';

  @override
  String get customerExistsBody =>
      'This phone number belongs to an existing customer. Use that customer instead of creating a duplicate.';

  @override
  String get customerExistsArchived => 'This customer is archived. An administrator can restore them.';

  @override
  String get viewCustomer => 'View customer';

  @override
  String get customerSavedTitle => 'Customer saved';

  @override
  String customerSavedBody(String name) {
    return '$name has been added to Sanad.';
  }

  @override
  String get backToHome => 'Back to home';

  @override
  String get customerUpdated => 'Customer details updated.';

  @override
  String get profileTitle => 'Customer profile';

  @override
  String get profileInfo => 'Customer information';

  @override
  String get profileHistory => 'Service history';

  @override
  String get profileTotalSpent => 'Total paid';

  @override
  String get profileVisits => 'Visits';

  @override
  String get profileLastVisit => 'Last visit';

  @override
  String get profileAddRecord => 'Add new record';

  @override
  String get profileNoHistoryTitle => 'No service records yet';

  @override
  String get profileNoHistoryBody => 'Records you add for this customer will appear here.';

  @override
  String get profileNeedsReview => 'Imported without a valid phone number. Edit the customer to add one.';

  @override
  String get archiveCustomer => 'Archive customer';

  @override
  String get restoreCustomer => 'Restore customer';

  @override
  String archiveCustomerConfirm(String name) {
    return 'Archive $name? Their history is kept, but they will no longer appear in searches.';
  }

  @override
  String get customerArchivedDone => 'Customer archived.';

  @override
  String get customerRestoredDone => 'Customer restored.';

  @override
  String get copyPhone => 'Copy phone number';

  @override
  String get areaPickerTitle => 'Select area';

  @override
  String get areaPickerSearch => 'Search areas';

  @override
  String get areaAddNew => 'Add new area';

  @override
  String areaAddNamed(String name) {
    return 'Add “$name”';
  }

  @override
  String get areaNewTitle => 'New area';

  @override
  String get areaName => 'Area name';

  @override
  String areaCreated(String name) {
    return 'Area “$name” added.';
  }

  @override
  String areaExisting(String name) {
    return '“$name” already exists and was selected.';
  }

  @override
  String get recordsTitle => 'Records';

  @override
  String get recordsSearchHint => 'Customer name or phone';

  @override
  String get recordsFilters => 'Filters';

  @override
  String get recordsSort => 'Sort';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortPriceHigh => 'Highest price';

  @override
  String get sortPriceLow => 'Lowest price';

  @override
  String recordsTotals(int count, String amount) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count records', one: '1 record');
    return '$_temp0 · $amount';
  }

  @override
  String get recordsEmptyTitle => 'No records found';

  @override
  String get recordsEmptyBody => 'Try changing the filters or search.';

  @override
  String get recordsNoneYetBody => 'Service records will appear here once you add them.';

  @override
  String get filterDate => 'Date';

  @override
  String get filterAnyDate => 'Any date';

  @override
  String get filterThisWeek => 'This week';

  @override
  String get filterThisMonth => 'This month';

  @override
  String get filterLastMonth => 'Last month';

  @override
  String get filterCustomRange => 'Custom range';

  @override
  String get filterNurse => 'Nurse';

  @override
  String get filterService => 'Service';

  @override
  String get filterArea => 'Area';

  @override
  String get filterPayment => 'Payment method';

  @override
  String get filterAny => 'Any';

  @override
  String get filterClearAll => 'Clear all';

  @override
  String get filterShowResults => 'Show results';

  @override
  String get addRecordTitle => 'New service record';

  @override
  String get editRecordTitle => 'Edit record';

  @override
  String get recordFor => 'Record for';

  @override
  String get fieldNurse => 'Nurse';

  @override
  String get fieldNurseHint => 'Select nurse';

  @override
  String get fieldService => 'Service';

  @override
  String get fieldServiceHint => 'Select service';

  @override
  String get fieldPrice => 'Price';

  @override
  String get fieldPriceHelper => 'The amount actually charged for this visit';

  @override
  String fieldPriceDefault(String amount) {
    return 'Default price: $amount';
  }

  @override
  String get fieldPaymentMethod => 'Payment method';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentElectronic => 'Electronic';

  @override
  String get paymentUnspecified => 'Not recorded';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldTime => 'Time';

  @override
  String get fieldPatientName => 'Patient name';

  @override
  String get fieldPatientHelper => 'Only if the service was for someone else (e.g. a family member)';

  @override
  String get saveRecord => 'Save record';

  @override
  String get recordSaved => 'Record saved.';

  @override
  String get recordQueued => 'No connection — the record is saved on this device and will sync automatically.';

  @override
  String get recordUpdated => 'Record updated.';

  @override
  String get draftRestored => 'Your unsaved entry was restored.';

  @override
  String get discardDraft => 'Discard';

  @override
  String get recordDetailsTitle => 'Record details';

  @override
  String get recordCustomer => 'Customer';

  @override
  String get recordService => 'Service';

  @override
  String get recordPayment => 'Payment';

  @override
  String get recordWhen => 'Date & time';

  @override
  String get recordAddressAtVisit => 'Address at time of visit';

  @override
  String get recordAreaAtVisit => 'Area at time of visit';

  @override
  String get recordPatient => 'Patient';

  @override
  String get recordCreatedAt => 'Created';

  @override
  String get recordLegacyRef => 'Excel row no.';

  @override
  String get recordImported => 'Imported from Excel';

  @override
  String get recordPendingSync => 'Waiting to sync';

  @override
  String get recordSyncFailed => 'Sync failed';

  @override
  String get recordNoTime => 'Time not recorded';

  @override
  String get archiveRecord => 'Archive record';

  @override
  String get archiveRecordConfirm =>
      'Archive this record? It will be hidden from history and totals but kept for audit.';

  @override
  String get recordArchived => 'Record archived.';

  @override
  String get openCustomer => 'Open customer';

  @override
  String nurseLabel(String name) {
    return 'Nurse: $name';
  }

  @override
  String get pendingTitle => 'Waiting to sync';

  @override
  String get pendingEmpty => 'Everything is synced.';

  @override
  String get pendingBody =>
      'These records are saved on this device. They are sent automatically when the connection returns.';

  @override
  String get pendingDiscard => 'Discard record';

  @override
  String get pendingDiscardConfirm => 'Discard this unsynced record? It has not reached the server and will be lost.';

  @override
  String pendingFailedHint(String reason) {
    return 'The server rejected this record: $reason';
  }

  @override
  String get nursesTitle => 'Nurses';

  @override
  String get nursesEmpty => 'No nurses yet. Add the nurses who provide services.';

  @override
  String get addNurse => 'Add nurse';

  @override
  String get editNurse => 'Edit nurse';

  @override
  String get nurseName => 'Name';

  @override
  String get nurseSaved => 'Nurse saved.';

  @override
  String get servicesTitle => 'Services';

  @override
  String get servicesEmpty => 'No services yet. Add the services you provide.';

  @override
  String get addService => 'Add service';

  @override
  String get editService => 'Edit service';

  @override
  String get serviceName => 'Service name';

  @override
  String get serviceDefaultPrice => 'Default price';

  @override
  String get serviceDefaultPriceHelper => 'Leave empty if the price varies. Changing it never affects past records.';

  @override
  String get serviceVariablePrice => 'Variable price';

  @override
  String get serviceSaved => 'Service saved.';

  @override
  String get areasTitle => 'Areas';

  @override
  String get areasEmpty => 'No areas yet.';

  @override
  String get addArea => 'Add area';

  @override
  String get editArea => 'Edit area';

  @override
  String get areaSaved => 'Area saved.';

  @override
  String get showInactive => 'Show inactive';

  @override
  String get statusActiveHelper => 'Inactive items stay in history but cannot be chosen for new records.';

  @override
  String deactivateConfirm(String name) {
    return 'Deactivate “$name”? It stays in past records but can no longer be selected.';
  }

  @override
  String get pickerNoResults => 'No matches';

  @override
  String pickerAddNamed(String name) {
    return 'Add “$name”';
  }

  @override
  String get pickerSearch => 'Search';

  @override
  String get moreTitle => 'More';

  @override
  String get moreManage => 'Manage';

  @override
  String get moreData => 'Data';

  @override
  String get moreAccount => 'Account';

  @override
  String get importTitle => 'Import from Excel';

  @override
  String get exportTitle => 'Export to Excel';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageSystem => 'System default';

  @override
  String get settingsAbout => 'About Sanad';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsPrivacy =>
      'Customer data is stored in the cloud database and protected by role-based access. Records saved offline are encrypted on this device until they sync.';

  @override
  String get userProfileTitle => 'My profile';

  @override
  String get profileName => 'Name';

  @override
  String get profileEmail => 'Email';

  @override
  String get profileRole => 'Role';

  @override
  String get roleAdmin => 'Administrator';

  @override
  String get roleStaff => 'Staff';

  @override
  String get changePassword => 'Change password';

  @override
  String get profileSaved => 'Profile updated.';

  @override
  String get usersTitle => 'Users';

  @override
  String get inviteUser => 'Invite user';

  @override
  String inviteSent(String email) {
    return 'Invitation sent to $email.';
  }

  @override
  String get inviteRole => 'Role';

  @override
  String get userYou => 'You';

  @override
  String get makeAdmin => 'Make administrator';

  @override
  String get makeStaff => 'Make staff';

  @override
  String get userUpdated => 'User updated.';

  @override
  String userDeactivateConfirm(String name) {
    return 'Deactivate $name? They will be signed out and unable to sign in.';
  }

  @override
  String get pendingSyncMenu => 'Waiting to sync';

  @override
  String get importIntro =>
      'Bring existing records from an Excel workbook into Sanad. Nothing is saved until you review the preview and confirm.';

  @override
  String get importChooseFile => 'Choose Excel file';

  @override
  String get importReading => 'Reading workbook…';

  @override
  String get importStepFile => 'File';

  @override
  String get importStepColumns => 'Columns';

  @override
  String get importStepPreview => 'Preview';

  @override
  String get importSheet => 'Sheet';

  @override
  String get importColumnsTitle => 'Check column mapping';

  @override
  String get importColumnsBody =>
      'Sanad matched these columns automatically. Fix any that are wrong before continuing.';

  @override
  String get importNotMapped => 'Not in file';

  @override
  String importHeaderRow(int row) {
    return 'Header found on row $row';
  }

  @override
  String get importBuildPreview => 'Build preview';

  @override
  String importMissingRequired(String fields) {
    return 'Map the required columns: $fields';
  }

  @override
  String get importPreviewTitle => 'Review before importing';

  @override
  String get importRecords => 'Records to import';

  @override
  String get importSkipped => 'Rows skipped';

  @override
  String get importNewCustomers => 'New customers';

  @override
  String get importMatchedCustomers => 'Existing customers';

  @override
  String get importNewAreas => 'New areas';

  @override
  String get importNewNurses => 'New nurses';

  @override
  String get importNewServices => 'New services';

  @override
  String get importRevenue => 'Total amount';

  @override
  String get importDateRange => 'Dates';

  @override
  String importNoPayment(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records have no payment method in the file. They will be marked “Not recorded”.',
      one: '1 record has no payment method in the file. It will be marked “Not recorded”.',
    );
    return '$_temp0';
  }

  @override
  String importReviewCustomers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count customers have no valid phone number and will be flagged for review.',
      one: '1 customer has no valid phone number and will be flagged for review.',
    );
    return '$_temp0';
  }

  @override
  String get importAlreadyImported =>
      'Data has been imported before. If this is a corrected version of the same file, roll back the earlier import first to avoid duplicates.';

  @override
  String get importWarnings => 'Warnings (rows are imported)';

  @override
  String get importErrors => 'Problems (rows are skipped)';

  @override
  String get importEntities => 'Names found in the file';

  @override
  String get importNew => 'new';

  @override
  String importRowsLabel(String rows) {
    return 'Rows: $rows';
  }

  @override
  String importConfirm(int count) {
    return 'Import $count records';
  }

  @override
  String get importConfirmTitle => 'Start import?';

  @override
  String get importConfirmBody =>
      'The import runs as a single transaction: either everything is saved or nothing is. You can roll it back later from the import history.';

  @override
  String get importRunning => 'Importing…';

  @override
  String get importDoneTitle => 'Import complete';

  @override
  String importDoneBody(int records, int customers, int matched) {
    return '$records records imported, $customers new customers created, $matched existing customers matched.';
  }

  @override
  String get importHistory => 'Import history';

  @override
  String get importHistoryEmpty => 'No imports yet.';

  @override
  String get importRolledBack => 'Rolled back';

  @override
  String get importRollback => 'Roll back';

  @override
  String importRollbackConfirm(String file) {
    return 'Roll back “$file”? Records created by this import are removed. Customers or names that were used afterwards are kept.';
  }

  @override
  String get importRollbackDone => 'Import rolled back.';

  @override
  String importBatchSummary(int count, String date) {
    return '$count records · $date';
  }

  @override
  String get importStartOver => 'Choose another file';

  @override
  String get importUnspecifiedName => 'Unspecified';

  @override
  String importShowRows(String rows) {
    return 'Rows $rows';
  }

  @override
  String get importField_legacyRef => 'Record no.';

  @override
  String get importField_serviceDate => 'Service date';

  @override
  String get importField_serviceTime => 'Service time';

  @override
  String get importField_customerName => 'Customer name';

  @override
  String get importField_phone => 'Phone';

  @override
  String get importField_address => 'Address';

  @override
  String get importField_area => 'Area';

  @override
  String get importField_nurse => 'Nurse';

  @override
  String get importField_service => 'Service';

  @override
  String get importField_price => 'Price';

  @override
  String get importField_paymentMethod => 'Payment method';

  @override
  String get importField_patientName => 'Patient (if different)';

  @override
  String get importField_notes => 'Notes';

  @override
  String get importField_status => 'Status (kept for reference)';

  @override
  String get importIssue_datemissing => 'Missing date';

  @override
  String get importIssue_dateinvalid => 'Unreadable date';

  @override
  String get importIssue_pricemissing => 'Missing price';

  @override
  String get importIssue_priceinvalid => 'Unreadable price';

  @override
  String get importIssue_customermissing => 'No customer name or phone';

  @override
  String get importIssue_dateambiguous => 'Day/month order assumed (day first)';

  @override
  String get importIssue_timemissing => 'No time — imported without a time';

  @override
  String get importIssue_timeinvalid => 'Unreadable time — imported without a time';

  @override
  String get importIssue_timeambiguous => 'AM/PM unknown — imported without a time';

  @override
  String get importIssue_phoneinvalid => 'Invalid or missing phone — customer flagged for review';

  @override
  String get importIssue_phoneshared => 'Same phone, different name — kept as patient name';

  @override
  String get importIssue_nursemissing => 'No nurse — set to “Unspecified”';

  @override
  String get importIssue_servicemissing => 'No service — set to “Unspecified”';

  @override
  String get importIssue_areamissing => 'No area — set to “Unspecified”';

  @override
  String get importIssue_pricecleaned => 'Price written as text — number extracted';

  @override
  String get importIssue_paymentunknown => 'Unrecognised payment method';

  @override
  String get importIssue_customerdetailschanged => 'Address/area differs from other visits — kept on this record';

  @override
  String get exportIntro => 'Create a formatted Excel workbook for administration, accounting or backup.';

  @override
  String get exportPeriod => 'Records period';

  @override
  String get exportAllTime => 'All time';

  @override
  String get exportSheets => 'Sheets to include';

  @override
  String get exportSheetRecords => 'Records (with customer details)';

  @override
  String get exportSheetCustomers => 'Customers';

  @override
  String get exportSheetNurses => 'Nurses';

  @override
  String get exportSheetServices => 'Services';

  @override
  String get exportSheetAreas => 'Areas';

  @override
  String get exportCreate => 'Create Excel file';

  @override
  String get exportWorking => 'Preparing workbook…';

  @override
  String get exportReady => 'Workbook ready';

  @override
  String exportReadyBody(int count, String file) {
    return '$count records exported to $file.';
  }

  @override
  String get exportShare => 'Share / save file';

  @override
  String get exportSheetTotal => 'Total';

  @override
  String get exportRecordId => 'Record ID';

  @override
  String get validationRequired => 'This field is required.';

  @override
  String get validationTooLong => 'This is too long.';

  @override
  String get validationInvalidPhone => 'Enter a valid Egyptian phone number, e.g. 01012345678.';

  @override
  String get validationInvalidPrice => 'Enter a valid amount.';

  @override
  String get validationNegativePrice => 'The price cannot be negative.';

  @override
  String get validationPriceTooHigh => 'This amount is too high.';

  @override
  String get validationInvalidEmail => 'Enter a valid email address.';

  @override
  String get validationPasswordTooShort => 'Use at least 8 characters.';

  @override
  String get validationPasswordsDoNotMatch => 'Passwords do not match.';

  @override
  String get validationFutureDate => 'The date cannot be in the future.';

  @override
  String get failureNetwork => 'No internet connection. Check your connection and try again.';

  @override
  String get failureServer => 'Something went wrong on the server. Please try again.';

  @override
  String get failureSessionExpired => 'Your session has expired. Please sign in again.';

  @override
  String get failurePermission => 'You do not have permission to do this.';

  @override
  String get failureDuplicatePhone => 'This phone number is already registered.';

  @override
  String get failureDuplicateName => 'This name already exists.';

  @override
  String get failureDuplicateEmail => 'A user with this email already exists.';

  @override
  String get failureDuplicateFile => 'This file has already been imported.';

  @override
  String get failureDuplicate => 'This value already exists.';

  @override
  String get failureValidation => 'Please check the highlighted fields.';

  @override
  String get failureNotFound => 'This item no longer exists.';

  @override
  String get failureUnexpected => 'Something went wrong. Please try again.';

  @override
  String get failureFileUnreadable => 'This file could not be read. Make sure it is an Excel (.xlsx) file.';

  @override
  String get failureFileNoSheets => 'The workbook has no sheets.';

  @override
  String get failureFileHeaderNotFound =>
      'No sheet with recognisable columns (date, customer name or phone, price) was found.';

  @override
  String get failureFileEmpty => 'There is nothing to import or export.';

  @override
  String get failureFileWrite => 'The Excel file could not be created.';

  @override
  String get failureAuthInvalid => 'Incorrect email or password.';

  @override
  String get failureAuthDisabled => 'This account has been deactivated. Contact your administrator.';

  @override
  String get failureAuthNotConfirmed => 'Confirm your email address first, then sign in.';

  @override
  String get failureAuthWeakPassword => 'Choose a stronger password.';

  @override
  String get failureAuthRateLimited => 'Too many attempts. Wait a moment and try again.';

  @override
  String get failureAuthUnknown => 'Sign-in failed. Please try again.';

  @override
  String get failureRuleNurseInactive => 'This nurse is no longer active. Choose another nurse.';

  @override
  String get failureRuleServiceInactive => 'This service is no longer active. Choose another service.';

  @override
  String get failureRuleCustomerArchived => 'This customer is archived.';

  @override
  String get failureRuleAlreadyImported => 'This file has already been imported.';

  @override
  String get failureRuleBatchNotFound => 'This import was already rolled back.';

  @override
  String get failureRuleSelfDemotion => 'You cannot remove your own administrator access.';

  @override
  String get failureRuleInUse => 'This item is in use and cannot be removed.';
}
