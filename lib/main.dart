import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'api/api_client.dart';
import 'l10n/app_strings.dart';
import 'models/bootstrap_response.dart';
import 'auth/auth_flow.dart';
import 'auth/session_store.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AqsaaApp());
}

class AqsaaApp extends StatelessWidget {
  const AqsaaApp({
    super.key,
    this.client,
    this.sessionStore,
    this.textDirection = TextDirection.ltr,
  });
  final ApiClient? client;
  final SessionStore? sessionStore;
  final TextDirection textDirection;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: AppStrings.appName,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF12685B)),
      scaffoldBackgroundColor: const Color(0xFFF5F7F3),
      useMaterial3: true,
    ),
    builder: (context, child) =>
        Directionality(textDirection: textDirection, child: child!),
    home: ConnectionScreen(client: client, sessionStore: sessionStore),
  );
}

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key, this.client, this.sessionStore});
  final ApiClient? client;
  final SessionStore? sessionStore;
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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      title: const Text(AppStrings.appName),
      backgroundColor: Colors.transparent,
    ),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 32, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  AppStrings.welcome,
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(AppStrings.subtitle, textAlign: TextAlign.center),
                const SizedBox(height: 32),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: FutureBuilder<BootstrapResponse>(
                      future: _response,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 24),
                              Text(
                                AppStrings.loading,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        }
                        if (snapshot.hasError) {
                          return Column(
                            children: [
                              Icon(
                                Icons.cloud_off_outlined,
                                size: 48,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                AppStrings.failed,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                AppStrings.error(snapshot.error),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: _retry,
                                icon: const Icon(Icons.refresh),
                                label: const Text(AppStrings.retry),
                              ),
                            ],
                          );
                        }
                        final institution = snapshot.data!.institution;
                        return AuthFlow(
                          api: _client,
                          store: _sessionStore,
                          institution: institution,
                          branding: InstitutionLogo(
                            uri: _client.logoUri(institution?.logo),
                          ),
                          welcomeBuilder: (openLogin) => Column(
                            children: [
                              InstitutionLogo(
                                uri: _client.logoUri(institution?.logo),
                              ),
                              const SizedBox(height: 20),
                              if (institution != null)
                                Text(
                                  institution.name,
                                  textAlign: TextAlign.center,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.headlineSmall,
                                ),
                              const SizedBox(height: 16),
                              const Icon(
                                Icons.check_circle_outline,
                                color: Color(0xFF12685B),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                institution == null
                                    ? AppStrings.empty
                                    : AppStrings.connected,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 24),
                              FilledButton(
                                onPressed: openLogin,
                                child: const Text(AppStrings.login),
                              ),
                              OutlinedButton.icon(
                                onPressed: _retry,
                                icon: const Icon(Icons.refresh),
                                label: const Text(AppStrings.refresh),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class InstitutionLogo extends StatelessWidget {
  const InstitutionLogo({super.key, this.uri});
  final Uri? uri;

  Widget _fallback() => Semantics(
    label: AppStrings.logoFallback,
    child: Icon(Icons.school_outlined, size: 64),
  );

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 96,
    height: 96,
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
