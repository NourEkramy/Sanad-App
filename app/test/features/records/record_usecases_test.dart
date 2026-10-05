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
    add = AddServiceRecord(repo, () => 'r${++ids}', clock: () => testNow);
  });

  group('AddServiceRecord', () {
    test('stores a record that belongs to exactly one customer', () async {
      final result = await add(customer(), validDraft);

      final record = result.valueOrNull!;
      expect(record.customerId, 'c1');
      expect(repo.inserted[record.id]!.customerId, 'c1');
      expect(repo.inserted[record.id]!.nurseId, 'n1');
      expect(repo.inserted[record.id]!.serviceId, 's1');
    });

    test('stores the actual price charged, in piasters', () async {
      final result = await add(customer(), validDraft.copyWith(price: '1,250.50'));
      expect(result.valueOrNull!.price, const Money.piasters(125050));
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
      expect(electronic.valueOrNull!.paymentMethod, PaymentMethod.electronic);
    });

    test('future dates are rejected', () async {
      final result = await add(customer(), validDraft.copyWith(serviceDate: DateTime(2026, 9, 13)));
      expect((result.failureOrNull as ValidationFailure).fields['serviceDate'], ValidationCodes.futureDate);
    });

    test('patient name equal to the customer name is not duplicated', () async {
      final same = await add(customer(), validDraft.copyWith(patientName: 'Ahmed Mohamed'));
      expect(same.valueOrNull!.patientName, isNull);
      final other = await add(customer(), validDraft.copyWith(patientName: 'His mother'));
      expect(other.valueOrNull!.patientName, 'His mother');
    });

    test('business rule violations are reported', () async {
      repo.inactiveNurses.add('n1');
      final result = await add(customer(), validDraft);
      expect(result.failureOrNull, const BusinessRuleFailure('nurse_inactive'));
      expect(repo.inserted, isEmpty);
    });
  });

  group('GetCustomerHistory', () {
    test("returns only the customer's records, newest first", () async {
      await add(customer(), validDraft.copyWith(serviceDate: DateTime(2026, 9, 1)));
      await add(customer(), validDraft.copyWith(serviceDate: DateTime(2026, 9, 10)));
      await add(customer(id: 'other'), validDraft);

      final history = (await GetCustomerHistory(repo)('c1')).valueOrNull!;

      expect(history.map((r) => r.serviceDate.day), [10, 1]);
      expect(history.every((r) => r.customerId == 'c1'), isTrue);
    });
  });
}
