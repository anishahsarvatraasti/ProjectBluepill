import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/model_helpers.dart';
import '../services/ai_service.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';
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
            return const Center(child: CircularProgressIndicator());
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

          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                SectionTitle(
                  title:
                      'Welcome${profile?['name'] == null ? '' : ', ${profile!['name']}'}',
                  subtitle: profile?['main_mission'] ??
                      'Connect today to the mission.',
                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed:
                            _refreshingAi ? null : () => _refreshAi(data),
                        icon: _refreshingAi
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: const Text('AI refresh'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _openCheckin(),
                        icon: const Icon(Icons.question_answer_outlined),
                        label: const Text('Check in'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ResponsiveWrap(
                  minItemWidth: 300,
                  children: [
                    _ScoreCard(score: lifeScore),
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
                const SizedBox(height: 16),
                const SectionTitle(
                  title: 'Progress',
                  subtitle: 'Scores, completion rates, focus, and blockers',
                ),
                const SizedBox(height: 12),
                ResponsiveWrap(
                  minItemWidth: 220,
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
                const SizedBox(height: 16),
                ResponsiveWrap(
                  minItemWidth: 360,
                  children: [
                    BpCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mood and Focus',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
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
                              const Icon(Icons.summarize_outlined),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'AI Weekly Summary',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                              ),
                              TextButton.icon(
                                onPressed: _summarizing
                                    ? null
                                    : _generateWeeklySummary,
                                icon: _summarizing
                                    ? const SizedBox.square(
                                        dimension: 16,
                                        child: CircularProgressIndicator(
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

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_border),
              SizedBox(width: 8),
              Text(
                'Life Score',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            '$score/100',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: score / 100),
          const SizedBox(height: 10),
          const Text('Tasks 40, habits 30, focus 20, reflection 10'),
        ],
      ),
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
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(text),
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
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.checklist),
              SizedBox(width: 8),
              Text(
                "Today's Tasks",
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (today.isEmpty)
            const Text(
                'No tasks due today. Add one action tied to your mission.')
          else
            for (final task in today)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  task['status'] == 'completed'
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: task['status'] == 'completed'
                      ? Colors.green
                      : Theme.of(context).colorScheme.primary,
                ),
                title: Text(task['title'].toString()),
                subtitle: Text('${task['priority']} priority'),
              ),
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
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Text(
            '$value%',
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(value: value / 100),
          const SizedBox(height: 10),
          Text(subtitle),
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
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text(
            value,
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
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_fire_department_outlined),
              SizedBox(width: 8),
              Text(
                'Habit Streaks',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (habits.isEmpty)
            const Text('Add a habit to start tracking streaks.')
          else
            for (final habit in habits.take(4))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(habit['title'].toString()),
                trailing: Text('${intValue(habit['current_streak'])} days'),
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

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            dotData: const FlDotData(show: true),
            color: Theme.of(context).colorScheme.primary,
            belowBarData: BarAreaData(
              show: true,
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
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

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 10,
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            barWidth: 3,
            color: Theme.of(context).colorScheme.primary,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}
