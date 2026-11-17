import 'package:aqsaa_mobile/api/api_client.dart';
import 'package:aqsaa_mobile/auth/session_store.dart';
import 'package:aqsaa_mobile/l10n/app_strings.dart';
import 'package:aqsaa_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:integration_test/integration_test.dart';
import '../test/api_client_test.dart' show jsonResponse;
import '../test/support/auth_fixtures.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Android secure storage restores mocked account and clears on logout',
    (tester) async {
      // All HTTP is mocked. The synthetic token uses a separate .invalid scope.
      const scope = 'https://aqsaa-integration.invalid/api/v1/';
      final store = SessionStore(PlatformSecureStore());
      await store.clear(scope);
      addTearDown(() => store.clear(scope));
      await store.save(credential(scope));
      final reopened = SessionStore(PlatformSecureStore());
      expect((await reopened.read(scope))!.token, 'synthetic-test-token');
      final api = ApiClient(
        baseUrl: scope,
        client: MockClient(
          (r) async => r.url.path.endsWith('bootstrap')
              ? jsonResponse()
              : authResponse(r),
        ),
      );
      addTearDown(api.close);
      await tester.pumpWidget(AqsaaApp(client: api, sessionStore: reopened));
      for (
        var i = 0;
        i < 50 && find.text('Test User').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Test User'), findsOneWidget);
      await tester.ensureVisible(find.text(AppStrings.logout));
      await tester.tap(find.text(AppStrings.logout));
      for (
        var i = 0;
        i < 50 && find.byType(TextFormField).evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(await store.read(scope), isNull);
    },
  );
}
