import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'push_messaging.dart';

class FirebasePushMessaging implements PushMessaging {
  FirebasePushMessaging(this._messaging);
  final FirebaseMessaging _messaging;

  @override
  Future<PushPermission> permissionStatus() async => _permission(
    (await _messaging.getNotificationSettings()).authorizationStatus,
  );

  @override
  Future<PushPermission> requestPermission() async => _permission(
    (await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    )).authorizationStatus,
  );

  PushPermission _permission(AuthorizationStatus value) => switch (value) {
    AuthorizationStatus.authorized ||
    AuthorizationStatus.provisional => PushPermission.authorized,
    AuthorizationStatus.denied ||
    AuthorizationStatus.deniedPermanently => PushPermission.denied,
    AuthorizationStatus.notDetermined => PushPermission.notDetermined,
  };

  @override
  Future<String?> token() => _messaging.getToken();

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<PushMessage> get foregroundMessages =>
      FirebaseMessaging.onMessage.map(_message);

  @override
  Stream<PushMessage> get openedMessages =>
      FirebaseMessaging.onMessageOpenedApp.map(_message);

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _messaging.getInitialMessage();
    return message == null ? null : _message(message);
  }

  PushMessage _message(RemoteMessage message) => PushMessage(
    data: Map.unmodifiable(
      message.data.map((key, value) => MapEntry(key, value.toString())),
    ),
  );
}
