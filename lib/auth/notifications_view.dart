import 'package:flutter/material.dart';
import '../api/api_client.dart';
import '../l10n/app_strings.dart';
import '../models/child_models.dart';
import '../models/notification_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'children_view.dart';
import 'notification_inbox_controller.dart';
import 'session_controller.dart';

class NotificationsView extends StatelessWidget {
  const NotificationsView({
    super.key,
    required this.controller,
    required this.session,
  });

  final NotificationInboxController controller;
  final SessionController session;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => AppPageFrame(
      padding: EdgeInsets.zero,
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            controller.refresh(),
            controller.refreshUnreadCount(),
          ]);
        },
        child: _content(context),
      ),
    ),
  );

  Widget _content(BuildContext context) {
    if (controller.loading && controller.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 120),
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Center(child: Text(AppStrings.loadingNotifications)),
        ],
      );
    }
    if (controller.listError != null && controller.items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 24),
        children: [
          AppPageHeading(
            title: AppStrings.notifications,
            subtitle: AppStrings.notificationsSubtitle,
          ),
          const SizedBox(height: 22),
          AppSectionCard(
            title: AppStrings.notificationsUnavailable,
            icon: Icons.notifications_off_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(AppStrings.error(controller.listError)),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: controller.refresh,
                  child: Text(AppStrings.retry),
                ),
              ],
            ),
          ),
        ],
      );
    }
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 24),
      children: [
        AppPageHeading(
          title: AppStrings.notifications,
          subtitle: AppStrings.notificationsSubtitle,
        ),
        if ((controller.unreadCount ?? 0) > 0) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: controller.markingAll ? null : () => _markAll(context),
              icon: controller.markingAll
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all),
              label: Text(AppStrings.markAllRead),
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (controller.items.isEmpty)
          AppSectionCard(
            title: AppStrings.noNotificationsTitle,
            icon: Icons.notifications_none,
            child: Text(AppStrings.noNotifications),
          )
        else
          for (final item in controller.items) ...[
            _NotificationCard(item: item, onTap: () => _open(context, item)),
            const SizedBox(height: 10),
          ],
        if (controller.loadMoreError != null) ...[
          const SizedBox(height: 8),
          Text(
            AppStrings.error(controller.loadMoreError),
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: controller.loadMore,
            child: Text(AppStrings.retry),
          ),
        ] else if (controller.loadingMore) ...[
          const Padding(
            padding: EdgeInsets.all(18),
            child: Center(child: CircularProgressIndicator()),
          ),
        ] else if (controller.canLoadMore) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: controller.loadMore,
            child: Text(AppStrings.loadMore),
          ),
        ],
      ],
    );
  }

  Future<void> _markAll(BuildContext context) async {
    try {
      await controller.markAllRead();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.error(error))));
      }
    }
  }

  Future<void> _open(BuildContext context, InboxNotification item) async {
    var selected = item;
    try {
      selected = await controller.markRead(item);
    } catch (error) {
      if (!context.mounted) return;
      if (error is ApiException &&
          (error.failure == ApiFailure.forbidden || error.statusCode == 404)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.notificationNoLongerAvailable)),
        );
        await controller.refresh();
        await controller.refreshUnreadCount();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.notificationReadFailed)),
      );
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            NotificationDetailScreen(item: selected, session: session),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});
  final InboxNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    color: item.isRead ? AppPalette.surface : AppPalette.surfaceTint,
    clipBehavior: Clip.antiAlias,
    child: Semantics(
      button: true,
      label: item.isRead
          ? AppStrings.readNotification
          : AppStrings.unreadNotification,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 15, 12, 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppPalette.surface,
                child: Icon(
                  _eventIcon(item.eventType),
                  color: AppPalette.emerald,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            AppStrings.notificationTitle(item),
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: item.isRead
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                          ),
                        ),
                        if (!item.isRead)
                          Semantics(
                            label: AppStrings.unreadNotification,
                            child: Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsetsDirectional.only(
                                start: 8,
                                top: 5,
                              ),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppPalette.emerald,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      AppStrings.notificationBody(item),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (item.student != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        item.student!.name,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      _formatDateTime(context, item.createdAt),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppPalette.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left
                    : Icons.chevron_right,
                color: AppPalette.secondaryText,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class NotificationDetailScreen extends StatefulWidget {
  const NotificationDetailScreen({
    super.key,
    required this.item,
    required this.session,
  });
  final InboxNotification item;
  final SessionController session;

  @override
  State<NotificationDetailScreen> createState() =>
      _NotificationDetailScreenState();
}

class _NotificationDetailScreenState extends State<NotificationDetailScreen> {
  bool _opening = false;
  bool _targetUnavailable = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final hasAction =
        !_targetUnavailable &&
        item.destination != NotificationDestination.unavailable;
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.notificationDetails)),
      body: AppPageFrame(
        child: ListView(
          children: [
            AppSectionCard(
              title: AppStrings.notificationTitle(item),
              icon: _eventIcon(item.eventType),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.notificationBody(item),
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  if (item.student != null) ...[
                    const SizedBox(height: 18),
                    AppInfoRow(
                      label: AppStrings.student,
                      value: item.student!.name,
                      icon: Icons.person_outline,
                    ),
                    AppInfoRow(
                      label: AppStrings.studentNumberLabel,
                      value: item.student!.number,
                      icon: Icons.badge_outlined,
                      valueTextDirection: TextDirection.ltr,
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    _formatDateTime(context, item.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            if (hasAction) ...[
              const SizedBox(height: AppSpacing.section),
              FilledButton.icon(
                onPressed: _opening ? null : _openTarget,
                icon: _opening
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.open_in_new),
                label: Text(
                  item.destination == NotificationDestination.attendance
                      ? AppStrings.viewAttendance
                      : AppStrings.viewChildDetails,
                ),
              ),
            ] else if (item.eventType == NotificationEventType.releasedResult)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.section),
                child: Text(AppStrings.resultsDestinationUnavailable),
              ),
            if (_targetUnavailable)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.section),
                child: Text(AppStrings.notificationTargetUnavailable),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTarget() async {
    final student = widget.item.student;
    if (student == null) return;
    setState(() => _opening = true);
    try {
      if (widget.item.destination == NotificationDestination.attendance) {
        final details = await widget.session.fetchChild(student.id);
        if (!mounted) return;
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => AttendanceScreen(
              initialDetails: details,
              session: widget.session,
            ),
          ),
        );
      } else {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (context) => ChildDetailsScreen(
              child: LinkedChild(student.id, student.number, student.name),
              session: widget.session,
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException &&
          (error.failure == ApiFailure.forbidden || error.statusCode == 404)) {
        setState(() => _targetUnavailable = true);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppStrings.error(error))));
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }
}

IconData _eventIcon(NotificationEventType type) => switch (type) {
  NotificationEventType.attendanceAbsent => Icons.event_busy_outlined,
  NotificationEventType.attendanceCorrected => Icons.fact_check_outlined,
  NotificationEventType.releasedResult => Icons.workspace_premium_outlined,
  NotificationEventType.promotionCommitted => Icons.trending_up,
  NotificationEventType.transferApproved => Icons.swap_horiz,
  NotificationEventType.unknown => Icons.notifications_outlined,
};

String _formatDateTime(BuildContext context, DateTime value) {
  final local = value.isUtc ? value.toLocal() : value;
  final material = MaterialLocalizations.of(context);
  final date = material.formatMediumDate(local);
  final time = material.formatTimeOfDay(TimeOfDay.fromDateTime(local));
  return '$date · $time';
}
