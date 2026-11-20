import 'package:flutter_test/flutter_test.dart';
import 'package:inhahub/models/models.dart';
import 'package:inhahub/services/timetable_service.dart';

void main() {
  test('Assignment isSubmitted detects submitted statuses', () {
    const a1 = Assignment(
      id: '1::HW1',
      courseId: '1',
      courseName: 'CS',
      name: 'HW1',
      due: '2026-11-25',
      status: 'Submitted for grading',
    );
    const a2 = Assignment(
      id: '1::HW2',
      courseId: '1',
      courseName: 'CS',
      name: 'HW2',
      due: '2026-11-26',
      status: 'No submission',
    );
    expect(a1.isSubmitted, isTrue);
    expect(a2.isSubmitted, isFalse);
  });

  test('TimetableService filters entries by class and day', () {
    const entries = [
      ScheduleEntry(
        cardId: 'c1',
        lessonId: 'l1',
        days: ['Mon', 'Wed'],
        periodStart: '09:00',
        periodEnd: '10:30',
        subject: 'Algorithms',
        teachers: ['Prof A'],
        classes: ['SOCIE 22-01'],
        classrooms: ['B201'],
      ),
    ];
    final byClass = TimetableService.filterByClass(entries, 'socie 22-01');
    expect(byClass.length, 1);
    expect(TimetableService.filterByDay(byClass, 'Mon').length, 1);
    expect(TimetableService.filterByDay(byClass, 'Tue').length, 0);
  });
}
