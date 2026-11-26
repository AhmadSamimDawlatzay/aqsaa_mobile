import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../api/api_client.dart';
import '../l10n/app_strings.dart';
import '../models/bootstrap_response.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import '../widgets/language_selector.dart';
import 'session_controller.dart';
import 'session_store.dart';
import 'children_view.dart';
import 'notification_inbox_controller.dart';
import 'notifications_view.dart';
import '../push/push_controller.dart';
import '../push/push_messaging.dart';

class AuthFlow extends StatefulWidget {
  const AuthFlow({
    super.key,
    required this.api,
    required this.store,
    required this.institution,
    required this.branding,
    required this.onRetryBootstrap,
    this.pushMessaging,
  });
  final ApiClient api;
  final SessionStore store;
  final Institution? institution;
  final Widget branding;
  final VoidCallback onRetryBootstrap;
  final PushMessaging? pushMessaging;
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
      if (session.phase == SessionPhase.authenticated) {
        return _AuthenticatedLayout(
          session: session,
          institution: widget.institution,
          pushMessaging: widget.pushMessaging,
        );
      }
      if (session.busy && session.phase != SessionPhase.signingIn) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.institution?.name ?? AppStrings.appName),
          ),
          body: AppPageFrame(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    session.phase == SessionPhase.loggingOut
                        ? AppStrings.signingOut
                        : AppStrings.checkingSession,
                  ),
                ],
              ),
            ),
          ),
        );
      }
      if (session.phase == SessionPhase.failure) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.institution?.name ?? AppStrings.appName),
          ),
          body: AppPageFrame(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    session.logoutUnconfirmed
                        ? AppStrings.logoutUnconfirmed
                        : AppStrings.error(session.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: session.retry,
                    child: Text(AppStrings.retry),
                  ),
                  if (session.hasSession && !session.logoutUnconfirmed)
                    TextButton(
                      onPressed: session.logout,
                      child: Text(AppStrings.logout),
                    ),
                ],
              ),
            ),
          ),
        );
      }
      return _signedOut(context);
    },
  );

  Widget _signedOut(BuildContext context) {
    final formVisible = session.showLogin;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.institution?.name ?? AppStrings.appName),
      ),
      body: AppPageFrame(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const LanguageSelector(compact: true),
              const SizedBox(height: 18),
              Center(child: widget.branding),
              const SizedBox(height: 18),
              AppPageHeading(
                title: formVisible
                    ? AppStrings.loginHeading
                    : AppStrings.welcome,
                subtitle: formVisible
                    ? AppStrings.loginSubtitle
                    : AppStrings.subtitle,
              ),
              const SizedBox(height: 22),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: formVisible
                      ? LoginForm(session: session)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.check_circle_outline,
                                  color: AppPalette.emerald,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    widget.institution == null
                                        ? AppStrings.empty
                                        : AppStrings.connected,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),
                            FilledButton.icon(
                              onPressed: session.openLogin,
                              icon: const Icon(Icons.login),
                              label: Text(AppStrings.login),
                            ),
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: widget.onRetryBootstrap,
                              icon: const Icon(Icons.refresh),
                              label: Text(AppStrings.refresh),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthenticatedLayout extends StatefulWidget {
  const _AuthenticatedLayout({
    required this.session,
    required this.institution,
    this.pushMessaging,
  });
  final SessionController session;
  final Institution? institution;
  final PushMessaging? pushMessaging;

  @override
  State<_AuthenticatedLayout> createState() => _AuthenticatedLayoutState();
}

class _AuthenticatedLayoutState extends State<_AuthenticatedLayout>
    with WidgetsBindingObserver {
  int _destination = 0;
  late final NotificationInboxController notifications;
  DateTime? _lastResumeRefresh;
  PushController? push;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    notifications = NotificationInboxController(session: widget.session);
    if (widget.session.capabilities!.canViewChildren) {
      notifications.initialize();
    }
    if (widget.pushMessaging != null) {
      push = PushController(
        messaging: widget.pushMessaging!,
        session: widget.session,
        onForegroundMessage: _onForegroundPush,
        onOpenInbox: _openInboxFromPush,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) => _offerPush());
    }
  }

  Future<void> _offerPush() async {
    if (!mounted || push == null) return;
    final permission = await push!.permissionStatus();
    if (!mounted) return;
    if (permission != PushPermission.notDetermined) {
      await push!.start(requestPermission: false);
      return;
    }
    final enable = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppStrings.pushPermissionTitle),
        content: Text(AppStrings.pushPermissionBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppStrings.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppStrings.enableNotifications),
          ),
        ],
      ),
    );
    if (mounted) await push!.start(requestPermission: enable == true);
  }

  void _onForegroundPush() {
    notifications.refresh();
    notifications.refreshUnreadCount();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(AppStrings.newNotification)));
  }

  void _openInboxFromPush() {
    if (!mounted || !widget.session.capabilities!.canViewChildren) return;
    setState(() => _destination = 1);
    notifications.refresh();
    notifications.refreshUnreadCount();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        !widget.session.capabilities!.canViewChildren) {
      return;
    }
    final now = DateTime.now();
    if (_lastResumeRefresh != null &&
        now.difference(_lastResumeRefresh!) < const Duration(seconds: 30)) {
      return;
    }
    _lastResumeRefresh = now;
    notifications.refresh();
    notifications.refreshUnreadCount();
    push?.resume();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    notifications.dispose();
    push?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.session.profile!;
    final canViewChildren = widget.session.capabilities!.canViewChildren;
    final destinations = canViewChildren
        ? [
            NavigationDestination(
              icon: Icon(Icons.people_outline),
              selectedIcon: Icon(Icons.people),
              label: AppStrings.childrenTab,
            ),
            NavigationDestination(
              icon: _NotificationNavigationIcon(
                controller: notifications,
                selected: false,
              ),
              selectedIcon: _NotificationNavigationIcon(
                controller: notifications,
                selected: true,
              ),
              label: AppStrings.notifications,
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle),
              label: AppStrings.accountTab,
            ),
          ]
        : <NavigationDestination>[];

    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.appName)),
      body: canViewChildren
          ? IndexedStack(
              index: _destination,
              children: [
                ChildrenView(
                  key: ValueKey('children-${profile.id}'),
                  session: widget.session,
                  institution: widget.institution,
                  profile: profile,
                ),
                NotificationsView(
                  controller: notifications,
                  session: widget.session,
                ),
                AccountView(
                  session: widget.session,
                  institution: widget.institution,
                  push: push,
                ),
              ],
            )
          : AccountView(
              session: widget.session,
              institution: widget.institution,
              push: push,
            ),
      bottomNavigationBar: canViewChildren
          ? NavigationBar(
              selectedIndex: _destination,
              destinations: destinations,
              onDestinationSelected: (index) {
                setState(() => _destination = index);
                if (index == 1) {
                  notifications.refresh();
                  notifications.refreshUnreadCount();
                }
              },
            )
          : null,
    );
  }
}

class _NotificationNavigationIcon extends StatelessWidget {
  const _NotificationNavigationIcon({
    required this.controller,
    required this.selected,
  });
  final NotificationInboxController controller;
  final bool selected;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final count = controller.unreadCount;
      final icon = Icon(
        selected ? Icons.notifications : Icons.notifications_outlined,
      );
      if (count == null || count == 0) return icon;
      final value = count > 99 ? '99+' : '$count';
      return Semantics(
        label: AppStrings.unreadNotificationCount(count),
        child: Badge(label: Text(value), child: icon),
      );
    },
  );
}

class AccountView extends StatelessWidget {
  const AccountView({
    super.key,
    required this.session,
    required this.institution,
    this.push,
  });
  final SessionController session;
  final Institution? institution;
  final PushController? push;

  @override
  Widget build(BuildContext context) => AppPageFrame(
    child: ListView(
      children: [
        AppPageHeading(
          title: AppStrings.accountHeading,
          subtitle: AppStrings.accountSubtitle,
        ),
        const SizedBox(height: 20),
        AppSectionCard(
          title: AppStrings.profileSection,
          icon: Icons.person_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppInfoRow(
                label: AppStrings.name,
                value: session.profile!.name,
                icon: Icons.badge_outlined,
              ),
              AppInfoRow(
                label: AppStrings.email,
                value: session.profile!.email,
                icon: Icons.mail_outline,
                valueTextDirection: TextDirection.ltr,
              ),
              if (session.profile!.roles.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: session.profile!.roles
                      .map(
                        (role) => Chip(
                          label: Text(AppStrings.roleLabel(role)),
                          visualDensity: VisualDensity.compact,
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ],
          ),
        ),
        if (institution != null) ...[
          const SizedBox(height: AppSpacing.section),
          AppSectionCard(
            title: AppStrings.institutionSection,
            icon: Icons.school_outlined,
            child: Text(
              institution!.name,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.section),
        AppSectionCard(
          title: AppStrings.language,
          icon: Icons.language,
          child: const LanguageSelector(compact: true),
        ),
        if (!session.capabilities!.hasSupportedAccess) ...[
          const SizedBox(height: AppSpacing.section),
          Text(AppStrings.noCapabilities),
        ],
        const SizedBox(height: AppSpacing.section),
        if (push != null)
          ListenableBuilder(
            listenable: push!,
            builder: (context, _) => _PushStatusCard(controller: push!),
          ),
        if (push != null) const SizedBox(height: AppSpacing.section),
        OutlinedButton.icon(
          onPressed: session.logout,
          icon: const Icon(Icons.logout),
          label: Text(AppStrings.logout),
        ),
      ],
    ),
  );
}

class _PushStatusCard extends StatelessWidget {
  const _PushStatusCard({required this.controller});
  final PushController controller;

  @override
  Widget build(BuildContext context) {
    final message = switch (controller.state) {
      PushState.registered => AppStrings.pushReady,
      PushState.denied => AppStrings.pushDenied,
      PushState.conflict => AppStrings.pushConflict,
      PushState.failed => AppStrings.pushRegistrationFailed,
      PushState.registering => AppStrings.pushRegistering,
      PushState.idle => AppStrings.pushNotEnabled,
    };
    return AppSectionCard(
      title: AppStrings.pushNotifications,
      icon: Icons.notifications_active_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          if (controller.state == PushState.failed) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: controller.retry,
              child: Text(AppStrings.retry),
            ),
          ],
          if (kDebugMode && controller.state == PushState.registered) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () async {
                final token = await controller.debugTokenForCopy();
                if (token == null || !context.mounted) return;
                await Clipboard.setData(ClipboardData(text: token));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(AppStrings.debugTokenCopied)),
                );
              },
              icon: const Icon(Icons.copy_outlined),
              label: Text(AppStrings.copyDebugToken),
            ),
          ],
        ],
      ),
    );
  }
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
            Text(AppStrings.invalidSession),
            const SizedBox(height: 16),
          ],
          TextFormField(
            controller: _email,
            enabled: !session.busy,
            decoration: InputDecoration(labelText: AppStrings.email),
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
                : Text(AppStrings.login),
          ),
          TextButton(
            onPressed: session.busy ? null : session.backToWelcome,
            child: Text(AppStrings.back),
          ),
        ],
      ),
    );
  }
}
