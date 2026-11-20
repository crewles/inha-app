import 'package:dio/dio.dart';

import '../models/models.dart';

class TimetableService {
  static const String baseUrl = 'https://iut.edupage.org';
  static const String _gsh = '00000000';
  static const List<String> dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
  static const Map<String, int> dayOrder = {
    'Mon': 0,
    'Tue': 1,
    'Wed': 2,
    'Thu': 3,
    'Fri': 4,
  };

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 25),
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'User-Agent': 'Mozilla/5.0',
        'Referer': 'https://iut.edupage.org/',
        'Origin': 'https://iut.edupage.org',
        'X-Requested-With': 'XMLHttpRequest',
      },
    ),
  );

  /// Current time in Tashkent (UTC+5).
  static DateTime nowTashkent() =>
      DateTime.now().toUtc().add(const Duration(hours: 5));

  Future<(List<ScheduleEntry>, String, String)> fetchTimetable({
    int? year,
  }) async {
    final targetYear = year ?? nowTashkent().year;
    final (ttNum, label) = await _getCurrentTtNum(targetYear);
    final raw = await _fetchRaw(ttNum);
    final tables = _parseTables(raw);
    final entries = _buildSchedule(tables);
    return (entries, ttNum, label);
  }

  Future<(String, String)> _getCurrentTtNum(int year) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/timetable/server/ttviewer.js?__func=getTTViewerData',
      data: {
        '__args': [null, year],
        '__gsh': _gsh,
      },
    );
    final timetables =
        (r.data!['r']['regular']['timetables'] as List<dynamic>);
    final tt = timetables.first as Map<String, dynamic>;
    return (tt['tt_num'].toString(), (tt['text'] ?? '').toString());
  }

  Future<Map<String, dynamic>> _fetchRaw(String ttNum) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '$baseUrl/timetable/server/regulartt.js?__func=regularttGetData',
      data: {
        '__args': [null, ttNum],
        '__gsh': _gsh,
      },
    );
    return r.data!;
  }

  Map<String, Map<String, Map<String, dynamic>>> _parseTables(
      Map<String, dynamic> raw) {
    final result = <String, Map<String, Map<String, dynamic>>>{};
    final tables =
        (raw['r']['dbiAccessorRes']['tables'] as List<dynamic>?) ?? [];
    for (final t in tables) {
      final tid = t['id'].toString();
      final rows = <String, Map<String, dynamic>>{};
      for (final row in (t['data_rows'] as List<dynamic>?) ?? []) {
        rows[row['id'].toString()] = Map<String, dynamic>.from(row as Map);
      }
      result[tid] = rows;
    }
    return result;
  }

  List<String> _decodeDays(String daysStr) {
    final out = <String>[];
    for (int i = 0; i < daysStr.length && i < dayNames.length; i++) {
      if (daysStr[i] == '1') out.add(dayNames[i]);
    }
    return out;
  }

  List<ScheduleEntry> _buildSchedule(
      Map<String, Map<String, Map<String, dynamic>>> tables) {
    final entries = <ScheduleEntry>[];
    final seen = <String>{};

    final periods = tables['periods'] ?? {};
    final subjects = tables['subjects'] ?? {};
    final teachers = tables['teachers'] ?? {};
    final classes = tables['classes'] ?? {};
    final classrooms = tables['classrooms'] ?? {};
    final lessons = tables['lessons'] ?? {};
    final cards = tables['cards'] ?? {};

    for (final entry in cards.entries) {
      final cardId = entry.key;
      final card = entry.value;
      final lessonId = card['lessonid']?.toString() ?? '';
      final lesson = lessons[lessonId];
      if (lesson == null) continue;

      final days = _decodeDays(card['days']?.toString() ?? '00000');
      if (days.isEmpty) continue;

      final periodId = card['period']?.toString() ?? '';
      final startTime = periods[periodId]?['starttime']?.toString() ?? '?';

      final sortedDays = [...days]..sort();
      final dedupKey = '$lessonId|${sortedDays.join(",")}|$startTime';
      if (seen.contains(dedupKey)) continue;
      seen.add(dedupKey);

      final dur = int.tryParse(lesson['durationperiods']?.toString() ?? '1') ?? 1;
      String endTime = '?';
      final pNum = int.tryParse(periodId);
      if (pNum != null) {
        final endPeriodId = (pNum + dur - 1).toString();
        endTime = periods[endPeriodId]?['endtime']?.toString() ?? '?';
      }

      final subjId = lesson['subjectid']?.toString() ?? '';
      final subjectName = subjects[subjId]?['name']?.toString() ?? subjId;

      final teacherNames = ((lesson['teacherids'] as List?) ?? [])
          .map((id) => teachers[id.toString()]?['name']?.toString() ?? id.toString())
          .toList();

      final classNames = ((lesson['classids'] as List?) ?? [])
          .map((id) => classes[id.toString()]?['name']?.toString() ?? id.toString())
          .toList();

      final classroomNames = ((card['classroomids'] as List?) ?? [])
          .map((id) => classrooms[id.toString()]?['name']?.toString() ?? id.toString())
          .toList();

      entries.add(ScheduleEntry(
        cardId: cardId,
        lessonId: lessonId,
        days: days,
        periodStart: startTime,
        periodEnd: endTime,
        subject: subjectName,
        teachers: teacherNames,
        classes: classNames,
        classrooms: classroomNames,
        durationPeriods: dur,
      ));
    }

    entries.sort((a, b) {
      final da = a.days.map((d) => dayOrder[d] ?? 9).reduce((x, y) => x < y ? x : y);
      final db = b.days.map((d) => dayOrder[d] ?? 9).reduce((x, y) => x < y ? x : y);
      if (da != db) return da.compareTo(db);
      return a.periodStart.compareTo(b.periodStart);
    });
    return entries;
  }

  static List<String> getClasses(List<ScheduleEntry> entries) {
    final set = <String>{};
    for (final e in entries) {
      set.addAll(e.classes);
    }
    final list = set.toList()..sort();
    return list;
  }

  static List<ScheduleEntry> filterByClass(
      List<ScheduleEntry> entries, String className) {
    final q = className.trim().toLowerCase();
    return entries
        .where((e) => e.classes.any((c) => c.trim().toLowerCase() == q))
        .toList();
  }

  static List<ScheduleEntry> filterByDay(
      List<ScheduleEntry> entries, String day) {
    final out = entries.where((e) => e.days.contains(day)).toList();
    out.sort((a, b) => a.periodStart.compareTo(b.periodStart));
    return out;
  }

  /// Returns (entry, dayCode, minutesUntilStart or null if another day).
  static (ScheduleEntry, String, int?)? findNextLesson(
      List<ScheduleEntry> groupEntries) {
    if (groupEntries.isEmpty) return null;
    final now = nowTashkent();
    final wd = now.weekday; // 1 = Mon ... 7 = Sun

    if (wd <= 5) {
      final todayCode = dayNames[wd - 1];
      final todayList = filterByDay(groupEntries, todayCode);
      for (final e in todayList) {
        final parts = e.periodStart.split(':');
        if (parts.length != 2) continue;
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h == null || m == null) continue;
        final start = DateTime(now.year, now.month, now.day, h, m);
        if (start.isAfter(now)) {
          return (e, todayCode, start.difference(now).inMinutes);
        }
      }
    }

    for (int delta = 1; delta <= 7; delta++) {
      final nextDay = now.add(Duration(days: delta));
      if (nextDay.weekday > 5) continue;
      final code = dayNames[nextDay.weekday - 1];
      final list = filterByDay(groupEntries, code);
      if (list.isNotEmpty) {
        return (list.first, code, null);
      }
    }
    return null;
  }
}
