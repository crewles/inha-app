import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/app_database.dart';
import '../l10n/strings.dart';
import '../models/models.dart';
import '../services/ai_review_service.dart';
import '../services/app_logger.dart';
import '../services/eclass_service.dart';
import '../services/ins_service.dart';
import '../services/notification_service.dart';
import '../services/timetable_service.dart';
import '../services/update_service.dart';
import '../ui/screens/assignment_detail_screen.dart';
import '../ui/screens/course_detail_screen.dart';
import '../ui/widgets/app_haptics.dart';

class AppState extends ChangeNotifier {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  final AppDatabase _db = AppDatabase.instance;
  final EclassService eclass = EclassService();
  final InsService _ins = InsService();
  final TimetableService _timetable = TimetableService();
  final UpdateService _updater = UpdateService();
  final AiReviewService aiReviewer = AiReviewService();

  bool isInitializing = true;
  bool isSyncing = false;
  bool isSyncingPrivateFiles = false;
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
  List<EclassPrivateFile> eclassPrivateFiles = [];
  List<LocalDraft> localDrafts = [];
  Set<String> hiddenAssignmentIds = {};
  final Map<String, List<GradeItem>> gradesByCourse = {};
  final Map<String, List<SyllabusWeight>> syllabusWeightsByCourse = {};
  final Map<String, AttendanceData?> attendanceByCourse = {};
  final Map<String, List<CourseFile>> filesByCourse = {};
  final Map<String, AiReviewResult> aiReviewsByAssignment = {};
  InsGradeData? insData;
  List<ScheduleEntry> timetableEntries = [];
  String timetableLabel = '';
  AppReleaseInfo? availableUpdate;
  bool updateBannerDismissed = false;
  String? profileAvatarPath;
  bool hasCustomAvatar = false;
  List<String> _groupHints = [];
  bool _autoDetectInFlight = false;

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

  List<Assignment> get eclassDraftAssignments =>
      activeAssignments.where((a) => a.isDraft).toList();

  int get totalDraftsCount =>
      eclassDraftAssignments.length +
      eclassPrivateFiles.length +
      localDrafts.length;

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

  void handleNotificationPayload(String payload) {
    if (!isLoggedIn) return;
    if (payload.startsWith('assignment::')) {
      final id = payload.substring('assignment::'.length);
      openTab(1);
      final matched = allAssignments.cast<Assignment?>().firstWhere(
            (a) => a?.id == id,
            orElse: () => null,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        nav.popUntil((r) => r.isFirst);
        if (matched != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) => AssignmentDetailScreen(assignment: matched),
            ),
          );
        }
      });
      return;
    }
    if (payload.startsWith('course_grades::')) {
      final cid = payload.substring('course_grades::'.length);
      openTab(0);
      final matched = courses.cast<Course?>().firstWhere(
            (c) => c?.id == cid,
            orElse: () => null,
          );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final nav = navigatorKey.currentState;
        if (nav == null) return;
        nav.popUntil((r) => r.isFirst);
        if (matched != null) {
          nav.push(
            MaterialPageRoute(
              builder: (_) =>
                  CourseDetailScreen(course: matched, initialTab: 1),
            ),
          );
        }
      });
      return;
    }
    if (payload.startsWith('timetable::')) {
      final dayIdx = int.tryParse(payload.substring('timetable::'.length));
      navigatorKey.currentState?.popUntil((r) => r.isFirst);
      openTab(2, timetableDay: dayIdx);
      return;
    }
    if (payload.startsWith('tab::')) {
      final tab = int.tryParse(payload.substring('tab::'.length));
      if (tab != null) {
        navigatorKey.currentState?.popUntil((r) => r.isFirst);
        openTab(tab);
      }
    }
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
    await AppLogger.instance.init(enabled: settings.diagnosticsEnabled);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final customAvatar = await _findCustomAvatarFile(dir);
      if (customAvatar != null) {
        profileAvatarPath = customAvatar.path;
        hasCustomAvatar = true;
      } else {
        final avatarFile = File(p.join(dir.path, 'profile_avatar.jpg'));
        if (await avatarFile.exists()) {
          profileAvatarPath = avatarFile.path;
        }
        hasCustomAvatar = false;
      }
    } catch (_) {}
    credentials = await _db.getCredentials();
    if (credentials != null) {
      eclass.restoreCredentials(credentials!);
    }

    // Load full offline cache from SQLite immediately
    courses = await _db.getCourses();
    allAssignments = await _db.getAssignments();
    eclassPrivateFiles = await _db.getEclassPrivateFiles();
    localDrafts = await _db.getLocalDrafts();
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

    autoDetectTimetableGroupIfNeeded();

    await NotificationService.instance.init();
    NotificationService.instance.setOnPayloadTap(handleNotificationPayload);
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

    await NotificationService.instance.configureBackgroundSync(
      enabled: settings.bgSyncEnabled,
      intervalHours: settings.bgSyncIntervalHours,
    );
    await syncCourses(silent: true);
    syncProfilePhoto();
    syncAllAssignments();
    syncPrivateFiles(silent: true);
    syncTimetable(silent: true);
    syncIns(silent: true);
    return true;
  }

  Future<File?> _findCustomAvatarFile(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          p.basename(entity.path).startsWith('custom_avatar_')) {
        return entity;
      }
    }
    return null;
  }

  Future<void> _deleteCustomAvatarFiles(Directory dir) async {
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is File &&
          p.basename(entity.path).startsWith('custom_avatar_')) {
        await entity.delete();
      }
    }
  }

  Future<void> syncProfilePhoto() async {
    if (!isLoggedIn || hasCustomAvatar) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final targetPath = p.join(dir.path, 'profile_avatar.jpg');
      final path = await eclass.downloadProfilePhoto(targetPath);
      if (path != null) {
        profileAvatarPath = path;
        notifyListeners();
        AppLogger.instance.info('AVATAR', 'Synced eClass profile photo');
      }
    } catch (e) {
      AppLogger.instance.error('AVATAR', 'Failed to sync profile photo', e);
    }
  }

  Future<bool> setCustomAvatar(String sourcePath) async {
    try {
      final src = File(sourcePath);
      if (!await src.exists()) return false;
      final size = await src.length();
      if (size <= 0 || size > 15 * 1024 * 1024) return false;
      final raf = await src.open();
      final List<int> head;
      try {
        head = await raf.read(16);
      } finally {
        await raf.close();
      }
      if (!EclassService.hasValidImageMagicBytes(head)) return false;

      final dir = await getApplicationDocumentsDirectory();
      await _deleteCustomAvatarFiles(dir);
      final rawExt = p.extension(sourcePath).toLowerCase();
      final ext = (rawExt.isNotEmpty && rawExt.length <= 5) ? rawExt : '.jpg';
      final dest = File(
        p.join(
            dir.path, 'custom_avatar_${DateTime.now().millisecondsSinceEpoch}$ext'),
      );
      await src.copy(dest.path);
      profileAvatarPath = dest.path;
      hasCustomAvatar = true;
      notifyListeners();
      AppLogger.instance.info('AVATAR', 'Updated custom profile photo');
      return true;
    } catch (e) {
      AppLogger.instance.error('AVATAR', 'Failed to set custom avatar', e);
      return false;
    }
  }

  Future<void> resetCustomAvatar() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      await _deleteCustomAvatarFiles(dir);
      hasCustomAvatar = false;
      final eclassFile = File(p.join(dir.path, 'profile_avatar.jpg'));
      final hasEclass = await eclassFile.exists();
      if (hasEclass) {
        try {
          await FileImage(eclassFile).evict();
        } catch (_) {}
      }
      profileAvatarPath = hasEclass ? eclassFile.path : null;
      notifyListeners();
      AppLogger.instance.info('AVATAR', 'Reset custom profile photo');
      syncProfilePhoto();
    } catch (e) {
      AppLogger.instance.error('AVATAR', 'Failed to reset custom avatar', e);
    }
  }

  Future<String?> uploadProfilePhotoToEclass(String sourcePath) async {
    if (!isLoggedIn) return 'Not signed in';
    try {
      await eclass.uploadProfilePhoto(sourcePath);
      try {
        final dir = await getApplicationDocumentsDirectory();
        final eclassCache = File(p.join(dir.path, 'profile_avatar.jpg'));
        await File(sourcePath).copy(eclassCache.path);
        await FileImage(eclassCache).evict();
      } catch (_) {}
      AppLogger.instance.info('AVATAR', 'Uploaded profile photo to eClass');
      return null;
    } catch (e) {
      AppLogger.instance
          .error('AVATAR', 'Failed to upload profile photo to eClass', e);
      return e.toString();
    }
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
    try {
      final dir = await getApplicationDocumentsDirectory();
      final stagedDir = Directory(p.join(dir.path, 'staged_drafts'));
      if (await stagedDir.exists()) {
        await stagedDir.delete(recursive: true);
      }
      final downloadsDir = Directory(p.join(dir.path, 'downloads'));
      if (await downloadsDir.exists()) {
        await downloadsDir.delete(recursive: true);
      }
      final avatarFile = File(p.join(dir.path, 'profile_avatar.jpg'));
      if (await avatarFile.exists()) {
        await avatarFile.delete();
      }
      await _deleteCustomAvatarFiles(dir);
    } catch (_) {}
    await AppLogger.instance.clear();
    await NotificationService.instance
        .configureBackgroundSync(enabled: false, intervalHours: 2);
    settings = settings.copyWith(
      timetableGroup: '',
      timetableGroupAutoDetected: false,
      aiApiKey: '',
    );
    await _db.saveSetting('timetable_group', '');
    await _db.saveSetting('timetable_group_auto_detected', 'false');
    await _db.saveSetting('ai_api_key', '');
    credentials = null;
    profileAvatarPath = null;
    hasCustomAvatar = false;
    _groupHints = [];
    courses = [];
    allAssignments = [];
    eclassPrivateFiles = [];
    localDrafts = [];
    hiddenAssignmentIds = {};
    gradesByCourse.clear();
    syllabusWeightsByCourse.clear();
    attendanceByCourse.clear();
    filesByCourse.clear();
    aiReviewsByAssignment.clear();
    insData = null;
    timetableEntries = [];
    timetableLabel = '';
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
      AppLogger.instance.info(
        'ECLASS',
        'Synced ${courses.length} courses (${visibleCourses.length} visible)',
      );
      syncProfilePhoto();
      autoDetectTimetableGroupIfNeeded(refreshHints: true);
    } catch (e) {
      lastError = e.toString();
      AppLogger.instance.error('ECLASS', 'syncCourses failed', e);
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
              payload: 'assignment::${a.id}',
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
              payload: 'course_grades::${course.id}',
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
      } catch (e) {
        AppLogger.instance.error(
            'ECLASS', 'Batch assignments sync fell back to per-course', e);
        for (final c in targetCourses) {
          try {
            final assigns = await eclass.getAssignments(c.id, c.name);
            await _db.saveCourseAssignments(c.id, assigns);
          } catch (_) {}
        }
      }

      allAssignments = await _db.getAssignments();
      AppLogger.instance
          .info('ECLASS', 'Synced ${allAssignments.length} assignments');
      if (oldIds.isNotEmpty && settings.notifyAssignments) {
        for (final a in allAssignments) {
          if (!oldIds.contains(a.id) && !hiddenAssignmentIds.contains(a.id)) {
            await NotificationService.instance.showNotification(
              id: a.id.hashCode,
              title: a.courseName,
              body: '${a.name}${a.due.isNotEmpty ? ' • ${a.due}' : ''}',
              payload: 'assignment::${a.id}',
            );
          }
        }
      }
      await _rescheduleDeadlineReminders();
      await _updateLastSync();
      await UpdateService.refreshHomeWidgets();
      syncPrivateFiles(silent: true);
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
                payload: 'tab::3',
              );
            }
          }
        }
        await UpdateService.refreshHomeWidgets();
        AppLogger.instance.info(
          'INS',
          'Synced ${data.courses.length} INS grade rows',
        );
        autoDetectTimetableGroupIfNeeded();
        return true;
      }
      insError = s.insNoData;
      return false;
    } on InsException catch (e) {
      insError = e.message;
      AppLogger.instance.error('INS', 'INS rejected request', e.message);
      return false;
    } catch (e) {
      insError = e.toString();
      AppLogger.instance.error('INS', 'syncIns failed', e);
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
      await autoDetectTimetableGroupIfNeeded();
      await _rescheduleClassReminders();
      await UpdateService.refreshHomeWidgets();
      AppLogger.instance.info(
        'TIMETABLE',
        'Synced ${entries.length} timetable entries',
      );
    } catch (e) {
      AppLogger.instance.error('TIMETABLE', 'syncTimetable failed', e);
    } finally {
      isTimetableLoading = false;
      notifyListeners();
    }
  }

  Future<void> autoDetectTimetableGroupIfNeeded({
    bool refreshHints = false,
  }) async {
    if (timetableEntries.isEmpty || _autoDetectInFlight) return;
    final classes = TimetableService.getClasses(timetableEntries);
    if (classes.isEmpty) return;
    final currentGroup = settings.timetableGroup.trim();
    if (currentGroup.isNotEmpty && classes.contains(currentGroup)) return;

    _autoDetectInFlight = true;
    try {
      if (isLoggedIn && (refreshHints || _groupHints.isEmpty)) {
        _groupHints = await eclass.fetchStudentGroupHints();
      }
      final stillNeeds = settings.timetableGroup.trim().isEmpty ||
          !TimetableService.getClasses(timetableEntries)
              .contains(settings.timetableGroup.trim());
      if (!stillNeeds) return;

      final detected = TimetableService.detectStudentGroup(
        entries: timetableEntries,
        studentId: credentials?.studentId,
        insDepartment: insData?.studentInfo['dept'],
        courses: courses,
        insCourses: insData?.courses ?? const [],
        eclassHints: _groupHints,
      );
      if (detected != null && detected.isNotEmpty) {
        await updateSettings(
          settings.copyWith(
            timetableGroup: detected,
            timetableGroupAutoDetected: true,
          ),
        );
        AppLogger.instance.info(
          'TIMETABLE',
          'Auto-detected timetable group: $detected',
        );
      }
    } catch (e) {
      AppLogger.instance
          .error('TIMETABLE', 'autoDetectTimetableGroup failed', e);
    } finally {
      _autoDetectInFlight = false;
    }
  }

  Future<void> confirmTimetableGroup() async {
    if (!settings.timetableGroupAutoDetected) return;
    await updateSettings(
      settings.copyWith(timetableGroupAutoDetected: false),
    );
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
    final prev = settings;
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
    await _db.saveSetting(
      'timetable_group_auto_detected',
      updated.timetableGroupAutoDetected.toString(),
    );
    await _db.saveSetting('haptics_enabled', updated.hapticsEnabled.toString());
    await _db.saveSetting(
        'diagnostics_enabled', updated.diagnosticsEnabled.toString());
    await _db.saveSetting('ai_provider', updated.aiProvider);
    await _db.saveSetting('ai_base_url', updated.aiBaseUrl);
    await _db.saveSetting('ai_api_key', updated.aiApiKey);
    await _db.saveSetting('ai_model', updated.aiModel);
    AppLogger.instance.enabled = updated.diagnosticsEnabled;
    notifyListeners();

    final classRemindersChanged =
        prev.notifyTimetable != updated.notifyTimetable ||
            prev.reminderOffsetMinutes != updated.reminderOffsetMinutes ||
            prev.timetableGroup != updated.timetableGroup ||
            prev.language != updated.language;
    final deadlineRemindersChanged =
        prev.notifyAssignments != updated.notifyAssignments ||
            prev.language != updated.language;
    final bgSyncChanged = prev.bgSyncEnabled != updated.bgSyncEnabled ||
        prev.bgSyncIntervalHours != updated.bgSyncIntervalHours;
    final widgetsChanged = prev.timetableGroup != updated.timetableGroup ||
        prev.language != updated.language ||
        prev.hideSubmitted != updated.hideSubmitted;

    if (classRemindersChanged) {
      await _rescheduleClassReminders();
    }
    if (deadlineRemindersChanged) {
      await _rescheduleDeadlineReminders();
    }
    if (bgSyncChanged) {
      await NotificationService.instance.configureBackgroundSync(
        enabled: isLoggedIn && updated.bgSyncEnabled,
        intervalHours: updated.bgSyncIntervalHours,
      );
    }
    if (widgetsChanged) {
      await UpdateService.refreshHomeWidgets();
    }
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
    eclassPrivateFiles = [];
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

  // ── Local Draft Staging (#8) ────────────────────────────────

  Future<void> stageLocalDraft({
    required Assignment assignment,
    required String sourcePath,
    required String fileName,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var destPath = sourcePath;
    var fileSize = 0;

    final srcFile = File(sourcePath);
    if (await srcFile.exists()) {
      fileSize = await srcFile.length();
      try {
        final dir = await getApplicationDocumentsDirectory();
        final stagedDir = Directory(p.join(dir.path, 'staged_drafts'));
        if (!await stagedDir.exists()) {
          await stagedDir.create(recursive: true);
        }
        final copied = await srcFile.copy(
          p.join(stagedDir.path, '${nowMs}_${p.basename(fileName)}'),
        );
        destPath = copied.path;
      } catch (_) {}
    }

    await _db.saveLocalDraft(
      LocalDraft(
        assignmentId: assignment.id,
        assignId: assignment.assignId,
        courseId: assignment.courseId,
        courseName: assignment.courseName,
        assignmentName: assignment.name,
        due: assignment.due,
        dueTimestamp: assignment.dueTimestamp,
        assignmentUrl: assignment.url,
        filePath: destPath,
        fileName: fileName,
        fileSize: fileSize,
        updatedAt: nowMs,
      ),
    );
    localDrafts = await _db.getLocalDrafts();
    notifyListeners();
  }

  Future<void> removeLocalDraft(LocalDraft draft) async {
    try {
      final f = File(draft.filePath);
      if (await f.exists()) {
        await f.delete();
      }
    } catch (_) {}
    if (draft.id != null) {
      await _db.deleteLocalDraft(draft.id!);
    }
    localDrafts = await _db.getLocalDrafts();
    notifyListeners();
  }

  Future<void> uploadLocalDraft(
    LocalDraft draft, {
    required bool submitForGrading,
  }) async {
    final assignId = draft.assignId;
    if (assignId == null) {
      throw EclassException('Assignment upload ID unavailable');
    }
    await eclass.uploadSubmission(
      assignId,
      draft.filePath,
      draft.fileName,
      submitForGrading: submitForGrading,
      assignmentUrl: draft.assignmentUrl,
    );
    await removeLocalDraft(draft);
    if (draft.courseId.isNotEmpty) {
      await syncCourseAssignments(draft.courseId, draft.courseName);
    } else {
      await syncAllAssignments();
    }
  }

  // ── eClass Private Files (/user/files.php) ──────────────────

  Future<void> syncPrivateFiles({bool silent = false}) async {
    if (!isLoggedIn) return;
    if (!silent) {
      isSyncingPrivateFiles = true;
      notifyListeners();
    }
    try {
      final fetched = await eclass.getPrivateFiles();
      eclassPrivateFiles = fetched;
      await _db.saveEclassPrivateFiles(fetched);
      AppLogger.instance.info(
        'ECLASS',
        'Synced ${fetched.length} eClass saved files',
      );
    } catch (e) {
      AppLogger.instance.error('ECLASS', 'syncPrivateFiles failed', e);
    } finally {
      isSyncingPrivateFiles = false;
      notifyListeners();
    }
  }

  Future<void> submitPrivateFileToAssignment({
    required EclassPrivateFile file,
    required Assignment assignment,
    required bool submitForGrading,
  }) async {
    final assignId = assignment.assignId;
    if (assignId == null) {
      throw EclassException('Assignment upload ID unavailable');
    }
    final localPath = await eclass.downloadPrivateFile(file);
    await eclass.uploadSubmission(
      assignId,
      localPath,
      file.filename,
      submitForGrading: submitForGrading,
      assignmentUrl: assignment.url,
    );
    if (assignment.courseId.isNotEmpty) {
      await syncCourseAssignments(assignment.courseId, assignment.courseName);
    } else {
      await syncAllAssignments();
    }
  }

  // ── AI Homework Reviews ─────────────────────────────────────

  Future<AiReviewResult?> loadAiReview(String assignmentId) async {
    final cached = aiReviewsByAssignment[assignmentId];
    if (cached != null) return cached;
    final fromDb = await _db.getAiReview(assignmentId);
    if (fromDb != null) {
      aiReviewsByAssignment[assignmentId] = fromDb;
      notifyListeners();
    }
    return fromDb;
  }

  Future<void> saveAiReview(AiReviewResult review) async {
    aiReviewsByAssignment[review.assignmentId] = review;
    await _db.saveAiReview(review);
    notifyListeners();
  }

  Future<void> clearAiReview(String assignmentId) async {
    aiReviewsByAssignment.remove(assignmentId);
    await _db.deleteAiReview(assignmentId);
    notifyListeners();
  }
}
