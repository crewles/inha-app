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
import 'package:inhahub/ui/widgets/expressive_widgets.dart';

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
      GradeItem(
        courseId: '101',
        name: 'P1',
        value: '6.00',
        category: 'Midterm exam',
        weight: '25.00 %',
        range: '0-10',
        percentage: '60.00 %',
        itemType: 'item',
      ),
      GradeItem(
        courseId: '101',
        name: 'P2',
        value: '6.00',
        category: 'Midterm exam',
        weight: '15.00 %',
        range: '0-6',
        percentage: '100.00 %',
        itemType: 'item',
      ),
      GradeItem(
        courseId: '101',
        name: 'Midterm exam SUM',
        value: '27.00',
        category: 'Midterm exam',
        weight: '40.00 %',
        range: '0-40',
        percentage: '67.50 %',
        itemType: 'sum',
      ),
      GradeItem(
        courseId: '101',
        name: 'Discussion',
        value: '10.00',
        category: 'Term Project',
        weight: '100.00 %',
        range: '0-10',
        percentage: '100.00 %',
        itemType: 'item',
      ),
      GradeItem(
        courseId: '101',
        name: 'Term Project SUM',
        value: '10.00',
        category: 'Term Project',
        weight: '10.00 %',
        range: '0-10',
        percentage: '100.00 %',
        itemType: 'sum',
      ),
      GradeItem(
        courseId: '101',
        name: 'Final exam SUM',
        value: '-',
        category: 'Final exam',
        weight: '50.00 %',
        range: '0-0',
        percentage: '-',
        itemType: 'sum',
      ),
      GradeItem(
        courseId: '101',
        name: 'Course total',
        value: '18.50',
        range: '0-50',
        percentage: '37.00 %',
        itemType: 'total',
      ),
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
      CourseFile(
        courseId: '101',
        name: 'Lab9_Starter_Code.zip',
        url: 'https://example.com/lab9.zip',
        size: 840000,
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
          'gpa': '3.960000',
          'credits_acquired': '96.00',
          'credits_attempted': '96.00',
        },
        studentInfo: const {
          'id': 'U2210001',
          'name': 'SIRAZETDINOV ARTEM',
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
        subject: 'Data Structure',
        teachers: ['Prof. Kim Dong-Hyun'],
        classes: ['SOCIE 22-01'],
        classrooms: ['B201 (90)'],
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
        classrooms: ['A304 (45)'],
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

  test('UserCredentials.effectiveInsPassword falls back to eclassPassword', () {
    const cAuto = UserCredentials(
      studentId: 'U2210001',
      eclassPassword: 'eclass_pw',
    );
    const cCustom = UserCredentials(
      studentId: 'U2210001',
      eclassPassword: 'eclass_pw',
      insPassword: 'ins_override',
    );
    expect(cAuto.effectiveInsPassword, 'eclass_pw');
    expect(cCustom.effectiveInsPassword, 'ins_override');
  });

  test('AttendanceRecord.statusType handles nbsp, dashes, and marks', () {
    const rPresent = AttendanceRecord(
      date: '2026-09-09',
      className: '1Class',
      attendance: '○',
      absence: '\u00A0',
      late: '-',
      others: '',
    );
    const rAbsent = AttendanceRecord(
      date: '2026-10-23',
      className: '14Class',
      attendance: '\u00A0',
      absence: '○',
      late: '',
      others: '',
    );
    const rLate = AttendanceRecord(
      date: '2026-10-25',
      className: '15Class',
      attendance: '-',
      absence: '',
      late: '○',
      others: '',
    );
    const rOther = AttendanceRecord(
      date: '2026-10-26',
      className: '16Class',
      attendance: '\u00A0',
      absence: '-',
      late: '',
      others: '○',
    );
    expect(rPresent.statusType, 'present');
    expect(rAbsent.statusType, 'absent');
    expect(rLate.statusType, 'late');
    expect(rOther.statusType, 'other');
  });

  test('TimetableService.matchCourse matches subjects and guards numeric levels',
      () {
    const entries = [
      ScheduleEntry(
        cardId: 'c1',
        lessonId: 'l1',
        days: ['Mon', 'Wed'],
        periodStart: '10:00',
        periodEnd: '11:30',
        subject: 'Data Structure',
        teachers: ['Prof. Sarvar'],
        classes: ['SOCIE 22-01'],
        classrooms: ['A202 (90)'],
      ),
      ScheduleEntry(
        cardId: 'c2',
        lessonId: 'l2',
        days: ['Tue'],
        periodStart: '13:00',
        periodEnd: '14:30',
        subject: 'Calculus 2',
        teachers: ['Prof. Euler'],
        classes: ['SOCIE 22-01'],
        classrooms: ['B304 (320)'],
      ),
    ];

    final matched = TimetableService.matchCourse(
      'Data Structures & Algorithms',
      entries,
      group: 'SOCIE 22-01',
    );
    expect(matched, isNotNull);
    expect(matched!.teacher, 'Prof. Sarvar');
    expect(matched.classroomSummary, 'A202');

    final wrongLevel = TimetableService.matchCourse(
      'Calculus 1',
      entries,
      group: 'SOCIE 22-01',
    );
    expect(wrongLevel, isNull);
  });

  test('formatGpa, formatCredits, and formatPersonName normalize portal strings',
      () {
    expect(formatGpa('3.960000'), '3.96');
    expect(formatGpa('4'), '4.00');
    expect(formatGpa('—'), '—');

    expect(formatCredits('96.0000'), '96');
    expect(formatCredits('3.50'), '3.5');

    expect(formatPersonName('SIRAZETDINOV'), 'Sirazetdinov');
    expect(formatPersonName('SIRAZETDINOV   ARTEM'), 'Sirazetdinov Artem');
    expect(formatPersonName('KIM DONG-HYUN'), 'Kim Dong-Hyun');
    expect(formatPersonName("O'TKIR"), "O'tkir");
    expect(formatPersonName('McDonald'), 'McDonald');
  });

  testWidgets('LoginScreen renders 2 fields, unified password note, and switches language',
      (tester) async {
    final app = FakeAppState(loggedIn: false);
    await tester.pumpWidget(_wrap(app, const LoginScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Inha App'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Your eClass password is also used for the INS portal.'),
        findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));

    await tester.ensureVisible(find.text('RU'));
    await tester.tap(find.text('RU'));
    await tester.pumpAndSettle();
    expect(find.text('Войти'), findsOneWidget);
  });

  testWidgets('CoursesScreen hides ID and shows matched professor and room',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const CoursesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Data Structures & Algorithms'), findsOneWidget);
    expect(find.textContaining('ID:'), findsNothing);
    expect(find.textContaining('Sirazetdinov'), findsOneWidget);
    expect(find.text('Prof. Kim Dong-Hyun'), findsOneWidget);
    expect(find.textContaining('B201'), findsOneWidget);
    expect(find.text('3.96'), findsOneWidget);
    expect(find.text('3.960000'), findsNothing);
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

  testWidgets('CourseDetailScreen renders Stitch Assignments, Grades, Attendance, and Files tabs',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(
      _wrap(app, CourseDetailScreen(course: app.courses.first)),
    );
    await tester.pumpAndSettle();

    // Header has professor & schedule, no ID
    expect(find.textContaining('ID:'), findsNothing);
    expect(find.text('Prof. Kim Dong-Hyun'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Submit work'), findsOneWidget);
    expect(find.text('Assignment 4: Red-Black Trees'), findsOneWidget);

    // Filter on Assignments tab
    await tester.tap(find.byKey(const ValueKey('cd_assign_filter_graded')));
    await tester.pumpAndSettle();
    expect(find.text('Lab 3: Binary Search Trees'), findsOneWidget);
    expect(find.text('Assignment 4: Red-Black Trees'), findsNothing);

    // Tab 1: Stitch Grades (no Submit work FAB, multi-category breakdown)
    await tester.tap(find.text('Grades'));
    await tester.pumpAndSettle();
    expect(find.text('Submit work'), findsNothing);
    expect(find.text('37.00 %'), findsOneWidget);
    expect(find.text('Syllabus Weight Breakdown'), findsOneWidget);
    expect(find.text('Midterm exam'), findsOneWidget);
    expect(find.text('P1'), findsOneWidget);
    final verticalScroll = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    await tester.scrollUntilVisible(
      find.text('Final exam'),
      250,
      scrollable: verticalScroll,
    );
    expect(find.text('Term Project'), findsOneWidget);
    expect(find.text('Final exam'), findsOneWidget);

    // Tab 2: Attendance
    await tester.tap(find.text('Attendance'));
    await tester.pumpAndSettle();
    expect(find.text('88%'), findsOneWidget);

    // Tab 3: Stitch Files (search, filters, Download all FAB)
    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    expect(find.text('Offline Materials'), findsOneWidget);
    expect(find.text('Download all (1)'), findsOneWidget);
    expect(find.text('Lecture_10_B-Trees.pdf'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cd_file_filter_labs')));
    await tester.pumpAndSettle();
    expect(find.text('Lab9_Starter_Code.zip'), findsOneWidget);
    expect(find.text('Lecture_10_B-Trees.pdf'), findsNothing);
  });

  testWidgets('TimetableScreen renders hero banner and schedule in dark mode',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const TimetableScreen(), dark: true));
    await tester.pumpAndSettle();

    expect(find.text('SOCIE 22-01'), findsOneWidget);
    expect(find.text('Data Structure'), findsAtLeastNWidgets(1));
    expect(find.text('Operating Systems'), findsAtLeastNWidgets(1));
  });

  testWidgets('InsScreen renders hero card and retry/override prompt on error',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const InsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Sirazetdinov Artem'), findsOneWidget);
    expect(find.text('3.96'), findsOneWidget);
    expect(find.text('Computer Algorithms'), findsOneWidget);

    final noInsApp = FakeAppState(withIns: false);
    noInsApp.insError = 'Invalid student ID or INS password';
    await tester.pumpWidget(_wrap(noInsApp, const InsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('Use custom INS password'), findsOneWidget);
  });

  testWidgets('SettingsScreen & HomeShell render Auto/Custom INS badges',
      (tester) async {
    final customApp = FakeAppState(withIns: true);
    await tester.pumpWidget(_wrap(customApp, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Sirazetdinov Artem'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);

    final autoApp = FakeAppState(withIns: false);
    await tester.pumpWidget(_wrap(autoApp, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Auto (eClass)'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Log out of Inha Portal'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Log out of Inha Portal'), findsOneWidget);

    await tester.pumpWidget(_wrap(customApp, const HomeShell()));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
