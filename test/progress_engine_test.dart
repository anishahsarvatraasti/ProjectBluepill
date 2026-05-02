import 'package:flutter_test/flutter_test.dart';
import 'package:project_bluepill/services/progress_engine.dart';

void main() {
  test('calculates life score from weighted components', () {
    final score = ProgressEngine.calculateLifeScore(
      tasksCompleted: 3,
      tasksMissed: 1,
      habitsCompleted: 3,
      habitsMissed: 2,
      focusScore: 7,
      reflectionCompleted: true,
    );

    expect(score, 72);
  });

  test('matches documented life score example', () {
    final score = ProgressEngine.calculateLifeScore(
      tasksCompleted: 75,
      tasksMissed: 25,
      habitsCompleted: 60,
      habitsMissed: 40,
      focusScore: 7,
      reflectionCompleted: true,
    );

    expect(score, 72);
  });
}
