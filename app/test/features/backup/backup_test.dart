import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sanad/core/errors/failure.dart';
import 'package:sanad/core/network/connectivity_service.dart';
import 'package:sanad/core/result/result.dart';
import 'package:sanad/core/storage/secure_store.dart';
import 'package:sanad/features/backup/data/drive_api.dart';
import 'package:sanad/features/backup/data/google_drive_backup_store.dart';
import 'package:sanad/features/backup/data/local_backup_source.dart';
import 'package:sanad/features/backup/domain/backup.dart';
import 'package:sanad/features/backup/presentation/backup_cubit.dart';
import 'package:sanad/features/customers/data/local_customer_repository.dart';
import 'package:sanad/features/excel/data/excel_workbook_codec.dart';
import 'package:sanad/features/excel/data/local_excel_repositories.dart';
import 'package:sanad/features/excel/domain/excel_usecases.dart';
import 'package:sanad/features/excel/domain/export/export_models.dart';

import '../../helpers/database.dart';

class FakeCloud implements CloudBackupStore {
  final uploads = <BackupPayload>[];
  RemoteBackup? remote;
  Uint8List? stored;
  Failure? failUpload;
  Failure? failConnect;
  Failure? failLatest;

  @override
  bool get isSupported => true;

  @override
  Future<Result<String>> connect() async =>
      failConnect != null ? Result.failure(failConnect!) : const Result.success('sanad@example.com');

  @override
  Future<VoidResult> disconnect() async => const Result.success(null);

  @override
  Future<Result<DateTime>> upload(BackupPayload payload) async {
    if (failUpload != null) return Result.failure(failUpload!);
    uploads.add(payload);
    stored = payload.data;
    return Result.success(DateTime(2026, 10, 5, 12));
  }

  @override
  Future<Result<RemoteBackup?>> latest() async =>
      failLatest != null ? Result.failure(failLatest!) : Result.success(remote);

  @override
  Future<Result<Uint8List>> download() async =>
      stored == null ? const Result.failure(BackupFailure(BackupFailureReason.noBackup)) : Result.success(stored!);
}

class FakeSource implements BackupSource {
  final changesController = StreamController<void>.broadcast();
  final restored = <Uint8List>[];

  @override
  Stream<void> get changes => changesController.stream;

  @override
  Future<Result<BackupPayload>> create() async =>
      Result.success(BackupPayload(workbook: Uint8List.fromList([1]), data: Uint8List.fromList([2])));

  @override
  Future<VoidResult> restore(Uint8List data) async {
    restored.add(data);
    return const Result.success(null);
  }
}

class FakeConnectivity implements ConnectivityService {
  final controller = StreamController<bool>.broadcast();

  @override
  Future<bool> get isOnline async => true;

  @override
  Stream<bool> get onStatusChange => controller.stream;
}

void main() {
  group('BackupCubit', () {
    late FakeCloud cloud;
    late FakeSource source;
    late FakeConnectivity connectivity;
    late MemoryStore store;
    late BackupCubit cubit;

    BackupCubit build() => BackupCubit(
      source: source,
      cloud: cloud,
      prefs: BackupPrefsStore(store),
      connectivity: connectivity,
      clock: () => DateTime(2026, 10, 5, 11),
      delay: const Duration(milliseconds: 20),
    );

    Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 60));

    setUp(() async {
      cloud = FakeCloud();
      source = FakeSource();
      connectivity = FakeConnectivity();
      store = MemoryStore();
      cubit = build();
      await cubit.start();
    });

    tearDown(() => cubit.close());

    test('connecting to an empty Drive backs up right away', () async {
      await cubit.connect();
      expect(cubit.state.prefs.account, 'sanad@example.com');
      expect(cloud.uploads, hasLength(1));
      expect(cubit.state.prefs.lastBackupAt, DateTime(2026, 10, 5, 12));
      expect(cubit.state.upToDate, isTrue);
    });

    test('an existing backup is never overwritten without asking', () async {
      cloud.remote = RemoteBackup(modifiedAt: DateTime(2026, 9, 1));
      await cubit.connect();
      expect(cubit.state.foundBackup, cloud.remote);
      source.changesController.add(null);
      await settle();
      expect(cloud.uploads, isEmpty, reason: 'waits for the user to choose');

      await cubit.keepDeviceData();
      expect(cloud.uploads, hasLength(1));
      expect(cubit.state.foundBackup, isNull);
      expect(cubit.state.prefs.account, 'sanad@example.com');
    });

    test('closing the app before choosing never overwrites the existing backup', () async {
      cloud.remote = RemoteBackup(modifiedAt: DateTime(2026, 9, 1));
      await cubit.connect();
      expect(cubit.state.prefs.connected, isFalse, reason: 'saved only after the choice');
      await cubit.close();

      cubit = build();
      await cubit.start();
      source.changesController.add(null);
      await settle();
      expect(cloud.uploads, isEmpty);
    });

    test('if Drive cannot be checked, nothing is uploaded', () async {
      cloud.failLatest = const NetworkFailure();
      await cubit.connect();
      expect(cubit.state.failure, const NetworkFailure());
      expect(cloud.uploads, isEmpty);
      expect(cubit.state.prefs.connected, isFalse);
    });

    test('changes are backed up automatically shortly after they happen', () async {
      await cubit.connect();
      source.changesController
        ..add(null)
        ..add(null)
        ..add(null);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.prefs.pendingSince, isNotNull);
      await settle();
      expect(cloud.uploads, hasLength(2), reason: 'one upload for a burst of changes');
      expect(cubit.state.prefs.pendingSince, isNull);
    });

    test('without a connection the backup waits, then runs when the connection is back', () async {
      await cubit.connect();
      cloud.failUpload = const NetworkFailure();
      source.changesController.add(null);
      await settle();
      expect(cubit.state.failure, const NetworkFailure());
      expect(cubit.state.prefs.pendingSince, isNotNull, reason: 'still waiting');

      cloud.failUpload = null;
      connectivity.controller.add(true);
      await settle();
      expect(cubit.state.failure, isNull);
      expect(cubit.state.prefs.pendingSince, isNull);
    });

    test('pending changes survive an app restart', () async {
      await cubit.connect();
      cloud.failUpload = const NetworkFailure();
      source.changesController.add(null);
      await settle();
      await cubit.close();

      cloud.failUpload = null;
      cubit = build();
      await cubit.start();
      await settle();
      expect(cloud.uploads, hasLength(2));
      expect(cubit.state.prefs.pendingSince, isNull);
    });

    test('restore replaces local data and asks the app to reload', () async {
      cloud
        ..remote = RemoteBackup(modifiedAt: DateTime(2026, 9, 1))
        ..stored = Uint8List.fromList(utf8.encode('{}'));
      await cubit.connect();
      expect((await cubit.restore()).failureOrNull, isNull);
      expect(source.restored, hasLength(1));
      expect(cubit.state.restoreCount, 1);
      expect(cubit.state.prefs.lastBackupAt, DateTime(2026, 9, 1));
    });

    test('a canceled sign-in is reported and nothing is saved', () async {
      cloud.failConnect = const BackupFailure(BackupFailureReason.canceled);
      await cubit.connect();
      expect(cubit.state.prefs.connected, isFalse);
      expect(cubit.state.failure, const BackupFailure(BackupFailureReason.canceled));
    });

    test('nothing is uploaded when Drive is not connected', () async {
      source.changesController.add(null);
      await settle();
      expect(cloud.uploads, isEmpty);
    });

    test('disconnecting stops automatic backups', () async {
      await cubit.connect();
      await cubit.disconnect();
      source.changesController.add(null);
      await settle();
      expect(cloud.uploads, hasLength(1));
      expect(cubit.state.prefs.connected, isFalse);
    });
  });

  test('local backup: the JSON restores the database and the workbook opens', () async {
    final db = await openTestDatabase();
    addTearDown(db.close);
    const codec = ExcelWorkbookCodec();
    final source = LocalBackupSource(db, ExportWorkbook(LocalExportRepository(db), codec), () => ExportLabels.english);
    final customers = LocalCustomerRepository(db);
    final areaId = (await db.reader.query('areas', limit: 1)).first['id']! as String;
    await customers.create(fullName: 'Mona Adel', phone: '01155555501', areaId: areaId);

    final payload = (await source.create()).valueOrNull!;
    expect(codec.decode(payload.workbook).valueOrNull!.map((s) => s.name), contains('Customers'));

    await customers.create(fullName: 'Later', phone: '01099999999', areaId: areaId);
    expect((await source.restore(payload.data)).failureOrNull, isNull);
    expect((await customers.list()).valueOrNull!.map((c) => c.fullName), ['Mona Adel']);

    expect(
      (await source.restore(Uint8List.fromList(utf8.encode('not json')))).failureOrNull,
      const FileFailure(FileFailureReason.notABackup),
    );
  });

  group('DriveApi', () {
    late List<http.Request> requests;
    late Map<String, Map<String, Object?>> files;
    var tokens = 0;

    DriveApi api({int expiredTokens = 0}) {
      requests = [];
      files = {};
      tokens = 0;
      final client = MockClient((request) async {
        requests.add(request);
        if (request.headers['Authorization'] == 'Bearer token-0' && expiredTokens > 0) {
          return http.Response('', 401);
        }
        final url = request.url.toString();
        if (request.method == 'GET' && request.url.path.endsWith('/files')) {
          final q = request.url.queryParameters['q']!;
          final match = files.entries.where((f) => q.contains("name = '${f.value['name']}'")).toList();
          return http.Response(
            jsonEncode({
              'files': [
                for (final f in match) {'id': f.key, 'modifiedTime': '2026-10-05T10:00:00Z'},
              ],
            }),
            200,
          );
        }
        if (request.method == 'POST') {
          final id = 'f${files.length}';
          final name = url.contains('upload')
              ? RegExp(r'"name":"([^"]+)"').firstMatch(request.body)!.group(1)
              : (jsonDecode(request.body) as Map)['name'];
          files[id] = {'name': name};
          return http.Response(jsonEncode({'id': id, 'modifiedTime': '2026-10-05T10:00:00Z'}), 200);
        }
        if (request.method == 'PATCH') {
          return http.Response(
            jsonEncode({'id': request.url.pathSegments.last, 'modifiedTime': '2026-10-05T11:00:00Z'}),
            200,
          );
        }
        if (url.contains('alt=media')) return http.Response.bytes([7, 8, 9], 200);
        return http.Response('{}', 404);
      });
      return DriveApi(({bool refresh = false}) async => 'token-${refresh ? ++tokens : tokens}', client: client);
    }

    test('creates the folder and files once, then replaces the content in place', () async {
      final drive = api();
      final folder = await drive.ensureFolder(BackupFiles.folder);
      await drive.put(parent: folder, name: BackupFiles.data, mimeType: 'application/json', bytes: Uint8List(1));
      expect(requests.where((r) => r.method == 'POST'), hasLength(2));

      expect(await drive.ensureFolder(BackupFiles.folder), folder, reason: 'found, not created again');
      final updated = await drive.put(
        parent: folder,
        name: BackupFiles.data,
        mimeType: 'application/json',
        bytes: Uint8List(1),
      );
      expect(requests.last.method, 'PATCH');
      expect(updated.modifiedAt, DateTime.utc(2026, 10, 5, 11).toLocal());
      expect(await drive.download(updated.id), [7, 8, 9]);
    });

    test('an expired token is refreshed once', () async {
      final drive = api(expiredTokens: 1);
      expect(await drive.find(BackupFiles.data), isNull);
      expect(requests.map((r) => r.headers['Authorization']), ['Bearer token-0', 'Bearer token-1']);
    });

    test('a refused permission is reported as such', () async {
      final drive = DriveApi(
        ({bool refresh = false}) async => 'token',
        client: MockClient((_) async => http.Response('', 403)),
      );
      await expectLater(drive.find('x'), throwsA(const BackupFailure(BackupFailureReason.notAuthorized)));
    });
  });

  group('setup errors say what to fix', () {
    test('a Google Cloud client that does not match the app is a setup problem', () {
      final failure = GoogleDriveBackupStore.signInFailure(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.unknownError,
          description: 'SDK reported an exception: 10: DEVELOPER_ERROR',
        ),
      );
      expect(failure.reason, BackupFailureReason.notConfigured);
      expect(failure.detail, contains('DEVELOPER_ERROR'));
    });

    test('other sign-in errors keep Google\'s detail', () {
      final failure = GoogleDriveBackupStore.signInFailure(
        const GoogleSignInException(code: GoogleSignInExceptionCode.interrupted, description: 'network'),
      );
      expect(failure, const BackupFailure(BackupFailureReason.signInFailed, 'interrupted: network'));
      expect(
        GoogleDriveBackupStore.signInFailure(const GoogleSignInException(code: GoogleSignInExceptionCode.canceled)),
        const BackupFailure(BackupFailureReason.canceled),
      );
    });

    test('Drive API not enabled in the project', () {
      const body =
          '{"error":{"code":403,"message":"Google Drive API has not been used in project 123 before or it is '
          'disabled.","errors":[{"reason":"accessNotConfigured"}],"status":"PERMISSION_DENIED"}}';
      final failure = DriveApi.failureFor(403, body) as BackupFailure;
      expect(failure.reason, BackupFailureReason.notConfigured);
      expect(failure.detail, startsWith('Google Drive API is not enabled'));
    });

    test('a missing permission is reported as not granted', () {
      const body =
          '{"error":{"code":403,"message":"Insufficient Permission","errors":[{"reason":"insufficientPermissions"}]}}';
      expect(
        DriveApi.failureFor(403, body),
        const BackupFailure(BackupFailureReason.notAuthorized, 'insufficientPermissions: Insufficient Permission'),
      );
      expect(DriveApi.failureFor(500, ''), const ServerFailure('drive_500'));
    });
  });
}
