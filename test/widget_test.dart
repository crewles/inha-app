import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:inhahub/models/models.dart';
import 'package:inhahub/services/timetable_service.dart';
import 'package:inhahub/state/app_state.dart';
import 'package:inhahub/ui/screens/assignments_screen.dart';
import 'package:inhahub/ui/screens/course_detail_screen.dart';
import 'package:inhahub/ui/screens/courses_screen.dart';
import 'package:inhahub/ui/screens/home_shell.dart';
import 'package:inhahub/ui/screens/ins_screen.dart';
import 'package:inhahub/ui/screens/login_screen.dart';
import 'package:inhahub/ui/screens/settings_screen.dart';
import 'package:inhahub/ui/screens/timetable_screen.dart';
import 'package:inhahub/ui/theme/app_theme.dart';

class FakeAppState extends AppState {
  int downloadsBytes = 12 * 1024 * 1024;

  FakeAppState({bool loggedIn = true, bool withIns = true}) {
    isInitializing = false;
    settings = const AppSettings(
      language: 'en',
      timetableGroup: 'SOCIE 22-01',
      bgSyncEnabled: true,
    );
    if (loggedIn) {
      credentials = UserCredentials(
        studentId: 'U2210001',
        eclassPassword: 'secret',
        insPassword: withIns ? 'ins_secret' : null,
      );
    }

    const c1 = Course(
      id: '101',
      name: 'Data Structures & Algorithms',
      isCurrent: true,
      overviewGrade: '97.6%',
    );
    const c2 = Course(
      id: '102',
      name: 'Operating Systems',
      isCurrent: false,
      overviewGrade: '89.4%',
    );
    courses = [c1, c2];

    final soonTs = (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 3600 * 12;
    allAssignments = [
      Assignment(
        id: '101::1',
        assignId: 1,
        courseId: '101',
        courseName: 'Data Structures & Algorithms',
        name: 'Assignment 4: Red-Black Trees',
        due: '21.11.2026 23:59',
        dueTimestamp: soonTs,
        status: 'No submission',
        files: const [
          AssignmentFile(
            name: 'spec.pdf',
            link: 'https://example.com/spec.pdf',
            size: 1400000,
          ),
        ],
      ),
      const Assignment(
        id: '101::2',
        assignId: 2,
        courseId: '101',
        courseName: 'Data Structures & Algorithms',
        name: 'Lab 3: Binary Search Trees',
        due: '10.11.2026 23:59',
        dueTimestamp: 1700000000,
        status: 'Submitted (Graded)',
        grade: '19.5',
        gradeMax: '20',
      ),
    ];

    gradesByCourse['101'] = const [
      GradeItem(courseId: '101', name: 'Midterm Exam', value: '48.5 / 50'),
    ];
    attendanceByCourse['101'] = const AttendanceData(
      courseId: '101',
      attendanceCount: 23,
      absenceCount: 2,
      lateCount: 1,
      othersCount: 0,
      records: [
        AttendanceRecord(
          date: '2026-10-24',
          className: 'Lecture 18',
          attendance: '○',
          absence: '',
          late: '',
          others: '',
        ),
        AttendanceRecord(
          date: '2026-10-17',
          className: 'Lecture 17',
          attendance: '',
          absence: 'X',
          late: '',
          others: '',
        ),
      ],
    );
    filesByCourse['101'] = const [
      CourseFile(
        courseId: '101',
        name: 'Lecture_10_B-Trees.pdf',
        url: 'https://example.com/lec10.pdf',
        size: 5200000,
        localPath: '/tmp/Lecture_10_B-Trees.pdf',
      ),
    ];

    if (withIns) {
      insData = InsGradeData(
        courses: const [
          InsCourseGrade(
            courseNumber: 'CSE301',
            title: 'Computer Algorithms',
            credit: '3.0',
            grade: 'A+',
            courseType: 'Major Core',
            semester: 'Spring 2026',
            professor: 'Prof. Kim',
          ),
          InsCourseGrade(
            courseNumber: 'MTH201',
            title: 'Calculus III',
            credit: '3.0',
            grade: 'B+',
            courseType: 'Elective',
            semester: 'Fall 2025',
          ),
        ],
        gpaInfo: const {
          'gpa': '3.85',
          'credits_acquired': '96',
          'credits_attempted': '96',
        },
        studentInfo: const {
          'id': 'U2210001',
          'name': 'Jasmina Kurbanova',
          'dept': 'SOCIE',
          'grade_year': '3',
          'rank': '12',
        },
        updatedAt: DateTime.now().millisecondsSinceEpoch - 600000,
      );
    }

    timetableEntries = const [
      ScheduleEntry(
        cardId: 'c1',
        lessonId: 'l1',
        days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        periodStart: '09:00',
        periodEnd: '10:30',
        subject: 'Data Structures',
        teachers: ['Prof. Kim Dong-Hyun'],
        classes: ['SOCIE 22-01'],
        classrooms: ['B201'],
      ),
      ScheduleEntry(
        cardId: 'c2',
        lessonId: 'l2',
        days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'],
        periodStart: '11:00',
        periodEnd: '12:30',
        subject: 'Operating Systems',
        teachers: ['Prof. Bekzod Alimov'],
        classes: ['SOCIE 22-01'],
        classrooms: ['A304'],
      ),
    ];
  }

  @override
  Future<void> updateSettings(AppSettings updated) async {
    settings = updated;
    notifyListeners();
  }

  @override
  Future<void> loadCourseDetailsFromCache(String courseId) async {}

  @override
  Future<void> syncCourseDetails(Course course) async {}

  @override
  Future<void> syncCourses({bool silent = false}) async {}

  @override
  Future<void> syncAllAssignments() async {}

  @override
  Future<bool> syncIns({bool silent = false}) async => true;

  @override
  Future<void> syncTimetable({bool silent = false}) async {}

  @override
  Future<int> getDownloadsCacheBytes() async => downloadsBytes;

  @override
  Future<void> clearCache() async {
    downloadsBytes = 0;
    courses = [];
    allAssignments = [];
    insData = null;
    timetableEntries = [];
    notifyListeners();
  }
}

Widget _wrap(AppState state, Widget child, {bool dark = false}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: AppTheme.buildTheme(
        dark ? AppTheme.darkColorScheme : AppTheme.lightColorScheme,
      ),
      home: child,
    ),
  );
}

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

  testWidgets('LoginScreen renders and switches language', (tester) async {
    final app = FakeAppState(loggedIn: false);
    await tester.pumpWidget(_wrap(app, const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Inha App'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.textContaining('Forgot password'), findsNothing);

    await tester.ensureVisible(find.text('RU'));
    await tester.tap(find.text('RU'));
    await tester.pumpAndSettle();
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets('CoursesScreen renders summary and course cards', (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const CoursesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Data Structures & Algorithms'), findsOneWidget);
    expect(find.text('3.85'), findsOneWidget);
    expect(find.text('Syllabus'), findsOneWidget);
  });

  testWidgets('AssignmentsScreen renders progress and filters', (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const AssignmentsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Assignment 4: Red-Black Trees'), findsOneWidget);
    expect(find.text('Submit Solution'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('filter_graded')));
    await tester.pumpAndSettle();
    expect(find.text('Lab 3: Binary Search Trees'), findsOneWidget);
    expect(find.text('Assignment 4: Red-Black Trees'), findsNothing);
  });

  testWidgets('CourseDetailScreen switches pill tabs cleanly', (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(
      _wrap(app, CourseDetailScreen(course: app.courses.first)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assignment 4: Red-Black Trees'), findsOneWidget);

    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();
    expect(find.text('Midterm Exam'), findsOneWidget);

    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();
    expect(find.text('88%'), findsOneWidget);

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('Lecture_10_B-Trees.pdf'), findsOneWidget);
  });

  testWidgets('TimetableScreen renders hero banner and schedule in dark mode',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const TimetableScreen(), dark: true));
    await tester.pumpAndSettle();

    expect(find.text('SOCIE 22-01'), findsOneWidget);
    expect(find.text('Data Structures'), findsAtLeastNWidgets(1));
    expect(find.text('Operating Systems'), findsAtLeastNWidgets(1));
  });

  testWidgets('InsScreen renders hero card, semesters, and password prompt',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const InsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Jasmina Kurbanova'), findsOneWidget);
    expect(find.text('3.85'), findsOneWidget);
    expect(find.text('Computer Algorithms'), findsOneWidget);

    final noInsApp = FakeAppState(withIns: false);
    await tester.pumpWidget(_wrap(noInsApp, const InsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Save & Load'), findsOneWidget);
  });

  testWidgets('SettingsScreen & HomeShell render without errors',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Jasmina Kurbanova'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Log out of Inha Portal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Log out of Inha Portal'), findsOneWidget);

    await tester.pumpWidget(_wrap(app, const HomeShell()));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
