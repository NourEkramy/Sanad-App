import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/core/utils/local_time.dart';
import 'package:sanad/core/utils/money.dart';
import 'package:sanad/core/validation/validators.dart';
import 'package:sanad/features/records/domain/entities/record_draft.dart';
import 'package:sanad/features/records/domain/entities/service_record.dart';
import 'package:sanad/features/records/domain/usecases/record_usecases.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeRecordRepository repo;
  late MemoryPendingStore pending;
  late AddServiceRecord add;
  var ids = 0;

  final validDraft = RecordDraft(
    nurseId: 'n1',
    nurseName: 'Sara Ahmed',
    serviceId: 's1',
    serviceName: 'Home Nursing Visit',
    price: '500',
    paymentMethod: PaymentMethod.cash,
    serviceDate: DateTime(2026, 9, 12),
    serviceTime: const LocalTime(19, 30),
  );

  setUp(() {
    repo = FakeRecordRepository();
    pending = MemoryPendingStore();
    add = AddServiceRecord(repo, pending, () => 'r${++ids}', clock: () => testNow);
  });

  group('AddServiceRecord', () {
    test('stores a record that belongs to exactly one customer', () async {
      final result = await add(customer(), validDraft);

      final (record, outcome) = result.valueOrNull!;
      expect(outcome, SaveOutcome.saved);
      expect(record.customerId, 'c1');
      expect(repo.inserted[record.id]!.customerId, 'c1');
      expect(repo.inserted[record.id]!.nurseId, 'n1');
      expect(repo.inserted[record.id]!.serviceId, 's1');
    });

    test('stores the actual price charged, in piasters', () async {
      final result = await add(customer(), validDraft.copyWith(price: '1,250.50'));
      expect(result.valueOrNull!.$1.price, const Money.piasters(125050));
    });

    test('requires nurse, service, price, payment method, date and time', () async {
      final result = await add(customer(), const RecordDraft());
      expect((result.failureOrNull as ValidationFailure).fields.keys, {
        'nurse',
        'service',
        'price',
        'paymentMethod',
        'serviceDate',
        'serviceTime',
      });
      expect(repo.addCalls, 0);
    });

    test('rejects invalid and negative prices', () async {
      expect(
        ((await add(customer(), validDraft.copyWith(price: 'abc'))).failureOrNull as ValidationFailure).fields['price'],
        ValidationCodes.invalidPrice,
      );
      expect(
        ((await add(customer(), validDraft.copyWith(price: '-10'))).failureOrNull as ValidationFailure).fields['price'],
        ValidationCodes.negativePrice,
      );
    });

    test('only cash or electronic payment can be chosen for new records', () async {
      final unspecified = await add(customer(), validDraft.copyWith(paymentMethod: PaymentMethod.unspecified));
      expect((unspecified.failureOrNull as ValidationFailure).fields, contains('paymentMethod'));

      final electronic = await add(customer(), validDraft.copyWith(paymentMethod: PaymentMethod.electronic));
      expect(electronic.valueOrNull!.$1.paymentMethod, PaymentMethod.electronic);
    });

    test('future dates are rejected', () async {
      final result = await add(customer(), validDraft.copyWith(serviceDate: DateTime(2026, 9, 13)));
      expect((result.failureOrNull as ValidationFailure).fields['serviceDate'], ValidationCodes.futureDate);
    });

    test('patient name equal to the customer name is not duplicated', () async {
      final same = await add(customer(), validDraft.copyWith(patientName: 'Ahmed Mohamed'));
      expect(same.valueOrNull!.$1.patientName, isNull);
      final other = await add(customer(), validDraft.copyWith(patientName: 'His mother'));
      expect(other.valueOrNull!.$1.patientName, 'His mother');
    });

    test('offline saves are queued on the device instead of being lost', () async {
      repo.failWith = const NetworkFailure();

      final result = await add(customer(), validDraft);

      final (record, outcome) = result.valueOrNull!;
      expect(outcome, SaveOutcome.queuedOffline);
      expect(record.syncState, SyncState.pending);
      expect(pending.records.keys, [record.id]);
    });

    test('server rejections are reported, not queued', () async {
      repo.inactiveNurses.add('n1');
      final result = await add(customer(), validDraft);
      expect(result.failureOrNull, const BusinessRuleFailure('nurse_inactive'));
      expect(pending.records, isEmpty);
    });
  });

  group('SyncPendingRecords', () {
    test('sends queued records once the connection is back, without duplicates', () async {
      repo.failWith = const NetworkFailure();
      final queued = (await add(customer(), validDraft)).valueOrNull!.$1;
      repo.failWith = null;

      final sync = SyncPendingRecords(repo, pending);
      final report = await sync();
      await sync(); // running again is harmless

      expect(report.sent, 1);
      expect(pending.records, isEmpty);
      expect(repo.inserted.keys, [queued.id], reason: 'same client-generated id → inserted once');
    });

    test('keeps records still offline and flags rejected ones', () async {
      repo.failWith = const NetworkFailure();
      await add(customer(), validDraft);
      await add(customer(), validDraft.copyWith(nurseId: 'gone'));

      var report = await SyncPendingRecords(repo, pending)();
      expect(report.remaining, 2);

      repo
        ..failWith = null
        ..inactiveNurses.add('gone');
      report = await SyncPendingRecords(repo, pending)();
      expect(report.sent, 1);
      expect(report.failed, 1);
      final failed = pending.records.values.single;
      expect(failed.syncState, SyncState.failed);
      expect(failed.syncError, 'nurse_inactive');
    });
  });

  group('GetCustomerHistory', () {
    test('merges queued and saved records, newest first', () async {
      await add(customer(), validDraft.copyWith(serviceDate: DateTime(2026, 9, 1)));
      repo.failWith = const NetworkFailure();
      await add(customer(), validDraft.copyWith(serviceDate: DateTime(2026, 9, 10)));
      await add(customer(id: 'other'), validDraft);
      repo.failWith = null;

      final history = (await GetCustomerHistory(repo, pending)('c1')).valueOrNull!;

      expect(history.map((r) => r.serviceDate.day), [10, 1]);
      expect(history.first.syncState, SyncState.pending);
      expect(history.every((r) => r.customerId == 'c1'), isTrue);
    });
  });
}
