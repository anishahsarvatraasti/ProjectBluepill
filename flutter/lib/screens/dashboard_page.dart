import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/model_helpers.dart';
import '../services/ai_service.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';
import '../ui/expressive_loading_indicator.dart';
import '../ui/responsive.dart';
import 'checkin_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _mcp = McpContextService();
  final _ai = AiService();
  late Future<Map<String, dynamic>> _future;
  bool _refreshingAi = false;
  bool _summarizing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final userId = SupabaseService.currentUserId;
    final data = await _mcp.updateDashboardData(userId);
    return {
      ...data,
      'all_tasks': await _mcp.getAllTasks(userId),
      'progress_history': await _mcp.getRecentProgress(userId, limit: 30),
      'recent_feedback': await _mcp.getRecentFeedback(userId, limit: 20),
    };
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project BluePill'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ExpressiveLoadingIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }

          final data = snapshot.data!;
          final profile = data['profile'] as Map<String, dynamic>?;
          final tasks = data['today_tasks'] as List<Map<String, dynamic>>;
          final allTasks = data['all_tasks'] as List<Map<String, dynamic>>;
          final goals = data['goals'] as List<Map<String, dynamic>>;
          final habits = data['habits'] as List<Map<String, dynamic>>;
          final progress =
              data['progress_history'] as List<Map<String, dynamic>>;
          final feedback =
              data['recent_feedback'] as List<Map<String, dynamic>>;
          final aiCheckinStreak = data['ai_checkin_streak'] is Map
              ? Map<String, dynamic>.from(data['ai_checkin_streak'] as Map)
              : null;
          final checkinStreakDays =
              intValue(aiCheckinStreak?['current_streak']);
          final lifeScore = intValue(data['life_score']);
          final recent = progress.length > 7
              ? progress.sublist(progress.length - 7)
              : progress;
          final weeklyScore = recent.isEmpty
              ? 0
              : (recent
                          .map((item) => intValue(item['life_score']))
                          .reduce((a, b) => a + b) /
                      recent.length)
                  .round();
          final taskRate = allTasks.isEmpty
              ? 0
              : (allTasks
                          .where((task) => task['status'] == 'completed')
                          .length /
                      allTasks.length *
                      100)
                  .round();
          final habitRate = habits.isEmpty
              ? 0
              : (habits
                          .map((habit) => doubleValue(habit['completion_rate']))
                          .reduce((a, b) => a + b) /
                      habits.length)
                  .round();
          final focusAvg = recent.isEmpty
              ? 0
              : (recent
                          .map((item) => intValue(item['focus_score']))
                          .reduce((a, b) => a + b) /
                      recent.length)
                  .round();
          final best = progress.isEmpty
              ? null
              : progress.reduce((a, b) =>
                  intValue(a['life_score']) > intValue(b['life_score'])
                      ? a
                      : b);
          final blocker = _commonBlocker(progress);
          final weeklySummaries = feedback
              .where((item) => item['feedback_type'] == 'weekly_summary')
              .map((item) => item['message'].toString())
              .toList();
          final weeklySummary =
              weeklySummaries.isEmpty ? null : weeklySummaries.first;
          final missionProgress = goals.isEmpty
              ? 0
              : (goals
                          .map((goal) => doubleValue(goal['progress_percent']))
                          .reduce((a, b) => a + b) /
                      goals.length)
                  .round();
          final name = profile?['name']?.toString().trim();
          final mission = profile?['main_mission']?.toString().trim();
          final completedToday =
              tasks.where((task) => task['status'] == 'completed').length;
          final openToday = tasks.length - completedToday;

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.sizeOf(context).width < 640 ? 14 : 24,
                vertical: MediaQuery.sizeOf(context).width < 640 ? 14 : 24,
              ),
              children: [
                _DashboardHero(
                  name: name == null || name.isEmpty ? null : name,
                  mission: mission == null || mission.isEmpty
                      ? 'Connect today to the mission.'
                      : mission,
                  score: lifeScore,
                  weeklyScore: weeklyScore,
                  completedToday: completedToday,
                  openToday: openToday,
                  focusAvg: focusAvg,
                  refreshingAi: _refreshingAi,
                  onRefreshAi: () => _refreshAi(data),
                  onCheckIn: _openCheckin,
                ),
                const SizedBox(height: 22),
                const SectionTitle(
                  title: "Today's Plan",
                  subtitle: 'Focus, tasks, habits, and adaptive guidance',
                ),
                const SizedBox(height: 12),
                ResponsiveWrap(
                  minItemWidth: 280,
                  children: [
                    _TextCard(
                      title: "Today's Focus",
                      icon: Icons.center_focus_strong,
                      text: data['today_focus'].toString(),
                    ),
                    _TaskCard(tasks: tasks),
                    _ProgressCard(
                      title: 'Mission Progress',
                      value: missionProgress,
                      subtitle: '${goals.length} active goals mapped',
                    ),
                    _HabitCard(habits: habits),
                    _TextCard(
                      title: 'AI Suggestion',
                      icon: Icons.tips_and_updates_outlined,
                      text: _latestFeedback(
                        data,
                        'suggestion',
                        data['ai_suggestion'].toString(),
                      ),
                    ),
                    _TextCard(
                      title: 'Weakness Alert',
                      icon: Icons.report_problem_outlined,
                      text: _latestFeedback(
                        data,
                        'warning',
                        data['weakness_alert'].toString(),
                      ),
                    ),
                    _TextCard(
                      title: 'Motivation',
                      icon: Icons.bolt_outlined,
                      text: _latestFeedback(
                        data,
                        'motivation',
                        data['motivation'].toString(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                const SectionTitle(
                  title: 'Progress',
                  subtitle: 'Scores, completion rates, focus, and blockers',
                ),
                const SizedBox(height: 12),
                ResponsiveWrap(
                  minItemWidth: 196,
                  children: [
                    _MetricCard(
                      title: 'Daily Life Score',
                      value: '$lifeScore',
                    ),
                    _MetricCard(
                      title: 'Weekly Life Score',
                      value: '$weeklyScore',
                    ),
                    _MetricCard(
                      title: 'Check-in Streak',
                      value:
                          '$checkinStreakDays day${checkinStreakDays == 1 ? '' : 's'}',
                    ),
                    _MetricCard(
                      title: 'Task Completion',
                      value: '$taskRate%',
                    ),
                    _MetricCard(
                      title: 'Habit Completion',
                      value: '$habitRate%',
                    ),
                    _MetricCard(
                      title: 'Focus Trend',
                      value: '$focusAvg/10',
                    ),
                    _MetricCard(
                      title: 'Best Productive Day',
                      value:
                          best == null ? 'No data' : compactDate(best['date']),
                    ),
                    _MetricCard(
                      title: 'Weakest Area',
                      value: _weakestArea(taskRate, habitRate, focusAvg),
                    ),
                    _MetricCard(
                      title: 'Common Blocker',
                      value: blocker ?? 'No blocker yet',
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                ResponsiveWrap(
                  minItemWidth: 360,
                  children: [
                    BpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _CardHeader(
                            icon: Icons.show_chart,
                            title: 'Mood and Focus',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(height: 240, child: _FocusChart(progress)),
                          const SizedBox(height: 12),
                          Text('Recent moods: ${_moodTrend(progress)}'),
                        ],
                      ),
                    ),
                    BpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Expanded(
                                child: _CardHeader(
                                  icon: Icons.summarize_outlined,
                                  title: 'AI Weekly Summary',
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _summarizing
                                    ? null
                                    : _generateWeeklySummary,
                                icon: _summarizing
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: ExpressiveLoadingIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.auto_awesome),
                                label: const Text('Generate'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            weeklySummary ??
                                'Generate a weekly review after you have check-ins and progress logs.',
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                BpCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SectionTitle(
                        title: 'Weekly Progress Chart',
                        subtitle: 'Daily life score out of 100',
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 240,
                        child: _WeeklyChart(progress: progress),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _latestFeedback(
    Map<String, dynamic> data,
    String type,
    String fallback,
  ) {
    final feedback = data['recent_feedback'] as List<Map<String, dynamic>>;
    final match = feedback.where((item) => item['feedback_type'] == type);
    return match.isEmpty ? fallback : match.first['message'].toString();
  }

  Future<void> _refreshAi(Map<String, dynamic> context) async {
    setState(() => _refreshingAi = true);
    try {
      final userId = SupabaseService.currentUserId;
      final suggestion = await _ai.generateDailySuggestion(context);
      final warning = await _ai.generateWeaknessAlert(context);
      final motivation = await _ai.generateMotivation(context);
      await _mcp.saveAIFeedback(userId, {
        'feedback_type': 'suggestion',
        'message': suggestion,
        'related_data': {'source': 'dashboard'},
      });
      await _mcp.saveAIFeedback(userId, {
        'feedback_type': 'warning',
        'message': warning,
        'related_data': {'source': 'dashboard'},
      });
      await _mcp.saveAIFeedback(userId, {
        'feedback_type': 'motivation',
        'message': motivation,
        'related_data': {'source': 'dashboard'},
      });
      _refresh();
    } catch (error) {
      _showError('Could not refresh AI feedback: $error');
    } finally {
      if (mounted) setState(() => _refreshingAi = false);
    }
  }

  Future<void> _openCheckin() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CheckinPage()),
    );
    _refresh();
  }

  Future<void> _generateWeeklySummary() async {
    setState(() => _summarizing = true);
    try {
      final userId = SupabaseService.currentUserId;
      final context = await _mcp.getUserContext(userId);
      final summary = await _ai.generateWeeklyReview(context);
      await _mcp.saveAIFeedback(userId, {
        'feedback_type': 'weekly_summary',
        'message': summary,
        'related_data': {'source': 'dashboard'},
      });
      _refresh();
    } catch (error) {
      _showError('Could not generate weekly summary: $error');
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String? _commonBlocker(List<Map<String, dynamic>> progress) {
    final counts = <String, int>{};
    for (final log in progress) {
      final blocker = log['blocker']?.toString();
      if (blocker == null || blocker.trim().isEmpty) continue;
      for (final item in blocker.split(',')) {
        final key = item.trim();
        if (key.isEmpty) continue;
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  String _weakestArea(int taskRate, int habitRate, int focusAvg) {
    final focusPercent = focusAvg * 10;
    if (taskRate <= habitRate && taskRate <= focusPercent) return 'Tasks';
    if (habitRate <= taskRate && habitRate <= focusPercent) return 'Habits';
    return 'Focus';
  }

  String _moodTrend(List<Map<String, dynamic>> progress) {
    final moods = progress
        .map((log) => log['mood']?.toString())
        .where((mood) => mood != null && mood.isNotEmpty)
        .cast<String>()
        .toList();
    if (moods.isEmpty) return 'No mood logs yet';
    return moods.reversed.take(6).join(', ');
  }
}

class _DashboardHero extends StatelessWidget {
  const _DashboardHero({
    required this.name,
    required this.mission,
    required this.score,
    required this.weeklyScore,
    required this.completedToday,
    required this.openToday,
    required this.focusAvg,
    required this.refreshingAi,
    required this.onRefreshAi,
    required this.onCheckIn,
  });

  final String? name;
  final String mission;
  final int score;
  final int weeklyScore;
  final int completedToday;
  final int openToday;
  final int focusAvg;
  final bool refreshingAi;
  final VoidCallback onRefreshAi;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width < 720;
    final greeting = name == null ? 'Welcome back' : 'Welcome back, $name';
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatusPill(
          icon: Icons.bolt_outlined,
          label: 'Daily command center',
          color: colorScheme.tertiary,
        ),
        const SizedBox(height: 12),
        Text(
          greeting,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          mission,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              onPressed: refreshingAi ? null : onRefreshAi,
              icon: refreshingAi
                  ? const SizedBox.square(
                      dimension: 16,
                      child: ExpressiveLoadingIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('AI refresh'),
            ),
            FilledButton.icon(
              onPressed: onCheckIn,
              icon: const Icon(Icons.question_answer_outlined),
              label: const Text('Check in'),
            ),
          ],
        ),
      ],
    );
    final scoreSummary = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ScorePanel(score: score),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _HeroMetric(
                label: 'Weekly',
                value: '$weeklyScore',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeroMetric(
                label: 'Tasks open',
                value: '$openToday',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _HeroMetric(
                label: 'Done today',
                value: '$completedToday',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HeroMetric(
                label: 'Focus',
                value: '$focusAvg/10',
              ),
            ),
          ],
        ),
      ],
    );

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 18 : 24),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  intro,
                  const SizedBox(height: 22),
                  scoreSummary,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 3, child: intro),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: scoreSummary),
                ],
              ),
      ),
    );
  }
}

class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.favorite_border,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Life Score',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$score/100',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: score.clamp(0, 100) / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasks, habits, focus, and reflection',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onPrimaryContainer.withValues(alpha: 0.78),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.title,
    required this.icon,
    required this.text,
  });

  final String title;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return _DashboardTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: icon, title: title),
          const SizedBox(height: 14),
          Text(
            text,
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.tasks});

  final List<Map<String, dynamic>> tasks;

  @override
  Widget build(BuildContext context) {
    final today = tasks.take(4).toList();
    return _DashboardTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(icon: Icons.checklist, title: "Today's Tasks"),
          const SizedBox(height: 10),
          if (today.isEmpty)
            const Text(
                'No tasks due today. Add one action tied to your mission.')
          else
            for (final task in today) _TaskSummaryRow(task: task),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final int value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return _DashboardTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(icon: Icons.flag_outlined, title: title),
          const SizedBox(height: 18),
          Text(
            '$value%',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: value.clamp(0, 100) / 100,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _DashboardTile(
      minHeight: 124,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({required this.habits});

  final List<Map<String, dynamic>> habits;

  @override
  Widget build(BuildContext context) {
    return _DashboardTile(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardHeader(
            icon: Icons.local_fire_department_outlined,
            title: 'Habit Streaks',
          ),
          const SizedBox(height: 10),
          if (habits.isEmpty)
            const Text('Add a habit to start tracking streaks.')
          else
            for (final habit in habits.take(4)) _HabitSummaryRow(habit: habit),
        ],
      ),
    );
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.child,
    this.minHeight = 184,
  });

  final Widget child;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: BpCard(child: child),
    );
  }
}

class _TaskSummaryRow extends StatelessWidget {
  const _TaskSummaryRow({required this.task});

  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final completed = task['status'] == 'completed';
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.radio_button_unchecked,
            color: completed ? colorScheme.secondary : colorScheme.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${task['priority']} priority',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitSummaryRow extends StatelessWidget {
  const _HabitSummaryRow({required this.habit});

  final Map<String, dynamic> habit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              habit['title'].toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${intValue(habit['current_streak'])} days',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.progress});

  final List<Map<String, dynamic>> progress;

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) {
      return const EmptyState(
        icon: Icons.trending_up,
        title: 'No score history yet',
        message: 'Complete a check-in or task to generate your first score.',
      );
    }

    final spots = progress.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        doubleValue(entry.value['life_score']),
      );
    }).toList();
    final colorScheme = Theme.of(context).colorScheme;
    final gridColor = Theme.of(context).dividerColor.withValues(alpha: 0.72);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (_) => FlLine(
            color: gridColor,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 20,
              getTitlesWidget: (value, _) => Text(
                value.round().toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            color: colorScheme.primary,
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusChart extends StatelessWidget {
  const _FocusChart(this.progress);

  final List<Map<String, dynamic>> progress;

  @override
  Widget build(BuildContext context) {
    if (progress.isEmpty) {
      return const EmptyState(
        icon: Icons.show_chart,
        title: 'No focus trend yet',
        message: 'Night check-ins will populate your focus trend.',
      );
    }

    final spots = progress.asMap().entries.map((entry) {
      return FlSpot(
        entry.key.toDouble(),
        doubleValue(entry.value['focus_score']),
      );
    }).toList();
    final colorScheme = Theme.of(context).colorScheme;
    final gridColor = Theme.of(context).dividerColor.withValues(alpha: 0.72);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) => FlLine(
            color: gridColor,
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 2,
              getTitlesWidget: (value, _) => Text(
                value.round().toString(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            color: colorScheme.secondary,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: colorScheme.secondary.withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}
