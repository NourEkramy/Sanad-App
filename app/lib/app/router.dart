import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/files/file_gateway.dart';
import '../features/areas/domain/entities/area.dart';
import '../features/areas/domain/usecases/area_usecases.dart';
import '../features/care_services/domain/entities/care_service.dart';
import '../features/care_services/domain/usecases/care_service_usecases.dart';
import '../features/customers/domain/entities/customer.dart';
import '../features/customers/domain/usecases/customer_usecases.dart';
import '../features/customers/presentation/cubit/customer_form_cubit.dart';
import '../features/customers/presentation/cubit/customer_profile_cubit.dart';
import '../features/customers/presentation/cubit/customer_search_cubit.dart';
import '../features/customers/presentation/cubit/customers_list_cubit.dart';
import '../features/customers/presentation/pages/customer_form_page.dart';
import '../features/customers/presentation/pages/customer_profile_page.dart';
import '../features/customers/presentation/pages/customers_page.dart';
import '../features/customers/presentation/pages/search_customer_page.dart';
import '../features/dashboard/presentation/dashboard_cubit.dart';
import '../features/dashboard/presentation/home_page.dart';
import '../features/excel/presentation/export_page.dart';
import '../features/excel/presentation/import_cubit.dart';
import '../features/excel/presentation/import_page.dart';
import '../features/nurses/domain/entities/nurse.dart';
import '../features/nurses/domain/usecases/nurse_usecases.dart';
import '../features/records/domain/entities/service_record.dart';
import '../features/records/presentation/cubit/record_details_cubit.dart';
import '../features/records/presentation/cubit/record_form_cubit.dart';
import '../features/records/presentation/cubit/records_list_cubit.dart';
import '../features/records/presentation/pages/record_details_page.dart';
import '../features/records/presentation/pages/record_form_page.dart';
import '../features/records/presentation/pages/records_page.dart';
import '../features/settings/presentation/catalog_cubit.dart';
import '../features/settings/presentation/catalog_pages.dart';
import '../features/settings/presentation/more_pages.dart';
import '../features/sheet/presentation/sheet_page.dart';
import 'di.dart';
import 'routes.dart';
import 'shell.dart';

GoRouter buildRouter() {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');

  Customer? customerExtra(GoRouterState s) => s.extra is Customer ? s.extra! as Customer : null;
  ServiceRecord? recordExtra(GoRouterState s) => s.extra is ServiceRecord ? s.extra! as ServiceRecord : null;

  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: Routes.home,
    routes: [
      // Full-screen flows above the tab bar.
      GoRoute(
        path: Routes.search,
        parentNavigatorKey: rootKey,
        builder: (_, s) => BlocProvider(
          create: (_) => CustomerSearchCubit(sl()),
          child: SearchCustomerPage(
            forRecord: s.uri.queryParameters['for'] == 'record',
            initialQuery: s.uri.queryParameters['q'],
          ),
        ),
      ),

      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) => BlocProvider(create: (_) => DashboardCubit(sl())..load(), child: const HomePage()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.customers,
                builder: (_, s) => BlocProvider(
                  key: ValueKey(s.uri.queryParameters['review']),
                  create: (_) =>
                      CustomersListCubit(sl(), needsReviewOnly: s.uri.queryParameters['review'] == '1')..load(),
                  child: const CustomersPage(),
                ),
                routes: [
                  GoRoute(
                    path: 'new',
                    parentNavigatorKey: rootKey,
                    builder: (_, s) => BlocProvider(
                      create: (_) => _customerForm()..loadAreas(),
                      child: CustomerFormPage(
                        initialPhone: s.uri.queryParameters['phone'],
                        thenAddRecord: s.uri.queryParameters['next'] == 'record',
                      ),
                    ),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (_, s) => BlocProvider(
                      create: (_) => CustomerProfileCubit(
                        customerId: s.pathParameters['id']!,
                        getCustomer: sl(),
                        getHistory: sl(),
                        setArchived: sl(),
                        initial: customerExtra(s),
                      )..load(),
                      child: const CustomerProfilePage(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'saved',
                        parentNavigatorKey: rootKey,
                        builder: (_, s) => _WithCustomer(
                          id: s.pathParameters['id']!,
                          initial: customerExtra(s),
                          builder: (c) => CustomerSavedPage(customer: c),
                        ),
                      ),
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootKey,
                        builder: (_, s) => _WithCustomer(
                          id: s.pathParameters['id']!,
                          initial: customerExtra(s),
                          builder: (c) => BlocProvider(
                            create: (_) => _customerForm(editing: c)..loadAreas(),
                            child: CustomerFormPage(editing: c),
                          ),
                        ),
                      ),
                      GoRoute(
                        path: 'records/new',
                        parentNavigatorKey: rootKey,
                        builder: (_, s) => _WithCustomer(
                          id: s.pathParameters['id']!,
                          initial: customerExtra(s),
                          builder: (c) => BlocProvider(
                            create: (_) => _recordForm(c)..init(),
                            child: RecordFormPage(thenProfile: s.uri.queryParameters['then'] == 'profile'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.records,
                builder: (_, _) => BlocProvider(
                  create: (_) => RecordsListCubit(
                    listRecords: sl(),
                    getTotals: sl(),
                    getNurses: sl(),
                    getServices: sl(),
                    getAreas: sl(),
                  )..init(),
                  child: const RecordsPage(),
                ),
                routes: [
                  GoRoute(
                    path: ':id',
                    parentNavigatorKey: rootKey,
                    builder: (_, s) => BlocProvider(
                      create: (_) => RecordDetailsCubit(
                        recordId: s.pathParameters['id']!,
                        getRecord: sl(),
                        archive: sl(),
                        initial: recordExtra(s),
                      )..load(),
                      child: const RecordDetailsPage(),
                    ),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootKey,
                        builder: (_, s) {
                          final record = recordExtra(s);
                          if (record == null) return const _Missing();
                          return _WithCustomer(
                            id: record.customerId,
                            builder: (c) => BlocProvider(
                              create: (_) => _recordForm(c, editing: record)..init(),
                              child: const RecordFormPage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.more,
                builder: (_, _) => const MorePage(),
                routes: [
                  GoRoute(
                    path: 'nurses',
                    builder: (_, _) => BlocProvider(
                      create: (_) => CatalogCubit<Nurse>(sl<GetNurses>().call)..load(),
                      child: NursesPage(saveNurse: sl()),
                    ),
                  ),
                  GoRoute(
                    path: 'services',
                    builder: (_, _) => BlocProvider(
                      create: (_) => CatalogCubit<CareService>(sl<GetCareServices>().call)..load(),
                      child: ServicesPage(saveService: sl()),
                    ),
                  ),
                  GoRoute(
                    path: 'areas',
                    builder: (_, _) => BlocProvider(
                      create: (_) => CatalogCubit<Area>(sl<GetAreas>().call)..load(),
                      child: AreasPage(createArea: sl(), updateArea: sl()),
                    ),
                  ),
                  GoRoute(
                    path: 'import',
                    builder: (_, _) => BlocProvider(
                      create: (_) => ImportCubit(
                        files: const PlatformFileGateway(),
                        openWorkbook: sl(),
                        prepareImport: sl(),
                        commitImport: sl(),
                        listBatches: sl(),
                        rollback: sl(),
                      )..loadBatches(),
                      child: const ImportPage(),
                    ),
                  ),
                  GoRoute(
                    path: 'export',
                    builder: (_, _) => BlocProvider(
                      create: (_) => ExportCubit(sl(), const PlatformFileGateway()),
                      child: const ExportPage(),
                    ),
                  ),
                  GoRoute(path: 'sheet', builder: (_, _) => const SheetPage()),
                  GoRoute(path: 'settings', builder: (_, _) => const SettingsPage()),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

CustomerFormCubit _customerForm({Customer? editing}) =>
    CustomerFormCubit(getAreas: sl(), createArea: sl(), createCustomer: sl(), updateCustomer: sl(), editing: editing);

RecordFormCubit _recordForm(Customer customer, {ServiceRecord? editing}) => RecordFormCubit(
  customer: customer,
  editing: editing,
  getNurses: sl(),
  getServices: sl(),
  saveNurse: sl(),
  saveService: sl(),
  addRecord: sl(),
  updateRecord: sl(),
  drafts: sl(),
);

/// Uses the customer passed with the navigation, or loads it (deep links,
/// web refresh).
class _WithCustomer extends StatelessWidget {
  const _WithCustomer({required this.id, required this.builder, this.initial});

  final String id;
  final Customer? initial;
  final Widget Function(Customer) builder;

  @override
  Widget build(BuildContext context) {
    final customer = initial;
    if (customer != null) return builder(customer);
    return FutureBuilder(
      future: sl<GetCustomer>()(id),
      builder: (context, snapshot) {
        final loaded = snapshot.data?.valueOrNull;
        if (loaded != null) return builder(loaded);
        if (snapshot.connectionState == ConnectionState.done) return const _Missing();
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _Missing extends StatelessWidget {
  const _Missing();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: Center(child: Text(MaterialLocalizations.of(context).alertDialogLabel)),
  );
}
