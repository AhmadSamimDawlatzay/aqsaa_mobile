import 'dart:async';
import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/l10n/app_strings.dart';
import 'package:aqsaa_mobile/main.dart';
import 'package:aqsaa_mobile/models/child_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'api_client_test.dart' show jsonResponse;
import 'support/auth_fixtures.dart';

Map<String, Object?> child(int id) => {
  'id': id,
  'student_number': 'TEST-$id',
  'first_name': 'Child',
  'last_name': '$id',
  'status': 'active',
};
Map<String, Object?> page(List<Object?> children, int current, int last) => {
  'data': children,
  'meta': {'current_page': current, 'last_page': last},
};

void main() {
  test(
    'linked child parses current placement and tolerates omitted or null placement',
    () {
      final withPlacement = LinkedChild.fromJson({
        ...child(1),
        'current_placement': {
          'class': {'id': 3, 'name': 'Class Seven'},
          'section': {'id': 4, 'name': 'Section A'},
          'branch': {'id': 5, 'name': 'Central'},
          'academic_year': {'id': 6, 'name': '2026'},
        },
      });
      final omitted = LinkedChild.fromJson(child(2));
      final nullPlacement = LinkedChild.fromJson({
        ...child(3),
        'current_placement': null,
      });

      expect(withPlacement.placement, {
        'class': 'Class Seven',
        'section': 'Section A',
        'branch': 'Central',
        'academic_year': '2026',
      });
      expect(omitted.placement, isEmpty);
      expect(nullPlacement.placement, isEmpty);
    },
  );

  testWidgets(
    'linked capability opens paginated children and authorized details; logout removes them',
    (tester) async {
      final memory = MemorySecureStore();
      final store = SessionStore(memory);
      await store.save(credential());
      final paths = <String>[];
      var childListRequests = 0;
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((r) async {
          paths.add(r.url.path);
          if (r.url.path.endsWith('bootstrap')) return jsonResponse();
          if (r.url.path.endsWith('capabilities')) {
            final data = capabilitiesJson();
            (data['data'] as Map)['linked_children'] = ['students'];
            return response(data);
          }
          if (r.url.path.endsWith('me/students')) {
            expect(r.headers['Authorization'], 'Bearer synthetic-test-token');
            childListRequests++;
            final current = int.parse(r.url.queryParameters['page']!);
            return response(page([child(current)], current, 2));
          }
          if (r.url.path.endsWith('me/students/2')) {
            return response({
              'data': {
                'student': child(2),
                'summary': {
                  'total': 1,
                  'present': 1,
                  'absent': 0,
                  'late': 0,
                  'excused': 0,
                  'attendance_rate': 100,
                  'unrecorded_days_are_absent': false,
                },
                'placement': {
                  'class': {'id': 3, 'name': 'Class One'},
                  'section': {'id': 4, 'name': 'Section A'},
                  'status': 'active',
                  'enrolled_at': '2026-08-20T00:00:00.000Z',
                },
                'records': {
                  'data': [
                    {
                      'id': 9,
                      'status': 'present',
                      'attendance_date': '2026-11-20',
                    },
                  ],
                  'meta': {'current_page': 1, 'last_page': 1},
                },
              },
            });
          }
          return authResponse(r);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(AqsaaApp(client: api, sessionStore: store));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AppStrings.myChildren).first);
      await tester.tap(find.text(AppStrings.myChildren).first);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.studentNumber('TEST-1')), findsOneWidget);
      await tester.ensureVisible(find.text(AppStrings.next));
      await tester.tap(find.text(AppStrings.next));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.studentNumber('TEST-2')), findsOneWidget);
      expect(find.text(AppStrings.studentNumber('TEST-1')), findsNothing);
      await tester.drag(find.byType(ListView), const Offset(0, 250));
      await tester.pumpAndSettle();
      expect(childListRequests, 3);
      await tester.ensureVisible(find.text(AppStrings.studentNumber('TEST-2')));
      await tester.tap(find.text(AppStrings.studentNumber('TEST-2')));
      await tester.pumpAndSettle();
      expect(find.text('Class One'), findsOneWidget);
      expect(find.text('Section A'), findsOneWidget);
      expect(find.text(AppStrings.enrollmentStatus('active')), findsOneWidget);
      expect(
        find.text(AppStrings.placementLabels['enrolled_at']!),
        findsOneWidget,
      );
      expect(find.textContaining('T00:00:00.000Z'), findsNothing);
      await tester.ensureVisible(find.text(AppStrings.viewAttendance));
      await tester.tap(find.text(AppStrings.viewAttendance));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.attendanceHistoryAllDates), findsOneWidget);
      expect(find.text(AppStrings.summaryPeriod), findsOneWidget);
      expect(find.text(AppStrings.allAvailableDates), findsOneWidget);
      expect(find.text(AppStrings.present), findsWidgets);
      await tester.drag(find.byType(ListView).last, const Offset(0, -520));
      await tester.pumpAndSettle();
      final attendanceContext = tester.element(
        find.text(AppStrings.attendanceHistoryAllDates),
      );
      expect(
        find.text(
          MaterialLocalizations.of(
            attendanceContext,
          ).formatMediumDate(DateTime(2026, 11, 20)),
        ),
        findsOneWidget,
      );
      Navigator.of(
        tester.element(find.text(AppStrings.attendanceHeading)),
      ).pop();
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.academicInformation), findsOneWidget);
      Navigator.of(
        tester.element(find.text(AppStrings.academicInformation)),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.accountTab).last);
      await tester.pumpAndSettle();
      expect(find.text('Test User'), findsOneWidget);
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AppStrings.logout));
      await tester.tap(find.text(AppStrings.logout).last);
      await tester.pumpAndSettle();
      expect(find.text('Test User'), findsNothing);
      expect(find.text(AppStrings.childrenTab), findsNothing);
      expect(paths.where((path) => path == '/api/v1/students'), isEmpty);
    },
  );

  testWidgets('HTTP failure is not empty; retry shows genuine empty list', (
    tester,
  ) async {
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
    var fail = true;
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((r) async {
        if (r.url.path.endsWith('bootstrap')) return jsonResponse();
        if (r.url.path.endsWith('capabilities')) {
          final data = capabilitiesJson(empty: true);
          (data['data'] as Map)['linked_children'] = ['students'];
          (data['data'] as Map)['has_linked_students'] = false;
          return response(data);
        }
        if (r.url.path.endsWith('me/students')) {
          return fail ? http.Response('', 500) : response(page([], 1, 1));
        }
        return authResponse(r);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(AqsaaApp(client: api, sessionStore: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.myChildren).last);
    await tester.tap(find.text(AppStrings.myChildren).last);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.noChildren), findsNothing);
    expect(find.textContaining('HTTP 500'), findsOneWidget);
    fail = false;
    await tester.ensureVisible(find.text(AppStrings.retry));
    await tester.tap(find.text(AppStrings.retry));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.noChildren), findsOneWidget);
  });

  testWidgets('revoked child access clears details without logging out', (
    tester,
  ) async {
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
    final paths = <String>[];
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((r) async {
        paths.add(r.url.path);
        if (r.url.path.endsWith('bootstrap')) return jsonResponse();
        if (r.url.path.endsWith('capabilities')) {
          return response({
            ...capabilitiesJson(),
            'data': {
              ...(capabilitiesJson()['data'] as Map),
              'linked_children': ['students'],
            },
          });
        }
        if (r.url.path.endsWith('me/students')) {
          return response(page([child(8)], 1, 1));
        }
        if (r.url.path.endsWith('me/students/8')) {
          return http.Response('Not found', 404);
        }
        return authResponse(r);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(AqsaaApp(client: api, sessionStore: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.myChildren).first);
    await tester.tap(find.text(AppStrings.myChildren).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.studentNumber('TEST-8')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.childAccessRevoked), findsOneWidget);
    Navigator.of(tester.element(find.text(AppStrings.childDetailsTitle))).pop();
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.accountTab), findsOneWidget);
    expect(paths.where((path) => path.endsWith('auth/logout')), isEmpty);
  });

  testWidgets('child switch discards an in-flight prior child response', (
    tester,
  ) async {
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
    final delayed = Completer<http.Response>();
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((r) async {
        if (r.url.path.endsWith('bootstrap')) return jsonResponse();
        if (r.url.path.endsWith('capabilities')) {
          return response({
            ...capabilitiesJson(),
            'data': {
              ...(capabilitiesJson()['data'] as Map),
              'linked_children': ['students'],
            },
          });
        }
        if (r.url.path.endsWith('me/students/1')) {
          return delayed.future;
        }
        if (r.url.path.endsWith('me/students/2')) {
          return response({
            'data': {
              'student': child(2),
              'placement': null,
              'summary': {
                'total': 0,
                'present': 0,
                'absent': 0,
                'late': 0,
                'excused': 0,
                'unrecorded_days_are_absent': false,
              },
              'records': {
                'data': [],
                'meta': {'current_page': 1, 'last_page': 1},
              },
            },
          });
        }
        if (r.url.path.endsWith('me/students')) {
          return response(page([child(1), child(2)], 1, 1));
        }
        return authResponse(r);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(AqsaaApp(client: api, sessionStore: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.myChildren).first);
    await tester.tap(find.text(AppStrings.myChildren).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.studentNumber('TEST-1')));
    await tester.tap(find.text(AppStrings.studentNumber('TEST-1')));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text(AppStrings.childDetailsTitle))).pop();
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.studentNumber('TEST-2')));
    await tester.tap(find.text(AppStrings.studentNumber('TEST-2')));
    await tester.pumpAndSettle();
    delayed.complete(
      response({
        'data': {
          'student': child(1),
          'placement': null,
          'summary': {
            'total': 0,
            'present': 0,
            'absent': 0,
            'late': 0,
            'excused': 0,
            'unrecorded_days_are_absent': false,
          },
          'records': {
            'data': [],
            'meta': {'current_page': 1, 'last_page': 1},
          },
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('Child 2'), findsOneWidget);
    expect(find.text('Child 1'), findsNothing);
  });

  testWidgets('long child names fit a compact RTL layout at larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final longName = 'A very long student name that should wrap comfortably';
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((r) async {
        if (r.url.path.endsWith('bootstrap')) return jsonResponse();
        if (r.url.path.endsWith('capabilities')) {
          return response({
            ...capabilitiesJson(),
            'data': {
              ...(capabilitiesJson()['data'] as Map),
              'linked_children': ['students'],
            },
          });
        }
        if (r.url.path.endsWith('me/students')) {
          return response({
            'data': [
              {
                'id': 12,
                'student_number': 'ST-12',
                'first_name': longName,
                'last_name': '',
                'placement': {
                  'class': {'name': 'A long class name'},
                  'section': {'name': 'A section'},
                  'branch': {'name': 'North branch'},
                },
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        }
        return authResponse(r);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      AqsaaApp(
        client: api,
        sessionStore: store,
        textDirection: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(longName), findsOneWidget);
    expect(find.text('A long class name · A section'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(AppStrings.accountTab).last);
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.accountHeading), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
