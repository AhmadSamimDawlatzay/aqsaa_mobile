import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/auth_fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'platform adapter persists and deletes through secure-storage API',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final store = SessionStore(PlatformSecureStore());
      await store.save(credential());
      expect((await store.read(testBase))!.token, credential().token);
      await store.clear(testBase);
      expect(await store.read(testBase), isNull);
    },
  );
  test(
    'random installation ID persists through logout and has no hardware input',
    () async {
      final memory = MemorySecureStore();
      final store = SessionStore(memory);
      final id = await store.deviceId();
      expect(id, matches(RegExp(r'^[a-f0-9]{64}$')));
      await store.save(credential());
      await store.clear(testBase);
      expect(await SessionStore(memory).deviceId(), id);
      expect(await SessionStore(MemorySecureStore()).deviceId(), isNot(id));
    },
  );
  test(
    'storage scopes tokens by full API base and rejects copied records',
    () async {
      final memory = MemorySecureStore();
      final store = SessionStore(memory);
      await store.save(credential());
      const other = 'https://other.test/api/v1/';
      expect(await store.read(other), isNull);
      await store.save(credential(other));
      await store.clear(other);
      expect(await store.read(testBase), isNotNull);
      final key = memory.values.keys.single;
      memory.values[key] = memory.values[key]!.replaceAll(testBase, other);
      await expectLater(
        store.read(testBase),
        throwsA(isA<SessionStorageException>()),
      );
    },
  );
  test(
    'storage errors and malformed data never silently become signed out',
    () async {
      final memory = MemorySecureStore();
      final store = SessionStore(memory);
      await store.save(credential());
      memory.failRead = true;
      await expectLater(
        store.read(testBase),
        throwsA(isA<SessionStorageException>()),
      );
      memory.failRead = false;
      memory.values[memory.values.keys.single] = '{';
      await expectLater(
        store.read(testBase),
        throwsA(isA<SessionStorageException>()),
      );
      expect(memory.values, isNotEmpty);
    },
  );
}
