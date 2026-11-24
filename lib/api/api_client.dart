import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bootstrap_response.dart';
import '../models/auth_models.dart';
import '../models/child_models.dart';
import '../models/notification_models.dart';

enum ApiFailure {
  configuration,
  network,
  timeout,
  http,
  contentType,
  contract,
  validation,
  invalidCredentials,
  unauthorized,
  forbidden,
  rateLimited,
  redirect,
}

class ApiException implements Exception {
  const ApiException(
    this.failure, {
    this.statusCode,
    this.fieldErrors = const {},
    this.retryAfter,
  });
  final ApiFailure failure;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;
  final String? retryAfter;
}

class ApiClient {
  ApiClient({
    this._baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'https://demo.aqsaa.app/api/v1',
    ),
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();
  final String _baseUrl;
  final http.Client _client;
  final Duration timeout;

  Uri get baseUri {
    final uri = Uri.tryParse(_baseUrl.trim().replaceFirst(RegExp(r'/+$'), ''));
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty ||
        !uri.path.endsWith('/api/v1') ||
        '/api/v1'.allMatches(uri.path).length != 1 ||
        uri.pathSegments.contains('..')) {
      throw const ApiException(ApiFailure.configuration);
    }
    return uri.replace(path: '${uri.path}/');
  }

  String get sessionScope => baseUri.toString();

  Future<BootstrapResponse> fetchBootstrap() => _parse(
    () async => BootstrapResponse.fromJson(await _request('GET', 'bootstrap')),
  );

  Future<SessionCredential> login({
    required String email,
    required String password,
    required String deviceId,
    required String deviceName,
  }) => _parse(() async {
    if (deviceId.trim().isEmpty ||
        deviceId.length > 191 ||
        deviceName.trim().isEmpty ||
        deviceName.length > 120) {
      throw const ApiException(
        ApiFailure.validation,
        fieldErrors: {
          'device_id': ['Invalid device identifier'],
        },
      );
    }
    final result = await _request(
      'POST',
      'auth/login',
      expectedStatus: 201,
      body: {
        'email': email.trim(),
        'password': password,
        'device_name': deviceName,
        'device_id': deviceId,
      },
    );
    return SessionCredential.fromLogin(result, sessionScope);
  });
  Future<UserProfile> fetchProfile(SessionCredential session) => _parse(
    () async =>
        UserProfile.fromJson(await _request('GET', 'me', session: session)),
  );
  Future<Capabilities> fetchCapabilities(SessionCredential session) => _parse(
    () async => Capabilities.fromJson(
      await _request('GET', 'capabilities', session: session),
    ),
  );
  Future<void> logout(SessionCredential session) async {
    await _request(
      'POST',
      'auth/logout',
      session: session,
      expectedStatus: 204,
    );
  }

  Future<ChildDetails> fetchChild(
    SessionCredential session,
    int id, {
    int page = 1,
  }) => _parse(
    () async => ChildDetails.fromJson(
      await _request(
        'GET',
        'me/students/$id?tab=student-attendances&page=$page',
        session: session,
      ),
    ),
  );

  Future<ChildPage> fetchChildren(SessionCredential session, {int page = 1}) =>
      _parse(
        () async => ChildPage.fromJson(
          await _request('GET', 'me/students?page=$page', session: session),
        ),
      );

  Future<AttendanceSummary> fetchAttendanceSummary(
    SessionCredential session,
    int id, {
    DateTime? from,
    DateTime? to,
  }) => _parse(() async {
    final query = <String, String>{};
    if (from != null) query['from'] = _date(from);
    if (to != null) query['to'] = _date(to);
    final suffix = query.isEmpty ? '' : '?${Uri(queryParameters: query).query}';
    return AttendanceSummary.fromJson(
      await _request(
        'GET',
        'students/$id/attendance-summary$suffix',
        session: session,
      ),
    );
  });

  Future<NotificationPage> fetchNotifications(
    SessionCredential session, {
    int page = 1,
    int perPage = 25,
  }) => _parse(
    () async => NotificationPage.fromJson(
      await _request(
        'GET',
        'notifications?page=$page&per_page=$perPage',
        session: session,
      ),
    ),
  );

  Future<int> fetchUnreadNotificationCount(SessionCredential session) =>
      _parse(() async {
        final response = authObject(
          await _request('GET', 'notifications/unread-count', session: session),
        );
        final count = authInt(authObject(response['data'])['count']);
        if (count < 0) throw const FormatException('Invalid unread count');
        return count;
      });

  Future<DateTime> markNotificationRead(SessionCredential session, String id) =>
      _parse(() async {
        final encodedId = Uri.encodeComponent(id);
        final response = authObject(
          await _request(
            'PATCH',
            'notifications/$encodedId/read',
            session: session,
          ),
        );
        final data = authObject(response['data']);
        if (authString(data['id']) != id) {
          throw const FormatException('Notification ID mismatch');
        }
        return DateTime.parse(authString(data['read_at']));
      });

  Future<void> markAllNotificationsRead(SessionCredential session) => _request(
    'PATCH',
    'notifications/read-all',
    session: session,
    expectedStatus: 204,
  );

  String _date(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<T> _parse<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FormatException {
      throw const ApiException(ApiFailure.contract);
    }
  }

  Future<Object?> _request(
    String method,
    String path, {
    SessionCredential? session,
    Map<String, String>? body,
    int expectedStatus = 200,
  }) async {
    final uri = baseUri.resolve(path);
    if (session != null && session.apiBase != sessionScope) {
      throw const ApiException(ApiFailure.configuration);
    }
    final request = http.Request(method, uri)..followRedirects = false;
    request.headers['Accept'] = 'application/json';
    if (session != null) {
      request.headers['Authorization'] = 'Bearer ${session.token}';
    }
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(timeout);
      final status = response.statusCode;
      if (status != expectedStatus) {
        var failure = switch (status) {
          401 => ApiFailure.unauthorized,
          403 => ApiFailure.forbidden,
          429 => ApiFailure.rateLimited,
          >= 300 && < 400 => ApiFailure.redirect,
          _ => ApiFailure.http,
        };
        final fields = <String, List<String>>{};
        if (status == 422) {
          var hasJsonMessage = false;
          try {
            final data = jsonDecode(utf8.decode(response.bodyBytes));
            hasJsonMessage = data is Map && data['message'] is String;
            if (data is Map && data['errors'] is Map) {
              for (final entry in (data['errors'] as Map).entries) {
                if (entry.key is String && entry.value is List) {
                  fields[entry.key as String] = List<String>.unmodifiable(
                    (entry.value as List).whereType<String>(),
                  );
                }
              }
            }
          } on FormatException {
            /* Never display raw server pages or bodies. */
          }
          if (fields.isNotEmpty) {
            failure = ApiFailure.validation;
          } else if (hasJsonMessage && path == 'auth/login') {
            failure = ApiFailure.invalidCredentials;
          }
        }
        throw ApiException(
          failure,
          statusCode: status,
          fieldErrors: Map.unmodifiable(fields),
          retryAfter: response.headers['retry-after'],
        );
      }
      if (expectedStatus == 204) return null;
      if (response.headers['content-type']
              ?.split(';')
              .first
              .trim()
              .toLowerCase() !=
          'application/json') {
        throw ApiException(ApiFailure.contentType, statusCode: status);
      }
      return jsonDecode(utf8.decode(response.bodyBytes));
    } on TimeoutException {
      throw const ApiException(ApiFailure.timeout);
    } on http.ClientException {
      throw const ApiException(ApiFailure.network);
    } on FormatException {
      throw const ApiException(ApiFailure.contract);
    }
  }

  Uri? logoUri(String? path) {
    if (path == null || path.trim().isEmpty) return null;
    final uri = Uri.tryParse(path);
    if (uri == null ||
        uri.hasScheme ||
        uri.hasAuthority ||
        uri.pathSegments.contains('..')) {
      return null;
    }
    return baseUri
        .resolve('../../')
        .resolve('storage/${path.replaceFirst(RegExp(r'^/+'), '')}');
  }

  void close() => _client.close();
}
