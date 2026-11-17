import 'dart:async';
import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/l10n/app_strings.dart';
import 'package:aqsaa_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'api_client_test.dart' show jsonResponse;
import 'support/auth_fixtures.dart';

void main() {
  testWidgets(
    'login validates, hides/shows password, prevents duplicates, then logs out',
    (tester) async {
      final memory = MemorySecureStore();
      final store = SessionStore(memory);
      final loginPending = Completer<http.Response>();
      var logins = 0;
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient((r) async {
          if (r.url.path.endsWith('bootstrap')) return jsonResponse();
          if (r.url.path.endsWith('login')) {
            logins++;
            return loginPending.future;
          }
          return authResponse(r);
        }),
      );
      addTearDown(api.close);
      await tester.pumpWidget(AqsaaApp(client: api, sessionStore: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.login));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, AppStrings.login),
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.requiredField), findsNWidgets(2));
      expect(logins, 0);
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isTrue,
      );
      await tester.tap(find.byTooltip(AppStrings.showPassword));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isFalse,
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, AppStrings.login),
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(logins, 1);
      loginPending.complete(response(loginJson(), 201));
      await tester.pumpAndSettle();
      expect(find.text('Test User'), findsOneWidget);
      expect(find.text('Roles: Teacher'), findsOneWidget);
      await tester.ensureVisible(find.text(AppStrings.logout));
      await tester.tap(find.text(AppStrings.logout));
      await tester.pumpAndSettle();
      expect(find.text('Test User'), findsNothing);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        isEmpty,
      );
      expect(await store.read(testBase), isNull);
    },
  );
  testWidgets('restored account with no capabilities still offers logout', (
    tester,
  ) async {
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((r) async {
        if (r.url.path.endsWith('bootstrap')) return jsonResponse();
        if (r.url.path.endsWith('capabilities')) {
          return response(capabilitiesJson(empty: true));
        }
        return authResponse(r);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(AqsaaApp(client: api, sessionStore: store));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.noCapabilities), findsOneWidget);
    expect(find.text(AppStrings.logout), findsOneWidget);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets('failed logout explains lack of confirmation and offers retry', (
    tester,
  ) async {
    final store = SessionStore(MemorySecureStore());
    await store.save(credential());
    final api = ApiClient(
      baseUrl: testBase,
      client: MockClient((r) async {
        if (r.url.path.endsWith('bootstrap')) return jsonResponse();
        if (r.url.path.endsWith('logout')) return http.Response('', 503);
        return authResponse(r);
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(AqsaaApp(client: api, sessionStore: store));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text(AppStrings.logout));
    await tester.tap(find.text(AppStrings.logout));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.logoutUnconfirmed), findsOneWidget);
    expect(find.text(AppStrings.retry), findsOneWidget);
    expect(await store.read(testBase), isNotNull);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets(
    'RTL login fits narrow viewport and shows invalid credentials safely',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = ApiClient(
        baseUrl: testBase,
        client: MockClient(
          (r) async => r.url.path.endsWith('bootstrap')
              ? jsonResponse()
              : response({
                  'message': 'The provided credentials are incorrect.',
                }, 422),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(
        AqsaaApp(
          client: api,
          sessionStore: SessionStore(MemorySecureStore()),
          textDirection: TextDirection.rtl,
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(AppStrings.login));
      await tester.tap(find.text(AppStrings.login));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'user@example.test',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'synthetic-password',
      );
      await tester.ensureVisible(
        find.widgetWithText(FilledButton, AppStrings.login),
      );
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.login));
      await tester.pumpAndSettle();
      expect(
        find.text(
          AppStrings.error(const ApiException(ApiFailure.invalidCredentials)),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
