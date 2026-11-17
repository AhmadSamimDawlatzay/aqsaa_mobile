import 'dart:async';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'support/auth_fixtures.dart';
import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/l10n/app_strings.dart';
import 'package:aqsaa_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'api_client_test.dart' show bootstrapJson, jsonResponse;

void main() {
  testWidgets('loading becomes connected with name and missing-logo fallback', (
    tester,
  ) async {
    final pending = Completer<http.Response>();
    final client = ApiClient(client: MockClient((_) => pending.future));
    addTearDown(client.close);
    await tester.pumpWidget(
      AqsaaApp(sessionStore: SessionStore(MemorySecureStore()), client: client),
    );
    expect(find.text(AppStrings.loading), findsOneWidget);
    pending.complete(jsonResponse());
    await tester.pumpAndSettle();
    expect(find.text('Test Academy'), findsOneWidget);
    expect(find.text(AppStrings.connected), findsOneWidget);
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
  });
  testWidgets('HTTP error can retry through loading to success', (
    tester,
  ) async {
    var calls = 0;
    final pending = Completer<http.Response>();
    final client = ApiClient(
      client: MockClient(
        (_) async =>
            ++calls == 1 ? http.Response('Unavailable', 503) : pending.future,
      ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      AqsaaApp(sessionStore: SessionStore(MemorySecureStore()), client: client),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('HTTP 503'), findsOneWidget);
    await tester.tap(find.text(AppStrings.retry));
    await tester.pump();
    expect(find.text(AppStrings.loading), findsOneWidget);
    pending.complete(jsonResponse());
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.connected), findsOneWidget);
    expect(calls, 2);
  });
  testWidgets('empty institution is explicit; RTL fits a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final client = ApiClient(
      client: MockClient(
        (_) async => jsonResponse(bootstrapJson(institution: null)),
      ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      AqsaaApp(
        sessionStore: SessionStore(MemorySecureStore()),
        client: client,
        textDirection: TextDirection.rtl,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.empty), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text(AppStrings.empty))),
      TextDirection.rtl,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('failed network logo keeps a visible fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InstitutionLogo(
          uri: Uri.parse('https://example.test/missing.png'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.school_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('HTML response never displays connected', (tester) async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '<html/>',
          200,
          headers: {'content-type': 'text/html'},
        ),
      ),
    );
    addTearDown(client.close);
    await tester.pumpWidget(
      AqsaaApp(sessionStore: SessionStore(MemorySecureStore()), client: client),
    );
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.failed), findsOneWidget);
    expect(find.text(AppStrings.connected), findsNothing);
    expect(find.text(AppStrings.retry), findsOneWidget);
  });
}
