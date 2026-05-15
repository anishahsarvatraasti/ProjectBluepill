import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/model_helpers.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';
import '../ui/expressive_loading_indicator.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage>
    with SingleTickerProviderStateMixin {
  final _mcp = McpContextService();
  late Future<Map<String, dynamic>> _future;
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _showSearch = false;
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _future = _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _load() async {
    final userId = SupabaseService.currentUserId;
    final today = dateKey(DateTime.now());
    final monthAgo = dateKey(DateTime.now().subtract(const Duration(days: 30)));

    final habits = await _mcp.getUserHabits(userId);
    final recentLogs = rows(await SupabaseService.client
        .from('habit_logs')
        .select()
        .eq('user_id', userId)
        .gte('date', monthAgo)
        .lte('date', today)
        .order('date', ascending: false));

    for (final h in habits) {
      _expandedCategories.add(h['category']?.toString() ?? 'personal');
    }

    final todayLogs = recentLogs.where((l) => l['date'] == today).toList();

    return {
      'habits': habits,
      'recent_logs': recentLogs,
      'today_logs': todayLogs,
    };
  }

  void _refresh() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _logHabit(Map<String, dynamic> habit, String status) async {
    final userId = SupabaseService.currentUserId;
    final today = dateKey(DateTime.now());
    final existing = await SupabaseService.client
        .from('habit_logs')
        .select()
        .eq('habit_id', habit['id'])
        .eq('date', today)
        .maybeSingle();
    final previousLog = maybeRow(existing);
    final wasCompleted = previousLog?['status'] == 'completed';

    await SupabaseService.client.from('habit_logs').upsert(
      {
        'habit_id': habit['id'],
        'user_id': userId,
        'date': today,
        'status': status,
      },
      onConflict: 'habit_id,date',
    );

    final logs30 = rows(await SupabaseService.client
        .from('habit_logs')
        .select()
        .eq('habit_id', habit['id'])
        .order('date', ascending: false)
        .limit(30));
    final completed = logs30.where((l) => l['status'] == 'completed');
    final completionRate =
        logs30.isEmpty ? 0 : (completed.length / logs30.length * 100).round();
    final streak = status == 'completed'
        ? intValue(habit['current_streak']) + (wasCompleted ? 0 : 1)
        : 0;

    await SupabaseService.client.from('habits').update({
      'current_streak': streak,
      'completion_rate': completionRate,
    }).eq('id', habit['id']);

    _refresh();

    if (mounted) {
      final verb = status == 'completed'
          ? 'completed'
          : status == 'partial'
              ? 'partial'
              : 'missed';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$verb — ${habit['title']}'),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              if (previousLog != null) {
                await SupabaseService.client
                    .from('habit_logs')
                    .upsert(previousLog, onConflict: 'habit_id,date');
              } else {
                await SupabaseService.client
                    .from('habit_logs')
                    .delete()
                    .eq('habit_id', habit['id'])
                    .eq('date', today);
              }
              _refresh();
            },
          ),
        ),
      );
    }
  }

  Future<void> _deleteHabit(Map<String, dynamic> habit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete habit'),
        content: Text('Delete "${habit['title']}" and all its logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await SupabaseService.client
          .from('habits')
          .delete()
          .eq('id', habit['id']);
      _refresh();
    }
  }

  Future<void> _editHabit([Map<String, dynamic>? habit]) async {
    final title = TextEditingController(text: habit?['title']?.toString());
    final target = TextEditingController(text: habit?['target']?.toString());
    var category = habit?['category']?.toString() ?? 'personal';
    var frequency = habit?['frequency']?.toString() ?? 'daily';
    final isNew = habit == null;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Text(isNew ? 'Add habit' : 'Edit habit'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: title,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Morning workout',
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: const [
                      DropdownMenuItem(value: 'health', child: Text('Health')),
                      DropdownMenuItem(
                          value: 'fitness', child: Text('Fitness')),
                      DropdownMenuItem(
                          value: 'productivity',
                          child: Text('Productivity')),
                      DropdownMenuItem(
                          value: 'learning', child: Text('Learning')),
                      DropdownMenuItem(
                          value: 'mindfulness', child: Text('Mindfulness')),
                      DropdownMenuItem(
                          value: 'social', child: Text('Social')),
                      DropdownMenuItem(
                          value: 'finance', child: Text('Finance')),
                      DropdownMenuItem(
                          value: 'personal', child: Text('Personal')),
                      DropdownMenuItem(
                          value: 'custom', child: Text('Custom...')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => category = value ?? category),
                  ),
                  if (category == 'custom') ...[
                    const SizedBox(height: 10),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Custom category',
                        hintText: 'e.g. Creative',
                      ),
                      onChanged: (v) => category = v.trim(),
                    ),
                  ],
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('Daily')),
                      DropdownMenuItem(
                          value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(
                          value: 'custom', child: Text('Custom')),
                    ],
                    onChanged: (value) =>
                        setDialogState(() => frequency = value ?? frequency),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: target,
                    decoration: const InputDecoration(
                      labelText: 'Target (optional)',
                      hintText: 'e.g. 30 min, 10 pages, 2L water',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  if (title.text.trim().isEmpty) return;
                  final data = {
                    'user_id': SupabaseService.currentUserId,
                    'title': title.text.trim(),
                    'category': category,
                    'frequency': frequency,
                    'target': target.text.trim(),
                  };
                  if (isNew) {
                    await SupabaseService.client.from('habits').insert(data);
                  } else {
                    await SupabaseService.client
                        .from('habits')
                        .update(data)
                        .eq('id', habit['id']);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  _refresh();
                },
                child: const Text('Save'),
              ),
            ],
          );
        });
      },
    );

    title.dispose();
    target.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _showSearch
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search habits...',
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text('Habits'),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off : Icons.search),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchQuery = '';
                _searchController.clear();
              }
            }),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Habits'),
            Tab(text: 'Calendar'),
            Tab(text: 'Stats'),
          ],
        ),
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
          return TabBarView(
            controller: _tabController,
            children: [
              _buildHabitsTab(data),
              _buildCalendarTab(data),
              _buildStatsTab(data),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editHabit(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHabitsTab(Map<String, dynamic> data) {
    final habits = data['habits'] as List<Map<String, dynamic>>;
    final recentLogs = data['recent_logs'] as List<Map<String, dynamic>>;
    final todayLogs = data['today_logs'] as List<Map<String, dynamic>>;

    var filtered = habits;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = habits.where((h) {
        return h['title']?.toString().toLowerCase().contains(q) == true ||
            h['category']?.toString().toLowerCase().contains(q) == true;
      }).toList();
    }

    if (filtered.isEmpty) {
      if (_searchQuery.isNotEmpty) {
        return const Center(
          child: EmptyState(
            icon: Icons.search_off,
            title: 'No results',
            message: 'Try a different search term.',
          ),
        );
      }
      return const Center(
        child: EmptyState(
          icon: Icons.repeat,
          title: 'No habits yet',
          message: 'Add habits like coding, workout, reading, or stretching.',
        ),
      );
    }

    // Group by category
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final h in filtered) {
      final cat = h['category']?.toString() ?? 'personal';
      grouped.putIfAbsent(cat, () => []).add(h);
    }

    final sortedCategories = grouped.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        _buildStatsBanner(filtered, recentLogs),
        const SizedBox(height: 16),
        for (final cat in sortedCategories) ...[
          _buildCategorySection(
              cat, grouped[cat]!, recentLogs, todayLogs),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildStatsBanner(
      List<Map<String, dynamic>> habits, List<Map<String, dynamic>> recentLogs) {
    final total = habits.length;
    final completed = recentLogs
        .where((l) => l['status'] == 'completed')
        .length;
    final missed = recentLogs.where((l) => l['status'] == 'missed').length;
    final rate = recentLogs.isEmpty
        ? 0
        : (completed / recentLogs.length * 100).round();
    final bestStreak = habits.fold<int>(
        0, (max, h) => intValue(h['best_streak'] ?? h['current_streak']) > max
            ? intValue(h['best_streak'] ?? h['current_streak'])
            : max);

    return BpCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _buildStatCircle(rate, 'Rate', Colors.green),
          const SizedBox(width: 16),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn('Habits', '$total'),
                _buildStatColumn('Best', '${bestStreak}d'),
                _buildStatColumn('Done', '$completed'),
                _buildStatColumn('Missed', '$missed'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCircle(int value, String label, Color color) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              value: value / 100,
              strokeWidth: 5,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text(
            '$value%',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildCategorySection(
    String category,
    List<Map<String, dynamic>> habits,
    List<Map<String, dynamic>> recentLogs,
    List<Map<String, dynamic>> todayLogs,
  ) {
    final expanded = _expandedCategories.contains(category);
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() {
            if (expanded) {
              _expandedCategories.remove(category);
            } else {
              _expandedCategories.add(category);
            }
          }),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  expanded
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  _capitalize(category),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${habits.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color:
                          Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          ...habits.map((h) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildHabitCard(h, recentLogs, todayLogs),
              )),
      ],
    );
  }

  Widget _buildHabitCard(
    Map<String, dynamic> habit,
    List<Map<String, dynamic>> recentLogs,
    List<Map<String, dynamic>> todayLogs,
  ) {
    final habitLogs = recentLogs.where((l) => l['habit_id'] == habit['id']);
    final todayLog = todayLogs
        .where((l) => l['habit_id'] == habit['id'])
        .toList();
    final status = todayLog.isEmpty ? null : todayLog.first['status'];
    final rate = intValue(habit['completion_rate']);
    final streak = intValue(habit['current_streak']);

    return BpCard(
      padding: const EdgeInsets.all(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showHabitDetail(habit, habitLogs.toList()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => _logHabit(
                      habit, status == 'completed' ? 'missed' : 'completed'),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      status == 'completed'
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      key: ValueKey(status),
                      color: status == 'completed'
                          ? Colors.green
                          : status == 'partial'
                              ? Colors.orange
                              : Theme.of(context).colorScheme.primary,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        habit['title'].toString(),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (habit['target'] != null &&
                          habit['target'].toString().isNotEmpty)
                        Text(
                          habit['target'].toString(),
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') _editHabit(habit);
                    if (value == 'delete') _deleteHabit(habit);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildMiniHeatmap(habitLogs.toList()),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (streak > 0) ...[
                          Text(
                            '🔥',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(width: 2),
                        ],
                        Text(
                          '${streak}d',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: streak > 0 ? Colors.orange : null,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$rate%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: rate >= 70
                            ? Colors.green
                            : rate >= 40
                                ? Colors.orange
                                : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildLogButton(
                  habit: habit,
                  label: 'Done',
                  icon: Icons.done,
                  isActive: status == 'completed',
                  activeColor: Colors.green,
                  onTap: () => _logHabit(habit, 'completed'),
                ),
                const SizedBox(width: 6),
                _buildLogButton(
                  habit: habit,
                  label: 'Half',
                  icon: Icons.timelapse,
                  isActive: status == 'partial',
                  activeColor: Colors.orange,
                  onTap: () => _logHabit(habit, 'partial'),
                ),
                const SizedBox(width: 6),
                _buildLogButton(
                  habit: habit,
                  label: 'Miss',
                  icon: Icons.close,
                  isActive: status == 'missed',
                  activeColor: Colors.red,
                  onTap: () => _logHabit(habit, 'missed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogButton({
    required Map<String, dynamic> habit,
    required String label,
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: isActive
          ? FilledButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: FilledButton.styleFrom(
                backgroundColor: activeColor,
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                minimumSize: Size.zero,
              ),
            )
          : OutlinedButton.icon(
              onPressed: onTap,
              icon: Icon(icon, size: 16),
              label: Text(label),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                minimumSize: Size.zero,
              ),
            ),
    );
  }

  Widget _buildMiniHeatmap(List<Map<String, dynamic>> logs) {
    final today = DateTime.now();
    final logMap = <String, String>{};
    for (final l in logs) {
      final d = l['date'].toString();
      if (!logMap.containsKey(d)) {
        logMap[d] = l['status'].toString();
      }
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        final day = today.subtract(Duration(days: 6 - i));
        final key = dateKey(day);
        final status = logMap[key];
        Color color;
        if (status == 'completed') {
          color = Colors.green;
        } else if (status == 'partial') {
          color = Colors.orange;
        } else if (status == 'missed') {
          color = Colors.red.shade300;
        } else {
          color = Theme.of(context).colorScheme.surfaceContainerHighest;
        }
        final isToday = i == 6;
        return Padding(
          padding: const EdgeInsets.only(right: 3),
          child: Container(
            width: isToday ? 18 : 14,
            height: isToday ? 18 : 14,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  void _showHabitDetail(
    Map<String, dynamic> habit,
    List<Map<String, dynamic>> logs,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _HabitDetailPage(
          habit: habit,
          logs: logs,
          onChanged: _refresh,
        ),
      ),
    );
  }

  // --- Calendar Tab ---

  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int? _selectedCalendarDay;

  Widget _buildCalendarTab(Map<String, dynamic> data) {
    final habits = data['habits'] as List<Map<String, dynamic>>;
    final recentLogs = data['recent_logs'] as List<Map<String, dynamic>>;

    final daysInMonth =
        DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_calendarMonth.year, _calendarMonth.month, 1).weekday % 7;
    final today = DateTime.now();
    final isCurrentMonth = _calendarMonth.month == today.month &&
        _calendarMonth.year == today.year;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    setState(() => _calendarMonth = DateTime(
                        _calendarMonth.year, _calendarMonth.month - 1)),
              ),
              Text(
                DateFormat('MMMM yyyy').format(_calendarMonth),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    setState(() => _calendarMonth = DateTime(
                        _calendarMonth.year, _calendarMonth.month + 1)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map((d) => Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: GridView.builder(
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1,
              ),
              itemCount: firstWeekday + daysInMonth,
              itemBuilder: (context, index) {
                if (index < firstWeekday) {
                  return const SizedBox.shrink();
                }
                final day = index - firstWeekday + 1;
                final dateStr =
                    dateKey(DateTime(_calendarMonth.year, _calendarMonth.month, day));
                final dayLogs = recentLogs.where((l) => l['date'] == dateStr).toList();

                final completed =
                    dayLogs.where((l) => l['status'] == 'completed').length;
                final missed =
                    dayLogs.where((l) => l['status'] == 'missed').length;
                final total = dayLogs.length;

                final isToday = isCurrentMonth && day == today.day;
                final isSelected = _selectedCalendarDay == day;

                Color? bgColor;
                if (total > 0 && completed == total) {
                  bgColor = Colors.green.withValues(alpha: 0.25);
                } else if (total > 0 && missed == total) {
                  bgColor = Colors.red.withValues(alpha: 0.2);
                } else if (total > 0) {
                  bgColor = Colors.orange.withValues(alpha: 0.2);
                }

                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedCalendarDay =
                          isSelected ? null : day),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(8),
                      border: isToday
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2)
                          : isSelected
                              ? Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  width: 1)
                              : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          fontWeight:
                              isToday ? FontWeight.w900 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_selectedCalendarDay != null) ...[
          const Divider(height: 1),
          _buildDayDetail(
            DateTime(
                _calendarMonth.year, _calendarMonth.month, _selectedCalendarDay!),
            recentLogs,
            habits,
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legendDot(Colors.green, 'Done'),
              const SizedBox(width: 16),
              _legendDot(Colors.orange, 'Partial'),
              const SizedBox(width: 16),
              _legendDot(Colors.red.shade300, 'Missed'),
              const SizedBox(width: 16),
              _legendDot(
                  Theme.of(context).colorScheme.surfaceContainerHighest, 'None'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildDayDetail(
    DateTime day,
    List<Map<String, dynamic>> allLogs,
    List<Map<String, dynamic>> habits,
  ) {
    final dateStr = dateKey(day);
    final dayLogs = allLogs.where((l) => l['date'] == dateStr).toList();
    final habitMap = {for (final h in habits) h['id'].toString(): h};

    return SizedBox(
      height: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              DateFormat('EEEE, MMMM d').format(day),
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            child: dayLogs.isEmpty
                ? const Center(child: Text('No logs for this day'))
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: dayLogs.map((l) {
                      final h = habitMap[l['habit_id'].toString()];
                      final title = h?['title']?.toString() ?? 'Unknown';
                      final status = l['status'].toString();
                      IconData icon;
                      Color color;
                      if (status == 'completed') {
                        icon = Icons.check_circle;
                        color = Colors.green;
                      } else if (status == 'partial') {
                        icon = Icons.timelapse;
                        color = Colors.orange;
                      } else {
                        icon = Icons.cancel;
                        color = Colors.red;
                      }
                      return ListTile(
                        dense: true,
                        leading: Icon(icon, color: color, size: 20),
                        title: Text(title),
                        trailing: Text(
                          _capitalize(status),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  // --- Stats Tab ---

  Widget _buildStatsTab(Map<String, dynamic> data) {
    final habits = data['habits'] as List<Map<String, dynamic>>;
    final recentLogs = data['recent_logs'] as List<Map<String, dynamic>>;

    if (habits.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.bar_chart,
          title: 'No data yet',
          message: 'Add habits and log them to see statistics.',
        ),
      );
    }

    // Per-habit stats
    final perHabit = <Map<String, dynamic>>[];
    for (final h in habits) {
      final hLogs =
          recentLogs.where((l) => l['habit_id'] == h['id']).toList();
      final completed = hLogs.where((l) => l['status'] == 'completed').length;
      final partial = hLogs.where((l) => l['status'] == 'partial').length;
      final missed = hLogs.where((l) => l['status'] == 'missed').length;
      final rate = hLogs.isEmpty
          ? 0.0
          : (completed / hLogs.length * 100);
      perHabit.add({
        'habit': h,
        'total': hLogs.length,
        'completed': completed,
        'partial': partial,
        'missed': missed,
        'rate': rate,
      });
    }

    perHabit.sort((a, b) => (b['rate'] as double).compareTo(a['rate'] as double));

    final totalComplete =
        perHabit.fold<int>(0, (s, h) => s + (h['completed'] as int));
    final totalPartial =
        perHabit.fold<int>(0, (s, h) => s + (h['partial'] as int));
    final totalMissed =
        perHabit.fold<int>(0, (s, h) => s + (h['missed'] as int));
    final grandTotal = totalComplete + totalPartial + totalMissed;
    final overallRate =
        grandTotal == 0 ? 0.0 : (totalComplete / grandTotal * 100);

    // Category breakdown
    final catStats = <String, List<int>>{};
    for (final h in habits) {
      final cat = h['category']?.toString() ?? 'personal';
      catStats.putIfAbsent(cat, () => [0, 0, 0]); // completed, partial, missed
    }
    for (final l in recentLogs) {
      final h = habits.where((x) => x['id'] == l['habit_id']).toList();
      if (h.isNotEmpty) {
        final cat = h.first['category']?.toString() ?? 'personal';
        final s = l['status'].toString();
        if (s == 'completed') { catStats[cat]![0]++; } else if (s == 'partial') { catStats[cat]![1]++; } else if (s == 'missed') { catStats[cat]![2]++; }
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overall rate
        BpCard(
          child: Column(
            children: [
              const Text('Overall Completion',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: overallRate / 100,
                        strokeWidth: 10,
                        backgroundColor:
                            Colors.green.withValues(alpha: 0.1),
                        valueColor:
                            const AlwaysStoppedAnimation(Colors.green),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${overallRate.round()}%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 28,
                          ),
                        ),
                        Text(
                          '$totalComplete / $grandTotal',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _statChip('$totalComplete', 'Done', Colors.green),
                  _statChip('$totalPartial', 'Partial', Colors.orange),
                  _statChip('$totalMissed', 'Missed', Colors.red),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Category breakdown
        BpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Category Breakdown',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              for (final entry in catStats.entries) ...[
                _buildCategoryBar(entry.key, entry.value[0],
                    entry.value[1], entry.value[2]),
                const SizedBox(height: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Habit ranking
        BpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Habit Ranking',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              for (int i = 0; i < perHabit.length; i++) ...[
                _buildHabitRankRow(i, perHabit[i]),
                if (i < perHabit.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Streaks overview
        BpCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Streaks',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(height: 12),
              for (final h in habits) ...[
                Row(
                  children: [
                    Text(h['title'].toString()),
                    const Spacer(),
                    if (intValue(h['current_streak']) > 0) ...[
                      Text('🔥 ',
                          style: Theme.of(context).textTheme.bodyLarge),
                    ],
                    Text(
                      '${intValue(h['current_streak'])} days',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: intValue(h['current_streak']) > 0
                            ? Colors.orange
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
            ],
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _statChip(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: color)),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildCategoryBar(
      String category, int completed, int partial, int missed) {
    final total = completed + partial + missed;
    if (total == 0) return const SizedBox.shrink();
    final cFrac = completed / total;
    final pFrac = partial / total;
    final mFrac = missed / total;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(_capitalize(category),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${(cFrac * 100).round()}%',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Colors.green)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                if (cFrac > 0)
                  Flexible(
                      flex: (cFrac * 100).round(),
                      child: Container(color: Colors.green)),
                if (pFrac > 0)
                  Flexible(
                      flex: (pFrac * 100).round(),
                      child: Container(color: Colors.orange)),
                if (mFrac > 0)
                  Flexible(
                      flex: (mFrac * 100).round(),
                      child: Container(color: Colors.red.shade300)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHabitRankRow(int index, Map<String, dynamic> stats) {
    final h = stats['habit'] as Map<String, dynamic>;
    final rate = stats['rate'] as double;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                )),
          ),
          Expanded(
            child: Text(h['title'].toString(),
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 60,
            child: LinearProgressIndicator(
              value: rate / 100,
              backgroundColor: Colors.green.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(
                rate >= 70
                    ? Colors.green
                    : rate >= 40
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: Text(
              '${rate.round()}%',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: rate >= 70
                    ? Colors.green
                    : rate >= 40
                        ? Colors.orange
                        : Colors.red,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _HabitDetailPage extends StatefulWidget {
  final Map<String, dynamic> habit;
  final List<Map<String, dynamic>> logs;
  final VoidCallback onChanged;

  const _HabitDetailPage({
    required this.habit,
    required this.logs,
    required this.onChanged,
  });

  @override
  State<_HabitDetailPage> createState() => _HabitDetailPageState();
}

class _HabitDetailPageState extends State<_HabitDetailPage> {
  int _selectedMonthOffset = 0;

  DateTime get _viewMonth {
    final now = DateTime.now();
    return DateTime(now.year, now.month + _selectedMonthOffset);
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.habit;
    final theme = Theme.of(context);
    final rate = intValue(h['completion_rate']);
    final streak = intValue(h['current_streak']);

    return Scaffold(
      appBar: AppBar(
        title: Text(h['title'].toString()),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              // Reuse the edit logic via parent callback
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card
          BpCard(
            child: Column(
              children: [
                SizedBox(
                  width: 100,
                  height: 100,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: rate / 100,
                          strokeWidth: 8,
                          backgroundColor:
                              Colors.green.withValues(alpha: 0.1),
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.green),
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$rate%',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                            ),
                          ),
                          Text(
                            'rate',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _detailStat('Category',
                        _capitalize(h['category']?.toString() ?? 'personal')),
                    _detailStat('Frequency',
                        _capitalize(h['frequency']?.toString() ?? 'daily')),
                    _detailStat(
                        'Streak', streak > 0 ? '$streak 🔥' : '$streak'),
                  ],
                ),
                if (h['target'] != null &&
                    h['target'].toString().isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Target: ${h['target']}',
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Monthly heatmap
          BpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Monthly Log',
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16)),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, size: 20),
                          onPressed: () => setState(
                              () => _selectedMonthOffset--),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                        Text(
                          DateFormat('MMM yyyy').format(_viewMonth),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, size: 20),
                          onPressed: () => setState(
                              () => _selectedMonthOffset++),
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildMonthGrid(h),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Recent logs
          BpCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Activity',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 8),
                ...widget.logs.take(20).map((l) {
                  final status = l['status'].toString();
                  final date = l['date'].toString();
                  IconData icon;
                  Color color;
                  if (status == 'completed') {
                    icon = Icons.check_circle;
                    color = Colors.green;
                  } else if (status == 'partial') {
                    icon = Icons.timelapse;
                    color = Colors.orange;
                  } else {
                    icon = Icons.cancel;
                    color = Colors.red;
                  }
                  final dt = DateTime.tryParse(date);
                  return ListTile(
                    dense: true,
                    leading: Icon(icon, color: color, size: 20),
                    title: Text(dt != null
                        ? DateFormat('MMM d, yyyy').format(dt)
                        : date),
                    trailing: Text(
                      _capitalize(status),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
                if (widget.logs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No logs yet')),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _detailStat(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w800, fontSize: 16)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildMonthGrid(Map<String, dynamic> habit) {
    final daysInMonth =
        DateTime(_viewMonth.year, _viewMonth.month + 1, 0).day;
    final firstWeekday =
        DateTime(_viewMonth.year, _viewMonth.month, 1).weekday % 7;
    final today = DateTime.now();
    final isCurrentMonth = _viewMonth.month == today.month &&
        _viewMonth.year == today.year;

    final logMap = <int, String>{};
    for (final l in widget.logs) {
      final dt = DateTime.tryParse(l['date'].toString());
      if (dt != null &&
          dt.month == _viewMonth.month &&
          dt.year == _viewMonth.year) {
        final d = dt.day;
        if (!logMap.containsKey(d)) {
          logMap[d] = l['status'].toString();
        }
      }
    }

    final children = <Widget>[];
    // Day-of-week headers
    for (final d in ['S', 'M', 'T', 'W', 'T', 'F', 'S']) {
      children.add(Center(
        child: Text(
          d,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ));
    }
    // Empty cells
    for (int i = 0; i < firstWeekday; i++) {
      children.add(const SizedBox.shrink());
    }
    // Day cells
    for (int day = 1; day <= daysInMonth; day++) {
      final status = logMap[day];
      Color? color;
      if (status == 'completed') { color = Colors.green; } else if (status == 'partial') { color = Colors.orange; } else if (status == 'missed') { color = Colors.red.shade300; }

      final isToday = isCurrentMonth && day == today.day;

      children.add(
        Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: color?.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(6),
            border: isToday
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary, width: 2)
                : null,
          ),
          child: Center(
            child: Text(
              '$day',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.w900 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
      ),
      children: children,
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
