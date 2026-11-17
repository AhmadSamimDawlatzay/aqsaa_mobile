import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bootstrap_response.dart';
import '../models/auth_models.dart';

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
