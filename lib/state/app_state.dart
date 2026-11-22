import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/eclass_service.dart';
import '../services/ins_service.dart';
import '../services/notification_service.dart';
import '../services/timetable_service.dart';
import '../services/update_service.dart';
import '../ui/widgets/app_haptics.dart';

class AppState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;
  final EclassService eclass = EclassService();
  final InsService _ins = InsService();
  final TimetableService _timetable = TimetableService();
  final UpdateService _updater = UpdateService();

  bool isInitializing = true;
  bool isSyncing = false;
  bool isInsLoading = false;
  bool isTimetableLoading = false;
  bool isCheckingUpdate = false;
  String? lastError;
  String? insError;

  int activeTabIndex = 0;
  int? _pendingTimetableDay;

  UserCredentials? credentials;
  AppSettings settings = const AppSettings();
  List<Course> courses = [];
  List<Assignment> allAssignments = [];
  Set<String> hiddenAssignmentIds = {};
  final Map<String, List<GradeItem>> gradesByCourse = {};
  final Map<String, List<SyllabusWeight>> syllabusWeightsByCourse = {};
  final Map<String, AttendanceData?> attendanceByCourse = {};
  final Map<String, List<CourseFile>> filesByCourse = {};
  InsGradeData? insData;
  List<ScheduleEntry> timetableEntries = [];
  String timetableLabel = '';
  AppReleaseInfo? availableUpdate;
  bool updateBannerDismissed = false;

  S get s => S(settings.language);
  bool get isLoggedIn => credentials != null;

  List<Course> get visibleCourses {
    if (settings.showAllCourses) return courses;
    final current = courses.where((c) => c.isCurrent).toList();
    return current.isNotEmpty ? current : courses;
  }

  bool isAssignmentHidden(String id) => hiddenAssignmentIds.contains(id);

  List<Assignment> get activeAssignments =>
      allAssignments.where((a) => !hiddenAssignmentIds.contains(a.id)).toList();

  List<Assignment> get hiddenAssignments =>
      allAssignments.where((a) => hiddenAssignmentIds.contains(a.id)).toList();

  void openTab(int index, {int? timetableDay}) {
    activeTabIndex = index.clamp(0, 4);
    if (timetableDay != null) {
      _pendingTimetableDay = timetableDay.clamp(0, 4);
    }
    notifyListeners();
  }

  int? consumePendingTimetableDay() {
    final day = _pendingTimetableDay;
    _pendingTimetableDay = null;
    return day;
  }

  Course? findCourseForSubject(String subject) =>
      TimetableService.matchSubjectToCourse(subject, courses);

  CourseScheduleInfo? courseScheduleFor(Course course) {
    return TimetableService.matchCourse(
      course.name,
      timetableEntries,
      group: settings.timetableGroup,
    );
  }

  ThemeMode get themeMode {
    switch (settings.themeMode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> init() async {
    isInitializing = true;
    notifyListeners();

    settings = await _db.getSettings();
    AppHaptics.enabled = settings.hapticsEnabled;
    credentials = await _db.getCredentials();
    if (credentials != null) {
      eclass.restoreCredentials(credentials!);
    }

    // Load full offline cache from SQLite immediately
    courses = await _db.getCourses();
    allAssignments = await _db.getAssignments();
    hiddenAssignmentIds = await _db.getHiddenAssignmentIds();
    insData = await _db.getInsData();
    timetableEntries = await _db.getTimetableEntries();
    final ttMeta = await _db.getTimetableMeta();
    timetableLabel = ttMeta['label'] ?? '';

    final initialTab = await UpdateService.getInitialTab();
    if (initialTab != null && initialTab >= 0 && initialTab <= 4) {
      activeTabIndex = initialTab;
    }
    UpdateService.setOnOpenTabHandler((tab) {
      if (tab >= 0 && tab <= 4) openTab(tab);
    });

    isInitializing = false;
    notifyListeners();

    await NotificationService.instance.init();
    await _rescheduleAllNotifications();
    await NotificationService.instance.configureBackgroundSync(
      enabled: isLoggedIn && settings.bgSyncEnabled,
      intervalHours: settings.bgSyncIntervalHours,
    );
    await UpdateService.refreshHomeWidgets();

    if (isLoggedIn) {
      syncCourses(silent: true);
      if (insData == null) {
        syncIns(silent: true);
      }
    }
    if (timetableEntries.isEmpty) {
      syncTimetable(silent: true);
    }
    checkForUpdate(silent: true);
  }

  // ── Auth ────────────────────────────────────────────────────

  Future<bool> login({
    required String studentId,
    required String eclassPassword,
    String? insPassword,
  }) async {
    lastError = null;
    final ok = await eclass.login(studentId.trim(), eclassPassword);
    if (!ok) {
      lastError = s.loginFailed;
      notifyListeners();
      return false;
    }

    final cleanIns = (insPassword != null && insPassword.trim().isNotEmpty)
        ? insPassword.trim()
        : null;
    credentials = UserCredentials(
      studentId: studentId.trim(),
      eclassPassword: eclassPassword,
      insPassword: cleanIns,
      eclassToken: eclass.apiToken,
    );
    await _db.saveCredentials(credentials!);
    notifyListeners();

    await syncCourses(silent: true);
    syncAllAssignments();
    syncTimetable(silent: true);
    syncIns(silent: true);
    return true;
  }

  Future<void> saveInsPassword(String password) async {
    if (credentials == null) return;
    final clean = password.trim();
    credentials = credentials!.copyWith(
      insPassword: clean.isEmpty ? null : clean,
      clearInsPassword: clean.isEmpty,
    );
    await _db.saveCredentials(credentials!);
    notifyListeners();
    await syncIns();
  }

  Future<void> logout() async {
    eclass.clearSession();
    await _db.clearAllData();
    await NotificationService.instance
        .configureBackgroundSync(enabled: false, intervalHours: 2);
    credentials = null;
    courses = [];
    allAssignments = [];
    hiddenAssignmentIds = {};
    gradesByCourse.clear();
    syllabusWeightsByCourse.clear();
    attendanceByCourse.clear();
    filesByCourse.clear();
    insData = null;
    lastError = null;
    insError = null;
    activeTabIndex = 0;
    notifyListeners();
    await UpdateService.refreshHomeWidgets();
  }

  // ── eClass Sync ─────────────────────────────────────────────

  Future<void> syncCourses({bool silent = false}) async {
    if (!isLoggedIn) return;
    if (!silent) {
      isSyncing = true;
      notifyListeners();
    }
    try {
      final fetched = await eclass.getCourses();
      if (fetched.isNotEmpty) {
        courses = fetched;
        await _db.saveCourses(fetched);
      }
      if (eclass.apiToken != null &&
          eclass.apiToken != credentials?.eclassToken) {
        credentials = credentials!.copyWith(eclassToken: eclass.apiToken);
        await _db.saveCredentials(credentials!);
      }
      await _updateLastSync();
    } catch (e) {
      lastError = e.toString();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> loadCourseDetailsFromCache(String courseId) async {
    gradesByCourse[courseId] = await _db.getGrades(courseId);
    syllabusWeightsByCourse[courseId] = await _db.getSyllabusWeights(courseId);
    attendanceByCourse[courseId] = await _db.getAttendance(courseId);
    filesByCourse[courseId] = await _db.getCourseFiles(courseId);
    notifyListeners();
  }

  Future<void> syncCourseDetails(Course course) async {
    if (!isLoggedIn) return;
    try {
      final oldAssigns = await _db.getAssignments(courseId: course.id);
      final oldIds = oldAssigns.map((a) => a.id).toSet();
      final oldGrades = await _db.getGrades(course.id);
      final oldGradeMap = {
        for (final g in oldGrades)
          '${g.itemType}::${g.category}::${g.name}': g.value
      };

      final results = await Future.wait([
        eclass.getAssignments(course.id, course.name),
        eclass.getGrades(course.id, overviewGrade: course.overviewGrade),
        eclass.getAttendance(course.id),
        eclass.getCourseFiles(course.id),
        eclass
            .getSyllabusWeights(course.id)
            .catchError((_) => const <SyllabusWeight>[]),
      ]);

      final assigns = results[0] as List<Assignment>;
      final grades = results[1] as List<GradeItem>;
      final attendance = results[2] as AttendanceData?;
      final files = results[3] as List<CourseFile>;
      final weights = results[4] as List<SyllabusWeight>;

      await _db.saveCourseAssignments(course.id, assigns);
      await _db.saveGrades(course.id, grades);
      if (weights.isNotEmpty) {
        await _db.saveSyllabusWeights(course.id, weights);
      }
      if (attendance != null) {
        await _db.saveAttendance(attendance);
      }
      await _db.saveCourseFiles(course.id, files);

      if (oldIds.isNotEmpty && settings.notifyAssignments) {
        for (final a in assigns) {
          if (!oldIds.contains(a.id) && !hiddenAssignmentIds.contains(a.id)) {
            await NotificationService.instance.showNotification(
              id: a.id.hashCode,
              title: course.name,
              body: '${a.name}${a.due.isNotEmpty ? ' • ${a.due}' : ''}',
            );
          }
        }
      }

      if (oldGradeMap.isNotEmpty && settings.notifyGrades) {
        for (final g in grades) {
          if (!g.isItem) continue;
          final v = g.value.trim();
          if (v.isEmpty || v == '-' || v == '—') continue;
          final key = '${g.itemType}::${g.category}::${g.name}';
          final prev = oldGradeMap[key];
          if (prev != v) {
            await NotificationService.instance.showGradeNotification(
              id: ('${course.id}::$key').hashCode,
              title: '${course.name} • ${s.notifyGrades}',
              body: '${g.name}: $v',
            );
          }
        }
      }

      allAssignments = await _db.getAssignments();
      gradesByCourse[course.id] = grades;
      if (weights.isNotEmpty) {
        syllabusWeightsByCourse[course.id] = weights;
      }
      attendanceByCourse[course.id] =
          attendance ?? attendanceByCourse[course.id];
      filesByCourse[course.id] = await _db.getCourseFiles(course.id);
      await _rescheduleDeadlineReminders();
      await UpdateService.refreshHomeWidgets();
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      notifyListeners();
    }
  }

  Future<void> syncAllAssignments() async {
    if (!isLoggedIn) return;
    isSyncing = true;
    notifyListeners();
    try {
      if (courses.isEmpty) {
        await syncCourses(silent: true);
      }
      final oldIds = allAssignments.map((a) => a.id).toSet();
      final targetCourses = visibleCourses;
      final ids = targetCourses.map((c) => c.id).toList();
      final nameMap = {for (final c in courses) c.id: c.name};

      try {
        // Fast single JSON API batch for current courses
        final assigns = await eclass.getAssignmentsViaApi(
          courseIds: ids.isNotEmpty ? ids : null,
          courseNamesById: nameMap,
          fetchStatus: true,
        );
        if (assigns.isNotEmpty) {
          final byCourse = <String, List<Assignment>>{};
          for (final a in assigns) {
            byCourse.putIfAbsent(a.courseId, () => []).add(a);
          }
          for (final entry in byCourse.entries) {
            await _db.saveCourseAssignments(entry.key, entry.value);
          }
        }
      } catch (_) {
        for (final c in targetCourses) {
          try {
            final assigns = await eclass.getAssignments(c.id, c.name);
            await _db.saveCourseAssignments(c.id, assigns);
          } catch (_) {}
        }
      }

      allAssignments = await _db.getAssignments();
      if (oldIds.isNotEmpty && settings.notifyAssignments) {
        for (final a in allAssignments) {
          if (!oldIds.contains(a.id) && !hiddenAssignmentIds.contains(a.id)) {
            await NotificationService.instance.showNotification(
              id: a.id.hashCode,
              title: a.courseName,
              body: '${a.name}${a.due.isNotEmpty ? ' • ${a.due}' : ''}',
            );
          }
        }
      }
      await _rescheduleDeadlineReminders();
      await _updateLastSync();
      await UpdateService.refreshHomeWidgets();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncCourseAssignments(String courseId, String courseName) async {
    if (!isLoggedIn) return;
    isSyncing = true;
    notifyListeners();
    try {
      final assigns = await eclass.getAssignments(courseId, courseName);
      if (assigns.isNotEmpty) {
        await _db.saveCourseAssignments(courseId, assigns);
      }
      allAssignments = await _db.getAssignments();
      await _rescheduleDeadlineReminders();
      await _updateLastSync();
      await UpdateService.refreshHomeWidgets();
    } catch (e) {
      lastError = e.toString();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> syncEverything() async {
    isSyncing = true;
    notifyListeners();
    try {
      await syncCourses(silent: true);
      for (final c in visibleCourses) {
        await syncCourseDetails(c);
      }
      await syncTimetable(silent: true);
      await syncIns(silent: true);
      await _updateLastSync();
    } finally {
      isSyncing = false;
      notifyListeners();
    }
  }

  Future<String> downloadCourseFile(CourseFile file) async {
    final path = await eclass.downloadFile(file.url, file.name);
    await _db.updateFileLocalPath(file.url, path);
    filesByCourse[file.courseId] = await _db.getCourseFiles(file.courseId);
    notifyListeners();
    return path;
  }

  // ── INS Sync (Direct, NO Proxy) ─────────────────────────────

  Future<bool> syncIns({bool silent = false}) async {
    final creds = credentials;
    if (creds == null) return false;
    final pw = creds.effectiveInsPassword;
    if (pw.isEmpty) return false;

    final oldGradeMap = {
      for (final c in (insData?.courses ?? const <InsCourseGrade>[]))
        '${c.yearterm}::${c.courseNumber}::${c.title}': c.grade.trim()
    };

    insError = null;
    if (!silent) {
      isInsLoading = true;
      notifyListeners();
    }
    try {
      final data = await _ins.fetchGradesAndTranscript(creds.studentId, pw);
      if (data != null) {
        insData = data;
        await _db.saveInsData(data);

        if (oldGradeMap.isNotEmpty && settings.notifyGrades) {
          for (final c in data.courses) {
            final g = c.grade.trim();
            if (g.isEmpty || g == '-' || g == '—') continue;
            final key = '${c.yearterm}::${c.courseNumber}::${c.title}';
            if (oldGradeMap[key] != g) {
              await NotificationService.instance.showGradeNotification(
                id: ('ins::$key').hashCode,
                title: 'INS • ${s.notifyGrades}',
                body: '${c.title.isNotEmpty ? c.title : c.courseNumber}: $g',
              );
            }
          }
        }
        await UpdateService.refreshHomeWidgets();
        return true;
      }
      insError = s.insNoData;
      return false;
    } on InsException catch (e) {
      insError = e.message;
      return false;
    } catch (e) {
      insError = e.toString();
      return false;
    } finally {
      isInsLoading = false;
      notifyListeners();
    }
  }

  // ── Timetable Sync ──────────────────────────────────────────

  Future<void> syncTimetable({bool silent = false}) async {
    if (!silent) {
      isTimetableLoading = true;
      notifyListeners();
    }
    try {
      final (entries, ttNum, label) = await _timetable.fetchTimetable();
      timetableEntries = entries;
      timetableLabel = label;
      await _db.saveTimetableEntries(entries, ttNum, label);
      await _rescheduleClassReminders();
      await UpdateService.refreshHomeWidgets();
    } catch (_) {
    } finally {
      isTimetableLoading = false;
      notifyListeners();
    }
  }

  // ── Hidden Deadlines & Updates ──────────────────────────────

  Future<void> setAssignmentHidden(String assignmentId, bool hidden) async {
    await _db.setAssignmentHidden(assignmentId, hidden);
    if (hidden) {
      hiddenAssignmentIds.add(assignmentId);
    } else {
      hiddenAssignmentIds.remove(assignmentId);
    }
    await _rescheduleDeadlineReminders();
    await UpdateService.refreshHomeWidgets();
    notifyListeners();
  }

  Future<UpdateCheckResult> checkForUpdate({bool silent = false}) async {
    if (!silent) {
      isCheckingUpdate = true;
      notifyListeners();
    }
    try {
      final res = await _updater.checkForUpdate();
      if (res.status == UpdateCheckStatus.available) {
        availableUpdate = res.release;
      } else if (res.status == UpdateCheckStatus.upToDate) {
        availableUpdate = null;
      }
      return res;
    } finally {
      isCheckingUpdate = false;
      notifyListeners();
    }
  }

  void dismissUpdateBanner() {
    updateBannerDismissed = true;
    notifyListeners();
  }

  // ── Settings & Reminders ────────────────────────────────────

  Future<void> updateSettings(AppSettings updated) async {
    settings = updated;
    AppHaptics.enabled = updated.hapticsEnabled;
    await _db.saveSetting('theme_mode', updated.themeMode);
    await _db.saveSetting('dynamic_color', updated.dynamicColor.toString());
    await _db.saveSetting('language', updated.language);
    await _db.saveSetting('hide_submitted', updated.hideSubmitted.toString());
    await _db.saveSetting(
        'show_all_courses', updated.showAllCourses.toString());
    await _db.saveSetting(
        'notify_assignments', updated.notifyAssignments.toString());
    await _db.saveSetting('notify_grades', updated.notifyGrades.toString());
    await _db.saveSetting(
        'notify_timetable', updated.notifyTimetable.toString());
    await _db.saveSetting(
        'reminder_offset_minutes', updated.reminderOffsetMinutes.toString());
    await _db.saveSetting('bg_sync_enabled', updated.bgSyncEnabled.toString());
    await _db.saveSetting(
        'bg_sync_interval_hours', updated.bgSyncIntervalHours.toString());
    await _db.saveSetting('timetable_group', updated.timetableGroup);
    await _db.saveSetting('haptics_enabled', updated.hapticsEnabled.toString());
    notifyListeners();

    await _rescheduleAllNotifications();
    await NotificationService.instance.configureBackgroundSync(
      enabled: isLoggedIn && updated.bgSyncEnabled,
      intervalHours: updated.bgSyncIntervalHours,
    );
    await UpdateService.refreshHomeWidgets();
  }

  Future<void> _rescheduleAllNotifications() async {
    await _rescheduleClassReminders();
    await _rescheduleDeadlineReminders();
  }

  Future<void> _rescheduleClassReminders() async {
    final group = settings.timetableGroup;
    final groupEntries = group.isEmpty
        ? <ScheduleEntry>[]
        : TimetableService.filterByClass(timetableEntries, group);
    await NotificationService.instance.rescheduleClassReminders(
      groupEntries: groupEntries,
      enabled: settings.notifyTimetable,
      offsetMinutes: settings.reminderOffsetMinutes,
      isRu: settings.language == 'ru',
    );
  }

  Future<void> _rescheduleDeadlineReminders() async {
    await NotificationService.instance.rescheduleDeadlineReminders(
      assignments: activeAssignments,
      enabled: settings.notifyAssignments,
      isRu: settings.language == 'ru',
    );
  }

  Future<int> getDownloadsCacheBytes() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filesDir = Directory(p.join(dir.path, 'downloads'));
      if (!await filesDir.exists()) return 0;
      int total = 0;
      await for (final entity in filesDir.list(recursive: true)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearCache() async {
    await _db.clearCacheOnly();
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filesDir = Directory(p.join(dir.path, 'downloads'));
      if (await filesDir.exists()) {
        await filesDir.delete(recursive: true);
      }
    } catch (_) {}
    courses = [];
    allAssignments = [];
    gradesByCourse.clear();
    syllabusWeightsByCourse.clear();
    attendanceByCourse.clear();
    filesByCourse.clear();
    insData = null;
    timetableEntries = [];
    timetableLabel = '';
    notifyListeners();
    await UpdateService.refreshHomeWidgets();
  }

  Future<void> _updateLastSync() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    settings = settings.copyWith(lastSyncAt: now);
    await _db.saveSetting('last_sync_at', now.toString());
  }
}
