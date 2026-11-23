import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/l10n/app_language.dart';
import 'package:aqsaa_mobile/l10n/app_strings.dart';
import 'package:aqsaa_mobile/l10n/locale_controller.dart';
import 'package:aqsaa_mobile/l10n/pashto_cupertino_localizations.dart';
import 'package:aqsaa_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'api_client_test.dart' show jsonResponse;
import 'support/auth_fixtures.dart';

ApiClient _client() => ApiClient(
  baseUrl: testBase,
  client: MockClient((request) async => jsonResponse()),
);

void main() {
  testWidgets('first launch defaults to Pashto and RTL', (tester) async {
    final client = _client();
    addTearDown(client.close);

    await tester.pumpWidget(
      AqsaaApp(client: client, sessionStore: SessionStore(MemorySecureStore())),
    );
    await tester.pumpAndSettle();

    final context = tester.element(find.text(AppStrings.connected));
    expect(Localizations.localeOf(context).languageCode, 'ps');
    expect(Directionality.of(context), TextDirection.rtl);
    expect(find.text('اقصی ته ښه راغلاست'), findsOneWidget);
  });

  test('language mapping and persistence use backend fa for Dari', () async {
    final memory = MemorySecureStore();
    final controller = LocaleController(memory);

    expect(controller.language, AppLanguage.pashto);
    expect(AppLanguage.fromCode('dr'), AppLanguage.dari);
    await controller.select(AppLanguage.dari);
    expect(memory.values[LocaleController.storageKey], 'fa');

    final restored = LocaleController(memory);
    await restored.restore();
    expect(restored.language, AppLanguage.dari);
    controller.dispose();
    restored.dispose();
  });

  test('every supported language has complete non-empty interface copy', () {
    for (final language in AppLanguage.values) {
      AppStrings.setLanguage(language);
      expect(AppStrings.translationCoverage, isNotEmpty);
      expect(
        AppStrings.translationCoverage.every(
          (value) => value.trim().isNotEmpty,
        ),
        isTrue,
        reason: language.name,
      );
    }
  });

  for (final language in AppLanguage.values) {
    testWidgets('${language.name} renders with the expected direction', (
      tester,
    ) async {
      final memory = MemorySecureStore()
        ..values[LocaleController.storageKey] = language.backendCode;
      final client = _client();
      addTearDown(client.close);

      await tester.pumpWidget(
        AqsaaApp(client: client, sessionStore: SessionStore(memory)),
      );
      await tester.pumpAndSettle();

      final context = tester.element(
        find.byKey(const ValueKey('language-selector')),
      );
      expect(Localizations.localeOf(context), language.locale);
      expect(Directionality.of(context), language.direction);
      expect(find.text(language.nativeName), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'language selector updates and persists without rebuilding session',
    (tester) async {
      final memory = MemorySecureStore();
      final controller = LocaleController(memory);
      final client = _client();
      addTearDown(client.close);

      await tester.pumpWidget(
        AqsaaApp(
          client: client,
          sessionStore: SessionStore(memory),
          localeController: controller,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<AppLanguage>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('English').last);
      await tester.pumpAndSettle();

      expect(controller.language, AppLanguage.english);
      expect(memory.values[LocaleController.storageKey], 'en');
      expect(find.text('Welcome to Aqsaa'), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text('Welcome to Aqsaa'))),
        TextDirection.ltr,
      );
      controller.dispose();
    },
  );

  testWidgets('Material date labels are localized in every language', (
    tester,
  ) async {
    for (final language in AppLanguage.values) {
      final memory = MemorySecureStore()
        ..values[LocaleController.storageKey] = language.backendCode;
      final client = _client();
      await tester.pumpWidget(
        AqsaaApp(client: client, sessionStore: SessionStore(memory)),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold).first);
      final material = MaterialLocalizations.of(context);
      expect(material.formatMediumDate(DateTime(2026, 11, 20)), isNotEmpty);
      expect(material.cancelButtonLabel, isNotEmpty);
      expect(material.okButtonLabel, isNotEmpty);
      client.close();
    }
  });

  testWidgets('the built-in date range dialog opens in every language', (
    tester,
  ) async {
    for (final language in AppLanguage.values) {
      await tester.pumpWidget(
        MaterialApp(
          locale: language.locale,
          supportedLocales: AppLanguage.values.map((value) => value.locale),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            PashtoCupertinoLocalizationsDelegate(),
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                key: const ValueKey('open-date-range'),
                onPressed: () => showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open-date-range')));
      await tester.pumpAndSettle();

      final dialogContext = tester.element(find.byType(DateRangePickerDialog));
      final material = MaterialLocalizations.of(dialogContext);
      expect(Localizations.localeOf(dialogContext), language.locale);
      expect(Directionality.of(dialogContext), language.direction);
      expect(material.cancelButtonLabel, isNotEmpty);
      expect(material.saveButtonLabel, isNotEmpty);
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);

      Navigator.of(dialogContext).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('switching language preserves the authenticated child screen', (
    tester,
  ) async {
    final memory = MemorySecureStore();
    final store = SessionStore(memory);
    await store.save(credential());
    final controller = LocaleController(memory);
    var detailRequests = 0;
    final client = ApiClient(
      baseUrl: testBase,
      client: MockClient((request) async {
        if (request.url.path.endsWith('bootstrap')) return jsonResponse();
        if (request.url.path.endsWith('capabilities')) {
          final data = capabilitiesJson();
          (data['data'] as Map)['linked_children'] = ['students'];
          return response(data);
        }
        if (request.url.path.endsWith('me/students')) {
          return response({
            'data': [
              {
                'id': 9,
                'student_number': 'TEST-9',
                'first_name': 'Long Student',
                'last_name': 'Name',
                'status': 'active',
              },
            ],
            'meta': {'current_page': 1, 'last_page': 1},
          });
        }
        if (request.url.path.endsWith('me/students/9')) {
          detailRequests++;
          return response({
            'data': {
              'student': {
                'id': 9,
                'student_number': 'TEST-9',
                'first_name': 'Long Student',
                'last_name': 'Name',
                'status': 'active',
              },
              'placement': null,
              'summary': {
                'total': 0,
                'present': 0,
                'absent': 0,
                'late': 0,
                'excused': 0,
                'unrecorded_days_are_absent': false,
              },
              'records': {'data': [], 'current_page': 1, 'last_page': 1},
            },
          });
        }
        return authResponse(request);
      }),
    );
    addTearDown(client.close);

    await tester.pumpWidget(
      AqsaaApp(
        client: client,
        sessionStore: store,
        localeController: controller,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.studentNumber('TEST-9')));
    await tester.pumpAndSettle();
    expect(find.text('Long Student Name'), findsOneWidget);

    await controller.select(AppLanguage.english);
    await tester.pumpAndSettle();

    expect(find.text('Long Student Name'), findsOneWidget);
    expect(find.text('Child details'), findsOneWidget);
    expect(detailRequests, 1);
    controller.dispose();
  });
}
