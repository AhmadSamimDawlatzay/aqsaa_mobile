import 'dart:async';
import 'dart:convert';
import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/models/bootstrap_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, Object?> bootstrapJson({
  Object? institution = const <String, Object?>{
    'name': 'Test Academy',
    'short_name': null,
    'logo': null,
    'timezone': 'Asia/Kabul',
    'default_locale': 'ps',
    'default_calendar': 'gregorian',
    'currency': {'id': 1, 'code': 'AFN', 'name': 'Afghani'},
  },
}) => {
  'api_version': 'v1',
  'institution': institution,
  'supported_locales': ['ps', 'fa', 'ar', 'en'],
};

http.Response jsonResponse([Map<String, Object?>? value]) => http.Response(
  jsonEncode(value ?? bootstrapJson()),
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('parses the actual unwrapped contract and nullable institution', () {
    final response = BootstrapResponse.fromJson(bootstrapJson());
    expect(response.institution!.name, 'Test Academy');
    expect(response.institution!.currency!.code, 'AFN');
    expect(response.institution!.defaultLocale, 'ps');
    expect(response.institution!.logo, isNull);
    expect(response.supportedLocales, ['ps', 'fa', 'ar', 'en']);
    expect(
      BootstrapResponse.fromJson(bootstrapJson(institution: null)).institution,
      isNull,
    );
  });
  test('rejects missing, wrapped, mistyped and wrong-version contracts', () {
    for (final value in [
      null,
      [],
      {'data': bootstrapJson()},
      {...bootstrapJson(), 'api_version': 'v2'},
      {
        ...bootstrapJson(),
        'supported_locales': [1],
      },
      bootstrapJson(institution: {'name': 42}),
    ]) {
      expect(() => BootstrapResponse.fromJson(value), throwsFormatException);
    }
  });
  test(
    'uses one API prefix, JSON accept header, and public storage logo',
    () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api/v1/',
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://example.test/api/v1/bootstrap',
          );
          expect(request.headers['Accept'], 'application/json');
          return jsonResponse();
        }),
      );
      addTearDown(client.close);
      expect((await client.fetchBootstrap()).apiVersion, 'v1');
      expect(
        client.logoUri('institutions/logos/a.png').toString(),
        'https://example.test/storage/institutions/logos/a.png',
      );
      expect(client.logoUri(null), isNull);
      expect(client.logoUri('../private/a.png'), isNull);
    },
  );
  test('reports HTTP, HTML, invalid JSON and network failures', () async {
    for (final entry in [
      (http.Response('Not found', 404), ApiFailure.http),
      (
        http.Response(
          '<html></html>',
          200,
          headers: {'content-type': 'text/html'},
        ),
        ApiFailure.contentType,
      ),
      (
        http.Response('{', 200, headers: {'content-type': 'application/json'}),
        ApiFailure.contract,
      ),
      (jsonResponse({'data': bootstrapJson()}), ApiFailure.contract),
    ]) {
      final client = ApiClient(client: MockClient((_) async => entry.$1));
      addTearDown(client.close);
      await expectLater(
        client.fetchBootstrap(),
        throwsA(
          isA<ApiException>().having((e) => e.failure, 'failure', entry.$2),
        ),
      );
    }
    final client = ApiClient(
      client: MockClient((_) => throw http.ClientException('offline')),
    );
    addTearDown(client.close);
    await expectLater(
      client.fetchBootstrap(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.failure,
          'failure',
          ApiFailure.network,
        ),
      ),
    );
  });
  test('times out and rejects invalid base configuration', () async {
    final client = ApiClient(
      timeout: const Duration(milliseconds: 1),
      client: MockClient((_) => Completer<http.Response>().future),
    );
    addTearDown(client.close);
    await expectLater(
      client.fetchBootstrap(),
      throwsA(
        isA<ApiException>().having(
          (e) => e.failure,
          'failure',
          ApiFailure.timeout,
        ),
      ),
    );
    for (final url in [
      'https://example.test',
      'http://example.test/api/v1',
      'https://example.test/api/v1/api/v1',
    ]) {
      final invalid = ApiClient(baseUrl: url);
      addTearDown(invalid.close);
      await expectLater(
        invalid.fetchBootstrap(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.failure,
            'failure',
            ApiFailure.configuration,
          ),
        ),
      );
    }
  });
}
