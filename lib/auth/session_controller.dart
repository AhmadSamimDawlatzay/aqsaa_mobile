import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../models/auth_models.dart';
import '../models/child_models.dart';
import '../models/notification_models.dart';
import 'session_store.dart';

enum SessionPhase {
  restoring,
  signedOut,
  signingIn,
  validating,
  authenticated,
  failure,
  loggingOut,
}

class SessionController extends ChangeNotifier {
  SessionController({required this.api, required this.store});
  final ApiClient api;
  final SessionStore store;
  SessionPhase phase = SessionPhase.restoring;
  UserProfile? profile;
  Capabilities? capabilities;
  Object? error;
  bool showLogin = false;
  bool invalidSessionNotice = false;
  bool logoutUnconfirmed = false;
  SessionCredential? _credential;
  bool _needsSave = false;
  bool _needsClear = false;
  bool _disposed = false;
  int _generation = 0;
  bool get hasSession => _credential != null;
  Future<T> _childRequest<T>(
    Future<T> Function(SessionCredential) action,
  ) async {
    if (phase != SessionPhase.authenticated ||
        capabilities?.canViewChildren != true ||
        _credential == null) {
      throw const ApiException(ApiFailure.forbidden);
    }
    final generation = _generation;
    try {
      final result = await action(_credential!);
      if (!_current(generation)) {
        throw const ApiException(ApiFailure.unauthorized);
      }
      return result;
    } on ApiException catch (e) {
      if (_current(generation) && e.failure == ApiFailure.unauthorized) {
        invalidSessionNotice = true;
        await _clear(++_generation);
      }
      rethrow;
    }
  }

  Future<ChildPage> fetchChildren({int page = 1}) =>
      _childRequest((credential) => api.fetchChildren(credential, page: page));
  Future<ChildDetails> fetchChild(int id, {int page = 1}) =>
      _childRequest((credential) => api.fetchChild(credential, id, page: page));
  Future<AttendanceSummary> fetchAttendanceSummary(
    int id, {
    DateTime? from,
    DateTime? to,
  }) => _childRequest(
    (credential) =>
        api.fetchAttendanceSummary(credential, id, from: from, to: to),
  );
  Future<T> _notificationRequest<T>(
    Future<T> Function(SessionCredential) action,
  ) async {
    if (phase != SessionPhase.authenticated || _credential == null) {
      throw const ApiException(ApiFailure.forbidden);
    }
    final generation = _generation;
    try {
      final result = await action(_credential!);
      if (!_current(generation)) {
        throw const ApiException(ApiFailure.unauthorized);
      }
      return result;
    } on ApiException catch (error) {
      if (_current(generation) && error.failure == ApiFailure.unauthorized) {
        invalidSessionNotice = true;
        await _clear(++_generation);
      }
      rethrow;
    }
  }

  Future<NotificationPage> fetchNotifications({
    int page = 1,
    int perPage = 25,
  }) => _notificationRequest(
    (credential) =>
        api.fetchNotifications(credential, page: page, perPage: perPage),
  );

  Future<int> fetchUnreadNotificationCount() =>
      _notificationRequest(api.fetchUnreadNotificationCount);

  Future<DateTime> markNotificationRead(String id) => _notificationRequest(
    (credential) => api.markNotificationRead(credential, id),
  );

  Future<void> markAllNotificationsRead() =>
      _notificationRequest(api.markAllNotificationsRead);
  bool get busy => {
    SessionPhase.restoring,
    SessionPhase.signingIn,
    SessionPhase.validating,
    SessionPhase.loggingOut,
  }.contains(phase);
  bool _current(int generation) => !_disposed && generation == _generation;
  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void openLogin() {
    showLogin = true;
    error = null;
    _emit();
  }

  void backToWelcome() {
    if (!busy) {
      showLogin = false;
      error = null;
      _emit();
    }
  }

  Future<void> restore() async {
    final generation = ++_generation;
    phase = SessionPhase.restoring;
    error = null;
    _emit();
    try {
      final saved = await store.read(api.sessionScope);
      if (!_current(generation)) return;
      _credential = saved;
      if (saved == null) {
        phase = SessionPhase.signedOut;
        _emit();
        return;
      }
      await _validate(generation);
    } catch (e) {
      if (_current(generation)) {
        error = e;
        phase = SessionPhase.failure;
        _emit();
      }
    }
  }

  Future<void> login(String email, String password) async {
    if (busy || hasSession || _needsClear) return;
    final generation = ++_generation;
    phase = SessionPhase.signingIn;
    error = null;
    invalidSessionNotice = false;
    _emit();
    try {
      final device = await store.deviceId();
      if (!_current(generation)) return;
      final session = await api.login(
        email: email,
        password: password,
        deviceId: device,
        deviceName: 'Aqsaa ${defaultTargetPlatform.name}',
      );
      if (!_current(generation)) return;
      _credential = session;
      _needsSave = true;
      await store.save(session);
      if (!_current(generation)) return;
      _needsSave = false;
      await _validate(generation);
    } catch (e) {
      if (!_current(generation)) return;
      error = e;
      phase = hasSession ? SessionPhase.failure : SessionPhase.signedOut;
      _emit();
    }
  }

  Future<void> _validate(int generation) async {
    phase = SessionPhase.validating;
    profile = null;
    capabilities = null;
    _emit();
    try {
      final user = await api.fetchProfile(_credential!);
      if (!_current(generation)) return;
      final access = await api.fetchCapabilities(_credential!);
      if (!_current(generation)) return;
      profile = user;
      capabilities = access;
      phase = SessionPhase.authenticated;
      error = null;
      _emit();
    } on ApiException catch (e) {
      if (!_current(generation)) return;
      if (e.failure == ApiFailure.unauthorized) {
        invalidSessionNotice = true;
        await _clear(generation);
      } else {
        error = e;
        phase = SessionPhase.failure;
        _emit();
      }
    }
  }

  Future<void> retry() async {
    if (busy) return;
    if (_needsClear) {
      await _clear(++_generation);
      return;
    }
    if (logoutUnconfirmed) {
      await logout();
      return;
    }
    if (_credential == null) {
      await restore();
      return;
    }
    final generation = ++_generation;
    error = null;
    try {
      if (_needsSave) {
        phase = SessionPhase.signingIn;
        _emit();
        await store.save(_credential!);
        if (!_current(generation)) return;
        _needsSave = false;
      }
      await _validate(generation);
    } catch (e) {
      if (_current(generation)) {
        error = e;
        phase = SessionPhase.failure;
        _emit();
      }
    }
  }

  Future<void> logout() async {
    if (_credential == null ||
        phase == SessionPhase.signingIn ||
        phase == SessionPhase.loggingOut ||
        phase == SessionPhase.restoring) {
      return;
    }
    final generation =
        ++_generation; // Invalidates any outstanding profile/capability response.
    phase = SessionPhase.loggingOut;
    profile = null;
    capabilities = null;
    error = null;
    _emit();
    try {
      await api.logout(_credential!);
      if (!_current(generation)) return;
      logoutUnconfirmed = false;
      await _clear(generation);
    } on ApiException catch (e) {
      if (!_current(generation)) return;
      if (e.failure == ApiFailure.unauthorized) {
        invalidSessionNotice =
            true; // Invalid token does NOT prove device cleanup.
        logoutUnconfirmed = false;
        await _clear(generation);
      } else {
        logoutUnconfirmed = true;
        error = e;
        phase = SessionPhase.failure;
        _emit();
      }
    } catch (e) {
      if (_current(generation)) {
        logoutUnconfirmed = true;
        error = e;
        phase = SessionPhase.failure;
        _emit();
      }
    }
  }

  Future<void> _clear(int generation) async {
    _credential = null;
    profile = null;
    capabilities = null;
    _needsSave = false;
    _needsClear = true;
    phase = SessionPhase.loggingOut;
    _emit();
    try {
      await store.clear(api.sessionScope);
      if (!_current(generation)) return;
      _needsClear = false;
      phase = SessionPhase.signedOut;
      showLogin = true;
      error = null;
    } catch (e) {
      if (!_current(generation)) return;
      error = e;
      phase = SessionPhase.failure;
    }
    _emit();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    profile = null;
    capabilities = null;
    _credential = null;
    super.dispose();
  }
}
