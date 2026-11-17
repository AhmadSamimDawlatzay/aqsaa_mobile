import '../api/api_client.dart';

// English source copy; migrate to ARB when ps/fa/ar/en translations are added.
abstract final class AppStrings {
  static const appName = 'Aqsaa';
  static const welcome = 'Welcome to Aqsaa';
  static const subtitle = 'Your institution, connected.';
  static const loading = 'Connecting to your institution...';
  static const connected = 'Connected';
  static const empty =
      'The API is connected, but no institution is configured yet.';
  static const failed = 'Unable to connect';
  static const retry = 'Retry';
  static const refresh = 'Refresh';
  static const logo = 'Institution logo';
  static const logoFallback = 'Institution logo unavailable';
  static String error(Object? error) {
    if (error is! ApiException) {
      return 'Something went wrong. Please try again.';
    }
    return switch (error.failure) {
      ApiFailure.configuration =>
        'Set API_BASE_URL to an HTTPS URL ending in /api/v1.',
      ApiFailure.network => 'Check your internet connection and try again.',
      ApiFailure.timeout =>
        'The server took too long to respond. Please try again.',
      ApiFailure.http =>
        'The server returned HTTP ${error.statusCode}. Please try again.',
      ApiFailure.contentType =>
        'HTTP ${error.statusCode}: the server did not return JSON. Check the API deployment.',
      ApiFailure.contract =>
        'The response does not match the mobile API v1 contract.',
    };
  }
}
