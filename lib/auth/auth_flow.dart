import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../l10n/app_strings.dart';
import '../models/bootstrap_response.dart';
import 'session_controller.dart';
import 'session_store.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({
    super.key,
    required this.api,
    required this.store,
    required this.institution,
    required this.branding,
    required this.welcomeBuilder,
  });
  final ApiClient api;
  final SessionStore store;
  final Institution? institution;
  final Widget branding;
  final Widget Function(VoidCallback openLogin) welcomeBuilder;
  @override
  State<AuthFlow> createState() => _AuthFlowState();
}

class _AuthFlowState extends State<AuthFlow> {
  late final SessionController session;
  @override
  void initState() {
    super.initState();
    session = SessionController(api: widget.api, store: widget.store);
    session.restore();
  }

  @override
  void dispose() {
    session.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) {
      if (session.phase == SessionPhase.signedOut && !session.showLogin) {
        return widget.welcomeBuilder(session.openLogin);
      }
      final formVisible =
          session.showLogin &&
          (session.phase == SessionPhase.signedOut ||
              session.phase == SessionPhase.signingIn);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: widget.branding),
          const SizedBox(height: 16),
          Text(
            widget.institution?.name ?? AppStrings.appName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          if (formVisible)
            LoginForm(session: session)
          else if (session.busy) ...[
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 16),
            Text(
              session.phase == SessionPhase.loggingOut
                  ? AppStrings.signingOut
                  : AppStrings.checkingSession,
              textAlign: TextAlign.center,
            ),
          ] else if (session.phase == SessionPhase.authenticated) ...[
            Text(
              AppStrings.home,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              session.profile!.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(session.profile!.email),
            const SizedBox(height: 8),
            Text(AppStrings.roles(session.profile!.roles)),
            const SizedBox(height: 16),
            Text(
              session.capabilities!.hasSupportedAccess
                  ? AppStrings.accessReady
                  : AppStrings.noCapabilities,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: session.logout,
              icon: const Icon(Icons.logout),
              label: const Text(AppStrings.logout),
            ),
          ] else ...[
            if (session.logoutUnconfirmed)
              const Text(AppStrings.logoutUnconfirmed),
            Text(AppStrings.error(session.error)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: session.retry,
              child: const Text(AppStrings.retry),
            ),
            if (session.hasSession && !session.logoutUnconfirmed)
              TextButton(
                onPressed: session.logout,
                child: const Text(AppStrings.logout),
              ),
          ],
        ],
      );
    },
  );
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key, required this.session});
  final SessionController session;
  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.session.busy || !_form.currentState!.validate()) return;
    final password = _password.text;
    _password.clear();
    FocusScope.of(context).unfocus();
    await widget.session.login(_email.text.trim(), password);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (session.invalidSessionNotice) ...[
            const Text(AppStrings.invalidSession),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _email,
            enabled: !session.busy,
            decoration: const InputDecoration(labelText: AppStrings.email),
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            textDirection: TextDirection.ltr,
            validator: (value) => value == null || value.trim().isEmpty
                ? AppStrings.requiredField
                : value.trim().length > 255 ||
                      !RegExp(
                        r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                      ).hasMatch(value.trim())
                ? AppStrings.invalidEmail
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            enabled: !session.busy,
            obscureText: _obscure,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: AppStrings.password,
              suffixIcon: IconButton(
                onPressed: session.busy
                    ? null
                    : () => setState(() => _obscure = !_obscure),
                tooltip: _obscure
                    ? AppStrings.showPassword
                    : AppStrings.hidePassword,
                icon: Icon(
                  _obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (value) => value == null || value.isEmpty
                ? AppStrings.requiredField
                : value.length > 255
                ? AppStrings.passwordTooLong
                : null,
          ),
          if (session.error != null) ...[
            const SizedBox(height: 16),
            Text(
              AppStrings.error(session.error),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            if (session.error case ApiException(fieldErrors: final errors))
              ...errors.keys.map((field) => Text(AppStrings.fieldError(field))),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: session.busy ? null : _submit,
            child: session.busy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(AppStrings.login),
          ),
          TextButton(
            onPressed: session.busy ? null : session.backToWelcome,
            child: const Text(AppStrings.back),
          ),
        ],
      ),
    );
  }
}
