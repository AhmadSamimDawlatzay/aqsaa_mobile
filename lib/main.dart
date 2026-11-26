import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api/api_client.dart';
import 'l10n/app_strings.dart';
import 'l10n/app_language.dart';
import 'l10n/locale_controller.dart';
import 'l10n/pashto_cupertino_localizations.dart';
import 'models/bootstrap_response.dart';
import 'auth/auth_flow.dart';
import 'auth/session_store.dart';
import 'theme/app_theme.dart';
import 'widgets/app_components.dart';
import 'config/installation_config.dart';
import 'push/firebase_push_messaging.dart';
import 'push/push_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Background delivery is intentionally passive. The authorized inbox is
  // refreshed only after UI/session restoration.
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PushMessaging? pushMessaging;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    final app = await Firebase.initializeApp();
    final config = InstallationConfig.current;
    config.validateFirebaseMetadata(
      androidPackageName: config.androidApplicationId,
      nativeProjectId: app.options.projectId,
      dartProjectId: config.firebaseProjectId,
    );
    pushMessaging = FirebasePushMessaging(FirebaseMessaging.instance);
  }
  runApp(AqsaaApp(pushMessaging: pushMessaging));
}

class AqsaaApp extends StatefulWidget {
  const AqsaaApp({
    super.key,
    this.client,
    this.sessionStore,
    this.localeController,
    this.textDirection,
    this.pushMessaging,
  });
  final ApiClient? client;
  final SessionStore? sessionStore;
  final LocaleController? localeController;
  final TextDirection? textDirection;
  final PushMessaging? pushMessaging;

  @override
  State<AqsaaApp> createState() => _AqsaaAppState();
}

class _AqsaaAppState extends State<AqsaaApp> {
  late final SessionStore _sessionStore;
  late final LocaleController _localeController;

  @override
  void initState() {
    super.initState();
    _sessionStore = widget.sessionStore ?? SessionStore(PlatformSecureStore());
    _localeController =
        widget.localeController ?? LocaleController(_sessionStore.storage);
    _localeController.restore();
  }

  @override
  void dispose() {
    if (widget.localeController == null) _localeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LocaleScope(
    controller: _localeController,
    child: ListenableBuilder(
      listenable: _localeController,
      builder: (context, _) => MaterialApp(
        title: InstallationConfig.current.displayName,
        debugShowCheckedModeBanner: false,
        theme: AqsaaTheme.light,
        locale: _localeController.locale,
        supportedLocales: AppLanguage.values.map((value) => value.locale),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          PashtoCupertinoLocalizationsDelegate(),
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: widget.textDirection == null
            ? null
            : (context, child) => Directionality(
                textDirection: widget.textDirection!,
                child: child!,
              ),
        home: ConnectionScreen(
          client: widget.client,
          sessionStore: _sessionStore,
          pushMessaging: widget.pushMessaging,
        ),
      ),
    ),
  );
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({
    super.key,
    this.client,
    this.sessionStore,
    this.pushMessaging,
  });
  final ApiClient? client;
  final SessionStore? sessionStore;
  final PushMessaging? pushMessaging;
  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen> {
  late final ApiClient _client;
  late final SessionStore _sessionStore;
  late Future<BootstrapResponse> _response;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? ApiClient();
    _sessionStore = widget.sessionStore ?? SessionStore(PlatformSecureStore());
    _response = _client.fetchBootstrap();
  }

  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  void _retry() {
    setState(() {
      _response = _client.fetchBootstrap();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BootstrapResponse>(
    future: _response,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Scaffold(
          body: AppPageFrame(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(AppStrings.loading),
                ],
              ),
            ),
          ),
        );
      }
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: Text(AppStrings.appName)),
          body: AppPageFrame(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 42,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.failed,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.error(snapshot.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh),
                    label: Text(AppStrings.retry),
                  ),
                ],
              ),
            ),
          ),
        );
      }
      final institution = snapshot.data!.institution;
      return AuthFlow(
        api: _client,
        store: _sessionStore,
        institution: institution,
        branding: InstitutionLogo(uri: _client.logoUri(institution?.logo)),
        onRetryBootstrap: _retry,
        pushMessaging: widget.pushMessaging,
      );
    },
  );
}

class InstitutionLogo extends StatelessWidget {
  const InstitutionLogo({super.key, this.uri, this.size = 64});
  final Uri? uri;
  final double size;

  Widget _fallback() => Semantics(
    label: AppStrings.logoFallback,
    child: Icon(Icons.school_outlined, size: size * 0.7),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: uri == null
        ? _fallback()
        : Image.network(
            uri.toString(),
            fit: BoxFit.contain,
            semanticLabel: AppStrings.logo,
            errorBuilder: (context, error, stackTrace) => _fallback(),
            loadingBuilder: (context, child, progress) =>
                progress == null ? child : _fallback(),
          ),
  );
}
