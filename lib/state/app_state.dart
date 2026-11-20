import 'package:flutter/material.dart';

import '../data/app_database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/eclass_service.dart';
import '../services/ins_service.dart';
import '../services/notification_service.dart';
import '../services/timetable_service.dart';

class AppState extends ChangeNotifier {
  final AppDatabase _db = AppDatabase.instance;
  final EclassService eclass = EclassService();
  final InsService _ins = InsService();
  final TimetableService _timetable = TimetableService();

  bool isInitializing = true;
  bool isSyncing = false;
  bool isInsLoading = false;
  bool isTimetableLoading = false;
  String? lastError;

  UserCredentials? credentials;
  AppSettings settings = const AppSettings();
  List<Course> courses = [];
  List<Assignment> allAssignments = [];
  final Map<String, List<GradeItem>> gradesByCourse = {};
  final Map<String, AttendanceData?> attendanceByCourse = {};
  final Map<String, List<CourseFile>> filesByCourse = {};
  InsGradeData? insData;
  List<ScheduleEntry> timetableEntries = [];
  String timetableLabel = '';

  S get s => S(settings.language);
  bool get isLoggedIn => credentials != null;

  List<Course> get visibleCourses {
    if (settings.showAllCourses) return courses;
    final current = courses.where((c) => c.isCurrent).toList();
    return current.isNotEmpty ? current : courses;
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
    credentials = await _db.getCredentials();
    if (credentials != null) {
      eclass.restoreCredentials(credentials!);
    }

    // Load full offline cache from SQLite immediately
    courses = await _db.getCourses();
    allAssignments = await _db.getAssignments();
    insData = await _db.getInsData();
    timetableEntries = await _db.getTimetableEntries();
    final ttMeta = await _db.getTimetableMeta();
    timetableLabel = ttMeta['label'] ?? '';

    isInitializing = false;
    notifyListeners();

    await NotificationService.instance.init();
    await _rescheduleAllNotifications();
    await NotificationService.instance.configureBackgroundSync(
      enabled: isLoggedIn && settings.bgSyncEnabled,
      intervalHours: settings.bgSyncIntervalHours,
    );

    if (isLoggedIn) {
      syncCourses(silent: true);
    }
    if (timetableEntries.isEmpty) {
      syncTimetable(silent: true);
    }
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
    if (cleanIns != null) {
      syncIns(silent: true);
    }
    return true;
  }

  Future<void> saveInsPassword(String password) async {
    if (credentials == null) return;
    credentials = credentials!.copyWith(
      insPassword: password.trim().isEmpty ? null : password.trim(),
      clearInsPassword: password.trim().isEmpty,
    );
    await _db.saveCredentials(credentials!);
    notifyListeners();
    if (credentials!.insPassword != null) {
      await syncIns();
    }
  }

  Future<void> logout() async {
    eclass.clearSession();
    await _db.clearAllData();
    await NotificationService.instance
        .configureBackgroundSync(enabled: false, intervalHours: 2);
    credentials = null;
    courses = [];
    allAssignments = [];
    gradesByCourse.clear();
    attendanceByCourse.clear();
    filesByCourse.clear();
    insData = null;
    notifyListeners();
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
    attendanceByCourse[courseId] = await _db.getAttendance(courseId);
    filesByCourse[courseId] = await _db.getCourseFiles(courseId);
    notifyListeners();
  }

  Future<void> syncCourseDetails(Course course) async {
    if (!isLoggedIn) return;
    try {
      final oldAssigns = await _db.getAssignments(courseId: course.id);
      final oldIds = oldAssigns.map((a) => a.id).toSet();

      final results = await Future.wait([
        eclass.getAssignments(course.id, course.name),
        eclass.getGrades(course.id, overviewGrade: course.overviewGrade),
        eclass.getAttendance(course.id),
        eclass.getCourseFiles(course.id),
      ]);

      final assigns = results[0] as List<Assignment>;
      final grades = results[1] as List<GradeItem>;
      final attendance = results[2] as AttendanceData?;
      final files = results[3] as List<CourseFile>;

      await _db.saveCourseAssignments(course.id, assigns);
      await _db.saveGrades(course.id, grades);
      if (attendance != null) {
        await _db.saveAttendance(attendance);
      }
      await _db.saveCourseFiles(course.id, files);

      if (oldIds.isNotEmpty && settings.notifyAssignments) {
        for (final a in assigns) {
          if (!oldIds.contains(a.id)) {
            await NotificationService.instance.showNotification(
              id: a.id.hashCode,
              title: course.name,
              body: '${a.name}${a.due.isNotEmpty ? ' • ${a.due}' : ''}',
            );
          }
        }
      }

      allAssignments = await _db.getAssignments();
      gradesByCourse[course.id] = grades;
      attendanceByCourse[course.id] =
          attendance ?? attendanceByCourse[course.id];
      filesByCourse[course.id] = await _db.getCourseFiles(course.id);
      await _rescheduleDeadlineReminders();
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
      await _rescheduleDeadlineReminders();
      await _updateLastSync();
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
      if (credentials?.insPassword != null) {
        await syncIns(silent: true);
      }
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
    if (creds == null ||
        creds.insPassword == null ||
        creds.insPassword!.isEmpty) {
      return false;
    }
    if (!silent) {
      isInsLoading = true;
      notifyListeners();
    }
    try {
      final data = await _ins.fetchGradesAndTranscript(
          creds.studentId, creds.insPassword!);
      if (data != null) {
        insData = data;
        await _db.saveInsData(data);
        return true;
      }
      return false;
    } catch (_) {
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
    } catch (_) {
    } finally {
      isTimetableLoading = false;
      notifyListeners();
    }
  }

  // ── Settings & Reminders ────────────────────────────────────

  Future<void> updateSettings(AppSettings updated) async {
    settings = updated;
    await _db.saveSetting('theme_mode', updated.themeMode);
    await _db.saveSetting('dynamic_color', updated.dynamicColor.toString());
    await _db.saveSetting('language', updated.language);
    await _db.saveSetting('hide_submitted', updated.hideSubmitted.toString());
    await _db.saveSetting('show_all_courses', updated.showAllCourses.toString());
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
    notifyListeners();

    await _rescheduleAllNotifications();
    await NotificationService.instance.configureBackgroundSync(
      enabled: isLoggedIn && updated.bgSyncEnabled,
      intervalHours: updated.bgSyncIntervalHours,
    );
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
      assignments: allAssignments,
      enabled: settings.notifyAssignments,
      isRu: settings.language == 'ru',
    );
  }

  Future<void> clearCache() async {
    await _db.clearCacheOnly();
    courses = [];
    allAssignments = [];
    gradesByCourse.clear();
    attendanceByCourse.clear();
    filesByCourse.clear();
    insData = null;
    timetableEntries = [];
    timetableLabel = '';
    notifyListeners();
  }

  Future<void> _updateLastSync() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    settings = settings.copyWith(lastSyncAt: now);
    await _db.saveSetting('last_sync_at', now.toString());
  }
}
