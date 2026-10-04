import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/features/customers/domain/usecases/customer_usecases.dart';
import 'package:sanad/features/customers/presentation/cubit/customer_search_cubit.dart';
import 'package:sanad/features/customers/presentation/pages/search_customer_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeCustomerRepository repo;

  setUp(() {
    repo = FakeCustomerRepository()
      ..add(customer())
      ..add(customer(id: 'c2', name: 'Mona Adel', phone: '01012999999'));
  });

  group('CustomerSearchCubit', () {
    blocTest<CustomerSearchCubit, CustomerSearchState>(
      'debounces typing and shows matching customers',
      build: () => CustomerSearchCubit(SearchCustomers(repo), debounce: const Duration(milliseconds: 10)),
      act: (cubit) async {
        cubit
          ..queryChanged('0')
          ..queryChanged('010')
          ..queryChanged('01012');
        await Future<void>.delayed(const Duration(milliseconds: 30));
      },
      verify: (cubit) {
        expect(cubit.state.status, SearchStatus.results);
        expect(cubit.state.results.map((c) => c.id), unorderedEquals(['c1', 'c2']));
        expect(repo.searchCalls, 1, reason: 'only the last query reaches the server');
      },
    );

    blocTest<CustomerSearchCubit, CustomerSearchState>(
      'reports "not found" for an unknown phone',
      build: () => CustomerSearchCubit(SearchCustomers(repo), debounce: Duration.zero),
      act: (cubit) async {
        cubit.queryChanged('01599999999');
        await Future<void>.delayed(const Duration(milliseconds: 10));
      },
      verify: (cubit) => expect(cubit.state.status, SearchStatus.notFound),
    );

    blocTest<CustomerSearchCubit, CustomerSearchState>(
      'clearing the query returns to the idle hint',
      build: () => CustomerSearchCubit(SearchCustomers(repo), debounce: Duration.zero),
      act: (cubit) => cubit.queryChanged('   '),
      expect: () => [const CustomerSearchState()],
    );
  });

  group('SearchCustomerPage', () {
    Future<void> pump(WidgetTester tester, {Locale locale = const Locale('en')}) => tester.pumpApp(
      BlocProvider(
        create: (_) => CustomerSearchCubit(SearchCustomers(repo), debounce: Duration.zero),
        child: const SearchCustomerPage(),
      ),
      locale: locale,
    );

    testWidgets('shows name and phone together for each match', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '01012345678');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(find.text('Ahmed Mohamed'), findsOneWidget);
      expect(find.textContaining('012345678'), findsWidgets);
      expect(find.text('Smouha'), findsOneWidget);
      expect(find.text('1 customer found'), findsOneWidget);
    });

    testWidgets('offers to add a new customer when nobody matches', (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField), '01599999999');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();

      expect(find.text('Customer not found'), findsOneWidget);
      expect(find.text('Add new customer'), findsOneWidget);
    });

    testWidgets('works in Arabic (right-to-left)', (tester) async {
      await pump(tester, locale: const Locale('ar'));
      expect(Directionality.of(tester.element(find.byType(TextField))), TextDirection.rtl);
      await tester.enterText(find.byType(TextField), '01599999999');
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(find.text('العميل غير موجود'), findsOneWidget);
      expect(find.text('إضافة عميل جديد'), findsOneWidget);
    });
  });
}
