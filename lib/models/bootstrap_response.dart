class BootstrapResponse {
  const BootstrapResponse({
    required this.apiVersion,
    required this.institution,
    required this.supportedLocales,
  });
  final String apiVersion;
  final Institution? institution;
  final List<String> supportedLocales;

  factory BootstrapResponse.fromJson(Object? value) {
    final json = _object(value);
    if (json['api_version'] != 'v1' ||
        !json.containsKey('institution') ||
        json['supported_locales'] is! List ||
        (json['supported_locales'] as List).any((v) => v is! String)) {
      throw const FormatException('Invalid bootstrap envelope');
    }
    return BootstrapResponse(
      apiVersion: 'v1',
      institution: json['institution'] == null
          ? null
          : Institution.fromJson(_object(json['institution'])),
      supportedLocales: List<String>.unmodifiable(
        json['supported_locales'] as List,
      ),
    );
  }
}

class Institution {
  const Institution({
    required this.name,
    this.shortName,
    this.logo,
    required this.timezone,
    required this.defaultLocale,
    required this.defaultCalendar,
    this.currency,
  });
  final String name;
  final String? shortName;
  final String? logo;
  final String timezone;
  final String defaultLocale;
  final String defaultCalendar;
  final InstitutionCurrency? currency;

  factory Institution.fromJson(Map<String, dynamic> json) => Institution(
    name: _requiredString(json, 'name'),
    shortName: _optionalString(json, 'short_name'),
    logo: _optionalString(json, 'logo'),
    timezone: _requiredString(json, 'timezone'),
    defaultLocale: _requiredString(json, 'default_locale'),
    defaultCalendar: _requiredString(json, 'default_calendar'),
    currency: json['currency'] == null
        ? null
        : InstitutionCurrency.fromJson(_object(json['currency'])),
  );
}

class InstitutionCurrency {
  const InstitutionCurrency({
    required this.id,
    required this.code,
    required this.name,
  });
  final int id;
  final String code;
  final String name;
  factory InstitutionCurrency.fromJson(Map<String, dynamic> json) {
    if (json['id'] is! int) throw const FormatException('Invalid currency id');
    return InstitutionCurrency(
      id: json['id'] as int,
      code: _requiredString(json, 'code'),
      name: _requiredString(json, 'name'),
    );
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Expected JSON object');
  }
  return value;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $key');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value != null && value is! String) throw FormatException('Invalid $key');
  return value as String?;
}
