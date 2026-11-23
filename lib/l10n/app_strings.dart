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
  static const loginHeading = 'Sign in to your account';
  static const loginSubtitle = 'Use your institution account to continue.';
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
  static const accountHeading = 'Account';
  static const accountSubtitle = 'Your profile and sign-out options.';
  static const accountTab = 'Account';
  static const childrenTab = 'Children';
  static const profileSection = 'Profile';
  static const institutionSection = 'Institution';
  static const name = 'Name';
  static const academicInformation = 'Academic information';
  static const attendanceHeading = 'Attendance';
  static const summaryPeriod = 'Summary period';
  static const allAvailableDates = 'All available dates';
  static const editSummaryPeriod = 'Edit summary period';
  static const attendanceHistoryAllDates = 'Attendance history — all dates';
  static const summaryUnavailable = 'Summary is unavailable for this period.';
  static const myChildren = 'My Children';
  static const noChildrenTitle = 'No linked students';
  static const loadingChildren = 'Loading your children...';
  static const errorHeading = 'Something went wrong';
  static const childDetailsTitle = 'Child details';
  static const viewAttendance = 'View attendance';
  static const chooseSummaryPeriod = 'Choose summary period';
  static const noAttendanceTitle = 'No attendance yet';
  static String studentNumber(String value) => 'Student number: $value';
  static String branchValue(String value) => 'Branch: $value';
  static const noChildren =
      'No students are linked to your account. Contact your institution administrator.';
  static const childAccessRevoked =
      'Access to this student is no longer available. Return to My Children or ask your institution administrator to check the link.';
  static const noPlacement = 'No current class placement is available.';
  static const noAttendance = 'No attendance records are available.';
  static const previous = 'Previous';
  static const next = 'Next';
  static const attendanceSummary = 'Attendance summary';
  static const present = 'Present';
  static const absent = 'Absent';
  static const late = 'Late';
  static const excused = 'Excused';
  static const filterDates = 'Filter summary by dates';
  static const nextAttendancePage = 'More attendance';
  static const unrecordedNotAbsent =
      'Unrecorded days are not counted as absent.';
  static const filteredSummary = 'Filtered totals';
  static String recordedDays(int value) => 'Recorded days: $value';
  static const placementLabels = {
    'class': 'Class',
    'section': 'Section',
    'program': 'Program',
    'level': 'Level',
    'academic_year': 'Academic year',
    'branch': 'Branch',
    'status': 'Enrollment status',
    'enrolled_at': 'Enrolled on',
  };
  static const noCapabilities =
      'No supported access is assigned to this account. Contact your institution administrator.';
  static const logoutUnconfirmed =
      'Server logout was not confirmed. Your session is kept on this device so you can retry. Remote device registration cleanup has not been confirmed.';
  static const invalidSession =
      'Your session is no longer valid. Please log in again. Any previous server device registration may still need administrator cleanup.';
  static String roles(List<String> roles) =>
      roles.isEmpty ? 'No roles assigned' : 'Roles: ${roles.join(', ')}';
  static String greeting(String name) =>
      'Welcome, ${name.trim().split(' ').first}';
  static String enrollmentStatus(String status) =>
      switch (status.toLowerCase()) {
        'active' => 'Active',
        'completed' => 'Completed',
        'cancelled' => 'Cancelled',
        'withdrawn' => 'Withdrawn',
        _ => status.replaceAll('_', ' '),
      };
  static String attendanceStatus(String status) =>
      switch (status.toLowerCase()) {
        'present' => present,
        'absent' => absent,
        'late' => late,
        'excused' => excused,
        _ => status.replaceAll('_', ' '),
      };
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
