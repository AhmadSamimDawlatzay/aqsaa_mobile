import 'package:flutter/material.dart';
import 'api/api_client.dart';
import 'l10n/app_strings.dart';
import 'models/bootstrap_response.dart';
import 'auth/auth_flow.dart';
import 'auth/session_store.dart';
import 'theme/app_theme.dart';
import 'widgets/app_components.dart';

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
    theme: AqsaaTheme.light,
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
          appBar: AppBar(title: const Text(AppStrings.appName)),
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
                    label: const Text(AppStrings.retry),
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
