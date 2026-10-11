import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import '../core/database/database_opener.dart';
import '../core/database/sanad_database.dart';
import '../core/network/connectivity_service.dart';
import '../core/storage/secure_store.dart';
import '../features/areas/data/local_area_repository.dart';
import '../features/areas/domain/repositories/area_repository.dart';
import '../features/areas/domain/usecases/area_usecases.dart';
import '../features/care_services/data/local_care_service_repository.dart';
import '../features/care_services/domain/repositories/care_service_repository.dart';
import '../features/care_services/domain/usecases/care_service_usecases.dart';
import '../features/customers/data/local_customer_repository.dart';
import '../features/customers/domain/repositories/customer_repository.dart';
import '../features/customers/domain/usecases/customer_usecases.dart';
import '../features/dashboard/data/local_dashboard_repository.dart';
import '../features/dashboard/domain/dashboard.dart';
import '../features/excel/data/excel_workbook_codec.dart';
import '../features/excel/data/local_excel_repositories.dart';
import '../features/excel/domain/excel_repositories.dart';
import '../features/excel/domain/excel_usecases.dart';
import '../features/nurses/data/local_nurse_repository.dart';
import '../features/nurses/domain/repositories/nurse_repository.dart';
import '../features/nurses/domain/usecases/nurse_usecases.dart';
import '../features/records/data/local_record_repository.dart';
import '../features/records/data/record_draft_store.dart';
import '../features/records/domain/repositories/record_repository.dart';
import '../features/records/domain/usecases/record_usecases.dart';
import '../features/sheet/data/apps_script_connector.dart';
import '../features/sheet/data/local_sheet_store.dart';
import '../features/sheet/domain/sheet_link.dart';
import '../features/sheet/domain/sheet_sync.dart';
import '../features/sheet/domain/sheet_usecases.dart';

/// Service locator. Only the composition root (this file, `app.dart` and
/// route builders) reads from it; everything else receives dependencies
/// through constructors.
final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final store = SecureStore();
  final db = await openSanadDatabase();

  // Infrastructure and repositories
  sl
    ..registerSingleton<KeyValueStore>(store)
    ..registerSingleton<SanadDatabase>(db)
    ..registerLazySingleton<ConnectivityService>(ConnectivityPlusService.new)
    ..registerLazySingleton<CustomerRepository>(() => LocalCustomerRepository(db))
    ..registerLazySingleton<RecordRepository>(() => LocalRecordRepository(db))
    ..registerLazySingleton<RecordDraftStore>(() => SecureRecordDraftStore(store))
    ..registerLazySingleton<AreaRepository>(() => LocalAreaRepository(db))
    ..registerLazySingleton<NurseRepository>(() => LocalNurseRepository(db))
    ..registerLazySingleton<CareServiceRepository>(() => LocalCareServiceRepository(db))
    ..registerLazySingleton<DashboardRepository>(() => LocalDashboardRepository(db))
    ..registerLazySingleton<ImportRepository>(() => LocalImportRepository(db))
    ..registerLazySingleton<ExportRepository>(() => LocalExportRepository(db))
    ..registerLazySingleton<WorkbookCodec>(() => const ExcelWorkbookCodec())
    ..registerLazySingleton<SheetConnector>(AppsScriptConnector.new)
    ..registerLazySingleton<SheetStore>(() => LocalSheetStore(db))
    ..registerLazySingleton(() => SheetLinkStore(store));

  // Use cases
  const uuid = Uuid();
  sl
    ..registerLazySingleton(() => GetDashboardStats(sl()))
    ..registerLazySingleton(() => SearchCustomers(sl()))
    ..registerLazySingleton(() => CreateCustomer(sl()))
    ..registerLazySingleton(() => UpdateCustomer(sl()))
    ..registerLazySingleton(() => GetCustomer(sl()))
    ..registerLazySingleton(() => ListCustomers(sl()))
    ..registerLazySingleton(() => SetCustomerArchived(sl()))
    ..registerLazySingleton(() => AddServiceRecord(sl(), uuid.v4))
    ..registerLazySingleton(() => GetCustomerHistory(sl()))
    ..registerLazySingleton(() => ListRecords(sl()))
    ..registerLazySingleton(() => GetRecordTotals(sl()))
    ..registerLazySingleton(() => GetRecord(sl()))
    ..registerLazySingleton(() => UpdateServiceRecord(sl()))
    ..registerLazySingleton(() => ArchiveServiceRecord(sl()))
    ..registerLazySingleton(() => GetAreas(sl()))
    ..registerLazySingleton(() => CreateArea(sl()))
    ..registerLazySingleton(() => UpdateArea(sl()))
    ..registerLazySingleton(() => GetNurses(sl()))
    ..registerLazySingleton(() => SaveNurse(sl()))
    ..registerLazySingleton(() => SetNurseActive(sl()))
    ..registerLazySingleton(() => GetCareServices(sl()))
    ..registerLazySingleton(() => SaveCareService(sl()))
    ..registerLazySingleton(() => SetCareServiceActive(sl()))
    ..registerLazySingleton(() => OpenWorkbook(sl()))
    ..registerLazySingleton(() => PrepareImport(sl()))
    ..registerLazySingleton(() => CommitImport(sl()))
    ..registerLazySingleton(() => ListImportBatches(sl()))
    ..registerLazySingleton(() => RollbackImport(sl()))
    ..registerLazySingleton(() => ExportWorkbook(sl(), sl()))
    ..registerLazySingleton(() => ConnectSheet(sl(), sl(), sl()))
    ..registerLazySingleton(() => LinkSheet(sl(), sl(), sl()))
    ..registerLazySingleton(() => SyncSheet(sl(), sl(), sl()));
}
