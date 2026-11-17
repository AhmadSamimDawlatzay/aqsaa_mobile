import '../api/api_client.dart';
import '../auth/session_store.dart';

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
  static const login = 'Log in';
  static const logout = 'Log out';
  static const email = 'Email';
  static const password = 'Password';
  static const showPassword = 'Show password';
  static const hidePassword = 'Hide password';
  static const requiredField = 'This field is required.';
  static const invalidEmail =
      'Enter a valid email address (up to 255 characters).';
  static const passwordTooLong = 'Password must be at most 255 characters.';
  static const back = 'Back to welcome';
  static const checkingSession = 'Verifying your session...';
  static const signingOut = 'Signing out...';
  static const home = 'Your account';
  static const accessReady =
      'Your account access is ready. More features will be added later.';
  static const noCapabilities =
      'No supported access is assigned to this account. Contact your institution administrator.';
  static const logoutUnconfirmed =
      'Server logout was not confirmed. Your session is kept on this device so you can retry. Remote device registration cleanup has not been confirmed.';
  static const invalidSession =
      'Your session is no longer valid. Please log in again. Any previous server device registration may still need administrator cleanup.';
  static String roles(List<String> roles) =>
      roles.isEmpty ? 'No roles assigned' : 'Roles: ${roles.join(', ')}';
  static String fieldError(String field) => switch (field) {
    'email' => 'Check the email address.',
    'password' => 'Check the password.',
    'device_id' || 'device_name' =>
      'The server rejected this installation identifier. Please contact support.',
    _ => 'The server rejected a login field.',
  };
  static String error(Object? error) {
    if (error is SessionStorageException) {
      return 'Secure storage is unavailable. Unlock your device and retry. Your stored session has not been deliberately removed.';
    }
    if (error is! ApiException) {
      return 'Something went wrong. Please try again.';
    }
    return switch (error.failure) {
      ApiFailure.invalidCredentials =>
        'The email or password is incorrect, or the account is inactive.',
      ApiFailure.validation =>
        'The server could not validate the submitted fields.',
      ApiFailure.unauthorized =>
        'Your session is no longer valid. Please log in again.',
      ApiFailure.forbidden =>
        'This account is not allowed to access this resource. Your session has been kept.',
      ApiFailure.rateLimited =>
        'Too many attempts. Wait a minute, then try again.',
      ApiFailure.redirect =>
        'The API returned a redirect. Check the configured API URL.',
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
