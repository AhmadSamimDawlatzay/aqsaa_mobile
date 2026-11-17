import 'dart:convert';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/models/auth_models.dart';
import 'package:http/http.dart' as http;

class MemorySecureStore implements SecureKeyValueStore {
  final values = <String, String>{};
  bool failRead = false;
  bool failWrite = false;
  bool failDelete = false;
  @override
  Future<String?> read(String key) async {
    if (failRead) throw StateError('storage unavailable');
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw StateError('storage unavailable');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw StateError('storage unavailable');
    values.remove(key);
  }
}

const testBase = 'https://example.test/api/v1/';
SessionCredential credential([String base = testBase]) => SessionCredential(
  apiBase: base,
  token: 'synthetic-test-token',
  expiresAt: DateTime.utc(2030),
);
Map<String, Object?> loginJson() => {
  'token': 'synthetic-test-token',
  'token_type': 'Bearer',
  'expires_at': '2030-01-01T00:00:00.000000Z',
};
Map<String, Object?> profileJson() => {
  'data': {
    'id': 5,
    'name': 'Test User',
    'email': 'user@example.test',
    'locale': 'ps',
    'roles': ['Teacher'],
    'branches': [
      {'id': 1, 'name': 'Main', 'code': 'MAIN'},
    ],
    'staff_id': 3,
    'teacher_id': 7,
  },
};
Map<String, Object?> capabilitiesJson({bool empty = false}) => {
  'data': {
    'read_only': true,
    'resources': empty ? [] : ['classes', 'students'],
    'resource_scopes': empty
        ? []
        : {'classes': 'general', 'students': 'linked_children'},
    'own_records': empty ? [] : ['staff-profile'],
    'linked_children': empty ? [] : ['attendance-summary'],
    'assigned_teaching': empty ? [] : ['assignments', 'timetable'],
    'technical_actions': [
      'logout',
      'device_registration',
      'notification_read_status',
    ],
  },
};
http.Response response(Object? body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);
http.Response authResponse(http.Request request) =>
    switch (request.url.path.split('/').last) {
      'login' => response(loginJson(), 201),
      'me' => response(profileJson()),
      'capabilities' => response(capabilitiesJson()),
      'logout' => http.Response('', 204),
      _ => throw StateError('Unexpected request'),
    };
