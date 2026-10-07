import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../services/translation_service.dart';
import '../services/csv_data_service.dart';
import '../services/excel_data_service.dart';
import '../theme/colors.dart';
import '../theme/app_theme.dart';
import '../utils/time_utils.dart';
import '../models/meditation_session.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/session_card.dart';
import '../widgets/edit_session_dialog.dart';
import '../widgets/practice_stats_table.dart';
import '../widgets/quality_rating_label.dart';
import '../utils/responsive.dart';
import '../utils/sitting_quality.dart';
import '../utils/session_calendar.dart';

enum _StatsReportView { calendar, barChart }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  late DateTime _sessionStartDate;
  late DateTime _sessionEndDate;

  DateTime? _oldestDate;
  late DateTime _weeklyCalendarStart;
  late DateTime _monthlyCalendarStart;
  _StatsReportView _weeklyReportView = _StatsReportView.calendar;
  _StatsReportView _monthlyReportView = _StatsReportView.calendar;
  bool _showCalendarQuality = true;

  // Make futures nullable to avoid LateInitializationError during first build.
  Future<List<dynamic>>? _weeklyDataFuture;
  Future<List<dynamic>>? _monthlyDataFuture;
  Future<List<dynamic>>? _yearlyDataFuture;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _sessionEndDate = TimeUtils.startOfDay(now);
    _sessionStartDate = TimeUtils.addDays(_sessionEndDate, -6);
    _weeklyCalendarStart = _startOfWeek(now);
    _monthlyCalendarStart = DateTime(now.year, now.month);
    _tabController = TabController(length: 5, vsync: this);

    // Safely load the data after the initial widget build frame completes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
  }

  void _loadData() {
    final provider = context.read<SessionProvider>();
    final loadFuture = provider.loadSessions().then(
      (_) => _refreshOldestDate(),
    );

    setState(() {
      _weeklyDataFuture = loadFuture.then((_) => provider.getWeeklyData());
      _monthlyDataFuture = loadFuture.then((_) => provider.getMonthlyData());
      _yearlyDataFuture = loadFuture.then((_) => provider.getYearlyData());
    });
  }

  void _refreshOldestDate() {
    if (!mounted) return;
    DateTime? oldest;
    // The provider already holds the complete active-profile list. Read its
    // published data so a late query cannot restore another profile's bounds.
    for (final session in context.read<SessionProvider>().sessions) {
      if (oldest == null || session.startTime.isBefore(oldest)) {
        oldest = session.startTime;
      }
    }
    setState(() => _oldestDate = oldest);
  }

  void _refreshReportFutures(SessionProvider provider) {
    if (!mounted) return;
    setState(() {
      _weeklyDataFuture = provider.getWeeklyData();
      _monthlyDataFuture = provider.getMonthlyData();
      _yearlyDataFuture = provider.getYearlyData();
    });
  }

  /// Pull-to-refresh handler: reloads sessions from the DB, rebuilds the
  /// weekly/monthly/yearly chart futures, and re-checks the oldest
  /// session date (which bounds the calendar/report date pickers).
  Future<void> _refreshSessionsAndReports(SessionProvider provider) async {
    await provider.loadSessions();
    _refreshReportFutures(provider);
    _refreshOldestDate();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Generates short durations to fit clean labels on small screens.
  String _formatShortDuration(int seconds) {
    if (seconds <= 0) return '';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final remainingSeconds = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${remainingSeconds}s';
    }
  }

  String _formatPracticeDuration(int seconds) {
    if (seconds <= 0) return '0:00';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}';
  }

  double? _averageQuality(Iterable<MeditationSession> sessions) {
    return SittingQuality.average(sessions.map((session) => session.quality));
  }

  Iterable<MeditationSession> _sessionsInRange(
    Iterable<MeditationSession> sessions,
    DateTime start,
    DateTime end,
  ) => sessions.where(
    (session) =>
        !session.startTime.isBefore(start) && session.startTime.isBefore(end),
  );

  @override
  Widget build(BuildContext context) {
    final t = TranslationService.of(context);
    final sessionProvider = context.watch<SessionProvider>();
    final settingsProvider = context.watch<SettingsProvider>();

    final isDark =
        settingsProvider.themeMode == 'dark' ||
        (settingsProvider.themeMode == 'deviceTheme' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    final theme = isDark ? AppTheme.darkTheme : AppTheme.lightTheme;

    final reports = _reports(t);
    final canSplit = WindowSize.of(context).canSplit;

    return Theme(
      data: theme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.translate('stats.title')),
          // Delete-all button is inside the Sessions tab
          //
          // The tab strip goes away once the reports move into a sidebar. Five
          // scrolling tabs across an iPad spend the width on empty label
          // padding, and the ones off the end stay hidden behind a scroll.
          bottom: canSplit
              ? null
              : TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 18),
                  tabs: [for (final report in reports) Tab(text: report.label)],
                ),
        ),
        body: canSplit
            ? _buildSplitReports(context, sessionProvider, reports)
            : TabBarView(
                controller: _tabController,
                children: [
                  for (var index = 0; index < reports.length; index++)
                    _buildReport(context, sessionProvider, index),
                ],
              ),
      ),
    );
  }

  /// The five reports, in tab order. Shared by the tab strip and the sidebar so
  /// the two cannot drift apart.
  List<({IconData icon, String label})> _reports(TranslationService t) => [
    (icon: Icons.insights_outlined, label: t.translate('stats.overview')),
    (icon: Icons.list_alt_outlined, label: t.translate('stats.sessions')),
    (
      icon: Icons.calendar_view_week_outlined,
      label: t.translate('stats.weekly'),
    ),
    (icon: Icons.calendar_month_outlined, label: t.translate('stats.monthly')),
    (icon: Icons.calendar_today_outlined, label: t.translate('stats.yearly')),
  ];

  Widget _buildReport(
    BuildContext context,
    SessionProvider provider,
    int index,
  ) => switch (index) {
    0 => _buildOverviewTab(context, provider),
    1 => _buildSessionsTab(context, provider),
    2 => _buildWeeklyTab(context, provider),
    3 => _buildMonthlyTab(context, provider),
    _ => _buildYearlyTab(context, provider),
  };

  /// iPads: the report list beside the report.
  ///
  /// Selection still lives in [_tabController], so rotating between this and the
  /// tab strip keeps whichever report was open.
  Widget _buildSplitReports(
    BuildContext context,
    SessionProvider provider,
    List<({IconData icon, String label})> reports,
  ) {
    return ListenableBuilder(
      listenable: _tabController,
      builder: (context, _) {
        final selected = _tabController.index;
        return TwoPaneLayout(
          startFlex: 2,
          endFlex: 5,
          startMaxWidth: 280,
          start: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final report = reports[index];
              return ListTile(
                leading: Icon(report.icon),
                title: Text(report.label),
                selected: index == selected,
                selectedTileColor: AppColors.primary.withValues(alpha: 0.08),
                onTap: () => _tabController.index = index,
              );
            },
          ),
          // Keyed so switching reports rebuilds the pane from the top rather
          // than carrying the previous report's scroll offset into it.
          end: KeyedSubtree(
            key: ValueKey<int>(selected),
            child: _buildReport(context, provider, selected),
          ),
        );
      },
    );
  }

  Widget _buildOverviewTab(BuildContext context, SessionProvider provider) {
    final t = TranslationService.of(context);
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildBigCard(
                  context,
                  label: t.translate('stats.totalSessions'),
                  value: '${provider.totalSessions}',
                  icon: Icons.self_improvement,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBigCard(
                  context,
                  label: t.translate('stats.currentStreak'),
                  value:
                      '${provider.currentStreak} ${provider.currentStreak == 1 ? t.translate('stats.day') : t.translate('stats.days')}',
                  icon: Icons.local_fire_department,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildBigCard(
                  context,
                  label: t.translate('stats.totalTime'),
                  value: TimeUtils.formatDurationReadable(
                    provider.totalDurationSeconds,
                  ),
                  icon: Icons.access_time,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildBigCard(
                  context,
                  label: t.translate('stats.bestStreak'),
                  value:
                      '${provider.longestStreak} ${provider.longestStreak == 1 ? t.translate('stats.day') : t.translate('stats.days')}',
                  icon: Icons.emoji_events,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.show_chart_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t.translate('stats.averageSession'),
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          TimeUtils.formatDurationReadable(
                            provider.averageDurationSeconds.round(),
                          ),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            t.translate('stats.thisPeriod'),
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          _buildPeriodRow(
            context,
            t.translate('stats.today'),
            provider.todayDurationSeconds,
          ),
          _buildPeriodRow(
            context,
            t.translate('stats.thisWeek'),
            provider.thisWeekDurationSeconds,
          ),
          _buildPeriodRow(
            context,
            t.translate('stats.last14Days'),
            provider.last14DaysDurationSeconds,
          ),
          _buildPeriodRow(
            context,
            t.translate('stats.thisMonth'),
            provider.thisMonthDurationSeconds,
          ),
          _buildPeriodRow(
            context,
            t.translate('stats.thisYear'),
            provider.thisYearDurationSeconds,
          ),
        ],
      ),
    );
  }

  Widget _buildBigCard(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodRow(BuildContext context, String label, int seconds) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          const SizedBox(width: 8),
          Text(
            TimeUtils.formatDurationReadable(seconds),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab(BuildContext context, SessionProvider provider) {
    final t = TranslationService.of(context);
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Filter sessions by date range
    final filteredSessions = provider.sessions
        .where((s) {
          final d = DateTime(
            s.startTime.year,
            s.startTime.month,
            s.startTime.day,
          );
          return d.isAtSameMomentAs(_sessionStartDate) ||
              d.isAfter(_sessionStartDate);
        })
        .where((s) {
          final d = DateTime(
            s.startTime.year,
            s.startTime.month,
            s.startTime.day,
          );
          return d.isAtSameMomentAs(_sessionEndDate) ||
              d.isBefore(_sessionEndDate);
        })
        .toList();

    if (filteredSessions.isEmpty) {
      return Column(
        children: [
          // Keep the range controls reachable even when that range is empty.
          _buildSessionsActionBar(context, provider, filteredSessions),
          const Divider(height: 1),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.self_improvement,
                      size: 80,
                      color: AppColors.primaryLight.withAlpha(100),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t.translate('history.noSessions'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w300),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.translate('history.noSessionsDesc'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    final groupedSessions = <String, List<MeditationSession>>{};
    for (final session in filteredSessions) {
      final dateKey =
          '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}-${session.startTime.day.toString().padLeft(2, '0')}';
      groupedSessions.putIfAbsent(dateKey, () => []);
      groupedSessions[dateKey]!.add(session);
    }

    final sortedDates = groupedSessions.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      children: [
        // ─── Action bar ──────────────────────────────────────────
        _buildSessionsActionBar(context, provider, filteredSessions),
        const Divider(height: 1),
        // ─── Session list ────────────────────────────────────────
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            itemCount: sortedDates.length,
            itemBuilder: (context, index) {
              final dateKey = sortedDates[index];
              final sessions = groupedSessions[dateKey]!;
              final date = DateTime.parse(dateKey);

              final totalSeconds = sessions.fold(
                0,
                (sum, s) => sum + s.durationSeconds,
              );
              final dailyQuality = _averageQuality(sessions);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                TimeUtils.formatDate(date),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${sessions.length} ${sessions.length == 1 ? t.translate('history.session') : t.translate('history.sessions')}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${t.translate('stats.dailyTotal')}: ${TimeUtils.formatDurationReadable(totalSeconds)}',
                                textAlign: TextAlign.end,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondaryLight,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (dailyQuality != null)
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${t.translate('stats.qualityAverage')}: ',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondaryLight,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      QualityRatingLabel(
                                        rating: dailyQuality,
                                        iconSize: 8,
                                        gap: 1,
                                        starSpacing: 0.5,
                                        compact: true,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textSecondaryLight,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...sessions.map(
                    (session) => SessionCard(
                      id: session.id,
                      startTime: session.startTime,
                      endTime: session.endTime,
                      durationSeconds: session.durationSeconds,
                      completed: session.completed,
                      quality: session.quality,
                      notes: session.notes,
                      onDelete: () => _confirmDelete(context, session.id),
                      onEdit: () => _onEditSession(context, session),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSessionsActionBar(
    BuildContext context,
    SessionProvider provider,
    List<MeditationSession> filteredSessions,
  ) {
    final t = TranslationService.of(context);
    final theme = Theme.of(context);

    final filteredTotalSeconds = filteredSessions.fold(
      0,
      (sum, s) => sum + s.durationSeconds,
    );
    final sessionCount = filteredSessions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Row 1: From / To date pickers ──
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 8,
            children: [
              _buildDateChip(
                context,
                label: t.translate('stats.from'),
                date: _sessionStartDate,
                onTap: () => _pickDate(isStart: true),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              _buildDateChip(
                context,
                label: t.translate('stats.to'),
                date: _sessionEndDate,
                onTap: () => _pickDate(isStart: false),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // ── Row 2: Summary + action buttons ──
          Row(
            children: [
              Expanded(
                child: Text(
                  '$sessionCount ${sessionCount == 1 ? t.translate('history.session') : t.translate('history.sessions')} — ${TimeUtils.formatDurationReadable(filteredTotalSeconds)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // ── Copy button ──
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 20),
                tooltip: t.translate('stats.copy'),
                onPressed: () => _copySessionsToClipboard(
                  context,
                  filteredSessions,
                  _sessionStartDate,
                  _sessionEndDate,
                ),
                visualDensity: VisualDensity.compact,
              ),
              // ── Export button ──
              IconButton(
                icon: const Icon(Icons.file_upload_outlined, size: 20),
                tooltip: t.translate('stats.exportFiltered'),
                onPressed: () => _exportFilteredSessions(
                  context,
                  filteredSessions,
                  _sessionStartDate,
                  _sessionEndDate,
                ),
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                icon: const Icon(Icons.table_view_outlined, size: 20),
                tooltip: t.translate('stats.exportExcel'),
                onPressed: () => _exportFilteredSessionsToExcel(
                  context,
                  filteredSessions,
                  _sessionStartDate,
                  _sessionEndDate,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip(
    BuildContext context, {
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today,
              size: 14,
              color: AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              '$label ${_formatShortDate(date)}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  String _formatShortDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _sessionStartDate : _sessionEndDate;
    final oldest = _oldestDate ?? DateTime(2000);
    final tomorrow = TimeUtils.addDays(DateTime.now(), 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // The default From date precedes the first session on a fresh install.
      // DatePicker asserts unless its current selection is inside the bounds.
      firstDate: initial.isBefore(oldest) ? initial : oldest,
      lastDate: initial.isAfter(tomorrow) ? initial : tomorrow,
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _sessionStartDate = DateTime(picked.year, picked.month, picked.day);
          // Ensure start is not after end
          if (_sessionStartDate.isAfter(_sessionEndDate)) {
            _sessionEndDate = _sessionStartDate;
          }
        } else {
          _sessionEndDate = DateTime(picked.year, picked.month, picked.day);
          // Ensure end is not before start
          if (_sessionEndDate.isBefore(_sessionStartDate)) {
            _sessionStartDate = _sessionEndDate;
          }
        }
      });
    }
  }

  void _copySessionsToClipboard(
    BuildContext context,
    List<MeditationSession> sessions,
    DateTime startDate,
    DateTime endDate,
  ) {
    final t = TranslationService.of(context);

    final buffer = StringBuffer();
    final rangeLabel =
        '${_formatShortDate(startDate)} — ${_formatShortDate(endDate)}';
    buffer.writeln('${t.translate('stats.title')} — $rangeLabel');
    buffer.writeln('─' * 32);
    buffer.writeln();

    // Group by date
    final grouped = <String, List<MeditationSession>>{};
    for (final session in sessions) {
      final key =
          '${session.startTime.year}-${session.startTime.month.toString().padLeft(2, '0')}-${session.startTime.day.toString().padLeft(2, '0')}';
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(session);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    int totalSeconds = 0;
    for (final dateKey in sortedDates) {
      final daySessions = grouped[dateKey]!;
      final dayTotal = daySessions.fold(0, (sum, s) => sum + s.durationSeconds);
      totalSeconds += dayTotal;

      buffer.writeln(
        '$dateKey — ${TimeUtils.formatDurationReadable(dayTotal)} (${daySessions.length} ${daySessions.length == 1 ? t.translate('history.session') : t.translate('history.sessions')})',
      );
      for (final session in daySessions) {
        final status = session.completed ? '✓' : '✗';
        final quality = SittingQuality.normalize(session.quality);
        final qualityText = quality == null
            ? ''
            : ' · ${t.translate('quality.label')}: ${SittingQuality.display(quality)}';
        final notesText = session.notes == null ? '' : ' - ${session.notes}';
        buffer.writeln(
          '  $status ${TimeUtils.formatDurationReadable(session.durationSeconds)}$qualityText$notesText',
        );
      }
    }

    buffer.writeln();
    buffer.writeln('─' * 32);
    final count = sessions.length;
    buffer.writeln(
      '${t.translate('stats.totalTime')}: ${TimeUtils.formatDurationReadable(totalSeconds)} — $count ${count == 1 ? t.translate('history.session') : t.translate('history.sessions')}',
    );

    Clipboard.setData(ClipboardData(text: buffer.toString()));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(t.translate('stats.copied')),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _exportFilteredSessions(
    BuildContext context,
    List<MeditationSession> sessions,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (sessions.isEmpty) return;

    try {
      final filename =
          'meditation_timer_${_formatShortDate(startDate)}_${_formatShortDate(endDate)}.csv';
      await CsvDataService.exportSessionsToCsv(sessions, filename: filename);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.of(context).translate('stats.exported'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.of(context).translate('stats.exportFailed')}: $e',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Exports just the sessions currently shown for [startDate]..[endDate]
  /// (the filtered/report range), not the whole history — see
  /// ExcelDataService for the actual .xlsx encoding.
  Future<void> _exportFilteredSessionsToExcel(
    BuildContext context,
    List<MeditationSession> sessions,
    DateTime startDate,
    DateTime endDate,
  ) async {
    if (sessions.isEmpty) return;

    try {
      final filename =
          'meditation_timer_${_formatShortDate(startDate)}_${_formatShortDate(endDate)}.xlsx';
      await ExcelDataService.exportSessionsToExcel(
        sessions,
        filename: filename,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              TranslationService.of(context).translate('stats.exportedExcel'),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${TranslationService.of(context).translate('stats.exportFailed')}: $e',
            ),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  /// Opens the edit dialog for one session and, if saved, refreshes both
  /// the session list and every report future so charts stay in sync
  /// with a quality/notes/time edit made from the stats screen.
  Future<void> _onEditSession(
    BuildContext context,
    MeditationSession session,
  ) async {
    final updated = await showEditSessionDialog(context, session);
    if (updated != null && context.mounted) {
      final provider = context.read<SessionProvider>();
      await provider.updateSession(updated);
      if (!mounted || !context.mounted) return;
      _refreshReportFutures(provider);
      _refreshOldestDate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            TranslationService.of(context).translate('editSession.updated'),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _confirmDelete(BuildContext context, String id) {
    final t = TranslationService.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.translate('history.deleteSession')),
        content: Text(t.translate('history.deleteConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t.translate('history.cancel')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final provider = context.read<SessionProvider>();
              await provider.deleteSession(id);
              _refreshReportFutures(provider);
              _refreshOldestDate();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(t.translate('history.delete')),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyTab(BuildContext context, SessionProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentWeek = _startOfWeek(DateTime.now());
    final endDate = TimeUtils.addDays(_weeklyCalendarStart, 6);
    return Column(
      children: [
        _buildReportViewSwitcher(
          context,
          selected: _weeklyReportView,
          onChanged: (view) => setState(() => _weeklyReportView = view),
        ),
        Expanded(
          child: _weeklyReportView == _StatsReportView.calendar
              ? _buildTimeSlotCalendar(
                  context,
                  provider: provider,
                  startDate: _weeklyCalendarStart,
                  dayCount: 7,
                  periodLabel:
                      '${_formatNumericDate(_weeklyCalendarStart)} – ${_formatNumericDate(endDate)}',
                  includeMonthInRows: true,
                  qualityToggleKey: const ValueKey(
                    'weekly-calendar-quality-toggle',
                  ),
                  onPrevious: () => setState(() {
                    _weeklyCalendarStart = _weeklyCalendarStart.subtract(
                      const Duration(days: 7),
                    );
                  }),
                  onNext: _weeklyCalendarStart.isBefore(currentWeek)
                      ? () => setState(() {
                          _weeklyCalendarStart = _weeklyCalendarStart.add(
                            const Duration(days: 7),
                          );
                        })
                      : null,
                  onCurrent: () =>
                      setState(() => _weeklyCalendarStart = currentWeek),
                )
              : _buildHistoricalBarChart(
                  context,
                  future: _weeklyDataFuture,
                  titleKey: 'stats.weeklyTitle',
                  barColor: AppColors.primary,
                ),
        ),
      ],
    );
  }

  Widget _buildMonthlyTab(BuildContext context, SessionProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final currentMonth = DateTime(DateTime.now().year, DateTime.now().month);
    final dayCount = DateTime(
      _monthlyCalendarStart.year,
      _monthlyCalendarStart.month + 1,
      0,
    ).day;
    return Column(
      children: [
        _buildReportViewSwitcher(
          context,
          selected: _monthlyReportView,
          onChanged: (view) => setState(() => _monthlyReportView = view),
        ),
        Expanded(
          child: _monthlyReportView == _StatsReportView.calendar
              ? _buildTimeSlotCalendar(
                  context,
                  provider: provider,
                  startDate: _monthlyCalendarStart,
                  dayCount: dayCount,
                  periodLabel:
                      '${_monthlyCalendarStart.year}-${_monthlyCalendarStart.month.toString().padLeft(2, '0')}',
                  includeMonthInRows: false,
                  qualityToggleKey: const ValueKey(
                    'monthly-calendar-quality-toggle',
                  ),
                  onPrevious: () => setState(() {
                    _monthlyCalendarStart = DateTime(
                      _monthlyCalendarStart.year,
                      _monthlyCalendarStart.month - 1,
                    );
                  }),
                  onNext: _monthlyCalendarStart.isBefore(currentMonth)
                      ? () => setState(() {
                          _monthlyCalendarStart = DateTime(
                            _monthlyCalendarStart.year,
                            _monthlyCalendarStart.month + 1,
                          );
                        })
                      : null,
                  onCurrent: () =>
                      setState(() => _monthlyCalendarStart = currentMonth),
                )
              : _buildHistoricalBarChart(
                  context,
                  future: _monthlyDataFuture,
                  titleKey: 'stats.monthlyTitle',
                  barColor: AppColors.primaryLight,
                  qualityRatingBuilder: (point) {
                    final month = point as MonthlyDataPoint;
                    return _averageQuality(
                      _sessionsInRange(
                        provider.sessions,
                        month.startDate,
                        DateTime(
                          month.startDate.year,
                          month.startDate.month + 1,
                        ),
                      ),
                    );
                  },
                  onBarTap: (point) => _showMonthDetails(
                    context,
                    provider,
                    point as MonthlyDataPoint,
                  ),
                ),
        ),
      ],
    );
  }

  /// The calendar-vs-bar-chart segmented toggle shown above each report
  /// tab; [selected]/[onChanged] let each tab (daily/weekly/monthly/...)
  /// keep its own independent view choice.
  Widget _buildReportViewSwitcher(
    BuildContext context, {
    required _StatsReportView selected,
    required ValueChanged<_StatsReportView> onChanged,
  }) {
    final t = TranslationService.of(context);

    Widget button({
      required _StatsReportView view,
      required IconData icon,
      required String label,
    }) {
      final isSelected = selected == view;
      final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
      final style = ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(0, 46)),
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 10),
        ),
      );

      if (isSelected) {
        return FilledButton.icon(
          onPressed: () => onChanged(view),
          icon: Icon(icon, size: 18),
          label: child,
          style: style,
        );
      }
      return OutlinedButton.icon(
        onPressed: () => onChanged(view),
        icon: Icon(icon, size: 18),
        label: child,
        style: style,
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: button(
              view: _StatsReportView.calendar,
              icon: Icons.calendar_month_outlined,
              label: t.translate('stats.view.calendar'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: button(
              view: _StatsReportView.barChart,
              icon: Icons.bar_chart_rounded,
              label: t.translate('stats.view.barChart'),
            ),
          ),
        ],
      ),
    );
  }

  /// Generic bar chart shared by every report period (day/week/month/
  /// year). [qualityRatingBuilder], when supplied, overlays a quality
  /// star rating per bar; [onBarTap] drives the year/month drill-down
  /// sheets ([_showYearDetails], [_showMonthDetails]).
  Widget _buildHistoricalBarChart(
    BuildContext context, {
    required Future<List<dynamic>>? future,
    required String titleKey,
    required Color barColor,
    ValueChanged<dynamic>? onBarTap,
    double? Function(dynamic point)? qualityRatingBuilder,
  }) {
    if (future == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildChartError(context);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;

        // Measured from the space this chart is actually given, not from the
        // window. On an iPad the report sits in a pane narrower than the
        // screen, and sizing the chart to the window would push it past the
        // pane's right edge.
        return LayoutBuilder(
          builder: (context, constraints) {
            final minimumChartWidth = constraints.maxWidth - 40;
            final chartWidth = qualityRatingBuilder == null
                ? minimumChartWidth
                : (data.length * 52.0).clamp(
                    minimumChartWidth,
                    double.infinity,
                  );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    TranslationService.of(context).translate(titleKey),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      height: 260,
                      child: _buildBarChart(
                        context,
                        data: data,
                        barColor: barColor,
                        onBarTap: onBarTap,
                        qualityRatingBuilder: qualityRatingBuilder,
                      ),
                    ),
                  ),
                  if (onBarTap != null) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: Text(
                        TranslationService.of(
                          context,
                        ).translate('stats.tapBarHint'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Drill-down sheet from a tapped year bar: shows that year's 12
  /// months, each tappable into [_showMonthDetails].
  Future<void> _showYearDetails(
    BuildContext context,
    SessionProvider provider,
    YearlyDataPoint year,
  ) {
    final future = provider.getMonthlyDataForYear(year.year);
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final t = TranslationService.of(sheetContext);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.68,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FutureBuilder<List<MonthlyDataPoint>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildChartError(context);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;
                  final total = data.fold<int>(
                    0,
                    (sum, point) => sum + point.durationSeconds,
                  );
                  final chartWidth = (data.length * 52.0).clamp(
                    MediaQuery.sizeOf(context).width - 40,
                    double.infinity,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.translate('stats.monthlyDetail')} — ${year.year}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${TimeUtils.formatDurationReadable(total)} · ${t.translate('stats.tapBarHint')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: _buildBarChart(
                              context,
                              data: data,
                              barColor: AppColors.primary,
                              qualityRatingBuilder: (point) {
                                final month = point as MonthlyDataPoint;
                                return _averageQuality(
                                  _sessionsInRange(
                                    provider.sessions,
                                    month.startDate,
                                    DateTime(
                                      month.startDate.year,
                                      month.startDate.month + 1,
                                    ),
                                  ),
                                );
                              },
                              onBarTap: (point) => _showMonthDetails(
                                sheetContext,
                                provider,
                                point as MonthlyDataPoint,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Drill-down sheet from a tapped month bar: shows that month's days
  /// via [SessionProvider.getDailyDataForMonth] (the calendar-grid
  /// variant, not the rolling-window one used by the main daily tab).
  Future<void> _showMonthDetails(
    BuildContext context,
    SessionProvider provider,
    MonthlyDataPoint month,
  ) {
    final monthEnd = DateTime(month.startDate.year, month.startDate.month + 1);
    final future = provider.getDailyDataForMonth(
      month.startDate.year,
      month.startDate.month,
    );
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final t = TranslationService.of(sheetContext);
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.72,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: FutureBuilder<List<DailyDataPoint>>(
                future: future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildChartError(context);
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data!;
                  final total = data.fold<int>(
                    0,
                    (sum, point) => sum + point.durationSeconds,
                  );
                  final monthQuality = _averageQuality(
                    _sessionsInRange(
                      provider.sessions,
                      month.startDate,
                      monthEnd,
                    ),
                  );
                  final chartWidth = (data.length * 52.0).clamp(
                    MediaQuery.sizeOf(context).width - 40,
                    double.infinity,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${t.translate('stats.dailyDetail')} — ${month.label} ${month.startDate.year}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      if (monthQuality == null)
                        Text(
                          '${t.translate('stats.monthlyTotal')}: ${TimeUtils.formatDurationReadable(total)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        )
                      else
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              '${t.translate('stats.monthlyTotal')}: ${TimeUtils.formatDurationReadable(total)} · ${t.translate('stats.qualityAverage')}: ',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                            QualityRatingLabel(
                              rating: monthQuality,
                              iconSize: 11,
                              starSpacing: 0.5,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SizedBox(
                            width: chartWidth,
                            child: _buildBarChart(
                              context,
                              data: data,
                              barColor: AppColors.primaryLight,
                              qualityRatingBuilder: (point) {
                                final day = point as DailyDataPoint;
                                final nextDay = day.date.add(
                                  const Duration(days: 1),
                                );
                                return _averageQuality(
                                  _sessionsInRange(
                                    provider.sessions,
                                    day.date,
                                    nextDay,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  /// Shorthand for this screen's call sites. Week and day boundaries are
  /// computed in [TimeUtils] alone, so they match SessionProvider's queries.
  DateTime _startOfWeek(DateTime date) => TimeUtils.startOfWeek(date);

  Widget _buildChartError(BuildContext context) => Center(
    child: Text(
      TranslationService.of(context).translate('stats.noData'),
      style: Theme.of(context).textTheme.bodyLarge,
    ),
  );

  String _formatNumericDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  /// The heatmap-style calendar view: one row per day, one cell per
  /// 6-hour slot (see SessionCalendar), shaded by practice time. Used
  /// by the calendar toggle in [_buildReportViewSwitcher] as the
  /// alternative to the bar chart.
  Widget _buildTimeSlotCalendar(
    BuildContext context, {
    required SessionProvider provider,
    required DateTime startDate,
    required int dayCount,
    required String periodLabel,
    required bool includeMonthInRows,
    required Key qualityToggleKey,
    required VoidCallback onPrevious,
    required VoidCallback? onNext,
    required VoidCallback onCurrent,
  }) {
    final t = TranslationService.of(context);
    final settings = context.watch<SettingsProvider>();
    final theme = Theme.of(context);
    final rows = SessionCalendar.build(
      startDate: startDate,
      days: dayCount,
      sessions: provider.sessions,
    );
    final totalSeconds = rows.fold<int>(
      0,
      (sum, row) => sum + row.totalSeconds,
    );
    final periodEnd = TimeUtils.addDays(startDate, dayCount);
    final periodQuality = _averageQuality(
      _sessionsInRange(provider.sessions, startDate, periodEnd),
    );
    final totalLabelKey = dayCount > 7
        ? 'stats.monthlyTotal'
        : 'stats.totalTime';
    final profileName = settings.userName.isEmpty
        ? t.translate('stats.calendar.meditator')
        : settings.userName;

    return RefreshIndicator(
      onRefresh: () => _refreshSessionsAndReports(provider),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              periodLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: t.translate('stats.calendar.previous'),
                        onPressed: onPrevious,
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      IconButton(
                        tooltip: t.translate('stats.calendar.current'),
                        onPressed: onCurrent,
                        icon: const Icon(Icons.today_outlined),
                      ),
                      IconButton(
                        tooltip: t.translate('stats.calendar.next'),
                        onPressed: onNext,
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_outline_rounded,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          t.translate('quality.label'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Switch.adaptive(
                        key: qualityToggleKey,
                        value: _showCalendarQuality,
                        onChanged: (value) =>
                            setState(() => _showCalendarQuality = value),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(18),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                t.translate(totalLabelKey),
                                style: theme.textTheme.bodySmall,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                TimeUtils.formatDurationReadable(totalSeconds),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_showCalendarQuality && periodQuality != null) ...[
                          Container(
                            width: 1,
                            height: 38,
                            color: theme.dividerColor,
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                Text(
                                  t.translate('stats.qualityAverage'),
                                  style: theme.textTheme.bodySmall,
                                ),
                                const SizedBox(height: 2),
                                QualityRatingLabel(
                                  rating: periodQuality,
                                  iconSize: 14,
                                  gap: 1,
                                  starSpacing: 0.5,
                                  compact: true,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _copyCalendarReport(context, rows),
                      icon: const Icon(Icons.copy_all_outlined, size: 18),
                      label: Text(t.translate('stats.calendar.copyReport')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(1),
              child: PracticeStatsTable(
                sessions: provider.sessions,
                showQuality: _showCalendarQuality,
                startDate: startDate,
                endDate: TimeUtils.addDays(periodEnd, -1),
                dateLabelBuilder: (date) => includeMonthInRows
                    ? TimeUtils.formatDate(date)
                    : '${date.day}',
                durationLabelBuilder: _formatPracticeDuration,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _copyCalendarReport(
    BuildContext context,
    List<SessionCalendarDay> rows,
  ) {
    Clipboard.setData(ClipboardData(text: SessionCalendar.buildReport(rows)));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(TranslationService.of(context).translate('stats.copied')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildYearlyTab(BuildContext context, SessionProvider provider) {
    final t = TranslationService.of(context);
    if (_yearlyDataFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<dynamic>>(
      future: _yearlyDataFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildChartError(context);
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;
        const itemsPerRow = 6;
        final rowCount = (data.length + itemsPerRow - 1) ~/ itemsPerRow;
        const rowHeight = 160.0;
        final chartHeight = rowCount * rowHeight;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.translate('stats.yearlyTitle'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: chartHeight,
                child: _buildYearlyChart(
                  context,
                  data: data,
                  barColor: AppColors.primary.withAlpha(180),
                  itemsPerRow: itemsPerRow,
                  onBarTap: (point) => _showYearDetails(
                    context,
                    provider,
                    point as YearlyDataPoint,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  t.translate('stats.tapBarHint'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Yearly bar chart that splits years into multiple rows (e.g., 6 per row)
  /// so all years are visible without being squished.
  Widget _buildYearlyChart(
    BuildContext context, {
    required List<dynamic> data,
    required Color barColor,
    int itemsPerRow = 6,
    ValueChanged<dynamic>? onBarTap,
  }) {
    final t = TranslationService.of(context);
    if (data.isEmpty) {
      return Center(
        child: Text(
          t.translate('stats.noData'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    // Group data into rows of itemsPerRow each.
    final rows = <List<dynamic>>[];
    for (int i = 0; i < data.length; i += itemsPerRow) {
      final end = (i + itemsPerRow < data.length)
          ? i + itemsPerRow
          : data.length;
      rows.add(data.sublist(i, end));
    }

    return Column(
      children: rows.map((rowData) {
        final maxSeconds = rowData.fold<int>(
          0,
          (max, d) => d.durationSeconds > max ? d.durationSeconds : max,
        );

        return Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Real data bars.
              ...rowData.map((point) {
                final int seconds = point.durationSeconds;
                final bool hasValue = seconds > 0;
                final height = maxSeconds > 0
                    ? (seconds / maxSeconds) * 100.0
                    : 0.0;

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: onBarTap == null ? null : () => onBarTap(point),
                      borderRadius: BorderRadius.circular(8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          SizedBox(
                            height: 14,
                            child: hasValue
                                ? FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      _formatShortDuration(seconds),
                                      style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: height.clamp(4.0, 100.0),
                            decoration: BoxDecoration(
                              color: hasValue
                                  ? barColor
                                  : Theme.of(
                                      context,
                                    ).dividerColor.withValues(alpha: 0.15),
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(6),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            height: 14,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                point.label,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              // Invisible spacers for partial last row so bar widths stay consistent.
              if (rowData.length < itemsPerRow)
                ...List.generate(
                  itemsPerRow - rowData.length,
                  (_) => const Expanded(child: SizedBox.shrink()),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // Preserve the original weekly/monthly bar chart as an alternate report view.
  Widget _buildBarChart(
    BuildContext context, {
    required List<dynamic> data,
    required Color barColor,
    ValueChanged<dynamic>? onBarTap,
    double? Function(dynamic point)? qualityRatingBuilder,
  }) {
    final t = TranslationService.of(context);
    if (data.isEmpty) {
      return Center(
        child: Text(
          t.translate('stats.noData'),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    final maxSeconds = data.fold<int>(
      0,
      (max, d) => d.durationSeconds > max ? d.durationSeconds : max,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : 194.0;
        final valueLabelHeight = qualityRatingBuilder == null ? 16.0 : 30.0;
        final maxBarHeight = (availableHeight - valueLabelHeight - 28).clamp(
          4.0,
          150.0,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((point) {
            final int seconds = point.durationSeconds;
            final bool hasValue = seconds > 0;
            final height = maxSeconds > 0
                ? (seconds / maxSeconds) * maxBarHeight
                : 0.0;
            final qualityRating = qualityRatingBuilder?.call(point);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: InkWell(
                  onTap: onBarTap == null ? null : () => onBarTap(point),
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: valueLabelHeight,
                        child: hasValue
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: qualityRating == null
                                    ? Text(
                                        _formatShortDuration(seconds),
                                        style: const TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                      )
                                    : Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            _formatShortDuration(seconds),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                          ),
                                          QualityRatingLabel(
                                            rating: qualityRating,
                                            iconSize: 7,
                                            gap: 0.5,
                                            starSpacing: 0.5,
                                            compact: true,
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                              )
                            : const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        height: height.clamp(4.0, maxBarHeight),
                        decoration: BoxDecoration(
                          color: hasValue
                              ? barColor
                              : Theme.of(
                                  context,
                                ).dividerColor.withValues(alpha: 0.15),
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 16,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            point.label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                            maxLines: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
