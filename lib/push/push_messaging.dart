import 'dart:async';

enum PushPermission { authorized, denied, notDetermined }

class PushMessage {
  const PushMessage({required this.data});
  final Map<String, String> data;

  static const supportedVersion = 'aqsaa.push.v1';

  String? get notificationId {
    if (data['version'] != supportedVersion) return null;
    final value = data['notification_id']?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool belongsToInstallation(String installation) {
    final value = data['installation']?.trim();
    return value == null || value.isEmpty || value == installation;
  }
}

abstract interface class PushMessaging {
  Future<PushPermission> permissionStatus();
  Future<PushPermission> requestPermission();
  Future<String?> token();
  Stream<String> get tokenRefreshes;
  Stream<PushMessage> get foregroundMessages;
  Stream<PushMessage> get openedMessages;
  Future<PushMessage?> initialMessage();
}
