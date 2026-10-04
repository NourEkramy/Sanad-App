import 'package:flutter_test/flutter_test.dart';
import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/core/validation/validators.dart';
import 'package:sanad/features/areas/domain/entities/area.dart';
import 'package:sanad/features/areas/domain/usecases/area_usecases.dart';
import 'package:sanad/features/customers/domain/entities/customer.dart';
import 'package:sanad/features/customers/domain/usecases/customer_usecases.dart';

import '../../helpers/fakes.dart';

void main() {
  late FakeCustomerRepository repo;

  setUp(() => repo = FakeCustomerRepository());

  group('CreateCustomer', () {
    test('creates a customer with a normalised phone', () async {
      final result = await CreateCustomer(repo)(
        const CustomerDraft(fullName: '  Sara   Ali ', phone: '010 1234 5678', areaId: 'a1', address: ' ', notes: ''),
      );

      final created = result.valueOrNull!;
      expect(created.fullName, 'Sara Ali');
      expect(created.phone, '01012345678');
      expect(created.address, isNull, reason: 'blank optional fields are stored as null');
      expect(repo.byId, hasLength(1));
    });

    test('requires name, phone and area', () async {
      final result = await CreateCustomer(repo)(const CustomerDraft(fullName: '', phone: '', areaId: null));

      final failure = result.failureOrNull as ValidationFailure;
      expect(failure.fields, {
        'fullName': ValidationCodes.required,
        'phone': ValidationCodes.required,
        'areaId': ValidationCodes.required,
      });
      expect(repo.byId, isEmpty);
    });

    test('rejects an invalid phone number', () async {
      final result = await CreateCustomer(repo)(const CustomerDraft(fullName: 'Ali', phone: '0101', areaId: 'a1'));
      expect((result.failureOrNull as ValidationFailure).fields['phone'], ValidationCodes.invalidPhone);
    });

    test('a duplicate phone returns the existing customer instead of creating one', () async {
      repo.add(customer());

      final result = await CreateCustomer(repo)(
        const CustomerDraft(fullName: 'Someone Else', phone: '+20 10 1234 5678', areaId: 'a2'),
      );

      final failure = result.failureOrNull;
      expect(failure, isA<CustomerExistsFailure>());
      expect((failure! as CustomerExistsFailure).existing.fullName, 'Ahmed Mohamed');
      expect(repo.byId, hasLength(1), reason: 'no duplicate was created');
    });

    test('an archived customer with the same phone also blocks duplicates', () async {
      repo.add(customer(archived: true));
      final result = await CreateCustomer(repo)(const CustomerDraft(fullName: 'X', phone: '01012345678', areaId: 'a1'));
      expect(result.failureOrNull, isA<CustomerExistsFailure>());
    });
  });

  group('UpdateCustomer', () {
    test('cannot take a phone number that belongs to another customer', () async {
      repo
        ..add(customer())
        ..add(customer(id: 'c2', name: 'Mona', phone: '01112345678'));

      final result = await UpdateCustomer(repo)(
        'c2',
        const CustomerDraft(fullName: 'Mona', phone: '01012345678', areaId: 'a1'),
      );
      expect(result.failureOrNull, isA<CustomerExistsFailure>());
    });

    test('keeping its own phone is allowed', () async {
      repo.add(customer());
      final result = await UpdateCustomer(repo)(
        'c1',
        const CustomerDraft(fullName: 'Ahmed M.', phone: '01012345678', areaId: 'a1'),
      );
      expect(result.valueOrNull?.fullName, 'Ahmed M.');
    });
  });

  group('SearchCustomers', () {
    setUp(() {
      repo
        ..add(customer())
        ..add(customer(id: 'c2', name: 'Mona Adel', phone: '01112345678'))
        ..add(customer(id: 'c3', name: 'Old', phone: '01012000000', archived: true));
    });

    test('finds by full phone, including Arabic digits', () async {
      final result = await SearchCustomers(repo)('٠١٠١٢٣٤٥٦٧٨');
      expect(result.valueOrNull!.map((c) => c.id), ['c1']);
    });

    test('supports partial phone input', () async {
      final result = await SearchCustomers(repo)('01012');
      expect(result.valueOrNull!.map((c) => c.id), ['c1'], reason: 'archived customers are excluded');
    });

    test('finds by name', () async {
      final result = await SearchCustomers(repo)('mona');
      expect(result.valueOrNull!.single.fullName, 'Mona Adel');
    });

    test('does not query the server for too-short input', () async {
      expect((await SearchCustomers(repo)('01')).valueOrNull, isEmpty);
      expect((await SearchCustomers(repo)('  ')).valueOrNull, isEmpty);
      expect(repo.searchCalls, 0);
    });

    test('propagates failures', () async {
      repo.failNext = const NetworkFailure();
      expect((await SearchCustomers(repo)('01012')).failureOrNull, const NetworkFailure());
    });
  });

  group('CreateArea', () {
    test('reuses an existing area with the same normalised name', () async {
      final areas = FakeAreaRepository([const Area(id: 'a1', name: 'الهانوفيل')]);
      final result = await CreateArea(areas)('  الهانوفيل ', known: areas.areas);
      expect(result.valueOrNull!.id, 'a1');
      expect(areas.areas, hasLength(1));
    });

    test('creates a new area and handles a concurrent duplicate', () async {
      final areas = FakeAreaRepository([const Area(id: 'a1', name: 'Smouha')]);
      // `known` is stale (empty) — the repository reports a duplicate and the
      // use case returns the existing area instead of failing.
      final result = await CreateArea(areas)('smouha', known: const []);
      expect(result.valueOrNull!.id, 'a1');

      final created = await CreateArea(areas)('Miami', known: areas.areas);
      expect(created.valueOrNull!.name, 'Miami');
      expect(areas.areas, hasLength(2));
    });

    test('requires a name', () async {
      final result = await CreateArea(FakeAreaRepository())('  ');
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });
}
