import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/config/env.dart';
import '../core/network/connectivity_service.dart';
import '../core/storage/secure_session_storage.dart';
import '../core/storage/secure_store.dart';
import '../features/areas/data/supabase_area_repository.dart';
import '../features/areas/domain/repositories/area_repository.dart';
import '../features/areas/domain/usecases/area_usecases.dart';
import '../features/auth/data/supabase_auth_repository.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/domain/usecases/auth_usecases.dart';
import '../features/care_services/data/supabase_care_service_repository.dart';
import '../features/care_services/domain/repositories/care_service_repository.dart';
import '../features/care_services/domain/usecases/care_service_usecases.dart';
import '../features/customers/data/supabase_customer_repository.dart';
import '../features/customers/domain/repositories/customer_repository.dart';
import '../features/customers/domain/usecases/customer_usecases.dart';
import '../features/dashboard/data/supabase_dashboard_repository.dart';
import '../features/dashboard/domain/dashboard.dart';
import '../features/excel/data/excel_workbook_codec.dart';
import '../features/excel/data/supabase_excel_repositories.dart';
import '../features/excel/domain/excel_repositories.dart';
import '../features/excel/domain/excel_usecases.dart';
import '../features/nurses/data/supabase_nurse_repository.dart';
import '../features/nurses/domain/repositories/nurse_repository.dart';
import '../features/nurses/domain/usecases/nurse_usecases.dart';
import '../features/records/data/local_record_stores.dart';
import '../features/records/data/supabase_record_repository.dart';
import '../features/records/domain/repositories/record_repository.dart';
import '../features/records/domain/usecases/record_usecases.dart';
import '../features/users/data/supabase_user_repository.dart';
import '../features/users/domain/user_management.dart';

/// Service locator. Only the composition root (this file, `app.dart` and
/// route builders) reads from it; everything else receives dependencies
/// through constructors.
final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final store = SecureStore();
  sl
    ..registerSingleton<KeyValueStore>(store)
    ..registerLazySingleton<ConnectivityService>(ConnectivityPlusService.new);

  if (!Env.isConfigured) return;

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseKey,
    authOptions: FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
      localStorage: SecureSessionStorage(store),
      pkceAsyncStorage: SecurePkceStorage(store),
    ),
    debug: false,
  );
  final client = Supabase.instance.client;

  // Repositories
  sl
    ..registerSingleton<SupabaseClient>(client)
    ..registerLazySingleton<AuthRepository>(() => SupabaseAuthRepository(client, store))
    ..registerLazySingleton<CustomerRepository>(() => SupabaseCustomerRepository(client))
    ..registerLazySingleton<RecordRepository>(() => SupabaseRecordRepository(client))
    ..registerLazySingleton<PendingRecordStore>(() => SecurePendingRecordStore(store))
    ..registerLazySingleton<RecordDraftStore>(() => SecureRecordDraftStore(store))
    ..registerLazySingleton<AreaRepository>(() => SupabaseAreaRepository(client))
    ..registerLazySingleton<NurseRepository>(() => SupabaseNurseRepository(client))
    ..registerLazySingleton<CareServiceRepository>(() => SupabaseCareServiceRepository(client))
    ..registerLazySingleton<DashboardRepository>(() => SupabaseDashboardRepository(client))
    ..registerLazySingleton<UserRepository>(() => SupabaseUserRepository(client))
    ..registerLazySingleton<ImportRepository>(() => SupabaseImportRepository(client))
    ..registerLazySingleton<ExportRepository>(() => SupabaseExportRepository(client))
    ..registerLazySingleton<WorkbookCodec>(() => const ExcelWorkbookCodec());

  // Use cases
  const uuid = Uuid();
  sl
    ..registerLazySingleton(() => SignIn(sl()))
    ..registerLazySingleton(() => SendPasswordReset(sl()))
    ..registerLazySingleton(() => UpdatePassword(sl()))
    ..registerLazySingleton(() => GetDashboardStats(sl()))
    ..registerLazySingleton(() => SearchCustomers(sl()))
    ..registerLazySingleton(() => CreateCustomer(sl()))
    ..registerLazySingleton(() => UpdateCustomer(sl()))
    ..registerLazySingleton(() => GetCustomer(sl()))
    ..registerLazySingleton(() => ListCustomers(sl()))
    ..registerLazySingleton(() => SetCustomerArchived(sl()))
    ..registerLazySingleton(() => AddServiceRecord(sl(), sl(), uuid.v4))
    ..registerLazySingleton(() => SyncPendingRecords(sl(), sl()))
    ..registerLazySingleton(() => GetCustomerHistory(sl(), sl()))
    ..registerLazySingleton(() => ListRecords(sl()))
    ..registerLazySingleton(() => GetRecordTotals(sl()))
    ..registerLazySingleton(() => GetRecord(sl(), sl()))
    ..registerLazySingleton(() => UpdateServiceRecord(sl()))
    ..registerLazySingleton(() => ArchiveServiceRecord(sl()))
    ..registerLazySingleton(() => DiscardPendingRecord(sl()))
    ..registerLazySingleton(() => GetAreas(sl()))
    ..registerLazySingleton(() => CreateArea(sl()))
    ..registerLazySingleton(() => UpdateArea(sl()))
    ..registerLazySingleton(() => GetNurses(sl()))
    ..registerLazySingleton(() => SaveNurse(sl()))
    ..registerLazySingleton(() => SetNurseActive(sl()))
    ..registerLazySingleton(() => GetCareServices(sl()))
    ..registerLazySingleton(() => SaveCareService(sl()))
    ..registerLazySingleton(() => SetCareServiceActive(sl()))
    ..registerLazySingleton(() => ListUsers(sl()))
    ..registerLazySingleton(() => ChangeUserAccess(sl()))
    ..registerLazySingleton(() => InviteUser(sl()))
    ..registerLazySingleton(() => OpenWorkbook(sl()))
    ..registerLazySingleton(() => PrepareImport(sl()))
    ..registerLazySingleton(() => CommitImport(sl()))
    ..registerLazySingleton(() => ListImportBatches(sl()))
    ..registerLazySingleton(() => RollbackImport(sl()))
    ..registerLazySingleton(() => ExportWorkbook(sl(), sl()));
}
