import 'dart:async';
import 'package:flutter/foundation.dart';
import '../api/api_client.dart';
import '../auth/session_controller.dart';
import '../config/installation_config.dart';
import 'push_messaging.dart';

enum PushState { idle, registering, registered, denied, conflict, failed }

class PushController extends ChangeNotifier {
  PushController({
    required this.messaging,
    required this.session,
    required this.onForegroundMessage,
    required this.onOpenInbox,
    this.retryDelays = const [
      Duration(seconds: 1),
      Duration(seconds: 2),
      Duration(seconds: 4),
    ],
  });

  final PushMessaging messaging;
  final SessionController session;
  final VoidCallback onForegroundMessage;
  final VoidCallback onOpenInbox;
  final List<Duration> retryDelays;
  PushState state = PushState.idle;
  Object? error;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<PushMessage>? _foregroundSubscription;
  StreamSubscription<PushMessage>? _openSubscription;
  Object? _identity;
  String? _registeredToken;
  bool _disposed = false;
  bool _started = false;

  Future<PushPermission> permissionStatus() => messaging.permissionStatus();

  Future<void> start({required bool requestPermission}) async {
    if (_started) return;
    _started = true;
    _identity = session.sessionIdentity;
    if (_identity == null) return;

    _tokenSubscription = messaging.tokenRefreshes.listen(_register);
    _foregroundSubscription = messaging.foregroundMessages.listen((message) {
      if (!_isCurrent ||
          !message.belongsToInstallation(InstallationConfig.current.flavor)) {
        return;
      }
      onForegroundMessage();
    });
    _openSubscription = messaging.openedMessages.listen(_handleOpen);

    var permission = await messaging.permissionStatus();
    if (!_isCurrent) return;
    if (permission == PushPermission.notDetermined && requestPermission) {
      permission = await messaging.requestPermission();
    }
    if (!_isCurrent) return;
    if (permission != PushPermission.authorized) {
      state = PushState.denied;
      _emit();
      return;
    }
    await _register(await messaging.token());
    final initial = await messaging.initialMessage();
    if (initial != null) _handleOpen(initial);
  }

  Future<void> retry() async {
    if (!_isCurrent) return;
    await _register(await messaging.token(), force: true);
  }

  Future<void> resume() async {
    if (!_isCurrent) return;
    final permission = await messaging.permissionStatus();
    if (!_isCurrent) return;
    if (permission == PushPermission.authorized) {
      await _register(await messaging.token());
    } else {
      state = PushState.denied;
      _emit();
    }
  }

  Future<String?> debugTokenForCopy() async {
    if (!kDebugMode || !_isCurrent) return null;
    return messaging.token();
  }

  Future<void> _register(String? token, {bool force = false}) async {
    if (!_isCurrent || token == null || token.isEmpty) return;
    if (!force && token == _registeredToken) return;
    state = PushState.registering;
    error = null;
    _emit();
    for (var attempt = 0; attempt <= retryDelays.length; attempt++) {
      try {
        await session.registerPushToken(token);
        if (!_isCurrent) return;
        _registeredToken = token;
        state = PushState.registered;
        _emit();
        return;
      } on ApiException catch (exception) {
        if (!_isCurrent) return;
        if (exception.failure == ApiFailure.conflict) {
          state = PushState.conflict;
          error = exception;
          _emit();
          return;
        }
        if (!_recoverable(exception) || attempt == retryDelays.length) {
          state = PushState.failed;
          error = exception;
          _emit();
          return;
        }
      } catch (exception) {
        if (!_isCurrent) return;
        if (attempt == retryDelays.length) {
          state = PushState.failed;
          error = exception;
          _emit();
          return;
        }
      }
      await Future<void>.delayed(retryDelays[attempt]);
      if (!_isCurrent) return;
    }
  }

  bool _recoverable(ApiException error) => {
    ApiFailure.network,
    ApiFailure.timeout,
    ApiFailure.rateLimited,
    ApiFailure.http,
  }.contains(error.failure);

  void _handleOpen(PushMessage message) {
    if (!_isCurrent ||
        !message.belongsToInstallation(InstallationConfig.current.flavor)) {
      return;
    }
    // The API has no safe notification-by-ID GET. The inbox refresh remains the
    // authoritative resolution path; push data never grants record access.
    onOpenInbox();
  }

  bool get _isCurrent =>
      !_disposed && _identity != null && _identity == session.sessionIdentity;

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _identity = null;
    _tokenSubscription?.cancel();
    _foregroundSubscription?.cancel();
    _openSubscription?.cancel();
    super.dispose();
  }
}
