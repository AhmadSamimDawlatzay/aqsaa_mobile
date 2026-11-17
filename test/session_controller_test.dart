import 'dart:async';
import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/session_controller.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/models/auth_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/auth_fixtures.dart';

void main() {
  late MemorySecureStore memory;
  late SessionStore store;
  SessionController controller(
    Future<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 15),
  }) {
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient(handler),
      timeout: timeout,
    );
    final session = SessionController(api: api, store: store);
    addTearDown(session.dispose);
    addTearDown(api.close);
    return session;
  }

  setUp(() {
    memory = MemorySecureStore();
    store = SessionStore(memory);
  });
  test('no token restores welcome without any authenticated request', () async {
    final session = controller(
      (_) async => throw StateError('Unexpected request'),
    );
    await session.restore();
    expect(session.phase, SessionPhase.signedOut);
    expect(session.showLogin, isFalse);
  });
  test(
    'login stores session then verifies profile and capability scopes',
    () async {
      final session = controller((r) async => authResponse(r));
      await session.restore();
      session.openLogin();
      await session.login('user@example.test', 'synthetic-password');
      expect(session.phase, SessionPhase.authenticated);
      expect(session.profile!.name, 'Test User');
      expect(session.capabilities!.generalResources, ['classes']);
      expect((await store.read(testBase))!.token, 'synthetic-test-token');
      expect(
        memory.values.values.any((v) => v.contains('synthetic-password')),
        isFalse,
      );
    },
  );
  test('stored expiry is not trusted over server verification', () async {
    await store.save(
      SessionCredential(
        apiBase: testBase,
        token: 'synthetic-test-token',
        expiresAt: DateTime.utc(2000),
      ),
    );
    final session = controller((r) async => authResponse(r));
    await session.restore();
    expect(session.phase, SessionPhase.authenticated);
  });
  test(
    '401 on profile or capabilities clears token and returns login',
    () async {
      for (final path in ['me', 'capabilities']) {
        await store.save(credential());
        final session = controller(
          (r) async => r.url.path.endsWith(path)
              ? response({'message': 'Unauthenticated.'}, 401)
              : authResponse(r),
        );
        await session.restore();
        expect(session.phase, SessionPhase.signedOut);
        expect(session.showLogin, isTrue);
        expect(session.invalidSessionNotice, isTrue);
        expect(session.profile, isNull);
        expect(await store.read(testBase), isNull);
      }
    },
  );
  test(
    'network, timeout, 503 and 403 preserve token and retry validation',
    () async {
      for (final failure in ['network', 'timeout', 'server', 'forbidden']) {
        await store.save(credential());
        var failing = true;
        final session = controller((r) async {
          if (!failing) return authResponse(r);
          if (failure == 'network') throw http.ClientException('offline');
          if (failure == 'timeout') return Completer<http.Response>().future;
          return response({}, failure == 'server' ? 503 : 403);
        }, timeout: const Duration(milliseconds: 20));
        await session.restore();
        expect(session.phase, SessionPhase.failure);
        expect(await store.read(testBase), isNotNull);
        expect(session.profile, isNull);
        failing = false;
        await session.retry();
        expect(session.phase, SessionPhase.authenticated);
      }
    },
  );
  test(
    'logout succeeds with token available then clears all account data',
    () async {
      await store.save(credential());
      final device = await store.deviceId();
      final session = controller((r) async {
        if (r.url.path.endsWith('logout')) {
          expect(await store.read(testBase), isNotNull);
          expect(r.headers['Authorization'], 'Bearer synthetic-test-token');
        }
        return authResponse(r);
      });
      await session.restore();
      await session.logout();
      expect(session.phase, SessionPhase.signedOut);
      expect(session.showLogin, isTrue);
      expect(session.profile, isNull);
      expect(session.capabilities, isNull);
      expect(await store.read(testBase), isNull);
      expect(await store.deviceId(), device);
    },
  );
  test(
    'failed logout retains token, blocks account switch, and retries server',
    () async {
      await store.save(credential());
      var failLogout = true;
      var loginRequests = 0;
      final session = controller((r) async {
        if (r.url.path.endsWith('login')) loginRequests++;
        if (r.url.path.endsWith('logout') && failLogout) {
          throw http.ClientException('offline');
        }
        return authResponse(r);
      });
      await session.restore();
      await session.logout();
      expect(session.logoutUnconfirmed, isTrue);
      expect(session.phase, SessionPhase.failure);
      expect(await store.read(testBase), isNotNull);
      await session.login('other@example.test', 'synthetic-password');
      expect(loginRequests, 0);
      failLogout = false;
      await session.retry();
      expect(await store.read(testBase), isNull);
      expect(session.phase, SessionPhase.signedOut);
    },
  );
  test(
    '401 logout clears invalid session without claiming remote cleanup',
    () async {
      await store.save(credential());
      final session = controller(
        (r) async =>
            r.url.path.endsWith('logout') ? response({}, 401) : authResponse(r),
      );
      await session.restore();
      await session.logout();
      expect(session.invalidSessionNotice, isTrue);
      expect(await store.read(testBase), isNull);
    },
  );
  test('late profile response cannot repopulate state after logout', () async {
    await store.save(credential());
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final session = controller((r) async {
      if (r.url.path.endsWith('me')) {
        started.complete();
        return pending.future;
      }
      return authResponse(r);
    });
    final restoration = session.restore();
    await started.future;
    await session.logout();
    pending.complete(response(profileJson()));
    await restoration;
    expect(session.phase, SessionPhase.signedOut);
    expect(session.profile, isNull);
    expect(session.capabilities, isNull);
    expect(await store.read(testBase), isNull);
  });
  test('storage write failure blocks home and can retry persistence', () async {
    final session = controller((r) async => authResponse(r));
    await session.restore();
    await store.deviceId();
    memory.failWrite = true;
    await session.login('user@example.test', 'synthetic-password');
    expect(session.phase, SessionPhase.failure);
    expect(session.profile, isNull);
    memory.failWrite = false;
    await session.retry();
    expect(session.phase, SessionPhase.authenticated);
    expect(await store.read(testBase), isNotNull);
  });
  test(
    'local deletion failure blocks login; retry completes cleanup without another logout',
    () async {
      await store.save(credential());
      var logoutCount = 0;
      final session = controller((r) async {
        if (r.url.path.endsWith('logout')) logoutCount++;
        return authResponse(r);
      });
      await session.restore();
      memory.failDelete = true;
      await session.logout();
      expect(session.phase, SessionPhase.failure);
      expect(session.profile, isNull);
      memory.failDelete = false;
      await session.retry();
      expect(session.phase, SessionPhase.signedOut);
      expect(logoutCount, 1);
      expect(await store.read(testBase), isNull);
    },
  );
}
