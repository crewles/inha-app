import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:inhahub/models/models.dart';
import 'package:inhahub/services/app_logger.dart';
import 'package:inhahub/services/eclass_service.dart';
import 'package:inhahub/services/gpa_calculator.dart';
import 'package:inhahub/services/timetable_service.dart';
import 'package:inhahub/services/update_service.dart';
import 'package:inhahub/state/app_state.dart';
import 'package:inhahub/ui/screens/assignment_detail_screen.dart';
import 'package:inhahub/ui/screens/assignments_screen.dart';
import 'package:inhahub/ui/screens/course_detail_screen.dart';
import 'package:inhahub/ui/screens/courses_screen.dart';
import 'package:inhahub/ui/screens/drafts_screen.dart';
import 'package:inhahub/ui/screens/gpa_calculator_screen.dart';
import 'package:inhahub/ui/screens/home_shell.dart';
import 'package:inhahub/ui/screens/ins_screen.dart';
import 'package:inhahub/ui/screens/login_screen.dart';
import 'package:inhahub/ui/screens/logs_screen.dart';
import 'package:inhahub/ui/screens/privacy_policy_screen.dart';
import 'package:inhahub/ui/screens/settings_screen.dart';
import 'package:inhahub/ui/screens/timetable_screen.dart';
import 'package:inhahub/ui/screens/widget_gallery_screen.dart';
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
    const c3 = Course(
      id: '103',
      name: 'Computer Networks',
      isCurrent: true,
      overviewGrade: '91.0%',
    );
    courses = [c1, c2, c3];

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
        intro: 'Implement left-leaning red-black tree rotation primitives.',
        maxPoints: '20',
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
        feedbackComment: 'Clean O(h) rotation logic!',
        submittedFiles: [
          AssignmentFile(
            name: 'bst_solution.cpp',
            link: 'https://example.com/bst_solution.cpp',
            size: 4200,
          ),
        ],
      ),
    ];

    syllabusWeightsByCourse['103'] = const [
      SyllabusWeight(courseId: '103', label: 'Midterm', percentage: 30),
      SyllabusWeight(courseId: '103', label: 'Final', percentage: 40),
      SyllabusWeight(courseId: '103', label: 'Assignments', percentage: 20),
      SyllabusWeight(courseId: '103', label: 'Attendance', percentage: 10),
    ];
    gradesByCourse['103'] = const [
      GradeItem(
        courseId: '103',
        name: 'Quiz 1',
        value: '18.00',
        category: 'Quizzes',
        weight: '-',
        range: '0-20',
        percentage: '90.00 %',
        itemType: 'item',
      ),
      GradeItem(
        courseId: '103',
        name: 'Course total',
        value: '91.00',
        range: '0-100',
        percentage: '91.00 %',
        itemType: 'total',
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
    AppLogger.instance.enabled = updated.diagnosticsEnabled;
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
  Future<void> syncPrivateFiles({bool silent = false}) async {}

  @override
  Future<bool> syncIns({bool silent = false}) async => true;

  @override
  Future<void> syncTimetable({bool silent = false}) async {}

  @override
  Future<void> autoDetectTimetableGroupIfNeeded({
    bool refreshHints = false,
  }) async {}

  @override
  Future<int> getDownloadsCacheBytes() async => downloadsBytes;

  @override
  Future<void> clearCache() async {
    downloadsBytes = 0;
    courses = [];
    allAssignments = [];
    eclassPrivateFiles = [];
    insData = null;
    timetableEntries = [];
    notifyListeners();
  }

  @override
  Future<void> setAssignmentHidden(String assignmentId, bool hidden) async {
    if (hidden) {
      hiddenAssignmentIds.add(assignmentId);
    } else {
      hiddenAssignmentIds.remove(assignmentId);
    }
    notifyListeners();
  }

  @override
  Future<UpdateCheckResult> checkForUpdate({bool silent = false}) async {
    return const UpdateCheckResult(status: UpdateCheckStatus.upToDate);
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

  test(
      'TimetableService.matchCourse matches subjects and guards numeric levels',
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

  test(
      'formatGpa, formatCredits, and formatPersonName normalize portal strings',
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

  testWidgets(
      'LoginScreen renders 2 fields, unified password note, and switches language',
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
    expect(find.text('Syllabus'), findsAtLeastNWidgets(1));
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

  testWidgets(
      'CourseDetailScreen renders Stitch Assignments, Grades, Attendance, and Files tabs',
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
    expect(find.byKey(const ValueKey('assign_menu_101::1')), findsOneWidget);

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

  test(
      'EclassService.parseSyllabusWeightsHtml extracts horizontal & vertical weights',
      () {
    const horizontalHtml = '''
      <table>
        <tr><th>출석(Attendance)</th><th>중간(Midterm)</th><th>기말(Final)</th><th>과제(Assignment)</th></tr>
        <tr><td>10%</td><td>30%</td><td>40%</td><td>20%</td></tr>
      </table>
    ''';
    final hWeights =
        EclassService.parseSyllabusWeightsHtml(horizontalHtml, '101');
    expect(hWeights.length, 4);
    expect(hWeights[0].label, 'Attendance');
    expect(hWeights[1].percentage, 30.0);

    const verticalHtml = '''
      <table>
        <tr><td>Midterm</td><td>35 %</td></tr>
        <tr><td>Final Exam</td><td>45 %</td></tr>
        <tr><td>Project</td><td>20 %</td></tr>
        <tr><td>Total</td><td>100 %</td></tr>
      </table>
    ''';
    final vWeights =
        EclassService.parseSyllabusWeightsHtml(verticalHtml, '102');
    expect(vWeights.length, 3);
    expect(vWeights[2].label, 'Project');
    expect(vWeights[2].percentage, 20.0);

    const unrelatedHtml = '''
      <table>
        <tr><td>Week 1</td><td>2 hours</td></tr>
        <tr><td>Week 2</td><td>3 hours</td></tr>
      </table>
    ''';
    expect(
      EclassService.parseSyllabusWeightsHtml(unrelatedHtml, '103'),
      isEmpty,
    );
  });

  test('TimetableService.matchSubjectToCourse & UpdateService.compareVersions',
      () {
    const courses = [
      Course(id: '1', name: 'Data Structures & Algorithms', isCurrent: true),
      Course(id: '2', name: 'Calculus 1', isCurrent: true),
    ];
    final m1 = TimetableService.matchSubjectToCourse('Data Structure', courses);
    expect(m1?.id, '1');
    expect(
        TimetableService.matchSubjectToCourse('Calculus 2', courses), isNull);

    expect(UpdateService.compareVersions('1.0.3', '1.0.2'), greaterThan(0));
    expect(UpdateService.compareVersions('v1.1.0', '1.0.9'), greaterThan(0));
    expect(UpdateService.compareVersions('1.0.3+4', '1.0.3'), 0);
    expect(UpdateService.compareVersions('1.0.1', '1.0.3'), lessThan(0));
  });

  testWidgets(
      'AssignmentDetailScreen renders problem statement, max pts, honor code, and hide action',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(
      _wrap(app, AssignmentDetailScreen(assignment: app.allAssignments.first)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Assignment 4: Red-Black Trees'), findsOneWidget);
    expect(find.text('20 Pts Max'), findsOneWidget);
    expect(
      find.text('Implement left-leaning red-black tree rotation primitives.'),
      findsOneWidget,
    );
    expect(find.text('spec.pdf'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ad_toggle_hide_btn')));
    await tester.pumpAndSettle();
    expect(app.isAssignmentHidden('101::1'), isTrue);
    expect(find.text('Hidden'), findsOneWidget);
  });

  testWidgets(
      'AssignmentsScreen hide/restore deadline and Completion Breakdown sheet work',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const AssignmentsScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('completion_pace_card')));
    await tester.pumpAndSettle();
    expect(find.text('Completion Breakdown'), findsOneWidget);
    expect(find.text('BY COURSE'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('assign_menu_101::1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle_hide_101::1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('filter_hidden')), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('filter_hidden')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter_hidden')));
    await tester.pumpAndSettle();
    expect(find.text('Assignment 4: Red-Black Trees'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assign_menu_101::1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toggle_hide_101::1')));
    await tester.pumpAndSettle();
    expect(app.isAssignmentHidden('101::1'), isFalse);
  });

  testWidgets(
      'CourseDetailScreen initialTab opens Grades with From Syllabus fallback and simulator',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(
      _wrap(app, CourseDetailScreen(course: app.courses[2], initialTab: 1)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Syllabus Weight Breakdown'), findsOneWidget);
    expect(find.text('From Syllabus'), findsOneWidget);

    final verticalScroll = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    final btn = find.byKey(const ValueKey('cd_open_gpa_calc_btn'));
    await tester.scrollUntilVisible(
      btn,
      250,
      scrollable: verticalScroll,
    );
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(find.text('GPA Calculator'), findsOneWidget);
    expect(find.text('COURSE SCORE SIMULATOR'), findsOneWidget);
  });

  test(
      'Syllabus parser handles hyphenated Mid-term, rowspan headers, and 100% totals',
      () {
    const inha65Html = '''
      <table>
        <tr>
          <th rowspan="2">Evaluation Ratio</th>
          <th>Mid-term</th>
          <th>Final</th>
          <th>Attendance</th>
          <th>Assignments</th>
          <th>Quiz</th>
          <th>Discussion</th>
          <th>Total</th>
        </tr>
        <tr>
          <td>35%</td>
          <td>40%</td>
          <td>5%</td>
          <td>5%</td>
          <td>10%</td>
          <td>5%</td>
          <td>100%</td>
        </tr>
      </table>
    ''';
    final w1 = EclassService.parseSyllabusWeightsHtml(inha65Html, '2577');
    final sum1 = w1.fold<double>(0, (acc, e) => acc + e.percentage);
    expect(sum1, 100.0);
    expect(w1.any((e) => e.label == 'Midterm' && e.percentage == 35.0), isTrue);

    const inha60Html = '''
      <table>
        <tr><th>Mid-Term Exam</th><th>Final Exam</th><th>Discussion</th><th>Total</th></tr>
        <tr><td>40</td><td>50</td><td>10</td><td>100</td></tr>
      </table>
    ''';
    final w2 = EclassService.parseSyllabusWeightsHtml(inha60Html, '2566');
    final sum2 = w2.fold<double>(0, (acc, e) => acc + e.percentage);
    expect(sum2, 100.0);
    expect(w2.firstWhere((e) => e.label == 'Midterm').percentage, 40.0);
  });

  test(
      'Assignment treats graded offline items as completed and sorts pending recent-first',
      () {
    const offlineExam = Assignment(
      id: '2566::14199',
      assignId: 14199,
      courseId: '2566',
      courseName: 'Engineering Mathematics',
      name: 'Mid Exam',
      due: '',
      dueTimestamp: 0,
      status: 'No submission',
      grade: '24',
      gradeMax: '30',
    );
    expect(offlineExam.isSubmitted, isTrue);
    expect(offlineExam.isGradedOnly, isTrue);

    final now = 1795000000;
    final items = [
      Assignment(
        id: '1',
        assignId: 1,
        courseId: '1',
        courseName: 'A',
        name: 'Undated Task',
        due: '',
        dueTimestamp: 0,
        status: 'No submission',
      ),
      Assignment(
        id: '2',
        assignId: 2,
        courseId: '1',
        courseName: 'A',
        name: 'Older Overdue',
        due: '01.11.2026',
        dueTimestamp: now - 86400 * 10,
        status: 'No submission',
      ),
      Assignment(
        id: '3',
        assignId: 3,
        courseId: '1',
        courseName: 'A',
        name: 'Upcoming Next',
        due: '25.11.2026',
        dueTimestamp: now + 3600,
        status: 'No submission',
      ),
      Assignment(
        id: '4',
        assignId: 4,
        courseId: '1',
        courseName: 'A',
        name: 'Recent Overdue',
        due: '15.11.2026',
        dueTimestamp: now - 3600,
        status: 'No submission',
      ),
    ];
    final sorted = Assignment.sortForDisplay(
      items,
      pendingMode: true,
      nowSec: now,
    );
    expect(
      sorted.map((e) => e.name).toList(),
      ['Upcoming Next', 'Recent Overdue', 'Older Overdue', 'Undated Task'],
    );
  });

  test('GpaCalculator computes 4.5-scale semester and projected cumulative GPA',
      () {
    final res = GpaCalculator.calculate(
      currentGpa: 3.96,
      completedCredits: 96,
      courses: const [
        GpaCourseEntry(name: 'Algo', credits: 3, letter: 'A+'), // 13.5
        GpaCourseEntry(name: 'Math', credits: 3, letter: 'A0'), // 12.0
        GpaCourseEntry(name: 'Seminar', credits: 2, letter: 'P'), // excluded
      ],
    );
    expect(res.semesterGradedCredits, 6);
    expect(res.semesterTotalCredits, 8);
    expect(res.semesterGpa, closeTo(4.25, 0.001));
    expect(
        res.projectedCumulativeGpa, closeTo((3.96 * 96 + 25.5) / 102, 0.001));
    expect(res.totalCredits, 104);

    final overall = GpaCalculator.calculateWeightedCoursePercent(const [
      GpaCategorySlider(label: 'Midterm', weightPct: 40, scorePct: 67.5),
      GpaCategorySlider(label: 'Project', weightPct: 10, scorePct: 100.0),
      GpaCategorySlider(label: 'Final', weightPct: 50, scorePct: 80.0),
    ]);
    expect(overall, closeTo(77.0, 0.001));
  });

  testWidgets(
      'GpaCalculatorScreen category sliders & manual grade slider work without header letter badge',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(
      _wrap(
        app,
        GpaCalculatorScreen(
          focusedCourse: app.courses.first,
          focusedGrades: app.gradesByCourse['101'] ?? const [],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('gpa_sim_overall_pct')), findsOneWidget);
    expect(find.byKey(const ValueKey('gpa_cat_slider_0')), findsOneWidget);
    expect(find.byKey(const ValueKey('gpa_cat_slider_1')), findsOneWidget);
    expect(find.byKey(const ValueKey('gpa_cat_slider_2')), findsOneWidget);
    expect(find.byKey(const ValueKey('gpa_sim_grade_slider')), findsOneWidget);
    expect(find.text('Auto'), findsOneWidget);

    final pctBefore = tester
        .widget<Text>(find.byKey(const ValueKey('gpa_sim_overall_pct')))
        .data;
    final catSlider2 = find.byKey(const ValueKey('gpa_cat_slider_2'));
    await tester.ensureVisible(catSlider2);
    await tester.pumpAndSettle();
    await tester.drag(catSlider2, const Offset(-180, 0));
    await tester.pumpAndSettle();
    final pctAfter = tester
        .widget<Text>(find.byKey(const ValueKey('gpa_sim_overall_pct')))
        .data;
    expect(pctAfter, isNot(equals(pctBefore)));

    final gradeSlider = find.byKey(const ValueKey('gpa_sim_grade_slider'));
    await tester.ensureVisible(gradeSlider);
    await tester.pumpAndSettle();
    await tester.drag(gradeSlider, const Offset(220, 0));
    await tester.pumpAndSettle();
    expect(find.text('Manual'), findsOneWidget);
  });

  testWidgets(
      'AssignmentDetailScreen shows No comment from instructor when graded without feedback',
      (tester) async {
    final app = FakeAppState();
    const gradedNoComment = Assignment(
      id: '2566::14199',
      assignId: 14199,
      courseId: '2566',
      courseName: 'Engineering Mathematics',
      name: 'Mid Exam',
      due: '',
      dueTimestamp: 0,
      status: 'No submission',
      grade: '24',
      gradeMax: '30',
      feedbackComment: '',
    );
    await tester.pumpWidget(
      _wrap(app, const AssignmentDetailScreen(assignment: gradedNoComment)),
    );
    await tester.pumpAndSettle();

    expect(find.text('No comment from instructor'), findsOneWidget);
    expect(find.text('No deadline set'), findsNothing);
    expect(find.text('Graded'), findsAtLeastNWidgets(1));
  });

  testWidgets(
      'GpaCalculatorScreen updates projected GPA interactively on grade tap',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const GpaCalculatorScreen()));
    await tester.pumpAndSettle();

    expect(find.text('GPA Calculator'), findsOneWidget);
    final projectedFinder =
        find.byKey(const ValueKey('gpa_calc_projected_value'));
    final initialCum = tester.widget<Text>(projectedFinder).data;

    final verticalScroll = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    final aPlusPill = find.byKey(const ValueKey('gpa_grade_0_A+'));
    await tester.scrollUntilVisible(aPlusPill, 200, scrollable: verticalScroll);
    await tester.ensureVisible(aPlusPill);
    await tester.pumpAndSettle();
    await tester.tap(aPlusPill);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      projectedFinder,
      -200,
      scrollable: verticalScroll,
    );
    await tester.ensureVisible(projectedFinder);
    await tester.pumpAndSettle();
    final updatedCum = tester.widget<Text>(projectedFinder).data;
    expect(updatedCum, isNot(equals(initialCum)));
  });

  testWidgets(
      'Cross-navigation: Courses GPA -> INS tab & Timetable -> CourseDetail',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const CoursesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('courses_glance_card')));
    await tester.pumpAndSettle();
    expect(app.activeTabIndex, 3);

    await tester.pumpWidget(_wrap(app, const TimetableScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data Structure').first);
    await tester.pumpAndSettle();
    expect(find.text('Course Detail'), findsOneWidget);
    expect(find.text('Data Structures & Algorithms'), findsOneWidget);
  });

  testWidgets('WidgetGalleryScreen & SettingsScreen v1.1.0 controls render',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const WidgetGalleryScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Next Lecture Glance'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('pin_widget_next_lecture')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('pin_widget_ins_academic')), findsOneWidget);

    await tester.pumpWidget(_wrap(app, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Haptic feedback'), findsOneWidget);
    expect(find.text('Home Screen Widgets'), findsOneWidget);

    final testNotifBtn = find.byKey(const ValueKey('test_notifications_btn'));
    await tester.scrollUntilVisible(
      testNotifBtn,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(testNotifBtn);
    await tester.pumpAndSettle();
    expect(find.text('Test Notifications'), findsOneWidget);

    await tester.tap(testNotifBtn);
    await tester.pumpAndSettle();
    expect(find.text('Notification Diagnostics'), findsOneWidget);
    expect(find.text('Classes'), findsOneWidget);
    expect(find.text('Deadlines'), findsOneWidget);
    expect(find.text('Scheduled'), findsOneWidget);
    expect(find.byKey(const ValueKey('notif_test_10s_btn')), findsOneWidget);

    Navigator.of(tester.element(find.text('Notification Diagnostics'))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('check_updates_btn')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Check for updates'), findsOneWidget);
    expect(
        find.text('Current version v${UpdateService.currentVersion} • GitHub Releases'),
        findsOneWidget);
  });

  test('Assignment isDraft and isSubmitted classify drafts vs submitted', () {
    const draftEn = Assignment(
      id: '1::D1',
      courseId: '1',
      courseName: 'CS',
      name: 'Draft EN',
      due: '2026-11-25',
      status: 'Draft (not submitted)',
    );
    const draftRu = Assignment(
      id: '1::D2',
      courseId: '1',
      courseName: 'CS',
      name: 'Draft RU',
      due: '2026-11-25',
      status: 'Черновик (не отправлен)',
    );
    const submitted = Assignment(
      id: '1::S1',
      courseId: '1',
      courseName: 'CS',
      name: 'Submitted',
      due: '2026-11-25',
      status: 'Submitted for grading',
    );
    const pending = Assignment(
      id: '1::P1',
      courseId: '1',
      courseName: 'CS',
      name: 'Pending',
      due: '2026-11-25',
      status: 'No submission',
    );
    const graded = Assignment(
      id: '1::G1',
      courseId: '1',
      courseName: 'CS',
      name: 'Graded',
      due: '2026-11-25',
      status: 'Graded',
      grade: '95',
      gradeMax: '100',
    );

    expect(draftEn.isDraft, isTrue);
    expect(draftEn.isSubmitted, isFalse);
    expect(draftRu.isDraft, isTrue);
    expect(draftRu.isSubmitted, isFalse);
    expect(submitted.isDraft, isFalse);
    expect(submitted.isSubmitted, isTrue);
    expect(pending.isDraft, isFalse);
    expect(pending.isSubmitted, isFalse);
    expect(graded.isSubmitted, isTrue);
  });

  test('EclassService.parseUploadResponse decodes text/plain JSON & errors',
      () {
    expect(
      EclassService.parseUploadResponse(
        '[{"itemid":123456,"filename":"hw.pdf"}]',
      ),
      123456,
    );
    expect(
      EclassService.parseUploadResponse([
        {'itemid': 987654},
      ]),
      987654,
    );
    expect(
      () => EclassService.parseUploadResponse('[{"error":"File too large"}]'),
      throwsA(
        isA<EclassException>().having(
          (e) => e.message,
          'message',
          contains('File too large'),
        ),
      ),
    );
    expect(
      () => EclassService.parseUploadResponse(
        '{"error":"Invalid token","errorcode":"invalidtoken"}',
      ),
      throwsA(
        isA<EclassException>().having(
          (e) => e.message,
          'message',
          contains('Invalid token'),
        ),
      ),
    );
    expect(
      () => EclassService.parseUploadResponse('[]'),
      throwsA(isA<EclassException>()),
    );
  });

  test('TimetableService.findNextLesson picks remaining Mon class at 10:20',
      () {
    const lessons = [
      ScheduleEntry(
        cardId: 'c1',
        lessonId: 'l1',
        days: ['Mon'],
        periodStart: '09:30',
        periodEnd: '11:00',
        subject: 'Linear Algebra',
        teachers: ['Askarova Ayjamal'],
        classes: ['CSE25-1'],
        classrooms: ['A203'],
      ),
      ScheduleEntry(
        cardId: 'c2',
        lessonId: 'l2',
        days: ['Mon'],
        periodStart: '11:30',
        periodEnd: '13:00',
        subject: 'Application Programming in Java',
        teachers: ['Tarawade Abhijit'],
        classes: ['CSE25-1'],
        classrooms: ['A606'],
      ),
      ScheduleEntry(
        cardId: 'c3',
        lessonId: 'l3',
        days: ['Mon'],
        periodStart: '13:30',
        periodEnd: '15:00',
        subject: 'Application Programming in Java',
        teachers: ['Tarawade Abhijit'],
        classes: ['CSE25-1'],
        classrooms: ['B102 PC Lab'],
      ),
      ScheduleEntry(
        cardId: 'c4',
        lessonId: 'l4',
        days: ['Tue'],
        periodStart: '08:00',
        periodEnd: '09:30',
        subject: 'Engineering Mathematics',
        teachers: ['Ditta Allah'],
        classes: ['CSE25-1'],
        classrooms: ['B210'],
      ),
    ];

    expect(TimetableService.nowTashkent().isUtc, isFalse);

    final next = TimetableService.findNextLesson(
      lessons,
      nowOverride: DateTime(2026, 11, 23, 10, 20),
    );
    expect(next, isNotNull);
    expect(next!.$1.subject, 'Application Programming in Java');
    expect(next.$2, 'Mon');
    expect(next.$3, 70);

    const defaults = AppSettings();
    expect(defaults.bgSyncEnabled, isTrue);
    expect(defaults.notifyAssignments, isTrue);
  });

  testWidgets('PrivacyPolicyScreen renders guarantees without technical jargon',
      (tester) async {
    final app = FakeAppState();
    await tester.pumpWidget(_wrap(app, const PrivacyPolicyScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Zero Developer Access to Your Data'), findsOneWidget);
    expect(find.textContaining('SQLite'), findsNothing);
    expect(find.textContaining('WorkManager'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('eclass.inha.ac.kr'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('eclass.inha.ac.kr'), findsOneWidget);
    expect(find.text('ins.inha.uz'), findsOneWidget);
    expect(find.text('iut.edupage.org'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('privacy_github_btn')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(const ValueKey('privacy_github_btn')), findsOneWidget);
  });

  testWidgets(
      'DraftsScreen renders eClass drafts, local staged files & filters',
      (tester) async {
    final app = FakeAppState();
    app.allAssignments = [
      ...app.allAssignments,
      const Assignment(
        id: '101::901',
        assignId: 901,
        courseId: '101',
        courseName: 'System Programming',
        name: 'Lab 05 Draft',
        due: '2026-11-28',
        dueTimestamp: 1795860000,
        status: 'Draft (not submitted)',
        submittedFiles: [
          AssignmentFile(
            name: 'lab05_solution.zip',
            link: 'https://eclass.inha.ac.kr/draft_file.zip',
            size: 1024 * 512,
          ),
        ],
      ),
    ];
    app.localDrafts = [
      const LocalDraft(
        id: 1,
        assignmentId: '101::2',
        assignId: 12,
        courseId: '101',
        courseName: 'Data Structures & Algorithms',
        assignmentName: 'Local Project Archive',
        due: '2026-11-30',
        dueTimestamp: 1796030000,
        filePath: '/tmp/bench.tar.gz',
        fileName: 'bench.tar.gz',
        fileSize: 2048 * 1024,
        updatedAt: 1795400000,
      ),
    ];

    await tester.pumpWidget(_wrap(app, const DraftsScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Lab 05 Draft'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Lab 05 Draft'), findsOneWidget);
    expect(find.text('lab05_solution.zip'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Local Project Archive'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Local Project Archive'), findsOneWidget);
    expect(find.text('bench.tar.gz'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('drafts_filter_eclass')),
      -250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('drafts_filter_eclass')));
    await tester.pumpAndSettle();
    expect(find.text('Lab 05 Draft'), findsOneWidget);
    expect(find.text('Local Project Archive'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('drafts_filter_local')));
    await tester.pumpAndSettle();
    expect(find.text('Lab 05 Draft'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Local Project Archive'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Local Project Archive'), findsOneWidget);
  });

  test('AppLogger sanitizes secrets/PII & EclassService validates avatar URLs',
      () async {
    AppLogger.instance.persistToDisk = false;
    await AppLogger.instance.clear();
    AppLogger.instance.enabled = false;

    final cleaned = AppLogger.sanitize(
      'Login U2210001 password=MySecret123 wstoken=abcdef0123456789abcdef0123456789 sesskey=abc123XYZ draftitemid=98765 Cookie: MoodleSession=sess12345',
    );
    expect(cleaned, isNot(contains('MySecret123')));
    expect(cleaned, isNot(contains('U2210001')));
    expect(cleaned, isNot(contains('abcdef0123456789abcdef0123456789')));
    expect(cleaned, isNot(contains('abc123XYZ')));
    expect(cleaned, isNot(contains('98765')));
    expect(cleaned, isNot(contains('sess12345')));
    expect(cleaned, contains('U*******'));
    expect(cleaned, contains('***'));

    AppLogger.instance.info('TEST', 'Should be ignored while opt-in is false');
    expect(AppLogger.instance.entries, isEmpty);

    await AppLogger.instance.recordCrash(
      StateError('Crash for U2210001 token=secret999'),
      StackTrace.current,
    );
    expect(AppLogger.instance.hasPendingCrashPrompt, isTrue);
    expect(AppLogger.instance.entries.length, 1);
    expect(
        AppLogger.instance.entries.first.message, isNot(contains('U2210001')));
    expect(
        AppLogger.instance.entries.first.message, isNot(contains('secret999')));

    final issueUri = AppLogger.instance.buildGithubIssueUri(
      repoWebUrl: 'https://github.com/crewles/inha-app',
      appVersion: '1.2.2',
      platformOverride: 'android',
    );
    expect(issueUri.host, 'github.com');
    expect(issueUri.path, '/crewles/inha-app/issues/new');
    expect(issueUri.queryParameters['labels'], 'bug');
    expect(issueUri.queryParameters['title'], startsWith('[Crash]'));
    expect(issueUri.queryParameters['title'], isNot(contains('U2210001')));
    expect(issueUri.queryParameters['body'], isNot(contains('U2210001')));
    expect(issueUri.queryParameters['body'], isNot(contains('secret999')));
    expect(issueUri.toString().length, lessThan(7500));

    expect(
      EclassService.isCustomAvatarUrl(
          'https://eclass.inha.ac.kr/theme/image.php/coursemosv2/core/123/u/f1'),
      isFalse,
    );
    expect(
      EclassService.isCustomAvatarUrl(
          'https://eclass.inha.ac.kr/pluginfile.php/65509/user/icon/coursemosv2/f1?rev=123'),
      isTrue,
    );

    await AppLogger.instance.clear();
  });

  testWidgets('LogsScreen & HomeShell insistent crash prompt work cleanly',
      (tester) async {
    AppLogger.instance.persistToDisk = false;
    await AppLogger.instance.clear();
    final app = FakeAppState();
    await AppLogger.instance.recordCrash(Exception('Simulated crash'));

    await tester.pumpWidget(_wrap(app, const HomeShell()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('crash_prompt_banner')), findsOneWidget);
    expect(find.byKey(const ValueKey('crash_report_github_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('crash_enable_logs_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('crash_dismiss_btn')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('crash_dismiss_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('crash_prompt_banner')), findsNothing);
    expect(app.settings.diagnosticsEnabled, isFalse);

    await tester.pumpWidget(_wrap(app, const LogsScreen()));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('logs_opt_in_switch')), findsOneWidget);
    expect(find.byKey(const ValueKey('logs_github_issue_btn')), findsOneWidget);
    expect(find.textContaining('Simulated crash'), findsOneWidget);

    await AppLogger.instance.clear();
  });

  test(
      'EclassService.parsePrivateFilesHtml parses M.form_filemanager.init /user/files.php',
      () {
    const html = '''
      <script>
      M.form_filemanager.init(Y, {
        "itemid": 492817362,
        "client_id": "6512a3b4c5d6e",
        "filepath": "/",
        "list": [
          {
            "filename": ".",
            "fullname": "New folder",
            "filepath": "/New folder/",
            "type": "folder",
            "datemodified": 1760605260,
            "date": "16/10/25, 12:01",
            "children": []
          },
          {
            "filename": "03 -Analyzing Space Complexity(1).pptx",
            "fullname": "03 -Analyzing Space Complexity(1).pptx",
            "filepath": "/",
            "size": 46694,
            "filesize": "45.6KB",
            "datemodified": 1793447040,
            "date": "30/10/26, 16:44",
            "mimetype": "Powerpoint presentation",
            "url": "https://eclass.inha.ac.kr/draftfile.php/65509/user/draft/492817362/03%20-Analyzing%20Space%20Complexity%281%29.pptx?forcedownload=1"
          },
          {
            "filename": "ContactForm.java",
            "fullname": "ContactForm.java",
            "filepath": "/",
            "size": 4710,
            "filesize": "4.6KB",
            "datemodified": 1793608200,
            "date": "02/11/26, 13:30",
            "mimetype": "Text file",
            "url": "https://eclass.inha.ac.kr/draftfile.php/65509/user/draft/492817362/ContactForm.java?forcedownload=1"
          }
        ]
      });
      </script>
    ''';

    final parsed = EclassService.parsePrivateFilesHtml(html);
    expect(parsed.length, 2);
    expect(parsed[0].filename, '03 -Analyzing Space Complexity(1).pptx');
    expect(parsed[0].size, 46694);
    expect(parsed[0].sizeText, '45.6KB');
    expect(parsed[0].modifiedText, '30/10/26, 16:44');
    expect(parsed[1].filename, 'ContactForm.java');
    expect(parsed[1].fileType, 'Text file');
  });

  testWidgets('DraftsScreen displays eClass Private Files & unclipped filters',
      (tester) async {
    final app = FakeAppState();
    app.eclassPrivateFiles = const [
      EclassPrivateFile(
        id: '/ContactForm.java',
        filename: 'ContactForm.java',
        filepath: '/',
        size: 4710,
        sizeText: '4.6KB',
        modifiedAt: 1793608200,
        modifiedText: '02/11/26, 13:30',
        downloadUrl: 'https://eclass.inha.ac.kr/draftfile.php/1/ContactForm.java',
        fileType: 'Text file',
      ),
    ];

    await tester.pumpWidget(_wrap(app, const DraftsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('All Drafts (1)'), findsOneWidget);
    expect(find.text('eClass (1)'), findsOneWidget);
    expect(find.text('On Phone (0)'), findsOneWidget);
    expect(find.text('ECLASS SAVED FILES (1)'), findsOneWidget);
    expect(find.text('ContactForm.java'), findsOneWidget);
    expect(find.text('Attach to Assignment'), findsOneWidget);
  });

  test('TimetableService.detectStudentGroup infers exact group from hints & courses',
      () {
    const entries = [
      ScheduleEntry(
        cardId: 'c1',
        lessonId: 'l1',
        days: ['Mon'],
        periodStart: '11:30',
        periodEnd: '13:00',
        subject: 'Application Programming in Java',
        teachers: ['Tarawade Abhijit'],
        classes: ['CSE25-1', 'CSE25-2', 'CSE25-3'],
        classrooms: ['A606'],
      ),
      ScheduleEntry(
        cardId: 'c2',
        lessonId: 'l2',
        days: ['Tue'],
        periodStart: '09:30',
        periodEnd: '11:00',
        subject: 'Academic English 3',
        teachers: ['Khidayatova Gulkhumor'],
        classes: ['CSE25-1', 'CSE25-2', 'CSE25-3'],
        classrooms: ['B204'],
      ),
      ScheduleEntry(
        cardId: 'c3',
        lessonId: 'l3',
        days: ['Mon'],
        periodStart: '09:30',
        periodEnd: '11:00',
        subject: 'Application Programming in Java',
        teachers: ['Dragunov Andrei'],
        classes: ['CSE25-4', 'CSE25-10'],
        classrooms: ['A402'],
      ),
      ScheduleEntry(
        cardId: 'c4',
        lessonId: 'l4',
        days: ['Wed'],
        periodStart: '09:30',
        periodEnd: '11:00',
        subject: 'Signals and Systems',
        teachers: ['Lee Joon'],
        classes: ['ICE25-1'],
        classrooms: ['B101'],
      ),
      ScheduleEntry(
        cardId: 'c5',
        lessonId: 'l5',
        days: ['Thu'],
        periodStart: '09:30',
        periodEnd: '11:00',
        subject: 'Operating Systems',
        teachers: ['Alimov Bekzod'],
        classes: ['CSE24-1'],
        classrooms: ['A304'],
      ),
    ];

    // 1. Direct hint exact & boundary check (CSE25-10 must not match CSE25-1).
    expect(
      TimetableService.detectStudentGroup(
        entries: entries,
        eclassHints: const ['Group: CSE 25-01'],
      ),
      'CSE25-1',
    );
    expect(
      TimetableService.detectStudentGroup(
        entries: entries,
        eclassHints: const ['CSE25-10'],
      ),
      'CSE25-10',
    );

    // 2. Multi-signal inference for CSE25-1 using cohort + courses + profs + section.
    const courses = [
      Course(
        id: '10',
        name: 'Application Programming in Java',
        isCurrent: true,
        professor: 'Abhijit Tarawade',
      ),
      Course(
        id: '11',
        name: 'Academic English 3',
        isCurrent: true,
        professor: 'Gulkhumor Khidayatova',
      ),
    ];
    expect(
      TimetableService.detectStudentGroup(
        entries: entries,
        studentId: 'U2510042',
        insDepartment: 'SOCIE',
        courses: courses,
        eclassHints: const [
          'Application Programming in Java [CSE2112-001]',
          'Academic English 3 (001)',
        ],
      ),
      'CSE25-1',
    );

    // Same professors with section (002) selects CSE25-2.
    expect(
      TimetableService.detectStudentGroup(
        entries: entries,
        studentId: 'U2510042',
        insDepartment: 'SOCIE',
        courses: courses,
        eclassHints: const ['Application Programming in Java [CSE2112-002]'],
      ),
      'CSE25-2',
    );

    // Different professor Dragunov Andrei + section (004) selects CSE25-4.
    expect(
      TimetableService.detectStudentGroup(
        entries: entries,
        studentId: 'U2510042',
        insDepartment: 'SOCIE',
        courses: const [
          Course(
            id: '10',
            name: 'Application Programming in Java',
            isCurrent: true,
            professor: 'Andrei Dragunov',
          ),
        ],
        eclassHints: const ['[CSE2112-004]'],
      ),
      'CSE25-4',
    );

    // Cohort ID alone with no other signals does not blindly guess.
    expect(
      TimetableService.detectStudentGroup(
        entries: entries,
        studentId: 'U2510042',
      ),
      isNull,
    );
  });

  testWidgets(
      'TimetableScreen shows auto-detected group confirmation banner & Yes/No actions',
      (tester) async {
    final app = FakeAppState();
    app.settings = app.settings.copyWith(timetableGroupAutoDetected: true);

    await tester.pumpWidget(_wrap(app, const TimetableScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('auto_group_confirm_banner')),
        findsOneWidget);
    expect(find.text('Group SOCIE 22-01 selected automatically'), findsOneWidget);
    expect(find.text('Is this your group?'), findsOneWidget);

    // Tapping No opens the group picker modal sheet.
    await tester.tap(find.byKey(const ValueKey('auto_group_no_btn')));
    await tester.pumpAndSettle();
    expect(find.text('Search group...'), findsOneWidget);

    Navigator.of(tester.element(find.text('Search group...'))).pop();
    await tester.pumpAndSettle();

    // Tapping Yes confirms and dismisses the banner.
    await tester.tap(find.byKey(const ValueKey('auto_group_yes_btn')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('auto_group_confirm_banner')), findsNothing);
    expect(app.settings.timetableGroupAutoDetected, isFalse);
  });
}
