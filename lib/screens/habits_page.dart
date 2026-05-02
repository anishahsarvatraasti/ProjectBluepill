import 'package:flutter/material.dart';

import '../models/model_helpers.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';

class HabitsPage extends StatefulWidget {
  const HabitsPage({super.key});

  @override
  State<HabitsPage> createState() => _HabitsPageState();
}

class _HabitsPageState extends State<HabitsPage> {
  final _mcp = McpContextService();
  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final userId = SupabaseService.currentUserId;
    return {
      'habits': await _mcp.getUserHabits(userId),
      'today_logs': await _mcp.getTodayHabitLogs(userId),
    };
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits'),
        actions: [
          IconButton(
            tooltip: 'Add habit',
            onPressed: () => _editHabit(),
            icon: const Icon(Icons.add),
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

          final habits = snapshot.data!['habits'] as List<Map<String, dynamic>>;
          final logs =
              snapshot.data!['today_logs'] as List<Map<String, dynamic>>;
          if (habits.isEmpty) {
            return const EmptyState(
              icon: Icons.repeat,
              title: 'No habits yet',
              message:
                  'Add habits like coding, workout, reading, or journaling.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final habit = habits[index];
              final log = logs.where((item) => item['habit_id'] == habit['id']);
              final status = log.isEmpty ? null : log.first['status'];
              return BpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          status == 'completed'
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          color: status == 'completed'
                              ? Colors.green
                              : Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            habit['title'].toString(),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') _editHabit(habit);
                            if (value == 'delete') _deleteHabit(habit);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _Pill(text: habit['frequency'].toString()),
                        _Pill(text: habit['category'].toString()),
                        _Pill(
                          text:
                              '${intValue(habit['current_streak'])} day streak',
                        ),
                        _Pill(
                          text:
                              '${doubleValue(habit['completion_rate']).round()}% rate',
                        ),
                        if (status != null) _Pill(text: 'today $status'),
                      ],
                    ),
                    if (habit['target'] != null &&
                        habit['target'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(habit['target'].toString()),
                    ],
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: () => _logHabit(habit, 'completed'),
                          icon: const Icon(Icons.done),
                          label: const Text('Complete'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _logHabit(habit, 'partial'),
                          icon: const Icon(Icons.timelapse),
                          label: const Text('Partial'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _logHabit(habit, 'missed'),
                          icon: const Icon(Icons.close),
                          label: const Text('Missed'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: habits.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editHabit(),
        child: const Icon(Icons.add),
      ),
    );
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
    final wasCompleted = maybeRow(existing)?['status'] == 'completed';

    await SupabaseService.client.from('habit_logs').upsert(
      {
        'habit_id': habit['id'],
        'user_id': userId,
        'date': today,
        'status': status,
      },
      onConflict: 'habit_id,date',
    );

    final recentLogs = rows(await SupabaseService.client
        .from('habit_logs')
        .select()
        .eq('habit_id', habit['id'])
        .order('date', ascending: false)
        .limit(30));
    final completed = recentLogs.where((log) => log['status'] == 'completed');
    final completionRate = recentLogs.isEmpty
        ? 0
        : (completed.length / recentLogs.length * 100).round();
    final streak = status == 'completed'
        ? intValue(habit['current_streak']) + (wasCompleted ? 0 : 1)
        : 0;

    await SupabaseService.client.from('habits').update({
      'current_streak': streak,
      'completion_rate': completionRate,
    }).eq('id', habit['id']);

    _refresh();
  }

  Future<void> _deleteHabit(Map<String, dynamic> habit) async {
    await SupabaseService.client.from('habits').delete().eq('id', habit['id']);
    _refresh();
  }

  Future<void> _editHabit([Map<String, dynamic>? habit]) async {
    final title = TextEditingController(text: habit?['title']?.toString());
    final category = TextEditingController(
        text: habit?['category']?.toString() ?? 'personal');
    final target = TextEditingController(text: habit?['target']?.toString());
    var frequency = habit?['frequency']?.toString() ?? 'daily';

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(habit == null ? 'Add habit' : 'Edit habit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                    ),
                    const SizedBox(height: 12),
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
                    const SizedBox(height: 12),
                    TextField(
                      controller: target,
                      decoration: const InputDecoration(
                        labelText: 'Target',
                        hintText: 'Study 2 hours, read 10 pages, workout',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (title.text.trim().isEmpty) return;
                    final data = {
                      'user_id': SupabaseService.currentUserId,
                      'title': title.text.trim(),
                      'category': category.text.trim(),
                      'frequency': frequency,
                      'target': target.text.trim(),
                    };
                    if (habit == null) {
                      await SupabaseService.client.from('habits').insert(data);
                    } else {
                      await SupabaseService.client
                          .from('habits')
                          .update(data)
                          .eq('id', habit['id']);
                    }
                    if (context.mounted) Navigator.pop(context);
                    _refresh();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    category.dispose();
    target.dispose();
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
