import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/bootstrap_response.dart';

enum ApiFailure { configuration, network, timeout, http, contentType, contract }

class ApiException implements Exception {
  const ApiException(this.failure, {this.statusCode});
  final ApiFailure failure;
  final int? statusCode;
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
        '/api/v1'.allMatches(uri.path).length != 1) {
      throw const ApiException(ApiFailure.configuration);
    }
    return uri.replace(path: '${uri.path}/');
  }

  Future<BootstrapResponse> fetchBootstrap() async {
    final uri = baseUri.resolve('bootstrap');
    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw ApiException(ApiFailure.http, statusCode: response.statusCode);
      }
      final type = response.headers['content-type']
          ?.split(';')
          .first
          .trim()
          .toLowerCase();
      if (type != 'application/json') {
        throw ApiException(
          ApiFailure.contentType,
          statusCode: response.statusCode,
        );
      }
      return BootstrapResponse.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)),
      );
    } on TimeoutException {
      throw const ApiException(ApiFailure.timeout);
    } on http.ClientException {
      throw const ApiException(ApiFailure.network);
    } on FormatException {
      throw const ApiException(ApiFailure.contract);
    }
  }

  // Laravel returns a public-disk path, not an API-relative URL.
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
