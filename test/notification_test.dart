import 'dart:async';
import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/notification_inbox_controller.dart';
import 'package:aqsaa_mobile/auth/notifications_view.dart';
import 'package:aqsaa_mobile/auth/session_controller.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/l10n/app_language.dart';
import 'package:aqsaa_mobile/l10n/app_strings.dart';
import 'package:aqsaa_mobile/models/notification_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/auth_fixtures.dart';

Map<String, Object?> notice(
  String id,
  String event, {
  bool read = false,
  String version = 'v1',
  String? route = 'guardian.student',
  String? tab,
}) => {
  'id': id,
  'event_type': event,
  'student': {'id': 9, 'student_number': 'ST-009', 'name': 'Student Name'},
  'translation_key': 'guardian.$event',
  'translation_params': {'student': 'Student Name'},
  'deep_link': route == null
      ? null
      : {
          'version': version,
          'route': route,
          'student_id': 9,
          'tab':
              tab ??
              (event.startsWith('attendance_')
                  ? 'student-attendances'
                  : event == 'released_result'
                  ? 'exam-results'
                  : 'student-movements'),
        },
  'title': 'Server title',
  'body': 'Server body',
  'read_at': read ? '2026-11-23T08:00:00.000000Z' : null,
  'created_at': '2026-11-23T07:00:00.000000Z',
};

Map<String, Object?> page(
  List<Map<String, Object?>> items, {
  int current = 1,
  int last = 1,
}) => {
  'data': items,
  'links': {'first': null, 'last': null, 'prev': null, 'next': null},
  'meta': {'current_page': current, 'last_page': last},
};

void main() {
  test('parses every guardian event and safe destinations', () {
    final events = {
      'attendance_absent': NotificationDestination.attendance,
      'attendance_corrected': NotificationDestination.attendance,
      'released_result': NotificationDestination.unavailable,
      'promotion_committed': NotificationDestination.childDetails,
      'transfer_approved': NotificationDestination.childDetails,
    };
    for (final entry in events.entries) {
      final item = InboxNotification.fromJson(notice('id', entry.key));
      expect(item.destination, entry.value, reason: entry.key);
      expect(item.student!.number, 'ST-009');
      expect(item.isRead, isFalse);
    }
  });

  test(
    'unknown events and unsupported deep-link versions are display only',
    () {
      final unknown = InboxNotification.fromJson(
        notice('unknown', 'new_event', version: 'v2'),
      );
      expect(unknown.eventType, NotificationEventType.unknown);
      expect(unknown.destination, NotificationDestination.unavailable);
      AppStrings.setLanguage(AppLanguage.english);
      expect(AppStrings.notificationTitle(unknown), 'Server title');
      expect(AppStrings.notificationBody(unknown), 'Server body');
    },
  );

  test('parses Laravel pagination and rejects malformed responses', () {
    final result = NotificationPage.fromJson(
      page([notice('one', 'attendance_absent')], current: 2, last: 3),
    );
    expect(result.page, 2);
    expect(result.lastPage, 3);
    expect(
      () => NotificationPage.fromJson({'data': [], 'meta': {}}),
      throwsFormatException,
    );
  });

  test('API uses authenticated methods and server unread total', () async {
    final requests = <http.Request>[];
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('unread-count')) {
          return response({
            'data': {'count': 117},
          });
        }
        if (request.url.path.endsWith('/read')) {
          return response({
            'data': {
              'id': 'notice-id',
              'read_at': '2026-11-23T08:00:00.000000Z',
            },
          });
        }
        if (request.url.path.endsWith('read-all')) {
          return http.Response('', 204);
        }
        return response(page([notice('notice-id', 'attendance_absent')]));
      }),
    );
    addTearDown(api.close);
    final session = credential();

    final list = await api.fetchNotifications(session, page: 1);
    final count = await api.fetchUnreadNotificationCount(session);
    await api.markNotificationRead(session, 'notice-id');
    await api.markAllNotificationsRead(session);

    expect(list.items, hasLength(1));
    expect(count, 117);
    expect(requests.map((request) => request.method), [
      'GET',
      'GET',
      'PATCH',
      'PATCH',
    ]);
    expect(
      requests.every(
        (request) =>
            request.headers['Authorization'] == 'Bearer synthetic-test-token',
      ),
      isTrue,
    );
  });

  test(
    'refresh replaces revoked items, pages deduplicate, and count is independent',
    () async {
      var firstLoad = true;
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/me')) return response(profileJson());
          if (request.url.path.endsWith('/capabilities')) {
            return response(capabilitiesJson());
          }
          if (request.url.path.endsWith('unread-count')) {
            return response({
              'data': {'count': 42},
            });
          }
          if (request.url.path.endsWith('/notifications')) {
            if (!firstLoad) return response(page([]));
            final requestedPage = int.parse(
              request.url.queryParameters['page'] ?? '1',
            );
            if (requestedPage == 2) {
              return response(
                page(
                  [
                    notice('one', 'attendance_absent'),
                    notice('two', 'promotion_committed'),
                  ],
                  current: 2,
                  last: 2,
                ),
              );
            }
            return response(
              page([notice('one', 'attendance_absent')], last: 2),
            );
          }
          throw StateError('Unexpected request: ${request.url}');
        }),
      );
      addTearDown(api.close);
      final store = SessionStore(MemorySecureStore());
      await store.save(credential());
      final session = SessionController(api: api, store: store);
      await session.restore();
      final inbox = NotificationInboxController(session: session);
      addTearDown(inbox.dispose);
      addTearDown(session.dispose);

      await inbox.initialize();
      expect(inbox.items.map((item) => item.id), ['one']);
      expect(inbox.unreadCount, 42);
      await inbox.loadMore();
      expect(inbox.items.map((item) => item.id), ['one', 'two']);

      firstLoad = false;
      await inbox.refresh();
      expect(inbox.items, isEmpty);
      expect(inbox.unreadCount, 42);
    },
  );

  test(
    'failed read leaves item unread; successful read synchronizes count',
    () async {
      var failRead = true;
      var count = 1;
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/me')) return response(profileJson());
          if (request.url.path.endsWith('/capabilities')) {
            return response(capabilitiesJson());
          }
          if (request.url.path.endsWith('unread-count')) {
            return response({
              'data': {'count': count},
            });
          }
          if (request.url.path.endsWith('/read')) {
            if (failRead) return response({'message': 'failed'}, 500);
            count = 0;
            return response({
              'data': {'id': 'one', 'read_at': '2026-11-23T08:00:00.000000Z'},
            });
          }
          if (request.url.path.endsWith('/notifications')) {
            return response(page([notice('one', 'attendance_absent')]));
          }
          throw StateError('Unexpected request');
        }),
      );
      addTearDown(api.close);
      final store = SessionStore(MemorySecureStore());
      await store.save(credential());
      final session = SessionController(api: api, store: store);
      await session.restore();
      final inbox = NotificationInboxController(session: session);
      addTearDown(inbox.dispose);
      addTearDown(session.dispose);
      await inbox.initialize();

      await expectLater(
        inbox.markRead(inbox.items.single),
        throwsA(isA<ApiException>()),
      );
      expect(inbox.items.single.isRead, isFalse);
      failRead = false;
      await inbox.markRead(inbox.items.single);
      expect(inbox.items.single.isRead, isTrue);
      expect(inbox.unreadCount, 0);
    },
  );

  test('a stale refresh cannot undo a confirmed read', () async {
    final delayedRefresh = Completer<http.Response>();
    var listRequests = 0;
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/me')) return response(profileJson());
        if (request.url.path.endsWith('/capabilities')) {
          return response(capabilitiesJson());
        }
        if (request.url.path.endsWith('unread-count')) {
          return response({
            'data': {'count': 0},
          });
        }
        if (request.url.path.endsWith('/read')) {
          return response({
            'data': {'id': 'one', 'read_at': '2026-11-23T08:00:00.000000Z'},
          });
        }
        if (request.url.path.endsWith('/notifications')) {
          listRequests++;
          if (listRequests == 1) {
            return response(page([notice('one', 'attendance_absent')]));
          }
          return delayedRefresh.future;
        }
        throw StateError('Unexpected request');
      }),
    );
    addTearDown(api.close);
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
    final session = SessionController(api: api, store: store);
    await session.restore();
    final inbox = NotificationInboxController(session: session);
    addTearDown(inbox.dispose);
    addTearDown(session.dispose);
    await inbox.initialize();

    final refresh = inbox.refresh();
    await Future<void>.delayed(Duration.zero);
    await inbox.markRead(inbox.items.single);
    delayedRefresh.complete(
      response(page([notice('one', 'attendance_absent')])),
    );
    await refresh;

    expect(inbox.items.single.isRead, isTrue);
  });

  test(
    'disposing the authenticated inbox discards late account data',
    () async {
      final delayedRefresh = Completer<http.Response>();
      var listRequests = 0;
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/me')) return response(profileJson());
          if (request.url.path.endsWith('/capabilities')) {
            return response(capabilitiesJson());
          }
          if (request.url.path.endsWith('unread-count')) {
            return response({
              'data': {'count': 1},
            });
          }
          if (request.url.path.endsWith('/notifications')) {
            listRequests++;
            if (listRequests == 1) {
              return response(
                page([notice('old-account', 'attendance_absent')]),
              );
            }
            return delayedRefresh.future;
          }
          throw StateError('Unexpected request');
        }),
      );
      addTearDown(api.close);
      final store = SessionStore(MemorySecureStore());
      await store.save(credential());
      final session = SessionController(api: api, store: store);
      await session.restore();
      addTearDown(session.dispose);
      final inbox = NotificationInboxController(session: session);
      await inbox.initialize();

      final refresh = inbox.refresh();
      await Future<void>.delayed(Duration.zero);
      inbox.dispose();
      delayedRefresh.complete(
        response(page([notice('late-account', 'promotion_committed')])),
      );
      await refresh;

      expect(inbox.items, isEmpty);
      expect(inbox.unreadCount, isNull);
    },
  );

  for (final language in AppLanguage.values) {
    testWidgets('${language.name} inbox renders with expected direction', (
      tester,
    ) async {
      AppStrings.setLanguage(language);
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/me')) return response(profileJson());
          if (request.url.path.endsWith('/capabilities')) {
            return response(capabilitiesJson());
          }
          if (request.url.path.endsWith('unread-count')) {
            return response({
              'data': {'count': 1},
            });
          }
          if (request.url.path.endsWith('/notifications')) {
            return response(page([notice('one', 'attendance_absent')]));
          }
          throw StateError('Unexpected request');
        }),
      );
      addTearDown(api.close);
      final store = SessionStore(MemorySecureStore());
      await store.save(credential());
      final session = SessionController(api: api, store: store);
      await session.restore();
      final inbox = NotificationInboxController(session: session);
      await inbox.initialize();
      addTearDown(inbox.dispose);
      addTearDown(session.dispose);

      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Directionality(
            textDirection: language.direction,
            child: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
              child: Scaffold(
                body: NotificationsView(controller: inbox, session: session),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.notifications), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(AppStrings.notifications))),
        language.direction,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
