import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show appFlavor;

class InstallationConfig {
  const InstallationConfig._({
    required this.flavor,
    required this.androidApplicationId,
    required this.displayName,
    required this.apiBaseUrl,
    required this.firebaseEnabled,
    required this.firebaseConfigPath,
    required this.firebaseProjectId,
    this.bundledLogoAsset,
  });

  final String flavor;
  final String androidApplicationId;
  final String displayName;
  final String apiBaseUrl;
  final String? bundledLogoAsset;
  final bool firebaseEnabled;
  final String firebaseConfigPath;
  final String firebaseProjectId;

  static InstallationConfig get current => resolve(
    flavor: appFlavor,
    debugApiOverride: const String.fromEnvironment('DEBUG_API_BASE_URL'),
    releaseMode: kReleaseMode,
  );

  static InstallationConfig resolve({
    required String? flavor,
    String debugApiOverride = '',
    required bool releaseMode,
  }) {
    final selected = switch (flavor) {
      'demo' => _demo,
      null || '' when !releaseMode => _demo,
      null || '' => throw StateError(
        'A release build requires an explicit installation flavor.',
      ),
      _ => throw StateError('Unknown installation flavor: $flavor'),
    };

    final override = debugApiOverride.trim();
    if (override.isEmpty) return selected;
    if (releaseMode) {
      throw StateError('DEBUG_API_BASE_URL is forbidden in release builds.');
    }
    final uri = Uri.tryParse(override.replaceFirst(RegExp(r'/+$'), ''));
    const localHosts = {'localhost', '127.0.0.1', '10.0.2.2'};
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        !localHosts.contains(uri.host) ||
        !uri.path.endsWith('/api/v1') ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      throw StateError(
        'DEBUG_API_BASE_URL must be a local /api/v1 development endpoint.',
      );
    }
    return selected._withApiBase(uri.toString());
  }

  InstallationConfig _withApiBase(String value) => InstallationConfig._(
    flavor: flavor,
    androidApplicationId: androidApplicationId,
    displayName: displayName,
    apiBaseUrl: value,
    firebaseEnabled: firebaseEnabled,
    firebaseConfigPath: firebaseConfigPath,
    firebaseProjectId: firebaseProjectId,
    bundledLogoAsset: bundledLogoAsset,
  );

  void validateFirebaseMetadata({
    required String androidPackageName,
    required String nativeProjectId,
    required String dartProjectId,
  }) {
    if (androidPackageName != androidApplicationId) {
      throw StateError(
        'Firebase Android package does not match the installation flavor.',
      );
    }
    if (nativeProjectId.trim().isEmpty ||
        dartProjectId.trim().isEmpty ||
        nativeProjectId != firebaseProjectId ||
        dartProjectId != firebaseProjectId) {
      throw StateError(
        'Native and Dart Firebase configurations must use one project.',
      );
    }
  }

  static const _demo = InstallationConfig._(
    flavor: 'demo',
    androidApplicationId: 'app.aqsaa.demo',
    displayName: 'Aqsaa Demo',
    apiBaseUrl: 'https://demo.aqsaa.app/api/v1',
    bundledLogoAsset: null,
    firebaseEnabled: true,
    firebaseProjectId: 'aqsaademo',
    firebaseConfigPath: 'android/app/src/demo/google-services.json',
  );
}
