import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import '../api/api_client.dart';
import '../l10n/app_strings.dart';
import '../models/auth_models.dart';
import '../models/bootstrap_response.dart';
import '../models/child_models.dart';
import '../theme/app_theme.dart';
import '../widgets/app_components.dart';
import 'session_controller.dart';

class ChildrenView extends StatefulWidget {
  const ChildrenView({
    super.key,
    required this.session,
    required this.institution,
    required this.profile,
  });
  final SessionController session;
  final Institution? institution;
  final UserProfile profile;

  @override
  State<ChildrenView> createState() => _ChildrenViewState();
}

class _ChildrenViewState extends State<ChildrenView> {
  AsyncSnapshot<ChildPage>? _children;
  int _page = 1;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([int page = 1]) async {
    final generation = ++_generation;
    setState(() {
      _page = page;
      _children = const AsyncSnapshot.waiting();
    });
    try {
      final data = await widget.session.fetchChildren(page: page);
      if (!mounted || generation != _generation) return;
      setState(
        () => _children = AsyncSnapshot.withData(ConnectionState.done, data),
      );
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _children = AsyncSnapshot.withError(
          ConnectionState.done,
          error,
          stack,
        ),
      );
    }
  }

  Future<void> _open(LinkedChild child) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) =>
            ChildDetailsScreen(child: child, session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AppPageFrame(
    padding: EdgeInsets.zero,
    child: RefreshIndicator(
      onRefresh: () => _load(_page),
      child:
          _children == null ||
              _children!.connectionState != ConnectionState.done
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 110),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 18),
                Center(child: Text(AppStrings.loadingChildren)),
              ],
            )
          : _children!.hasError
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 24),
              children: [
                _childrenHeading(context),
                const SizedBox(height: 22),
                _FeatureError(
                  message: AppStrings.error(_children!.error),
                  onRetry: () => _load(_page),
                ),
              ],
            )
          : _childrenList(context, _children!.requireData),
    ),
  );

  Widget _childrenHeading(BuildContext context) => AppPageHeading(
    eyebrow: widget.institution?.name ?? AppStrings.appName,
    title: AppStrings.myChildren,
    subtitle: AppStrings.greeting(widget.profile.name),
  );

  Widget _childrenList(BuildContext context, ChildPage data) => ListView(
    physics: const AlwaysScrollableScrollPhysics(),
    padding: const EdgeInsetsDirectional.fromSTEB(20, 22, 20, 24),
    children: [
      _childrenHeading(context),
      const SizedBox(height: 20),
      if (data.children.isEmpty)
        AppSectionCard(
          title: AppStrings.noChildrenTitle,
          icon: Icons.people_outline,
          child: Text(AppStrings.noChildren),
        )
      else
        for (final child in data.children) ...[
          _ChildCard(child: child, onTap: () => _open(child)),
          const SizedBox(height: 12),
        ],
      if (data.lastPage > 1) ...[
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              onPressed: data.page > 1 ? () => _load(data.page - 1) : null,
              icon: const Icon(Icons.chevron_left),
              label: Text(AppStrings.previous),
            ),
            const Spacer(),
            Text(
              '${_localizedNumber(context, data.page)} / ${_localizedNumber(context, data.lastPage)}',
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: data.page < data.lastPage
                  ? () => _load(data.page + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
              label: Text(AppStrings.next),
              iconAlignment: IconAlignment.end,
            ),
          ],
        ),
      ],
    ],
  );
}

class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.child, required this.onTap});
  final LinkedChild child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final placement = child.placement;
    final classSection = [
      placement['class'],
      placement['section'],
    ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 12, 16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppPalette.surfaceTint,
                child: Text(
                  child.name.trim().isEmpty
                      ? '•'
                      : child.name.trim().characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: AppPalette.emeraldDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      softWrap: true,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      AppStrings.studentNumber(child.number),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppPalette.secondaryText,
                      ),
                    ),
                    if (classSection.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        classSection,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    if (placement['academic_year'] case final year?)
                      Text(
                        AppStrings.academicYearValue(year),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppPalette.secondaryText,
                        ),
                      ),
                    if (placement['branch'] case final branch?)
                      Text(
                        AppStrings.branchValue(branch),
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
    );
  }
}

class ChildDetailsScreen extends StatefulWidget {
  const ChildDetailsScreen({
    super.key,
    required this.child,
    required this.session,
  });
  final LinkedChild child;
  final SessionController session;

  @override
  State<ChildDetailsScreen> createState() => _ChildDetailsScreenState();
}

class _ChildDetailsScreenState extends State<ChildDetailsScreen> {
  AsyncSnapshot<ChildDetails>? _details;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _details = const AsyncSnapshot.waiting());
    try {
      final details = await widget.session.fetchChild(widget.child.id);
      if (!mounted || generation != _generation) return;
      setState(
        () => _details = AsyncSnapshot.withData(ConnectionState.done, details),
      );
    } catch (error, stack) {
      if (!mounted || generation != _generation) return;
      setState(
        () => _details = AsyncSnapshot.withError(
          ConnectionState.done,
          error,
          stack,
        ),
      );
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppStrings.childDetailsTitle)),
    body: AppPageFrame(
      child:
          _details == null || _details!.connectionState != ConnectionState.done
          ? const Center(child: CircularProgressIndicator())
          : _details!.hasError
          ? _FeatureError(
              message:
                  _details!.error is ApiException &&
                      ((_details!.error as ApiException).failure ==
                              ApiFailure.forbidden ||
                          (_details!.error as ApiException).statusCode == 404)
                  ? AppStrings.childAccessRevoked
                  : AppStrings.error(_details!.error),
              onRetry: _load,
            )
          : _detailsContent(context, _details!.requireData),
    ),
  );

  Widget _detailsContent(BuildContext context, ChildDetails details) {
    final placement = details.placement;
    return ListView(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: AppPalette.surfaceTint,
                  child: Icon(
                    Icons.person_outline,
                    color: AppPalette.emerald,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        details.child.name,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        softWrap: true,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppStrings.studentNumber(details.child.number),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppPalette.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.section),
        AppSectionCard(
          title: AppStrings.academicInformation,
          icon: Icons.menu_book_outlined,
          child: placement.isEmpty
              ? Text(AppStrings.noPlacement)
              : Column(
                  children: [
                    for (final key in const [
                      'class',
                      'section',
                      'program',
                      'level',
                      'academic_year',
                      'branch',
                      'status',
                      'enrolled_at',
                    ])
                      if (placement[key] case final value?)
                        AppInfoRow(
                          label: AppStrings.placementLabels[key] ?? key,
                          value: key == 'status'
                              ? AppStrings.enrollmentStatus(value)
                              : key == 'enrolled_at'
                              ? _formatTimestamp(context, value)
                              : value,
                          icon: _academicIcon(key),
                        ),
                  ],
                ),
        ),
        const SizedBox(height: AppSpacing.section),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (context) => AttendanceScreen(
                initialDetails: details,
                session: widget.session,
              ),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined),
          label: Text(AppStrings.viewAttendance),
        ),
      ],
    );
  }

  String _formatTimestamp(BuildContext context, String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return value;
    final local = parsed.isUtc ? parsed.toLocal() : parsed;
    return MaterialLocalizations.of(context).formatMediumDate(local);
  }

  IconData _academicIcon(String key) => switch (key) {
    'class' => Icons.class_outlined,
    'section' => Icons.groups_outlined,
    'branch' => Icons.location_city_outlined,
    'status' => Icons.verified_outlined,
    'enrolled_at' => Icons.event_outlined,
    _ => Icons.school_outlined,
  };
}

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({
    super.key,
    required this.initialDetails,
    required this.session,
  });
  final ChildDetails initialDetails;
  final SessionController session;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  late ChildDetails _details = widget.initialDetails;
  AsyncSnapshot<AttendanceSummary>? _filteredSummary;
  DateTime? _from;
  DateTime? _to;
  int _summaryGeneration = 0;
  int _historyGeneration = 0;
  bool _loadingHistory = false;

  Future<void> _choosePeriod() async {
    final today = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year, today.month, today.day),
      initialDateRange: DateTimeRange(
        start: _from ?? DateTime(today.year, 1, 1),
        end: _to ?? DateTime(today.year, today.month, today.day),
      ),
      helpText: AppStrings.chooseSummaryPeriod,
    );
    if (range == null || !mounted) return;
    setState(() {
      _from = range.start;
      _to = range.end;
      _filteredSummary = const AsyncSnapshot.waiting();
    });
    await _loadSummary();
  }

  Future<void> _loadSummary() async {
    final from = _from;
    final to = _to;
    if (from == null || to == null) return;
    final generation = ++_summaryGeneration;
    try {
      final result = await widget.session.fetchAttendanceSummary(
        _details.child.id,
        from: from,
        to: to,
      );
      if (!mounted || generation != _summaryGeneration) return;
      setState(
        () => _filteredSummary = AsyncSnapshot.withData(
          ConnectionState.done,
          result,
        ),
      );
    } catch (error, stack) {
      if (!mounted || generation != _summaryGeneration) return;
      setState(
        () => _filteredSummary = AsyncSnapshot.withError(
          ConnectionState.done,
          error,
          stack,
        ),
      );
    }
  }

  Future<void> _loadHistoryPage(int page) async {
    final generation = ++_historyGeneration;
    setState(() {
      _loadingHistory = true;
      _historyError = null;
    });
    try {
      final result = await widget.session.fetchChild(
        _details.child.id,
        page: page,
      );
      if (!mounted || generation != _historyGeneration) return;
      setState(() {
        _details = result;
        _loadingHistory = false;
      });
    } catch (error, stack) {
      if (!mounted || generation != _historyGeneration) return;
      setState(() {
        _loadingHistory = false;
        _historyError = AsyncSnapshot.withError(
          ConnectionState.done,
          error,
          stack,
        );
      });
    }
  }

  AsyncSnapshot<ChildDetails>? _historyError;

  @override
  void dispose() {
    _summaryGeneration++;
    _historyGeneration++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(AppStrings.attendanceHeading)),
    body: AppPageFrame(
      child: ListView(
        children: [
          AppPageHeading(
            title: _details.child.name,
            subtitle: AppStrings.studentNumber(_details.child.number),
          ),
          const SizedBox(height: AppSpacing.section),
          AppSectionCard(
            title: AppStrings.attendanceSummary,
            icon: Icons.donut_small_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.summaryPeriod,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _from == null || _to == null
                                ? AppStrings.allAvailableDates
                                : '${_formatDate(context, _from!)} – ${_formatDate(context, _to!)}',
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _choosePeriod,
                      tooltip: AppStrings.editSummaryPeriod,
                      icon: const Icon(Icons.edit_calendar_outlined),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_filteredSummary?.connectionState ==
                    ConnectionState.waiting)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_filteredSummary?.hasError == true)
                  _SummaryFailure(onRetry: _loadSummary)
                else
                  _SummaryGrid(
                    summary: _filteredSummary?.data ?? _details.summary,
                  ),
                if (!_details.summary.unrecordedDaysAreAbsent) ...[
                  const SizedBox(height: 10),
                  Text(
                    AppStrings.unrecordedNotAbsent,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.section),
          AppPageHeading(title: AppStrings.attendanceHistoryAllDates),
          const SizedBox(height: 12),
          if (_historyError?.hasError == true)
            _FeatureError(
              message: AppStrings.error(_historyError!.error),
              onRetry: () => _loadHistoryPage(_details.page),
            )
          else if (_loadingHistory)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_details.attendance.isEmpty)
            AppSectionCard(
              title: AppStrings.noAttendanceTitle,
              icon: Icons.event_busy_outlined,
              child: Text(AppStrings.noAttendance),
            )
          else
            for (final record in _details.attendance) ...[
              _AttendanceRow(record: record),
              const SizedBox(height: 9),
            ],
          if (_details.lastPage > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _details.page > 1
                      ? () => _loadHistoryPage(_details.page - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                  label: Text(AppStrings.previous),
                ),
                const Spacer(),
                Text(
                  '${_localizedNumber(context, _details.page)} / ${_localizedNumber(context, _details.lastPage)}',
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _details.page < _details.lastPage
                      ? () => _loadHistoryPage(_details.page + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                  label: Text(AppStrings.next),
                  iconAlignment: IconAlignment.end,
                ),
              ],
            ),
          ],
        ],
      ),
    ),
  );

  String _formatDate(BuildContext context, DateTime value) =>
      MaterialLocalizations.of(context).formatMediumDate(value);
}

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = (constraints.maxWidth - 10) / 2;
      return Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          _SummaryCount(
            label: AppStrings.present,
            count: summary.present,
            icon: Icons.check_circle_outline,
            color: AppPalette.success,
            width: width,
          ),
          _SummaryCount(
            label: AppStrings.absent,
            count: summary.absent,
            icon: Icons.cancel_outlined,
            color: AppPalette.danger,
            width: width,
          ),
          _SummaryCount(
            label: AppStrings.late,
            count: summary.late,
            icon: Icons.schedule_outlined,
            color: AppPalette.warning,
            width: width,
          ),
          _SummaryCount(
            label: AppStrings.excused,
            count: summary.excused,
            icon: Icons.event_available_outlined,
            color: AppPalette.info,
            width: width,
          ),
        ],
      );
    },
  );
}

class _SummaryCount extends StatelessWidget {
  const _SummaryCount({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.width,
  });
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final double width;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      color: color.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.control),
        side: BorderSide(color: color.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Flexible(child: Text(label, softWrap: true)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _localizedNumber(context, count),
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.record});
  final AttendanceRecord record;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (record.status.toLowerCase()) {
      'present' => (Icons.check_circle_outline, AppPalette.success),
      'absent' => (Icons.cancel_outlined, AppPalette.danger),
      'late' => (Icons.schedule_outlined, AppPalette.warning),
      'excused' => (Icons.event_available_outlined, AppPalette.info),
      _ => (Icons.info_outline, AppPalette.secondaryText),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                MaterialLocalizations.of(context).formatMediumDate(record.date),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            AppStatusBadge(
              label: AppStrings.attendanceStatus(record.status),
              icon: icon,
              color: color,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryFailure extends StatelessWidget {
  const _SummaryFailure({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(AppStrings.summaryUnavailable),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        label: Text(AppStrings.retry),
      ),
    ],
  );
}

class _FeatureError extends StatelessWidget {
  const _FeatureError({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => AppSectionCard(
    title: AppStrings.errorHeading,
    icon: Icons.cloud_off_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(message),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh),
          label: Text(AppStrings.retry),
        ),
      ],
    ),
  );
}

String _localizedNumber(BuildContext context, num value) =>
    NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    ).format(value);
