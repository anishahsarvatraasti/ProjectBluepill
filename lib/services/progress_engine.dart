import '../models/model_helpers.dart';

class ProgressEngine {
  static int calculateLifeScore({
    required int tasksCompleted,
    required int tasksMissed,
    required int habitsCompleted,
    required int habitsMissed,
    required int? focusScore,
    required bool reflectionCompleted,
  }) {
    final totalTasks = tasksCompleted + tasksMissed;
    final totalHabits = habitsCompleted + habitsMissed;

    final taskPoints =
        totalTasks == 0 ? 0 : (tasksCompleted / totalTasks * 40).round();
    final habitPoints =
        totalHabits == 0 ? 0 : (habitsCompleted / totalHabits * 30).round();
    final normalizedFocus = focusScore?.clamp(0, 10).toInt();
    final focusPoints =
        normalizedFocus == null ? 0 : ((normalizedFocus / 10) * 20).round();
    final reflectionPoints = reflectionCompleted ? 10 : 0;

    return (taskPoints + habitPoints + focusPoints + reflectionPoints)
        .clamp(0, 100)
        .toInt();
  }

  static Map<String, dynamic> buildDailyProgressLog({
    required String userId,
    required List<Map<String, dynamic>> todayTasks,
    required List<Map<String, dynamic>> todayHabitLogs,
    required List<Map<String, dynamic>> todayCheckins,
    Map<String, dynamic>? extracted,
  }) {
    final completedTasks =
        todayTasks.where((task) => task['status'] == 'completed').length;
    final missedTasks =
        todayTasks.where((task) => task['status'] == 'missed').length;
    final completedHabits =
        todayHabitLogs.where((log) => log['status'] == 'completed').length;
    final missedHabits =
        todayHabitLogs.where((log) => log['status'] == 'missed').length;

    final extractedCompletedTasks =
        (extracted?['completed_tasks'] as List?)?.length ?? 0;
    final extractedMissedTasks =
        (extracted?['missed_tasks'] as List?)?.length ?? 0;
    final extractedCompletedHabits =
        (extracted?['habits_completed'] as List?)?.length ?? 0;
    final extractedMissedHabits =
        (extracted?['habits_missed'] as List?)?.length ?? 0;

    final focusScore = intValue(extracted?['focus_score'], -1);
    final normalizedFocus =
        focusScore < 0 ? null : focusScore.clamp(0, 10).toInt();
    final reflectionCompleted = todayCheckins.isNotEmpty || extracted != null;
    final blockerList = extracted?['blockers'];

    final data = <String, dynamic>{
      'user_id': userId,
      'date': dateKey(DateTime.now()),
      'tasks_completed': completedTasks + extractedCompletedTasks,
      'tasks_missed': missedTasks + extractedMissedTasks,
      'habits_completed': completedHabits + extractedCompletedHabits,
      'habits_missed': missedHabits + extractedMissedHabits,
      'focus_score': normalizedFocus,
      'mood': extracted?['mood'],
      'blocker': blockerList is List ? blockerList.join(', ') : null,
      'ai_summary': _summaryFromExtracted(extracted),
    };

    data['life_score'] = calculateLifeScore(
      tasksCompleted: data['tasks_completed'] as int,
      tasksMissed: data['tasks_missed'] as int,
      habitsCompleted: data['habits_completed'] as int,
      habitsMissed: data['habits_missed'] as int,
      focusScore: normalizedFocus,
      reflectionCompleted: reflectionCompleted,
    );

    return data;
  }

  static String? _summaryFromExtracted(Map<String, dynamic>? extracted) {
    if (extracted == null) return null;
    final mood = extracted['mood'];
    final lesson = extracted['lesson'];
    final adjustment = extracted['tomorrow_adjustment'];
    final parts = [
      if (mood != null) 'Mood: $mood',
      if (lesson != null) 'Lesson: $lesson',
      if (adjustment != null) 'Tomorrow: $adjustment',
    ];
    return parts.isEmpty ? null : parts.join('. ');
  }
}
