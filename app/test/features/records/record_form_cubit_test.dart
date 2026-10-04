import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/features/care_services/domain/entities/care_service.dart';
import 'package:sanad/features/care_services/domain/usecases/care_service_usecases.dart';
import 'package:sanad/features/nurses/domain/entities/nurse.dart';
import 'package:sanad/features/nurses/domain/usecases/nurse_usecases.dart';
import 'package:sanad/features/records/domain/entities/record_draft.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';
import 'package:sanad/features/records/domain/usecases/record_usecases.dart';
import 'package:sanad/features/records/presentation/cubit/record_form_cubit.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeRecordRepository records;
  late MemoryDraftStore drafts;
  late FakeServiceRepository services;

  const injection = CareService(id: 's1', name: 'حقن عضل', defaultPrice: Money.piasters(7500));
  const variable = CareService(id: 's2', name: 'صيدلية');
  const visit = CareService(id: 's3', name: 'Home Nursing Visit', defaultPrice: Money.piasters(50000));

  RecordFormCubit build() => RecordFormCubit(
    customer: customer(),
    getNurses: GetNurses(FakeNurseRepository([const Nurse(id: 'n1', name: 'Sara Ahmed')])),
    getServices: GetCareServices(services),
    saveNurse: SaveNurse(FakeNurseRepository()),
    saveService: SaveCareService(services),
    addRecord: AddServiceRecord(records, MemoryPendingStore(), () => 'new-id', clock: () => testNow),
    updateRecord: UpdateServiceRecord(records, clock: () => testNow),
    drafts: drafts,
    clock: () => testNow,
  );

  setUp(() {
    records = FakeRecordRepository();
    drafts = MemoryDraftStore();
    services = FakeServiceRepository([injection, variable, visit]);
  });

  test('defaults date and time to now', () async {
    final cubit = build();
    await cubit.init();
    expect(cubit.state.draft.serviceDate, DateTime(2026, 9, 12));
    expect(cubit.state.draft.serviceTime, const LocalTime(19, 30));
    await cubit.close();
  });

  test('choosing a service suggests its default price', () async {
    final cubit = build();
    await cubit.init();
    cubit.selectService(injection);
    expect(cubit.state.draft.price, '75');
    cubit.selectService(visit);
    expect(cubit.state.draft.price, '500', reason: 'not edited yet, so it follows the service');
    await cubit.close();
  });

  test('a typed price is never overwritten by another service default', () async {
    final cubit = build();
    await cubit.init();
    cubit
      ..selectService(visit)
      ..priceChanged('450')
      ..selectService(injection);
    expect(cubit.state.draft.price, '450');
    await cubit.close();
  });

  test('variable-price services leave the price for the user', () async {
    final cubit = build();
    await cubit.init();
    cubit.selectService(variable);
    expect(cubit.state.draft.price, '');
    await cubit.close();
  });

  test('saves the actual price, not the service default', () async {
    final cubit = build();
    await cubit.init();
    cubit
      ..selectNurse(const Nurse(id: 'n1', name: 'Sara Ahmed'))
      ..selectService(visit)
      ..priceChanged('420')
      ..paymentChanged(PaymentMethod.electronic);
    await cubit.submit();

    expect(cubit.state.status, RecordFormStatus.saved);
    final saved = records.inserted['new-id']!;
    expect(saved.price, Money.pounds(420));
    expect(saved.paymentMethod, PaymentMethod.electronic);
    expect(saved.serviceName, 'Home Nursing Visit');
    expect(drafts.drafts, isEmpty, reason: 'draft is cleared after saving');
    await cubit.close();
  });

  test('typed input is kept as a draft and restored when reopening the form', () async {
    var cubit = build();
    await cubit.init();
    cubit
      ..selectService(visit)
      ..notesChanged('Bring gloves');
    await cubit.close(); // flushes the pending draft write

    expect(drafts.drafts['c1']?.notes, 'Bring gloves');

    cubit = build();
    await cubit.init();
    expect(cubit.state.restoredDraft, isTrue);
    expect(cubit.state.draft.serviceId, 's3');
    expect(cubit.state.draft.price, '500');
    await cubit.discardDraft();
    expect(drafts.drafts, isEmpty);
    await cubit.close();
  });

  test('a failed save keeps everything the user typed', () async {
    records.inactiveNurses.add('n1');
    final cubit = build();
    await cubit.init();
    cubit
      ..selectNurse(const Nurse(id: 'n1', name: 'Sara Ahmed'))
      ..selectService(visit)
      ..paymentChanged(PaymentMethod.cash);
    await cubit.submit();

    expect(cubit.state.status, RecordFormStatus.editing);
    expect(cubit.state.failure, isNotNull);
    expect(cubit.state.draft.serviceId, 's3');
    expect(cubit.state.draft.price, '500');
    await cubit.close();
    expect(drafts.drafts['c1'], isA<RecordDraft>());
  });
}
