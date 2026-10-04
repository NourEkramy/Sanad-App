import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/care_services/domain/entities/care_service.dart';
import 'package:sanad/features/care_services/domain/usecases/care_service_usecases.dart';
import 'package:sanad/features/nurses/domain/entities/nurse.dart';
import 'package:sanad/features/nurses/domain/usecases/nurse_usecases.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';
import 'package:sanad/features/records/domain/usecases/record_usecases.dart';
import 'package:sanad/features/records/presentation/cubit/record_form_cubit.dart';
import 'package:sanad/features/records/presentation/pages/record_form_page.dart';

import '../../helpers/fakes.dart';
import '../../helpers/pump_app.dart';

void main() {
  late FakeRecordRepository records;

  setUp(() => records = FakeRecordRepository());

  late GoRouter router;

  Widget page() {
    final cubit = RecordFormCubit(
      customer: customer(),
      getNurses: GetNurses(FakeNurseRepository([const Nurse(id: 'n1', name: 'Sara Ahmed')])),
      getServices: GetCareServices(
        FakeServiceRepository([
          const CareService(id: 's1', name: 'Home Nursing Visit', defaultPrice: Money.piasters(50000)),
        ]),
      ),
      saveNurse: SaveNurse(FakeNurseRepository()),
      saveService: SaveCareService(FakeServiceRepository()),
      addRecord: AddServiceRecord(records, MemoryPendingStore(), () => 'rec-1', clock: () => testNow),
      updateRecord: UpdateServiceRecord(records, clock: () => testNow),
      drafts: MemoryDraftStore(),
      clock: () => testNow,
    )..init();
    // A tiny router so `context.pop` works like in the app.
    router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('history')),
        ),
        GoRoute(
          path: '/form',
          builder: (_, _) => BlocProvider.value(value: cubit, child: const RecordFormPage()),
        ),
      ],
    );
    return Router.withConfig(config: router);
  }

  testWidgets('the primary flow: confirm customer → nurse → service → price → payment → save', (tester) async {
    await tester.pumpApp(page());
    unawaited(router.push('/form'));
    await tester.pumpAndSettle();

    // Customer confirmation and sensible defaults.
    expect(find.text('Ahmed Mohamed'), findsOneWidget);
    expect(find.textContaining('010 1234 5678'), findsOneWidget);
    expect(find.text('Sep 12, 2026'), findsOneWidget);
    expect(find.textContaining('7:30'), findsOneWidget);

    await tester.tap(find.text('Select nurse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sara Ahmed'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select service'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home Nursing Visit'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '500'), findsOneWidget, reason: 'default price suggested');

    await tester.enterText(find.widgetWithText(TextField, '500'), '450');
    await tester.tap(find.text('Electronic'));
    await tester.pump();
    await tester.tap(find.text('Save record'));
    await tester.pumpAndSettle();

    final saved = records.inserted['rec-1']!;
    expect(saved.price, Money.pounds(450));
    expect(saved.paymentMethod, PaymentMethod.electronic);
    expect(saved.nurseName, 'Sara Ahmed');
    expect(find.text('Record saved.'), findsOneWidget);
    expect(find.text('history'), findsOneWidget, reason: 'returns to the previous screen');
  });

  testWidgets('shows clear validation errors and saves nothing', (tester) async {
    await tester.pumpApp(page());
    unawaited(router.push('/form'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save record'));
    await tester.pumpAndSettle();

    expect(find.text('This field is required.'), findsNWidgets(4)); // nurse, service, price, payment
    expect(records.inserted, isEmpty);
  });
}
