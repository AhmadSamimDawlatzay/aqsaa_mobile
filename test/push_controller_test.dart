import 'dart:async';
import 'dart:convert';
import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/session_controller.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/push/push_controller.dart';
import 'package:aqsaa_mobile/push/push_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/auth_fixtures.dart';

class FakePushMessaging implements PushMessaging {
  PushPermission permission = PushPermission.authorized;
  String? currentToken = 'push-token-one';
  final tokens = StreamController<String>.broadcast();
  final foreground = StreamController<PushMessage>.broadcast();
  final opened = StreamController<PushMessage>.broadcast();
  PushMessage? initial;

  @override
  Future<PushMessage?> initialMessage() async => initial;
  @override
  Future<PushPermission> permissionStatus() async => permission;
  @override
  Future<PushPermission> requestPermission() async => permission;
  @override
  Future<String?> token() async => currentToken;
  @override
  Stream<String> get tokenRefreshes => tokens.stream;
  @override
  Stream<PushMessage> get foregroundMessages => foreground.stream;
  @override
  Stream<PushMessage> get openedMessages => opened.stream;

  Future<void> close() async {
    await tokens.close();
    await foreground.close();
    await opened.close();
  }
}

void main() {
  late FakePushMessaging messaging;
  late SessionController session;
  late ApiClient api;
  late SessionStore store;
  var hasSession = false;

  Future<void> authenticate(
    Future<http.Response> Function(http.Request) handler,
  ) async {
    store = SessionStore(MemorySecureStore());
    api = ApiClient(baseUrl: testBase, client: MockClient(handler));
    session = SessionController(api: api, store: store);
    hasSession = true;
    await session.restore();
    session.openLogin();
    await session.login('user@example.test', 'synthetic-password');
    expect(session.phase, SessionPhase.authenticated);
  }

  setUp(() {
    messaging = FakePushMessaging();
    hasSession = false;
  });
  tearDown(() async {
    await messaging.close();
    if (hasSession) {
      session.dispose();
      api.close();
    }
  });

  test('registers the token and registers rotations once', () async {
    final registered = <String>[];
    await authenticate((request) async {
      if (request.url.path.contains('/devices/')) {
        registered.add(jsonDecode(request.body)['push_token'] as String);
        return response({'data': {}});
      }
      return authResponse(request);
    });
    final controller = PushController(
      messaging: messaging,
      session: session,
      onForegroundMessage: () {},
      onOpenInbox: () {},
      retryDelays: const [],
    );
    addTearDown(controller.dispose);

    await controller.start(requestPermission: true);
    expect(controller.state, PushState.registered);
    messaging.tokens.add('push-token-two');
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(registered, ['push-token-one', 'push-token-two']);
  });

  test('permission denial is non-blocking and 409 is not retried', () async {
    var registrations = 0;
    await authenticate((request) async {
      if (request.url.path.contains('/devices/')) {
        registrations++;
        return response({'message': 'Conflict'}, 409);
      }
      return authResponse(request);
    });
    messaging.permission = PushPermission.denied;
    var controller = PushController(
      messaging: messaging,
      session: session,
      onForegroundMessage: () {},
      onOpenInbox: () {},
      retryDelays: const [],
    );
    await controller.start(requestPermission: true);
    expect(controller.state, PushState.denied);
    expect(session.phase, SessionPhase.authenticated);
    expect(registrations, 0);
    controller.dispose();

    await messaging.close();
    messaging = FakePushMessaging();
    controller = PushController(
      messaging: messaging,
      session: session,
      onForegroundMessage: () {},
      onOpenInbox: () {},
      retryDelays: const [],
    );
    addTearDown(controller.dispose);
    await controller.start(requestPermission: true);
    expect(controller.state, PushState.conflict);
    expect(registrations, 1);
  });

  test(
    'messages refresh safely and stale registration cannot survive logout',
    () async {
      final pendingRegistration = Completer<http.Response>();
      await authenticate((request) async {
        if (request.url.path.contains('/devices/')) {
          return pendingRegistration.future;
        }
        return authResponse(request);
      });
      var foreground = 0;
      var opened = 0;
      final controller = PushController(
        messaging: messaging,
        session: session,
        onForegroundMessage: () => foreground++,
        onOpenInbox: () => opened++,
        retryDelays: const [],
      );
      addTearDown(controller.dispose);
      final start = controller.start(requestPermission: true);
      await Future<void>.delayed(Duration.zero);
      await session.logout();
      pendingRegistration.complete(response({'data': {}}));
      await start;
      expect(session.phase, SessionPhase.signedOut);
      expect(controller.state, isNot(PushState.registered));

      messaging.foreground.add(const PushMessage(data: {'version': 'unknown'}));
      messaging.opened.add(
        const PushMessage(data: {'installation': 'another-installation'}),
      );
      await Future<void>.delayed(Duration.zero);
      expect(foreground, 0);
      expect(opened, 0);
    },
  );

  test('payload parsing allowlists version and installation', () {
    const message = PushMessage(
      data: {
        'version': PushMessage.supportedVersion,
        'installation': 'demo',
        'notification_id': 'notification-123',
      },
    );
    expect(message.notificationId, 'notification-123');
    expect(message.belongsToInstallation('demo'), isTrue);
    expect(message.belongsToInstallation('customer'), isFalse);
    expect(
      const PushMessage(data: {'notification_id': 'unsafe'}).notificationId,
      isNull,
    );
  });
}
