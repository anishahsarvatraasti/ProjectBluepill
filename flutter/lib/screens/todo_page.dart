import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/tasks/v1.dart' as google_tasks;

import '../config/app_config.dart';
import '../models/model_helpers.dart';
import '../services/ai_service.dart';
import '../services/google_tasks_service.dart';
import '../services/mcp_context_service.dart';
import '../services/supabase_service.dart';
import '../ui/bp_card.dart';
import '../ui/expressive_loading_indicator.dart';
import '../ui/google_calendar_sign_in_button.dart';

class TodoPage extends StatefulWidget {
  const TodoPage({super.key});

  @override
  State<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends State<TodoPage> {
  final _mcp = McpContextService();
  final _ai = AiService();
  final _googleTasks = GoogleTasksService();
  late Future<List<Map<String, dynamic>>> _future;
  List<Map<String, dynamic>>? _orderedTasks;
  bool _ordering = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _googleTasks.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return _mcp.getAllTasks(SupabaseService.currentUserId);
  }

  void _refresh() {
    setState(() {
      _future = _load();
      _orderedTasks = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo List'),
        actions: [
          IconButton(
            tooltip: 'AI task order',
            onPressed: _ordering ? null : _orderWithAi,
            icon: _ordering
                ? const SizedBox.square(
                    dimension: 18,
                    child: ExpressiveLoadingIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_awesome),
          ),
          IconButton(
            tooltip: 'Add task',
            onPressed: () => _editTask(),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Sync Google Tasks',
            onPressed: _openGoogleTasksSync,
            icon: const Icon(Icons.sync),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: ExpressiveLoadingIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final tasks = _orderedTasks ?? snapshot.data ?? [];

          if (tasks.isEmpty) {
            return const EmptyState(
              icon: Icons.check_circle_outline,
              title: 'No tasks yet',
              message:
                  'Add a task and connect your day to your long-term mission.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return BpCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Checkbox(
                    value: task['status'] == 'completed',
                    onChanged: (value) => _toggleTask(task, value ?? false),
                  ),
                  title: Text(
                    task['title'].toString(),
                    style: TextStyle(
                      decoration: task['status'] == 'completed'
                          ? TextDecoration.lineThrough
                          : null,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Chip(text: '${task['priority']} priority'),
                        _Chip(text: task['category'].toString()),
                        _Chip(text: compactDate(task['due_date'])),
                        if (task['estimated_minutes'] != null)
                          _Chip(text: '${task['estimated_minutes']} min'),
                        _Chip(text: task['status'].toString()),
                      ],
                    ),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') _editTask(task);
                      if (value == 'delete') _deleteTask(task);
                      if (value == 'tomorrow') _moveToTomorrow(task);
                      if (value == 'missed') _markMissed(task);
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(
                          value: 'missed', child: Text('Mark missed')),
                      PopupMenuItem(
                        value: 'tomorrow',
                        child: Text('Move to tomorrow'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: tasks.length,
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editTask(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _openGoogleTasksSync() async {
    try {
      final tasks = await _future;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => _GoogleTasksSyncDialog(
          service: _googleTasks,
          localTasks: tasks,
          onSync: _syncGoogleTasks,
          onSynced: _refresh,
        ),
      );
    } catch (error) {
      _showError('Could not open Google Tasks sync: $error');
    }
  }

  Future<GoogleTasksSyncResult> _syncGoogleTasks(
    List<Map<String, dynamic>> localTasks,
  ) async {
    final userId = SupabaseService.currentUserId;
    final taskList = await _googleTasks.getOrCreateSyncTaskList();
    final taskListId = taskList.id;
    if (taskListId == null) {
      throw StateError('Google Tasks did not return a task list id.');
    }

    final googleTasks = await _googleTasks.listTasks(taskListId);
    final googleById = <String, google_tasks.Task>{
      for (final task in googleTasks)
        if (task.id != null) task.id!: task,
    };
    final linkedGoogleIds = <String>{};
    var createdGoogle = 0;
    var updatedGoogle = 0;
    var importedLocal = 0;
    var updatedLocal = 0;

    for (final localTask in localTasks) {
      final googleTaskId = _stringValue(localTask['google_task_id']);
      if (googleTaskId == null) {
        final created = await _googleTasks.createTask(
          taskListId,
          _draftFromLocalTask(localTask),
        );
        await _saveGoogleTaskLink(localTask['id'], taskListId, created);
        final createdId = created.id;
        if (createdId != null) linkedGoogleIds.add(createdId);
        createdGoogle++;
        continue;
      }

      linkedGoogleIds.add(googleTaskId);
      final remoteTask = googleById[googleTaskId];
      if (remoteTask == null) {
        final created = await _googleTasks.createTask(
          taskListId,
          _draftFromLocalTask(localTask),
        );
        await _saveGoogleTaskLink(localTask['id'], taskListId, created);
        final createdId = created.id;
        if (createdId != null) linkedGoogleIds.add(createdId);
        createdGoogle++;
        continue;
      }

      if (_googleTaskChangedSinceLastSync(localTask, remoteTask)) {
        await _updateLocalTaskFromGoogle(
          localTask['id'],
          userId,
          taskListId,
          remoteTask,
        );
        updatedLocal++;
      } else {
        final updated = await _googleTasks.updateTask(
          taskListId,
          googleTaskId,
          _draftFromLocalTask(localTask),
        );
        await _saveGoogleTaskLink(localTask['id'], taskListId, updated);
        updatedGoogle++;
      }
    }

    for (final googleTask in googleTasks) {
      final googleTaskId = googleTask.id;
      if (googleTaskId == null || linkedGoogleIds.contains(googleTaskId)) {
        continue;
      }
      await _insertLocalTaskFromGoogle(userId, taskListId, googleTask);
      importedLocal++;
    }

    return GoogleTasksSyncResult(
      createdGoogle: createdGoogle,
      updatedGoogle: updatedGoogle,
      importedLocal: importedLocal,
      updatedLocal: updatedLocal,
    );
  }

  GoogleTaskDraft _draftFromLocalTask(Map<String, dynamic> task) {
    return GoogleTaskDraft(
      title: task['title']?.toString().trim().isEmpty ?? true
          ? 'Untitled task'
          : task['title'].toString(),
      notes: task['description']?.toString() ?? '',
      dueDate: DateTime.tryParse(task['due_date']?.toString() ?? ''),
      completed: task['status'] == 'completed',
      completedAt: DateTime.tryParse(task['completed_at']?.toString() ?? ''),
    );
  }

  bool _googleTaskChangedSinceLastSync(
    Map<String, dynamic> localTask,
    google_tasks.Task googleTask,
  ) {
    final lastSynced = DateTime.tryParse(
      localTask['google_task_updated_at']?.toString() ?? '',
    );
    final googleUpdated = DateTime.tryParse(googleTask.updated ?? '');
    if (lastSynced == null || googleUpdated == null) return false;
    return googleUpdated.isAfter(lastSynced.add(const Duration(seconds: 1)));
  }

  Future<void> _saveGoogleTaskLink(
    Object? localTaskId,
    String taskListId,
    google_tasks.Task googleTask,
  ) async {
    final taskId = googleTask.id;
    if (localTaskId == null || taskId == null) return;
    try {
      await SupabaseService.client.from('tasks').update({
        'google_task_id': taskId,
        'google_task_list_id': taskListId,
        'google_task_updated_at': _googleUpdatedAt(googleTask),
      }).eq('id', localTaskId);
    } catch (error) {
      _throwGoogleTaskSchemaError(error);
    }
  }

  Future<void> _updateLocalTaskFromGoogle(
    Object? localTaskId,
    String userId,
    String taskListId,
    google_tasks.Task googleTask,
  ) async {
    if (localTaskId == null) return;
    try {
      await SupabaseService.client
          .from('tasks')
          .update(
            _localDataFromGoogleTask(userId, taskListId, googleTask)
              ..remove('user_id'),
          )
          .eq('id', localTaskId);
    } catch (error) {
      _throwGoogleTaskSchemaError(error);
    }
  }

  Future<void> _insertLocalTaskFromGoogle(
    String userId,
    String taskListId,
    google_tasks.Task googleTask,
  ) async {
    try {
      await SupabaseService.client
          .from('tasks')
          .insert(_localDataFromGoogleTask(userId, taskListId, googleTask));
    } catch (error) {
      _throwGoogleTaskSchemaError(error);
    }
  }

  Map<String, dynamic> _localDataFromGoogleTask(
    String userId,
    String taskListId,
    google_tasks.Task googleTask,
  ) {
    final completed = googleTask.status == 'completed';
    return {
      'user_id': userId,
      'title': googleTask.title?.trim().isEmpty ?? true
          ? 'Untitled task'
          : googleTask.title,
      'description': googleTask.notes ?? '',
      'priority': 'medium',
      'category': 'personal',
      'status': completed ? 'completed' : 'pending',
      'completed_at': completed
          ? DateTime.tryParse(googleTask.completed ?? '')?.toIso8601String()
          : null,
      'due_date': _googleDueDateKey(googleTask.due),
      'google_task_id': googleTask.id,
      'google_task_list_id': taskListId,
      'google_task_updated_at': _googleUpdatedAt(googleTask),
    };
  }

  String? _googleDueDateKey(String? value) {
    if (value == null || value.length < 10) return null;
    return value.substring(0, 10);
  }

  String? _googleUpdatedAt(google_tasks.Task task) {
    return DateTime.tryParse(task.updated ?? '')?.toIso8601String();
  }

  String? _stringValue(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Never _throwGoogleTaskSchemaError(Object error) {
    final text = error.toString();
    if (text.contains('PGRST204') &&
        (text.contains('google_task_id') ||
            text.contains('google_task_list_id') ||
            text.contains('google_task_updated_at'))) {
      throw StateError(
        'Run the latest supabase/schema.sql so tasks can store Google Tasks sync IDs.',
      );
    }
    throw error;
  }

  Future<void> _orderWithAi() async {
    setState(() => _ordering = true);
    try {
      final userId = SupabaseService.currentUserId;
      final tasks = await _future;
      final context = await _mcp.getUserContext(userId);
      final ordered = await _ai.generateTaskPriorityOrder(tasks, context);
      final orderedIds = ordered.map((task) => task['id']).toSet();
      final remaining = tasks
          .where((task) => !orderedIds.contains(task['id']))
          .toList(growable: false);
      if (!mounted) return;
      setState(() => _orderedTasks = [...ordered, ...remaining]);
    } catch (error) {
      _showError('Could not order tasks: $error');
    } finally {
      if (mounted) setState(() => _ordering = false);
    }
  }

  Future<void> _toggleTask(Map<String, dynamic> task, bool completed) async {
    await _runTaskMutation(() async {
      await SupabaseService.client.from('tasks').update({
        'status': completed ? 'completed' : 'pending',
        'completed_at': completed ? DateTime.now().toIso8601String() : null,
      }).eq('id', task['id']);
    });
  }

  Future<void> _markMissed(Map<String, dynamic> task) async {
    await _runTaskMutation(() async {
      await SupabaseService.client.from('tasks').update({
        'status': 'missed',
        'completed_at': null,
      }).eq('id', task['id']);
    });
  }

  Future<void> _moveToTomorrow(Map<String, dynamic> task) async {
    final tomorrow = dateKey(DateTime.now().add(const Duration(days: 1)));
    await _runTaskMutation(() async {
      await SupabaseService.client.from('tasks').update({
        'status': 'pending',
        'due_date': tomorrow,
        'completed_at': null,
      }).eq('id', task['id']);
    });
  }

  Future<void> _deleteTask(Map<String, dynamic> task) async {
    await _runTaskMutation(() async {
      await SupabaseService.client.from('tasks').delete().eq('id', task['id']);
    });
  }

  Future<void> _runTaskMutation(Future<void> Function() mutation) async {
    try {
      await mutation();
      if (mounted) _refresh();
    } catch (error) {
      _showError('Could not update task: $error');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _editTask([Map<String, dynamic>? task]) async {
    List<Map<String, dynamic>> goals;
    try {
      goals = await _mcp.getUserGoals(SupabaseService.currentUserId);
    } catch (error) {
      goals = [];
      _showError('Could not load goals: $error');
    }
    if (!mounted) return;
    final goalIds = goals.map((goal) => goal['id'].toString()).toSet();
    final title = TextEditingController(text: task?['title']?.toString());
    final description =
        TextEditingController(text: task?['description']?.toString());
    final estimate = TextEditingController(
      text: task?['estimated_minutes']?.toString() ?? '',
    );
    var priority = task?['priority']?.toString() ?? 'medium';
    var category = task?['category']?.toString() ?? 'personal';
    final linkedGoalId = task?['goal_id']?.toString();
    var goalId = linkedGoalId != null && goalIds.contains(linkedGoalId)
        ? linkedGoalId
        : 'none';
    var dueDate = DateTime.tryParse(task?['due_date']?.toString() ?? '');
    var saving = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(task == null ? 'Add task' : 'Edit task'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (errorText != null) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          errorText!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
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
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'high', child: Text('High')),
                        DropdownMenuItem(
                            value: 'medium', child: Text('Medium')),
                        DropdownMenuItem(value: 'low', child: Text('Low')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => priority = value ?? priority),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'study', child: Text('Study')),
                        DropdownMenuItem(value: 'work', child: Text('Work')),
                        DropdownMenuItem(
                            value: 'health', child: Text('Health')),
                        DropdownMenuItem(
                          value: 'finance',
                          child: Text('Finance'),
                        ),
                        DropdownMenuItem(
                          value: 'personal',
                          child: Text('Personal'),
                        ),
                        DropdownMenuItem(
                            value: 'career', child: Text('Career')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? category),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: goalId,
                      decoration: const InputDecoration(
                        labelText: 'Linked goal',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: 'none',
                          child: Text('None'),
                        ),
                        for (final goal in goals)
                          DropdownMenuItem<String>(
                            value: goal['id'].toString(),
                            child: Text(goal['title'].toString()),
                          ),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => goalId = value ?? 'none'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: estimate,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Estimated minutes',
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365)),
                          lastDate:
                              DateTime.now().add(const Duration(days: 3650)),
                          initialDate: dueDate ?? DateTime.now(),
                        );
                        if (picked != null) {
                          setDialogState(() => dueDate = picked);
                        }
                      },
                      icon: const Icon(Icons.calendar_month_outlined),
                      label: Text(
                        dueDate == null
                            ? 'Set due date'
                            : 'Due ${compactDate(dueDate!.toIso8601String())}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final trimmedTitle = title.text.trim();
                          final trimmedEstimate = estimate.text.trim();
                          final estimatedMinutes = trimmedEstimate.isEmpty
                              ? null
                              : int.tryParse(trimmedEstimate);
                          if (trimmedTitle.isEmpty) {
                            setDialogState(
                              () => errorText = 'Task title is required.',
                            );
                            return;
                          }
                          if (trimmedEstimate.isNotEmpty &&
                              (estimatedMinutes == null ||
                                  estimatedMinutes <= 0)) {
                            setDialogState(
                              () => errorText =
                                  'Estimated minutes must be a positive number.',
                            );
                            return;
                          }

                          setDialogState(() {
                            saving = true;
                            errorText = null;
                          });

                          try {
                            final data = {
                              'user_id': SupabaseService.currentUserId,
                              'title': trimmedTitle,
                              'description': description.text.trim(),
                              'priority': priority,
                              'category': category,
                              'due_date':
                                  dueDate == null ? null : dateKey(dueDate!),
                              'estimated_minutes': estimatedMinutes,
                            };
                            if (goalId != 'none' ||
                                task?.containsKey('goal_id') == true) {
                              data['goal_id'] =
                                  goalId == 'none' ? null : goalId;
                            }
                            if (task == null) {
                              await _saveNewTask(data);
                            } else {
                              final updateData = Map<String, dynamic>.from(data)
                                ..remove('user_id');
                              await _updateTask(task['id'], updateData);
                            }
                            if (context.mounted) Navigator.pop(context);
                            if (mounted) _refresh();
                          } catch (error) {
                            setDialogState(() {
                              saving = false;
                              errorText = 'Could not save task: $error';
                            });
                          }
                        },
                  child: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: ExpressiveLoadingIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    title.dispose();
    description.dispose();
    estimate.dispose();
  }

  Future<void> _saveNewTask(Map<String, dynamic> data) async {
    try {
      await SupabaseService.client.from('tasks').insert(data);
    } catch (error) {
      if (!_isMissingGoalIdError(error) || !data.containsKey('goal_id')) {
        rethrow;
      }
      final fallbackData = Map<String, dynamic>.from(data)..remove('goal_id');
      await SupabaseService.client.from('tasks').insert(fallbackData);
    }
  }

  Future<void> _updateTask(
    Object taskId,
    Map<String, dynamic> data,
  ) async {
    try {
      await SupabaseService.client.from('tasks').update(data).eq('id', taskId);
    } catch (error) {
      if (!_isMissingGoalIdError(error) || !data.containsKey('goal_id')) {
        rethrow;
      }
      final fallbackData = Map<String, dynamic>.from(data)..remove('goal_id');
      await SupabaseService.client
          .from('tasks')
          .update(fallbackData)
          .eq('id', taskId);
    }
  }

  bool _isMissingGoalIdError(Object error) {
    final text = error.toString();
    return text.contains('PGRST204') && text.contains('goal_id');
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

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

class GoogleTasksSyncResult {
  const GoogleTasksSyncResult({
    required this.createdGoogle,
    required this.updatedGoogle,
    required this.importedLocal,
    required this.updatedLocal,
  });

  final int createdGoogle;
  final int updatedGoogle;
  final int importedLocal;
  final int updatedLocal;

  int get total => createdGoogle + updatedGoogle + importedLocal + updatedLocal;

  String get message {
    if (total == 0) return 'Everything is already in sync.';
    return [
      if (createdGoogle > 0) '$createdGoogle pushed to Google',
      if (updatedGoogle > 0) '$updatedGoogle updated in Google',
      if (importedLocal > 0) '$importedLocal imported',
      if (updatedLocal > 0) '$updatedLocal updated locally',
    ].join(', ');
  }
}

class _GoogleTasksSyncDialog extends StatefulWidget {
  const _GoogleTasksSyncDialog({
    required this.service,
    required this.localTasks,
    required this.onSync,
    required this.onSynced,
  });

  final GoogleTasksService service;
  final List<Map<String, dynamic>> localTasks;
  final Future<GoogleTasksSyncResult> Function(List<Map<String, dynamic>> tasks)
      onSync;
  final VoidCallback onSynced;

  @override
  State<_GoogleTasksSyncDialog> createState() => _GoogleTasksSyncDialogState();
}

class _GoogleTasksSyncDialogState extends State<_GoogleTasksSyncDialog> {
  GoogleSignInAccount? _user;
  bool _authorized = false;
  bool _initializing = true;
  bool _busy = false;
  String? _error;
  GoogleTasksSyncResult? _result;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await widget.service.initialize(
        onAuthChanged: (user, authorized) {
          if (!mounted) return;
          setState(() {
            _user = user;
            _authorized = authorized;
            _error = null;
          });
        },
        onError: (error) {
          if (!mounted) return;
          setState(() => _error = error.toString());
        },
      );
      if (!mounted) return;
      setState(() {
        _user = widget.service.currentUser;
        _authorized = widget.service.isAuthorized;
        _initializing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _initializing = false;
      });
    }
  }

  Future<void> _connect() async {
    await _run(() async {
      await widget.service.signInAndAuthorize();
      setState(() {
        _user = widget.service.currentUser;
        _authorized = widget.service.isAuthorized;
      });
    });
  }

  Future<void> _authorize() async {
    await _run(() async {
      await widget.service.authorizeTasks();
      setState(() => _authorized = widget.service.isAuthorized);
    });
  }

  Future<void> _sync() async {
    await _run(() async {
      final result = await widget.onSync(widget.localTasks);
      widget.onSynced();
      setState(() => _result = result);
    });
  }

  Future<void> _disconnect() async {
    await _run(() async {
      await widget.service.disconnect();
      setState(() {
        _user = null;
        _authorized = false;
        _result = null;
      });
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Sync Google Tasks'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: _initializing
            ? const SizedBox(
                height: 120,
                child: Center(child: ExpressiveLoadingIndicator()),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_error != null) ...[
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (!AppConfig.googleApisConfigured)
                    const Text(
                      'Add GOOGLE_OAUTH_CLIENT_ID to .env and enable the Google Tasks API.',
                    )
                  else if (_user == null) ...[
                    const Text(
                      'Connect Google to sync this Todo list with a Project BluePill list in Google Tasks.',
                    ),
                    const SizedBox(height: 14),
                    if (kIsWeb)
                      googleCalendarSignInButton(
                        onPressed: _connect,
                        label: 'Connect Google Tasks',
                      )
                    else
                      FilledButton.icon(
                        onPressed: _busy ? null : _connect,
                        icon: _busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: ExpressiveLoadingIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.task_alt),
                        label: const Text('Connect Google Tasks'),
                      ),
                  ] else if (!_authorized) ...[
                    Text('Connected as ${_user!.email}.'),
                    const SizedBox(height: 14),
                    FilledButton.icon(
                      onPressed: _busy ? null : _authorize,
                      icon: _busy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: ExpressiveLoadingIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.verified_user_outlined),
                      label: const Text('Allow Tasks access'),
                    ),
                  ] else ...[
                    Text('Connected as ${_user!.email}.'),
                    const SizedBox(height: 8),
                    const Text(
                      'Sync creates or updates tasks in the Project BluePill Google Tasks list and imports Google tasks back here.',
                    ),
                    if (_result != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _result!.message,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ],
                ],
              ),
      ),
      actions: [
        if (_user != null)
          TextButton.icon(
            onPressed: _busy ? null : _disconnect,
            icon: const Icon(Icons.link_off),
            label: const Text('Disconnect'),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        if (_authorized)
          FilledButton.icon(
            onPressed: _busy ? null : _sync,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: ExpressiveLoadingIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
            label: const Text('Sync now'),
          ),
      ],
    );
  }
}
