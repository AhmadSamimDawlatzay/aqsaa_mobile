import 'auth_models.dart';

class LinkedChild {
  const LinkedChild(
    this.id,
    this.number,
    this.name, {
    this.placement = const {},
  });
  final int id;
  final String number;
  final String name;
  final Map<String, String> placement;
  factory LinkedChild.fromJson(Object? value) {
    final json = authObject(value);
    final last = json['last_name'];
    if (last != null && last is! String) throw const FormatException();
    final rawPlacement = json['placement'];
    final placement = <String, String>{};
    if (rawPlacement is Map) {
      for (final key in ['class', 'section', 'branch']) {
        final entry = rawPlacement[key];
        if (entry is Map && entry['name'] is String) {
          placement[key] = entry['name'] as String;
        } else if (entry is String) {
          placement[key] = entry;
        }
      }
    } else if (rawPlacement != null) {
      throw const FormatException();
    }
    return LinkedChild(
      authInt(json['id']),
      authString(json['student_number']),
      '${authString(json['first_name'])} ${last ?? ''}'.trim(),
      placement: Map.unmodifiable(placement),
    );
  }
}

class ChildPage {
  const ChildPage(this.children, this.page, this.lastPage);
  final List<LinkedChild> children;
  final int page;
  final int lastPage;
  factory ChildPage.fromJson(Object? value) {
    final json = authObject(value);
    final data = json['data'];
    final meta = authObject(json['meta']);
    if (data is! List) throw const FormatException();
    final page = authInt(meta['current_page']);
    final last = authInt(meta['last_page']);
    if (page < 1 || last < 1) throw const FormatException();
    return ChildPage(
      List.unmodifiable(data.map(LinkedChild.fromJson)),
      page,
      last,
    );
  }
}

class AttendanceSummary {
  const AttendanceSummary({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
    required this.excused,
    required this.unrecordedDaysAreAbsent,
    this.attendanceRate,
  });
  final int total, present, absent, late, excused;
  final bool unrecordedDaysAreAbsent;
  final num? attendanceRate;
  factory AttendanceSummary.fromJson(Object? value) {
    final response = authObject(value);
    final json = response['data'] == null
        ? response
        : authObject(response['data']);
    return AttendanceSummary(
      total: authInt(json['total'] ?? json['recorded_days']),
      present: authInt(json['present']),
      absent: authInt(json['absent']),
      late: authInt(json['late']),
      excused: authInt(json['excused']),
      unrecordedDaysAreAbsent: json['unrecorded_days_are_absent'] == false
          ? false
          : throw const FormatException('Invalid absence rule'),
      attendanceRate: json['attendance_rate'] is num
          ? json['attendance_rate'] as num
          : null,
    );
  }
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.status,
    required this.date,
  });
  final int id;
  final String status;
  final DateTime date;
  factory AttendanceRecord.fromJson(Object? value) {
    final json = authObject(value);
    return AttendanceRecord(
      id: authInt(json['id']),
      status: authString(json['status']),
      date: DateTime.parse(authString(json['attendance_date'])),
    );
  }
}

class ChildDetails {
  const ChildDetails(
    this.child,
    this.placement,
    this.summary,
    this.attendance,
    this.page,
    this.lastPage,
  );
  final LinkedChild child;
  final Map<String, String> placement;
  final AttendanceSummary summary;
  final List<AttendanceRecord> attendance;
  final int page;
  final int lastPage;
  factory ChildDetails.fromJson(Object? value) {
    final json = authObject(authObject(value)['data']);
    final placement = json['placement'] == null
        ? <String, dynamic>{}
        : authObject(json['placement']);
    final names = <String, String>{};
    for (final key in [
      'class',
      'section',
      'program',
      'level',
      'academic_year',
      'branch',
    ]) {
      if (placement[key] != null) {
        names[key] = authString(authObject(placement[key])['name']);
      }
    }
    for (final key in ['status', 'enrolled_at']) {
      if (placement[key] != null) {
        names[key] = authString(placement[key]);
      }
    }
    final records = authObject(json['records']);
    // The child-detail endpoint serializes Laravel's paginator directly, so
    // its page values are top-level (unlike /me/students, which has `meta`).
    final meta = records['meta'] is Map ? authObject(records['meta']) : records;
    final rows = records['data'];
    if (rows is! List) throw const FormatException('Invalid attendance page');
    return ChildDetails(
      LinkedChild.fromJson(json['student']),
      Map.unmodifiable(names),
      AttendanceSummary.fromJson(json['summary']),
      List.unmodifiable(rows.map(AttendanceRecord.fromJson)),
      authInt(meta['current_page']),
      authInt(meta['last_page']),
    );
  }
}
