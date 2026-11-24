import 'auth_models.dart';

enum NotificationEventType {
  attendanceAbsent,
  attendanceCorrected,
  releasedResult,
  promotionCommitted,
  transferApproved,
  unknown,
}

enum NotificationDestination { attendance, childDetails, unavailable }

class NotificationStudent {
  const NotificationStudent({
    required this.id,
    required this.number,
    required this.name,
  });

  final int id;
  final String number;
  final String name;

  factory NotificationStudent.fromJson(Object? value) {
    final json = authObject(value);
    return NotificationStudent(
      id: authInt(json['id']),
      number: authString(json['student_number']),
      name: authString(json['name']),
    );
  }
}

class NotificationDeepLink {
  const NotificationDeepLink({
    required this.version,
    required this.route,
    required this.studentId,
    required this.tab,
  });

  final String version;
  final String route;
  final int studentId;
  final String tab;

  factory NotificationDeepLink.fromJson(Object? value) {
    final json = authObject(value);
    return NotificationDeepLink(
      version: authString(json['version']),
      route: authString(json['route']),
      studentId: authInt(json['student_id']),
      tab: authString(json['tab']),
    );
  }
}

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.eventType,
    required this.rawEventType,
    required this.translationKey,
    required this.translationParams,
    required this.title,
    required this.body,
    required this.createdAt,
    this.student,
    this.deepLink,
    this.readAt,
  });

  final String id;
  final NotificationEventType eventType;
  final String? rawEventType;
  final NotificationStudent? student;
  final String? translationKey;
  final Map<String, String> translationParams;
  final NotificationDeepLink? deepLink;
  final String? title;
  final String? body;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  NotificationDestination get destination {
    final link = deepLink;
    final child = student;
    if (link == null ||
        child == null ||
        link.version != 'v1' ||
        link.route != 'guardian.student' ||
        link.studentId != child.id) {
      return NotificationDestination.unavailable;
    }
    return switch ((eventType, link.tab)) {
      (
        NotificationEventType.attendanceAbsent ||
            NotificationEventType.attendanceCorrected,
        'student-attendances',
      ) =>
        NotificationDestination.attendance,
      (
        NotificationEventType.promotionCommitted ||
            NotificationEventType.transferApproved,
        'student-movements',
      ) =>
        NotificationDestination.childDetails,
      _ => NotificationDestination.unavailable,
    };
  }

  InboxNotification markRead(DateTime value) => InboxNotification(
    id: id,
    eventType: eventType,
    rawEventType: rawEventType,
    student: student,
    translationKey: translationKey,
    translationParams: translationParams,
    deepLink: deepLink,
    title: title,
    body: body,
    readAt: value,
    createdAt: createdAt,
  );

  factory InboxNotification.fromJson(Object? value) {
    final json = authObject(value);
    final rawEventType = json['event_type'] == null
        ? null
        : authString(json['event_type']);
    final rawParams = json['translation_params'];
    final params = <String, String>{};
    if (rawParams is Map) {
      for (final entry in rawParams.entries) {
        if (entry.key is String && entry.value is String) {
          params[entry.key as String] = entry.value as String;
        }
      }
    } else if (rawParams != null) {
      throw const FormatException('Invalid translation parameters');
    }
    return InboxNotification(
      id: authString(json['id']),
      eventType: switch (rawEventType) {
        'attendance_absent' => NotificationEventType.attendanceAbsent,
        'attendance_corrected' => NotificationEventType.attendanceCorrected,
        'released_result' => NotificationEventType.releasedResult,
        'promotion_committed' => NotificationEventType.promotionCommitted,
        'transfer_approved' => NotificationEventType.transferApproved,
        _ => NotificationEventType.unknown,
      },
      rawEventType: rawEventType,
      student: json['student'] == null
          ? null
          : NotificationStudent.fromJson(json['student']),
      translationKey: json['translation_key'] == null
          ? null
          : authString(json['translation_key']),
      translationParams: Map.unmodifiable(params),
      deepLink: json['deep_link'] == null
          ? null
          : NotificationDeepLink.fromJson(json['deep_link']),
      title: json['title'] == null ? null : authString(json['title']),
      body: json['body'] == null ? null : authString(json['body']),
      readAt: json['read_at'] == null
          ? null
          : DateTime.parse(authString(json['read_at'])),
      createdAt: DateTime.parse(authString(json['created_at'])),
    );
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.lastPage,
  });

  final List<InboxNotification> items;
  final int page;
  final int lastPage;

  factory NotificationPage.fromJson(Object? value) {
    final json = authObject(value);
    final data = json['data'];
    final meta = authObject(json['meta']);
    if (data is! List) throw const FormatException('Invalid notifications');
    final page = authInt(meta['current_page']);
    final lastPage = authInt(meta['last_page']);
    if (page < 1 || lastPage < 1) {
      throw const FormatException('Invalid notification pagination');
    }
    return NotificationPage(
      items: List.unmodifiable(data.map(InboxNotification.fromJson)),
      page: page,
      lastPage: lastPage,
    );
  }
}
