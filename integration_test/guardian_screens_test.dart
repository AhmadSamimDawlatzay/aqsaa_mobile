import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/l10n/app_strings.dart';
import 'package:aqsaa_mobile/l10n/app_language.dart';
import 'package:aqsaa_mobile/l10n/locale_controller.dart';
import 'package:aqsaa_mobile/main.dart';
import 'package:aqsaa_mobile/models/notification_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import '../test/api_client_test.dart' show jsonResponse;
import '../test/support/auth_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures welcome and login in every language', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    final memory = MemorySecureStore();
    final store = SessionStore(memory);
    final locale = LocaleController(memory);
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((request) async => jsonResponse()),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      AqsaaApp(client: api, sessionStore: store, localeController: locale),
    );
    await tester.pumpAndSettle();

    for (final language in AppLanguage.values) {
      await locale.select(language);
      await tester.pumpAndSettle();
      await _capture(binding, '${language.backendCode}-welcome');
      await tester.tap(find.text(AppStrings.login).last);
      await tester.pumpAndSettle();
      await _capture(binding, '${language.backendCode}-login');
      await tester.tap(find.text(AppStrings.back));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('captures guardian navigation screens with mock data', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
    final locale = LocaleController(store.storage);
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('bootstrap')) return jsonResponse();
        if (path.endsWith('capabilities')) {
          final caps = capabilitiesJson();
          (caps['data'] as Map)['linked_children'] = ['students'];
          return response(caps);
        }
        if (path.endsWith('me/students/21')) {
          return response({
            'data': {
              'student': {
                'id': 21,
                'student_number': 'SAMPLE-0021',
                'first_name': 'Sample',
                'last_name': 'Student',
                'status': 'active',
              },
              'placement': {
                'class': {'id': 1, 'name': 'Class Seven'},
                'section': {'id': 2, 'name': 'Section A'},
                'program': {'id': 3, 'name': 'General'},
                'level': {'id': 4, 'name': 'Middle'},
                'academic_year': {'id': 5, 'name': '2026'},
                'branch': {'id': 6, 'name': 'Central'},
                'status': 'active',
                'enrolled_at': '2026-08-20T12:00:00Z',
              },
              'summary': {
                'total': 4,
                'present': 2,
                'absent': 1,
                'late': 1,
                'excused': 0,
                'unrecorded_days_are_absent': false,
              },
              'records': {
                'data': [
                  {
                    'id': 101,
                    'status': 'present',
                    'attendance_date': '2026-11-20',
                  },
                  {
                    'id': 102,
                    'status': 'late',
                    'attendance_date': '2026-11-19',
                  },
                ],
                'current_page': 1,
                'last_page': 1,
              },
            },
          });
        }
        if (path.endsWith('me/students')) {
          return response({
            'data': [
              {
                'id': 21,
                'student_number': 'SAMPLE-0021',
                'first_name': 'Sample',
                'last_name': 'Student',
                'status': 'active',
                'current_placement': {
                  'class': {'name': 'Class Seven'},
                  'section': {'name': 'Section A'},
                  'branch': {'name': 'Central'},
                  'academic_year': {'name': '2026'},
                },
              },
              {
                'id': 22,
                'student_number': 'SAMPLE-0022',
                'first_name': 'Another',
                'last_name': 'Student',
                'status': 'active',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        }
        if (path.endsWith('notifications/unread-count')) {
          return response({
            'data': {'count': 1},
          });
        }
        if (path.endsWith('notifications/fixture-notice/read')) {
          return response({
            'data': {
              'id': 'fixture-notice',
              'read_at': '2026-11-23T09:00:00.000000Z',
            },
          });
        }
        if (path.endsWith('notifications')) {
          return response({
            'data': [
              {
                'id': 'fixture-notice',
                'event_type': 'attendance_absent',
                'student': {
                  'id': 21,
                  'student_number': 'SAMPLE-0021',
                  'name': 'Sample Student',
                },
                'translation_key': 'guardian.attendance_absent',
                'translation_params': {'student': 'Sample Student'},
                'deep_link': {
                  'version': 'v1',
                  'route': 'guardian.student',
                  'student_id': 21,
                  'tab': 'student-attendances',
                },
                'title': 'Attendance update',
                'body': 'Sample Student was recorded absent.',
                'read_at': null,
                'created_at': '2026-11-23T07:00:00.000000Z',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        }
        return authResponse(request);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      AqsaaApp(client: api, sessionStore: store, localeController: locale),
    );
    await tester.pumpAndSettle();
    for (final language in AppLanguage.values) {
      await locale.select(language);
      await tester.pumpAndSettle();
      final suffix = language.backendCode;
      await tester.ensureVisible(
        find.text(AppStrings.studentNumber('SAMPLE-0021')),
      );
      expect(find.text(AppStrings.academicYearValue('2026')), findsOneWidget);
      await _capture(binding, '$suffix-my-children');

      await tester.tap(find.text(AppStrings.studentNumber('SAMPLE-0021')));
      await tester.pumpAndSettle();
      await _capture(binding, '$suffix-child-details');

      await tester.ensureVisible(find.text(AppStrings.viewAttendance));
      await tester.tap(find.text(AppStrings.viewAttendance));
      await tester.pumpAndSettle();
      await _capture(binding, '$suffix-attendance');

      Navigator.of(
        tester.element(find.text(AppStrings.attendanceHeading)),
      ).pop();
      await tester.pumpAndSettle();
      Navigator.of(
        tester.element(find.text(AppStrings.academicInformation)),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.notifications).last);
      await tester.pumpAndSettle();
      await _capture(binding, '$suffix-notifications');
      await tester.tap(
        find.text(
          AppStrings.notificationTitle(
            InboxNotification.fromJson({
              'id': 'fixture-notice',
              'event_type': 'attendance_absent',
              'translation_key': 'guardian.attendance_absent',
              'translation_params': {'student': 'Sample Student'},
              'title': 'Attendance update',
              'body': 'Sample Student was recorded absent.',
              'created_at': '2026-11-23T07:00:00.000000Z',
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _capture(binding, '$suffix-notification-detail');
      Navigator.of(
        tester.element(find.text(AppStrings.notificationDetails)),
      ).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.accountTab).last);
      await tester.pumpAndSettle();
      await _capture(binding, '$suffix-account');
      if (language != AppLanguage.values.last) {
        await tester.tap(find.text(AppStrings.childrenTab).last);
        await tester.pumpAndSettle();
      }
    }
  });
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.takeScreenshot(name);
  debugPrint('SCREENSHOT_READY:$name');
  await Future<void>.delayed(const Duration(milliseconds: 400));
}
