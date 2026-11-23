import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/l10n/app_strings.dart';
import 'package:aqsaa_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import '../test/api_client_test.dart' show jsonResponse;
import '../test/support/auth_fixtures.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures guardian navigation screens with mock data', (
    tester,
  ) async {
    await binding.convertFlutterSurfaceToImage();
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
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
        return authResponse(request);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(AqsaaApp(client: api, sessionStore: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.text(AppStrings.studentNumber('SAMPLE-0021')),
    );
    expect(find.text(AppStrings.academicYearValue('2026')), findsOneWidget);
    await _capture(binding, 'guardian-my-children');

    await tester.tap(find.text(AppStrings.studentNumber('SAMPLE-0021')));
    await tester.pumpAndSettle();
    await _capture(binding, 'guardian-child-details');

    await tester.ensureVisible(find.text(AppStrings.viewAttendance));
    await tester.tap(find.text(AppStrings.viewAttendance));
    await tester.pumpAndSettle();
    await _capture(binding, 'guardian-attendance');

    Navigator.of(tester.element(find.text(AppStrings.attendanceHeading))).pop();
    await tester.pumpAndSettle();
    Navigator.of(
      tester.element(find.text(AppStrings.academicInformation)),
    ).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.accountTab).last);
    await tester.pumpAndSettle();
    await _capture(binding, 'guardian-account');
  });
}

Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  String name,
) async {
  await binding.takeScreenshot(name);
  debugPrint('SCREENSHOT_READY:$name');
  await Future<void>.delayed(const Duration(seconds: 14));
}
