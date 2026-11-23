import 'dart:convert';
import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/models/auth_models.dart';
import 'package:aqsaa_mobile/models/child_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'support/auth_fixtures.dart';

void main() {
  test(
    'login posts exact contract, no bearer, and parses 201 token expiry',
    () async {
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/auth/login');
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], isNull);
          expect(jsonDecode(request.body), {
            'email': 'user@example.test',
            'password': 'synthetic-password',
            'device_id': 'installation-test',
            'device_name': 'Test Android',
          });
          return response(loginJson(), 201);
        }),
      );
      addTearDown(api.close);
      final session = await api.login(
        email: ' user@example.test ',
        password: 'synthetic-password',
        deviceId: 'installation-test',
        deviceName: 'Test Android',
      );
      expect(session.token, 'synthetic-test-token');
      expect(session.apiBase, testBase);
      expect(session.expiresAt, DateTime.utc(2030));
    },
  );
  test('device identifier is mandatory before sending login', () async {
    var requests = 0;
    final api = ApiClient(
      client: MockClient((_) async {
        requests++;
        return response(loginJson(), 201);
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.login(
        email: 'user@example.test',
        password: 'synthetic-password',
        deviceId: '',
        deviceName: 'Test',
      ),
      throwsA(
        isA<ApiException>().having(
          (e) => e.failure,
          'failure',
          ApiFailure.validation,
        ),
      ),
    );
    expect(requests, 0);
  });
  test(
    'login distinguishes credential, field, rate and server errors',
    () async {
      for (final item in [
        (
          response({'message': 'The provided credentials are incorrect.'}, 422),
          ApiFailure.invalidCredentials,
        ),
        (
          response({
            'message': 'Invalid',
            'errors': {
              'email': ['Invalid email'],
            },
          }, 422),
          ApiFailure.validation,
        ),
        (
          http.Response('', 429, headers: {'retry-after': '60'}),
          ApiFailure.rateLimited,
        ),
        (response({'message': 'Error'}, 500), ApiFailure.http),
      ]) {
        final api = ApiClient(client: MockClient((_) async => item.$1));
        addTearDown(api.close);
        try {
          await api.login(
            email: 'user@example.test',
            password: 'synthetic-password',
            deviceId: 'test-id',
            deviceName: 'Test',
          );
          fail('Expected exception');
        } on ApiException catch (e) {
          expect(e.failure, item.$2);
          if (e.failure == ApiFailure.validation) {
            expect(e.fieldErrors['email'], ['Invalid email']);
          }
          if (e.failure == ApiFailure.rateLimited) expect(e.retryAfter, '60');
        }
      }
    },
  );
  test(
    'only authenticated endpoints attach bearer; redirects are not followed',
    () async {
      final requests = <http.Request>[];
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((request) async {
          requests.add(request);
          expect(request.followRedirects, isFalse);
          expect(
            request.headers['Authorization'],
            'Bearer synthetic-test-token',
          );
          return authResponse(request);
        }),
      );
      addTearDown(api.close);
      final user = await api.fetchProfile(credential());
      expect(user.name, 'Test User');
      expect(user.branches.single.code, 'MAIN');
      expect(user.staffId, 3);
      await api.fetchCapabilities(credential());
      await api.logout(credential());
      expect(requests.map((r) => r.method), ['GET', 'GET', 'POST']);
      final redirect = ApiClient(
        baseUrl: testBase,
        client: MockClient((request) async {
          expect(request.followRedirects, isFalse);
          return http.Response(
            '',
            302,
            headers: {'location': 'https://external.test/steal'},
          );
        }),
      );
      addTearDown(redirect.close);
      await expectLater(
        redirect.fetchProfile(credential()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            ApiFailure.redirect,
          ),
        ),
      );
    },
  );
  test('token cannot be sent to another origin or API installation', () async {
    for (final base in [
      'https://other.test/api/v1/',
      'https://example.test/other/api/v1/',
    ]) {
      var sent = false;
      final api = ApiClient(
        baseUrl: base,
        client: MockClient((_) async {
          sent = true;
          return response(profileJson());
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.fetchProfile(credential()),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            ApiFailure.configuration,
          ),
        ),
      );
      expect(sent, isFalse);
    }
  });
  test(
    'capabilities retain each scope; empty Laravel collection is supported',
    () {
      final caps = Capabilities.fromJson(capabilitiesJson());
      expect(caps.generalResources, ['classes']);
      expect(caps.resourceScopes['students'], ResourceScope.linkedChildren);
      expect(caps.ownRecords, ['staff-profile']);
      expect(caps.linkedChildren, ['attendance-summary']);
      expect(caps.assignedTeaching, ['assignments', 'timetable']);
      expect(caps.technicalActions, contains('logout'));
      expect(
        Capabilities.fromJson(capabilitiesJson(empty: true)).hasSupportedAccess,
        isFalse,
      );
      expect(() => Capabilities.fromJson({'data': {}}), throwsFormatException);
      expect(
        () => SessionCredential.fromLogin({
          ...loginJson(),
          'token_type': 'Other',
        }, testBase),
        throwsFormatException,
      );
    },
  );

  test(
    'child detail parses missing placement, summary, and attendance records',
    () {
      final detail = ChildDetails.fromJson({
        'data': {
          'student': {
            'id': 8,
            'student_number': 'ST-8',
            'first_name': 'Amina',
            'last_name': null,
            'status': 'active',
          },
          'placement': null,
          'summary': {
            'present': 0,
            'absent': 0,
            'late': 1,
            'excused': 0,
            'recorded_days': 1,
            'attendance_rate': 100,
            'unrecorded_days_are_absent': false,
          },
          'records': {
            'data': [
              {'id': 4, 'status': 'late', 'attendance_date': '2026-11-20'},
            ],
            'current_page': 2,
            'last_page': 3,
          },
        },
      });
      expect(detail.child.name, 'Amina');
      expect(detail.placement, isEmpty);
      expect(detail.summary.total, 1);
      expect(detail.summary.unrecordedDaysAreAbsent, isFalse);
      expect(detail.attendance.single.status, 'late');
      expect(detail.page, 2);
      expect(detail.lastPage, 3);
      expect(
        () => AttendanceSummary.fromJson({'total': 0}),
        throwsFormatException,
      );
    },
  );

  test(
    'attendance date query is sent exactly to authorized endpoint',
    () async {
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((r) async {
          expect(r.url.path, '/api/v1/students/8/attendance-summary');
          expect(r.url.queryParameters, {
            'from': '2026-11-01',
            'to': '2026-11-22',
          });
          expect(r.headers['Authorization'], 'Bearer synthetic-test-token');
          return response({
            'data': {
              'present': 1,
              'absent': 0,
              'late': 0,
              'excused': 0,
              'recorded_days': 1,
              'unrecorded_days_are_absent': false,
            },
          });
        }),
      );
      addTearDown(api.close);
      final result = await api.fetchAttendanceSummary(
        credential(),
        8,
        from: DateTime(2026, 11, 1),
        to: DateTime(2026, 11, 22),
      );
      expect(result.present, 1);
    },
  );
  test('child attendance history requests the selected Laravel page', () async {
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((r) async {
        expect(r.url.path, '/api/v1/me/students/8');
        expect(r.url.queryParameters, {
          'tab': 'student-attendances',
          'page': '2',
        });
        expect(r.headers['Authorization'], 'Bearer synthetic-test-token');
        return response({
          'data': {
            'student': {
              'id': 8,
              'student_number': 'ST-8',
              'first_name': 'Amina',
              'last_name': null,
            },
            'placement': null,
            'summary': {
              'present': 1,
              'absent': 0,
              'late': 0,
              'excused': 0,
              'total': 1,
              'unrecorded_days_are_absent': false,
            },
            'records': {'data': [], 'current_page': 2, 'last_page': 2},
          },
        });
      }),
    );
    addTearDown(api.close);
    final child = await api.fetchChild(credential(), 8, page: 2);
    expect(child.page, 2);
  });
}
