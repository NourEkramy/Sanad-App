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
  String get greetingMorning => 'Good morning';

  @override
  String get greetingEvening => 'Good evening';

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
      'Your data is stored only on this phone. If you connect Google Drive, a backup is kept in your own Drive, visible only to you until you share it.';

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
  String get validationFutureDate => 'The date cannot be in the future.';

  @override
  String get failureNetwork =>
      'No internet connection. Your data is safe on this phone; the backup will run when you are back online.';

  @override
  String get failureDuplicatePhone => 'This phone number is already registered.';

  @override
  String get failureDuplicateName => 'This name already exists.';

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
  String get failureRuleInUse => 'This item is in use and cannot be removed.';

  @override
  String get moreApp => 'App';

  @override
  String get failureServer => 'Google Drive answered with an error. Please try again.';

  @override
  String get failureFileNotABackup => 'This file is not a Sanad backup.';

  @override
  String get failureBackupCanceled => 'Google sign-in was canceled.';

  @override
  String get failureBackupNotAuthorized =>
      'Google Drive access was not granted. Tap Connect and allow access to the files Sanad creates.';

  @override
  String get failureBackupNotConfigured =>
      'Google Drive is not set up correctly for this copy of the app. In Google Cloud check: the Google Drive API is enabled, and an Android client exists with package com.sanad.sanad and the SHA-1 of this app.';

  @override
  String get failureBackupNoBackup => 'No Sanad backup was found in this Google Drive.';

  @override
  String get backupTitle => 'Google Drive backup';

  @override
  String get backupIntro =>
      'Your data is stored on this phone. Connect Google Drive to keep a copy in your own Drive: Sanad.xlsx (all sheets, ready to open and share) and a full backup to restore on a new phone. After every change the copy is updated automatically.';

  @override
  String get backupConnect => 'Connect Google Drive';

  @override
  String get backupAccount => 'Google account';

  @override
  String get backupLast => 'Last backup';

  @override
  String get backupNever => 'Not backed up yet';

  @override
  String get backupUpToDate => 'Everything is backed up';

  @override
  String get backupPendingChanges => 'Changes waiting to be backed up';

  @override
  String get backupNotUpToDate => 'The last backup did not complete';

  @override
  String get backupInProgress => 'Backing up…';

  @override
  String get backupRestoring => 'Restoring…';

  @override
  String get backupNow => 'Back up now';

  @override
  String get backupRestore => 'Restore from Google Drive';

  @override
  String get backupRestoreConfirmTitle => 'Replace the data on this phone?';

  @override
  String get backupRestoreConfirm =>
      'All customers, records, nurses, services and areas on this phone will be replaced by the backup in Google Drive.';

  @override
  String get backupRestored => 'Data restored from Google Drive';

  @override
  String get backupFoundTitle => 'A backup is already in this Google Drive';

  @override
  String backupFoundBody(String date) {
    return 'Sanad found a backup from $date. Restore it to this phone, or keep this phone\'s data and replace the backup.';
  }

  @override
  String get backupKeepDevice => 'Keep this phone\'s data';

  @override
  String get backupKeepDeviceConfirm =>
      'The backup in Google Drive will be replaced by the data on this phone. Earlier versions stay in the file\'s version history in Drive.';

  @override
  String get backupDisconnect => 'Disconnect Google Drive';

  @override
  String get backupDisconnectConfirm => 'Automatic backups will stop. Files already in Google Drive stay there.';

  @override
  String get backupWhere =>
      'Files are in Google Drive › Sanad. Open Sanad.xlsx there to view it or share it with others. Drive keeps earlier versions of each file.';

  @override
  String get backupUnsupported =>
      'Google Drive backup works in the Android app. Here, use Export to Excel to save a copy.';

  @override
  String get backupBannerConnect => 'Back up your data to Google Drive';

  @override
  String get backupBannerFailed => 'The Google Drive backup did not complete';

  @override
  String get backupBannerAction => 'Open';

  @override
  String get failureBackupSignInFailed => 'Google sign-in failed. Please try again.';
}
