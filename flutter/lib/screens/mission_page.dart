import 'package:flutter/material.dart';

import '../models/model_helpers.dart';
import '../services/ai_service.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';
import '../ui/expressive_loading_indicator.dart';

class MissionPage extends StatefulWidget {
  const MissionPage({super.key});

  @override
  State<MissionPage> createState() => _MissionPageState();
}

class _MissionPageState extends State<MissionPage> {
  final _mcp = McpContextService();
  final _ai = AiService();
  late Future<Map<String, dynamic>> _future;
  bool _loadingAdvice = false;
  String? _advice;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final userId = SupabaseService.currentUserId;
    final profile = await SupabaseService.client
        .from('users_profile')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    return {
      'profile': maybeRow(profile),
      'goals': await _mcp.getUserGoals(userId),
    };
  }

  void _refresh() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mission'),
        actions: [
          IconButton(
            tooltip: 'Mission advice',
            onPressed: _loadingAdvice ? null : _getAdvice,
            icon: _loadingAdvice
                ? const SizedBox.square(
                    dimension: 18,
                    child: ExpressiveLoadingIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: 'Add goal',
            onPressed: () => _editGoal(),
            icon: const Icon(Icons.add),
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
          final goals = data['goals'] as List<Map<String, dynamic>>;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              BpCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dream Mission',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      profile?['main_mission']?.toString() ??
                          'Add your mission in settings.',
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Dream Mission -> Long-Term Goal -> Monthly Goal -> Weekly Goal -> Today Task',
                    ),
                  ],
                ),
              ),
              if (_advice != null) ...[
                const SizedBox(height: 14),
                BpCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.psychology_alt_outlined),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_advice!)),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              for (final type in ['life', 'yearly', 'monthly', 'weekly']) ...[
                _GoalGroup(
                  type: type,
                  goals:
                      goals.where((goal) => goal['goal_type'] == type).toList(),
                  allGoals: goals,
                  onEdit: _editGoal,
                  onDelete: _deleteGoal,
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editGoal(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _getAdvice() async {
    setState(() => _loadingAdvice = true);
    try {
      final context = await _mcp.getUserContext(SupabaseService.currentUserId);
      final advice = await _ai.generateMissionAdvice(context);
      setState(() => _advice = advice);
    } finally {
      if (mounted) setState(() => _loadingAdvice = false);
    }
  }

  Future<void> _deleteGoal(Map<String, dynamic> goal) async {
    await SupabaseService.client.from('goals').delete().eq('id', goal['id']);
    _refresh();
  }

  Future<void> _editGoal([Map<String, dynamic>? goal]) async {
    final existingGoals =
        await _mcp.getUserGoals(SupabaseService.currentUserId);
    if (!mounted) return;
    final title = TextEditingController(text: goal?['title']?.toString());
    final description =
        TextEditingController(text: goal?['description']?.toString());
    var type = goal?['goal_type']?.toString() ?? 'weekly';
    var status = goal?['status']?.toString() ?? 'active';
    var progress = doubleValue(goal?['progress_percent']);
    var parentId = goal?['parent_goal_id']?.toString();
    var deadline = DateTime.tryParse(goal?['deadline']?.toString() ?? '');

    await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(goal == null ? 'Add goal' : 'Edit goal'),
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
                      controller: description,
                      minLines: 2,
                      maxLines: 4,
                      decoration:
                          const InputDecoration(labelText: 'Description'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(labelText: 'Goal type'),
                      items: const [
                        DropdownMenuItem(value: 'life', child: Text('Life')),
                        DropdownMenuItem(
                            value: 'yearly', child: Text('Yearly')),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Monthly'),
                        ),
                        DropdownMenuItem(
                            value: 'weekly', child: Text('Weekly')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => type = value ?? type),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: parentId,
                      decoration:
                          const InputDecoration(labelText: 'Parent goal'),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('None'),
                        ),
                        for (final item in existingGoals)
                          if (item['id'] != goal?['id'])
                            DropdownMenuItem<String?>(
                              value: item['id'].toString(),
                              child: Text(item['title'].toString()),
                            ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => parentId = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'paused', child: Text('Paused')),
                        DropdownMenuItem(
                          value: 'completed',
                          child: Text('Completed'),
                        ),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Archived'),
                        ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Progress'),
                        Expanded(
                          child: Slider(
                            value: progress,
                            min: 0,
                            max: 100,
                            divisions: 20,
                            label: '${progress.round()}%',
                            onChanged: (value) =>
                                setDialogState(() => progress = value),
                          ),
                        ),
                      ],
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                          initialDate: deadline ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => deadline = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        deadline == null
                            ? 'Set deadline'
                            : 'Deadline ${compactDate(deadline!.toIso8601String())}',
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
                      'description': description.text.trim(),
                      'goal_type': type,
                      'parent_goal_id': parentId,
                      'deadline': deadline == null ? null : dateKey(deadline!),
                      'progress_percent': progress.round(),
                      'status': status,
                    };
                    if (goal == null) {
                      await SupabaseService.client.from('goals').insert(data);
                    } else {
                      await SupabaseService.client
                          .from('goals')
                          .update(data)
                          .eq('id', goal['id']);
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
    description.dispose();
  }
}

class _GoalGroup extends StatelessWidget {
  const _GoalGroup({
    required this.type,
    required this.goals,
    required this.allGoals,
    required this.onEdit,
    required this.onDelete,
  });

  final String type;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> allGoals;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    return BpCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${type[0].toUpperCase()}${type.substring(1)} Goals',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (goals.isEmpty)
            const Text('No goals here yet.')
          else
            for (final goal in goals)
              _GoalTile(
                  goal: goal,
                  allGoals: allGoals,
                  onEdit: onEdit,
                  onDelete: onDelete),
        ],
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.allGoals,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> goal;
  final List<Map<String, dynamic>> allGoals;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(Map<String, dynamic>) onDelete;

  @override
  Widget build(BuildContext context) {
    final parent =
        allGoals.where((item) => item['id'] == goal['parent_goal_id']);
    final progress = doubleValue(goal['progress_percent']);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal['title'].toString(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: 'Edit',
                onPressed: () => onEdit(goal),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: () => onDelete(goal),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          if (goal['description'] != null &&
              goal['description'].toString().isNotEmpty)
            Text(goal['description'].toString()),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress / 100),
          const SizedBox(height: 6),
          Text(
            '${progress.round()}% complete'
            '${parent.isEmpty ? '' : ' | Parent: ${parent.first['title']}'}'
            '${goal['deadline'] == null ? '' : ' | Due ${compactDate(goal['deadline'])}'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: const Color(0xFF667085)),
          ),
        ],
      ),
    );
  }
}
