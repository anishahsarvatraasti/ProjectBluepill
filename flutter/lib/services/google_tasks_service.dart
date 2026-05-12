import 'dart:async';

import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/tasks/v1.dart' as google_tasks;
import 'package:googleapis_auth/googleapis_auth.dart' as google_auth;

import 'google_api_auth_service.dart';

typedef TasksAuthChanged = FutureOr<void> Function(
  GoogleSignInAccount? user,
  bool authorized,
);

class GoogleTasksService {
  GoogleTasksService();

  static const List<String> tasksScopes = [
    google_tasks.TasksApi.tasksScope,
  ];

  final GoogleSignIn _signIn = GoogleApiAuthService.signIn;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _authSubscription;
  GoogleSignInAccount? _currentUser;
  GoogleSignInClientAuthorization? _authorization;
  google_auth.AuthClient? _authClient;
  google_tasks.TasksApi? _tasksApi;

  GoogleSignInAccount? get currentUser => _currentUser;

  bool get isAuthorized => _authorization != null;

  Future<void> initialize({
    required TasksAuthChanged onAuthChanged,
    required void Function(Object error) onError,
  }) async {
    await GoogleApiAuthService.initialize();

    await _authSubscription?.cancel();
    _authSubscription = _signIn.authenticationEvents.listen((event) async {
      try {
        switch (event) {
          case GoogleSignInAuthenticationEventSignIn():
            await _setUser(event.user);
          case GoogleSignInAuthenticationEventSignOut():
            _clearAuthClient();
            _currentUser = null;
            _authorization = null;
        }
        await onAuthChanged(_currentUser, isAuthorized);
      } catch (error) {
        onError(error);
      }
    }, onError: onError);

    final lightweight = _signIn.attemptLightweightAuthentication();
    if (lightweight != null) {
      final user = await lightweight;
      if (user != null) {
        await _setUser(user);
        await onAuthChanged(_currentUser, isAuthorized);
      }
    }
  }

  Future<void> signInAndAuthorize() async {
    GoogleSignInAccount? user = _currentUser;
    if (user == null) {
      if (!_signIn.supportsAuthenticate()) {
        throw UnsupportedError(
          'Use the Google sign-in button before authorizing Tasks.',
        );
      }
      user = await _signIn.authenticate(scopeHint: tasksScopes);
      await _setUser(user);
    }
    await authorizeTasks();
  }

  Future<void> authorizeTasks() async {
    final user = _currentUser;
    if (user == null) {
      throw StateError('Connect a Google account first.');
    }
    final authorization =
        await user.authorizationClient.authorizeScopes(tasksScopes);
    _setAuthorization(authorization);
  }

  Future<google_tasks.TaskList> getOrCreateSyncTaskList() async {
    final api = _requireApi();
    final lists = await api.tasklists.list(maxResults: 100);
    google_tasks.TaskList? existing;
    for (final list in lists.items ?? <google_tasks.TaskList>[]) {
      if (list.title == 'Project BluePill') {
        existing = list;
        break;
      }
    }
    if (existing != null && existing.id != null) return existing;
    return api.tasklists.insert(
      google_tasks.TaskList(title: 'Project BluePill'),
    );
  }

  Future<List<google_tasks.Task>> listTasks(String taskListId) async {
    final api = _requireApi();
    final tasks = <google_tasks.Task>[];
    String? pageToken;
    do {
      final page = await api.tasks.list(
        taskListId,
        maxResults: 100,
        pageToken: pageToken,
        showCompleted: true,
        showDeleted: false,
        showHidden: true,
      );
      tasks.addAll(page.items ?? []);
      pageToken = page.nextPageToken;
    } while (pageToken != null);
    return tasks.where((task) => task.deleted != true).toList(growable: false);
  }

  Future<google_tasks.Task> createTask(
    String taskListId,
    GoogleTaskDraft draft,
  ) async {
    final api = _requireApi();
    return api.tasks.insert(_taskFromDraft(draft), taskListId);
  }

  Future<google_tasks.Task> updateTask(
    String taskListId,
    String taskId,
    GoogleTaskDraft draft,
  ) async {
    final api = _requireApi();
    return api.tasks.patch(_taskFromDraft(draft), taskListId, taskId);
  }

  Future<void> deleteTask(String taskListId, String taskId) async {
    final api = _requireApi();
    await api.tasks.delete(taskListId, taskId);
  }

  Future<void> disconnect() async {
    await _signIn.disconnect();
    _clearAuthClient();
    _currentUser = null;
    _authorization = null;
  }

  Future<void> dispose() async {
    await _authSubscription?.cancel();
    _clearAuthClient();
  }

  Future<void> _setUser(GoogleSignInAccount user) async {
    _currentUser = user;
    final authorization =
        await user.authorizationClient.authorizationForScopes(tasksScopes);
    if (authorization == null) {
      _clearAuthClient();
      _authorization = null;
      return;
    }
    _setAuthorization(authorization);
  }

  void _setAuthorization(GoogleSignInClientAuthorization authorization) {
    _clearAuthClient();
    _authorization = authorization;
    _authClient = authorization.authClient(scopes: tasksScopes);
    _tasksApi = google_tasks.TasksApi(_authClient!);
  }

  void _clearAuthClient() {
    _authClient?.close();
    _authClient = null;
    _tasksApi = null;
  }

  google_tasks.TasksApi _requireApi() {
    final api = _tasksApi;
    if (api == null) {
      throw StateError('Authorize Google Tasks access first.');
    }
    return api;
  }

  google_tasks.Task _taskFromDraft(GoogleTaskDraft draft) {
    return google_tasks.Task(
      title: draft.title,
      notes: draft.notes,
      due: draft.dueDate == null ? null : _googleDueDate(draft.dueDate!),
      status: draft.completed ? 'completed' : 'needsAction',
      completed: draft.completed
          ? (draft.completedAt ?? DateTime.now()).toUtc().toIso8601String()
          : null,
    );
  }

  String _googleDueDate(DateTime date) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    return utcDate.toIso8601String();
  }
}

class GoogleTaskDraft {
  const GoogleTaskDraft({
    required this.title,
    required this.notes,
    required this.dueDate,
    required this.completed,
    required this.completedAt,
  });

  final String title;
  final String notes;
  final DateTime? dueDate;
  final bool completed;
  final DateTime? completedAt;
}
