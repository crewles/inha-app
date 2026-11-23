import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/models.dart';
import 'timetable_service.dart';

class NotificationService {
  static final NotificationService instance = NotificationService._internal();
  NotificationService._internal();

  static const _bgChannel = MethodChannel('uz.inha.inhahub/bg_sync');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  late tz.Location _tashkent;
  void Function(String payload)? _onPayloadTap;
  String? _pendingLaunchPayload;

  void setOnPayloadTap(void Function(String payload) handler) {
    _onPayloadTap = handler;
    final pending = _pendingLaunchPayload;
    if (pending != null && pending.isNotEmpty) {
      _pendingLaunchPayload = null;
      handler(pending);
    }
  }

  void _dispatchPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    final handler = _onPayloadTap;
    if (handler != null) {
      handler(payload);
    } else {
      _pendingLaunchPayload = payload;
    }
  }

  Future<void> init() async {
    if (_initialized) return;
    try {
      tz_data.initializeTimeZones();
      _tashkent = tz.getLocation('Asia/Tashkent');
      tz.setLocalLocation(_tashkent);

      const androidInit =
          AndroidInitializationSettings('@drawable/ic_stat_inha');
      const initSettings = InitializationSettings(android: androidInit);
      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (resp) =>
            _dispatchPayload(resp.payload),
      );

      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        _dispatchPayload(launchDetails?.notificationResponse?.payload);
      }

      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
      _initialized = true;
    } catch (_) {}
  }

  Future<void> showGradeNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) =>
      showNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
        channelId: 'inha_grades',
        channelName: 'Grade Updates',
      );

  Future<bool?> areNotificationsEnabled() async {
    if (!_initialized) await init();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return androidPlugin?.areNotificationsEnabled();
  }

  Future<bool?> requestPermission() async {
    if (!_initialized) await init();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return androidPlugin?.requestNotificationsPermission();
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_initialized) await init();
    return _plugin.pendingNotificationRequests();
  }

  Future<bool?> canScheduleExactAlarms() async {
    if (!_initialized) await init();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return androidPlugin?.canScheduleExactNotifications();
  }

  Future<bool?> requestExactAlarmPermission() async {
    if (!_initialized) await init();
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return androidPlugin?.requestExactAlarmsPermission();
  }

  Future<(AndroidScheduleMode mode, bool exact)> _resolveScheduleMode({
    bool requestIfDenied = false,
  }) async {
    try {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      var canExact =
          await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (!canExact && requestIfDenied) {
        await androidPlugin?.requestExactAlarmsPermission();
        canExact =
            await androidPlugin?.canScheduleExactNotifications() ?? false;
      }
      if (canExact) {
        return (AndroidScheduleMode.exactAllowWhileIdle, true);
      }
    } catch (_) {}
    return (AndroidScheduleMode.inexactAllowWhileIdle, false);
  }

  Future<void> sendInstantTestNotification({required bool isRu}) async {
    await showNotification(
      id: 9001,
      title: isRu ? 'Тест уведомлений Inha App' : 'Inha App Notification Test',
      body: isRu
          ? 'Уведомления работают корректно!'
          : 'Notifications are working properly!',
      payload: 'tab::4',
    );
  }

  Future<bool> scheduleDelayedTestNotification({
    required bool isRu,
    int delaySeconds = 10,
  }) async {
    if (!_initialized) await init();
    final (mode, exact) = await _resolveScheduleMode(requestIfDenied: true);
    final fireAt =
        tz.TZDateTime.now(_tashkent).add(Duration(seconds: delaySeconds));
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'inha_updates',
        'Inha App Updates',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );
    await _plugin.zonedSchedule(
      9002,
      isRu
          ? 'Отложенный тест ($delaySecondsс)'
          : 'Delayed Test (${delaySeconds}s)',
      isRu
          ? 'Запланированные будильники в фоне работают!'
          : 'Scheduled background reminders are working!',
      fireAt,
      details,
      payload: 'tab::1',
      androidScheduleMode: mode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    return exact;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String channelId = 'inha_updates',
    String channelName = 'Inha App Updates',
  }) async {
    if (!_initialized) await init();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(android: androidDetails),
      payload: payload,
    );
  }

  Future<void> _cancelPendingInRange(int startInclusive, int endExclusive) async {
    try {
      final pending = await _plugin.pendingNotificationRequests();
      for (final req in pending) {
        if (req.id >= startInclusive && req.id < endExclusive) {
          await _plugin.cancel(req.id);
        }
      }
    } catch (_) {}
  }

  // ── Offline Scheduled Class Reminders (Weekly, Asia/Tashkent) ──

  Future<void> rescheduleClassReminders({
    required List<ScheduleEntry> groupEntries,
    required bool enabled,
    required int offsetMinutes,
    required bool isRu,
  }) async {
    if (!_initialized) await init();

    // Clear previous class reminder IDs (range 1000..1199)
    await _cancelPendingInRange(1000, 1200);
    if (!enabled || groupEntries.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'inha_timetable',
        'Class Reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final (scheduleMode, _) = await _resolveScheduleMode();
    int nextId = 1000;
    final now = tz.TZDateTime.now(_tashkent);

    for (final e in groupEntries) {
      final parts = e.periodStart.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour == null || minute == null) continue;

      for (final dayCode in e.days) {
        if (nextId >= 1200) break;
        final dayIdx = TimetableService.dayNames.indexOf(dayCode);
        if (dayIdx < 0) continue;
        final targetWeekday = dayIdx + 1; // 1 = Mon .. 5 = Fri

        var scheduled = tz.TZDateTime(
          _tashkent,
          now.year,
          now.month,
          now.day,
          hour,
          minute,
        ).subtract(Duration(minutes: offsetMinutes));

        while (scheduled.weekday != targetWeekday || !scheduled.isAfter(now)) {
          scheduled = scheduled.add(const Duration(days: 1));
        }

        final cleanedRooms = e.classrooms
            .map(TimetableService.cleanClassroomName)
            .where((r) => r.isNotEmpty)
            .toList();
        final room = cleanedRooms.isEmpty ? '—' : cleanedRooms.join(', ');
        final title = isRu
            ? 'Пара через $offsetMinutes мин: ${e.subject}'
            : 'Class in $offsetMinutes min: ${e.subject}';
        final body = '${e.periodStart}–${e.periodEnd} • $room';

        try {
          await _plugin.zonedSchedule(
            nextId++,
            title,
            body,
            scheduled,
            details,
            payload: 'timetable::$dayIdx',
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          );
        } catch (_) {}
      }
    }
  }

  // ── Offline Scheduled Assignment Deadline Reminders (24h & 2h) ──

  Future<void> rescheduleDeadlineReminders({
    required List<Assignment> assignments,
    required bool enabled,
    required bool isRu,
  }) async {
    if (!_initialized) await init();

    // Clear previous deadline reminder IDs (range 2000..2299)
    await _cancelPendingInRange(2000, 2300);
    if (!enabled) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'inha_deadlines',
        'Assignment Deadlines',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

    final (scheduleMode, _) = await _resolveScheduleMode();
    final now = tz.TZDateTime.now(_tashkent);
    int nextId = 2000;

    final pending = assignments
        .where((a) => !a.isSubmitted && a.dueTimestamp > 0)
        .toList()
      ..sort((a, b) => a.dueTimestamp.compareTo(b.dueTimestamp));

    for (final a in pending) {
      if (nextId >= 2298) break;
      final dueDt = tz.TZDateTime.fromMillisecondsSinceEpoch(
        _tashkent,
        a.dueTimestamp * 1000,
      );
      if (!dueDt.isAfter(now)) continue;

      for (final hoursBefore in const [24, 2]) {
        final fireAt = dueDt.subtract(Duration(hours: hoursBefore));
        if (!fireAt.isAfter(now)) continue;

        final title = isRu
            ? 'Дедлайн через $hoursBefore ч: ${a.name}'
            : 'Due in ${hoursBefore}h: ${a.name}';
        final body = '${a.courseName} • ${a.due}';

        try {
          await _plugin.zonedSchedule(
            nextId++,
            title,
            body,
            fireAt,
            details,
            payload: 'assignment::${a.id}',
            androidScheduleMode: scheduleMode,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (_) {}
      }
    }
  }

  // ── Native Android WorkManager Background Sync ──────────────

  Future<void> configureBackgroundSync({
    required bool enabled,
    required int intervalHours,
  }) async {
    try {
      if (enabled) {
        await _bgChannel.invokeMethod('schedule', {
          'intervalMinutes': intervalHours * 60,
        });
      } else {
        await _bgChannel.invokeMethod('cancel');
      }
    } catch (_) {}
  }
}
