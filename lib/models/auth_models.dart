// Models follow AuthController and BootstrapController, not Laravel Sanctum.
class SessionCredential {
  const SessionCredential({
    required this.apiBase,
    required this.token,
    required this.expiresAt,
  });
  final String apiBase;
  final String token;
  final DateTime expiresAt;

  factory SessionCredential.fromLogin(Object? value, String apiBase) {
    final json = authObject(value);
    if (json['token_type'] != 'Bearer') {
      throw const FormatException('Invalid token type');
    }
    return SessionCredential(
      apiBase: apiBase,
      token: authString(json['token']),
      expiresAt: DateTime.parse(authString(json['expires_at'])),
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.locale,
    required this.roles,
    required this.branches,
    required this.staffId,
    required this.teacherId,
  });
  final int id;
  final String name;
  final String email;
  final String? locale;
  final List<String> roles;
  final List<UserBranch> branches;
  final int? staffId;
  final int? teacherId;
  factory UserProfile.fromJson(Object? value) {
    final json = authObject(authObject(value)['data']);
    final branches = json['branches'];
    if (branches is! List) throw const FormatException('Invalid branches');
    return UserProfile(
      id: authInt(json['id']),
      name: authString(json['name']),
      email: authString(json['email']),
      locale: json['locale'] == null ? null : authString(json['locale']),
      roles: authStrings(json['roles']),
      branches: List.unmodifiable(branches.map(UserBranch.fromJson)),
      staffId: json['staff_id'] == null ? null : authInt(json['staff_id']),
      teacherId: json['teacher_id'] == null
          ? null
          : authInt(json['teacher_id']),
    );
  }
}

class UserBranch {
  const UserBranch(this.id, this.name, this.code);
  final int id;
  final String name;
  final String? code;
  factory UserBranch.fromJson(Object? value) {
    final json = authObject(value);
    return UserBranch(
      authInt(json['id']),
      authString(json['name']),
      json['code'] == null ? null : authString(json['code']),
    );
  }
}

enum ResourceScope { general, linkedChildren, unknown }

class Capabilities {
  const Capabilities({
    required this.readOnly,
    required this.resources,
    required this.resourceScopes,
    required this.ownRecords,
    required this.linkedChildren,
    required this.assignedTeaching,
    required this.technicalActions,
  });
  final bool readOnly;
  final List<String> resources;
  final Map<String, ResourceScope> resourceScopes;
  final List<String> ownRecords;
  final List<String> linkedChildren;
  final List<String> assignedTeaching;
  final List<String> technicalActions;
  bool get canViewChildren => linkedChildren.contains('students');
  List<String> get generalResources => resources
      .where((r) => resourceScopes[r] == ResourceScope.general)
      .toList(growable: false);
  bool get hasSupportedAccess =>
      generalResources.isNotEmpty ||
      resources.any((r) => resourceScopes[r] == ResourceScope.linkedChildren) ||
      ownRecords.isNotEmpty ||
      linkedChildren.isNotEmpty ||
      assignedTeaching.isNotEmpty;

  factory Capabilities.fromJson(Object? value) {
    final json = authObject(authObject(value)['data']);
    if (json['read_only'] is! bool) {
      throw const FormatException('Invalid read_only');
    }
    final rawScopes = json['resource_scopes'];
    // Laravel serializes an empty keyed Collection as [], otherwise as an object.
    final scopes = rawScopes is List && rawScopes.isEmpty
        ? <String, dynamic>{}
        : authObject(rawScopes);
    return Capabilities(
      readOnly: json['read_only'] as bool,
      resources: authStrings(json['resources']),
      resourceScopes: Map.unmodifiable(
        scopes.map(
          (key, value) => MapEntry(key, switch (authString(value)) {
            'general' => ResourceScope.general,
            'linked_children' => ResourceScope.linkedChildren,
            _ => ResourceScope.unknown,
          }),
        ),
      ),
      ownRecords: authStrings(json['own_records']),
      linkedChildren: authStrings(json['linked_children']),
      assignedTeaching: authStrings(json['assigned_teaching']),
      technicalActions: authStrings(json['technical_actions']),
    );
  }
}

Map<String, dynamic> authObject(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected object');
  }
  return value;
}

String authString(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FormatException('Expected string');
  }
  return value;
}

int authInt(Object? value) {
  if (value is! int) throw const FormatException('Expected integer');
  return value;
}

List<String> authStrings(Object? value) {
  if (value is! List || value.any((v) => v is! String)) {
    throw const FormatException('Expected string list');
  }
  return List<String>.unmodifiable(value);
}
