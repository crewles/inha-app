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

  Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    _tashkent = tz.getLocation('Asia/Tashkent');
    tz.setLocalLocation(_tashkent);

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
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
    );
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
    for (int id = 1000; id < 1200; id++) {
      await _plugin.cancel(id);
    }
    if (!enabled || groupEntries.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'inha_timetable',
        'Class Reminders',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

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

        final room = e.classrooms.isEmpty ? '—' : e.classrooms.join(', ');
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
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
    for (int id = 2000; id < 2300; id++) {
      await _plugin.cancel(id);
    }
    if (!enabled) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'inha_deadlines',
        'Assignment Deadlines',
        importance: Importance.high,
        priority: Priority.high,
      ),
    );

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
            androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
