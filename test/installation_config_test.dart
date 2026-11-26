import 'package:aqsaa_mobile/config/installation_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('demo flavor has one fixed installation identity', () {
    final config = InstallationConfig.resolve(
      flavor: 'demo',
      releaseMode: true,
    );

    expect(config.flavor, 'demo');
    expect(config.androidApplicationId, 'app.aqsaa.demo');
    expect(config.displayName, 'Aqsaa Demo');
    expect(config.apiBaseUrl, 'https://demo.aqsaa.app/api/v1');
    expect(config.firebaseEnabled, isTrue);
    expect(config.firebaseProjectId, 'aqsaademo');
    expect(
      config.firebaseConfigPath,
      'android/app/src/demo/google-services.json',
    );
  });

  test('release requires a known native flavor and forbids API overrides', () {
    expect(
      () => InstallationConfig.resolve(flavor: null, releaseMode: true),
      throwsStateError,
    );
    expect(
      () => InstallationConfig.resolve(
        flavor: 'customer-typo',
        releaseMode: true,
      ),
      throwsStateError,
    );
    expect(
      () => InstallationConfig.resolve(
        flavor: 'demo',
        debugApiOverride: 'https://customer.example/api/v1',
        releaseMode: true,
      ),
      throwsStateError,
    );
  });

  test('debug override accepts only explicit local development servers', () {
    final local = InstallationConfig.resolve(
      flavor: 'demo',
      debugApiOverride: 'http://10.0.2.2:8000/api/v1',
      releaseMode: false,
    );
    expect(local.apiBaseUrl, 'http://10.0.2.2:8000/api/v1');
    expect(local.androidApplicationId, 'app.aqsaa.demo');

    for (final invalid in [
      'https://customer.example/api/v1',
      'http://10.0.2.2:8000/not-api',
      'http://user@localhost/api/v1',
    ]) {
      expect(
        () => InstallationConfig.resolve(
          flavor: 'demo',
          debugApiOverride: invalid,
          releaseMode: false,
        ),
        throwsStateError,
        reason: invalid,
      );
    }
  });

  test('tests default to demo only outside release mode', () {
    final config = InstallationConfig.resolve(flavor: null, releaseMode: false);
    expect(config.flavor, 'demo');
    expect(config.apiBaseUrl, 'https://demo.aqsaa.app/api/v1');
  });

  test('Firebase metadata must match package and project boundaries', () {
    final config = InstallationConfig.resolve(
      flavor: 'demo',
      releaseMode: false,
    );
    expect(
      () => config.validateFirebaseMetadata(
        androidPackageName: 'app.aqsaa.customer',
        nativeProjectId: 'aqsaademo',
        dartProjectId: 'aqsaademo',
      ),
      throwsStateError,
    );
    expect(
      () => config.validateFirebaseMetadata(
        androidPackageName: 'app.aqsaa.demo',
        nativeProjectId: 'demo-project',
        dartProjectId: 'other-project',
      ),
      throwsStateError,
    );
    expect(
      () => config.validateFirebaseMetadata(
        androidPackageName: 'app.aqsaa.demo',
        nativeProjectId: 'aqsaademo',
        dartProjectId: 'aqsaademo',
      ),
      returnsNormally,
    );
  });
}
