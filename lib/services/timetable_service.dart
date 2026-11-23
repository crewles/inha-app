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

  /// Current time in Tashkent (UTC+5) as a wall-clock DateTime (non-UTC)
  /// so comparisons with DateTime(y, m, d, h, min) share the same time scale.
  static DateTime nowTashkent() {
    final utcPlus5 = DateTime.now().toUtc().add(const Duration(hours: 5));
    return DateTime(
      utcPlus5.year,
      utcPlus5.month,
      utcPlus5.day,
      utcPlus5.hour,
      utcPlus5.minute,
      utcPlus5.second,
      utcPlus5.millisecond,
      utcPlus5.microsecond,
    );
  }

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
    final timetables = (r.data!['r']['regular']['timetables'] as List<dynamic>);
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

      final dur =
          int.tryParse(lesson['durationperiods']?.toString() ?? '1') ?? 1;
      String endTime = '?';
      final pNum = int.tryParse(periodId);
      if (pNum != null) {
        final endPeriodId = (pNum + dur - 1).toString();
        endTime = periods[endPeriodId]?['endtime']?.toString() ?? '?';
      }

      final subjId = lesson['subjectid']?.toString() ?? '';
      final subjectName = subjects[subjId]?['name']?.toString() ?? subjId;

      final teacherNames = ((lesson['teacherids'] as List?) ?? [])
          .map((id) =>
              teachers[id.toString()]?['name']?.toString() ?? id.toString())
          .toList();

      final classNames = ((lesson['classids'] as List?) ?? [])
          .map((id) =>
              classes[id.toString()]?['name']?.toString() ?? id.toString())
          .toList();

      final classroomNames = ((card['classroomids'] as List?) ?? [])
          .map((id) =>
              classrooms[id.toString()]?['name']?.toString() ?? id.toString())
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
      final da =
          a.days.map((d) => dayOrder[d] ?? 9).reduce((x, y) => x < y ? x : y);
      final db =
          b.days.map((d) => dayOrder[d] ?? 9).reduce((x, y) => x < y ? x : y);
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
    List<ScheduleEntry> groupEntries, {
    DateTime? nowOverride,
  }) {
    if (groupEntries.isEmpty) return null;
    final now = nowOverride ?? nowTashkent();
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

  static final Set<String> _matchStopWords = {
    'in',
    'of',
    'the',
    'and',
    'for',
    'to',
    'with',
    'on',
    'introduction',
    'intro',
    'lab',
    'lecture',
    'practice',
    'tutorial',
    'course',
  };

  /// Matches an eClass [courseName] against EduPage [entries] (prioritizing
  /// [group] when set) to extract professor, classrooms, and weekly slots.
  static CourseScheduleInfo? matchCourse(
    String courseName,
    List<ScheduleEntry> entries, {
    String group = '',
  }) {
    if (courseName.trim().isEmpty || entries.isEmpty) return null;

    final trimmedGroup = group.trim();
    final pool = trimmedGroup.isNotEmpty
        ? filterByClass(entries, trimmedGroup)
        : <ScheduleEntry>[];
    final candidates = pool.isNotEmpty ? pool : entries;

    final courseNorm = _normalizeSubject(courseName);
    if (courseNorm.isEmpty) return null;
    final courseTokens = _tokenizeSubject(courseNorm);
    final courseLevels = _extractLevels(courseNorm);

    // Group candidate entries by their normalized EduPage subject name.
    final bySubject = <String, List<ScheduleEntry>>{};
    for (final e in candidates) {
      final subjNorm = _normalizeSubject(e.subject);
      if (subjNorm.isEmpty) continue;
      bySubject.putIfAbsent(subjNorm, () => []).add(e);
    }

    String? bestSubj;
    double bestScore = 0;

    for (final entry in bySubject.entries) {
      final subjNorm = entry.key;
      final subjLevels = _extractLevels(subjNorm);
      if (courseLevels.isNotEmpty &&
          subjLevels.isNotEmpty &&
          courseLevels.join(',') != subjLevels.join(',')) {
        continue;
      }

      double score = 0;
      if (subjNorm == courseNorm) {
        score = 1.0;
      } else {
        final subjTokens = _tokenizeSubject(subjNorm);
        if (courseTokens.isNotEmpty && subjTokens.isNotEmpty) {
          final overlap =
              courseTokens.where((t) => subjTokens.contains(t)).length;
          final maxLen = courseTokens.length > subjTokens.length
              ? courseTokens.length
              : subjTokens.length;
          score = overlap / maxLen;
          if (score < 0.55 &&
              (courseNorm.contains(subjNorm) ||
                  subjNorm.contains(courseNorm))) {
            final minTokens = courseTokens.length < subjTokens.length
                ? courseTokens.length
                : subjTokens.length;
            if (minTokens >= 2 && overlap == minTokens) {
              score = 0.72;
            }
          }
        }
      }

      if (score >= 0.55 && score > bestScore) {
        bestScore = score;
        bestSubj = subjNorm;
      }
    }

    if (bestSubj == null) return null;
    final matched = bySubject[bestSubj]!;

    final teacherCounts = <String, int>{};
    final roomSet = <String>{};
    final slotSet = <(int, String, String)>{};

    for (final e in matched) {
      for (final t in e.teachers) {
        final clean = t.trim();
        if (clean.isNotEmpty) {
          teacherCounts[clean] = (teacherCounts[clean] ?? 0) + 1;
        }
      }
      for (final r in e.classrooms) {
        final clean = cleanClassroomName(r);
        if (clean.isNotEmpty) roomSet.add(clean);
      }
      for (final d in e.days) {
        final ord = dayOrder[d] ?? 9;
        slotSet.add((ord, d, e.periodStart));
      }
    }

    final sortedTeachers = teacherCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final teacher = sortedTeachers.isEmpty
        ? ''
        : (trimmedGroup.isNotEmpty
            ? sortedTeachers.map((e) => e.key).join(', ')
            : sortedTeachers.first.key);

    final sortedSlots = slotSet.toList()
      ..sort((a, b) {
        final dCmp = a.$1.compareTo(b.$1);
        return dCmp != 0 ? dCmp : a.$3.compareTo(b.$3);
      });
    final daySummaries = sortedSlots
        .map((s) => s.$3.isEmpty ? s.$2 : '${s.$2} ${s.$3}')
        .toList();

    return CourseScheduleInfo(
      teacher: teacher,
      classrooms: roomSet.toList(),
      daySummaries: daySummaries,
    );
  }

  /// Strips trailing capacity tags like `(90)` or `(40)` from room labels.
  static String cleanClassroomName(String raw) {
    return raw.replaceAll(RegExp(r'\s*\(\d+\)\s*$'), '').trim();
  }

  static String _normalizeSubject(String raw) {
    var s = raw
        .replaceAll(RegExp(r'\[[^\]]*\]'), ' ')
        .replaceAll(RegExp(r'\(\s*\d{2,4}\s*\)'), ' ')
        .replaceAll('&', ' ')
        .toLowerCase();
    s = s.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static Set<String> _tokenizeSubject(String norm) {
    final out = <String>{};
    for (final rawTok in norm.split(' ')) {
      if (rawTok.isEmpty || _matchStopWords.contains(rawTok)) continue;
      var tok = rawTok;
      if (tok.length > 3 &&
          tok.endsWith('s') &&
          !tok.endsWith('ss') &&
          !tok.endsWith('is')) {
        tok = tok.substring(0, tok.length - 1);
      }
      if (tok.isNotEmpty && !_matchStopWords.contains(tok)) {
        out.add(tok);
      }
    }
    return out;
  }

  static List<String> _extractLevels(String norm) {
    final levels = <String>[];
    for (final tok in norm.split(' ')) {
      if (RegExp(r'^[1-9]$').hasMatch(tok)) {
        levels.add(tok);
      } else if (tok == 'i') {
        levels.add('1');
      } else if (tok == 'ii') {
        levels.add('2');
      } else if (tok == 'iii') {
        levels.add('3');
      } else if (tok == 'iv') {
        levels.add('4');
      }
    }
    return levels;
  }

  /// Reverse-matches an EduPage or INS [subjectName] to an enrolled eClass [Course].
  static Course? matchSubjectToCourse(
      String subjectName, List<Course> courses) {
    if (subjectName.trim().isEmpty || courses.isEmpty) return null;
    final subjNorm = _normalizeSubject(subjectName);
    if (subjNorm.isEmpty) return null;
    final subjTokens = _tokenizeSubject(subjNorm);
    final subjLevels = _extractLevels(subjNorm);

    Course? best;
    double bestScore = 0;

    for (final c in courses) {
      final courseNorm = _normalizeSubject(c.name);
      if (courseNorm.isEmpty) continue;
      final courseLevels = _extractLevels(courseNorm);
      if (subjLevels.isNotEmpty &&
          courseLevels.isNotEmpty &&
          subjLevels.join(',') != courseLevels.join(',')) {
        continue;
      }

      double score = 0;
      if (courseNorm == subjNorm) {
        score = 1.0;
      } else {
        final courseTokens = _tokenizeSubject(courseNorm);
        if (courseTokens.isNotEmpty && subjTokens.isNotEmpty) {
          final overlap =
              courseTokens.where((t) => subjTokens.contains(t)).length;
          final maxLen = courseTokens.length > subjTokens.length
              ? courseTokens.length
              : subjTokens.length;
          score = overlap / maxLen;
          if (score < 0.55 &&
              (courseNorm.contains(subjNorm) ||
                  subjNorm.contains(courseNorm))) {
            final minTokens = courseTokens.length < subjTokens.length
                ? courseTokens.length
                : subjTokens.length;
            if (minTokens >= 1 && overlap == minTokens) {
              score = 0.72;
            }
          }
        }
      }

      if (score >= 0.55) {
        final weighted = score + (c.isCurrent ? 0.05 : 0.0);
        if (weighted > bestScore) {
          bestScore = weighted;
          best = c;
        }
      }
    }
    return best;
  }

  static final RegExp _cohortYearRx = RegExp(r'^[A-Z](\d{2})\d{4,}$');
  static final RegExp _classYearSecRx = RegExp(r'(\d{2})-(\d+)$');

  static String _normalizeGroupToken(String raw) {
    var out = raw.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    out = out.replaceFirstMapped(
      RegExp(r'-0+(\d+)$'),
      (m) => '-${m.group(1)}',
    );
    return out;
  }

  static Map<int, int> _extractSectionVotes({
    required List<String> hints,
    required List<InsCourseGrade> insCourses,
  }) {
    final votes = <int, int>{};

    void addVote(int? sec, [int weight = 1]) {
      if (sec != null && sec >= 1 && sec <= 30) {
        votes[sec] = (votes[sec] ?? 0) + weight;
      }
    }

    for (final c in insCourses) {
      final m = RegExp(r'^0*(\d{1,2})$').firstMatch(c.classNumber.trim());
      if (m != null) {
        addVote(int.tryParse(m.group(1)!), 2);
      }
    }

    final patterns = [
      RegExp(r'\b(?:section|sec|group|gr)\.?\s*#?\s*0*(\d{1,2})\b',
          caseSensitive: false),
      RegExp(r'\b[A-Z]{2,}\d{3,4}\s*[-_]\s*0*(\d{1,2})\b',
          caseSensitive: false),
      RegExp(r'\(\s*0*(\d{1,2})\s*\)'),
      RegExp(r'\[\s*0*(\d{1,2})\s*\]'),
    ];

    for (final raw in hints) {
      for (final rx in patterns) {
        for (final m in rx.allMatches(raw)) {
          addVote(int.tryParse(m.group(1)!));
        }
      }
    }
    return votes;
  }

  static double _scoreDepartmentMatch(String clsUpper, String deptSignals) {
    if (deptSignals.trim().isEmpty) return 0.0;
    final prefix = clsUpper.split(RegExp(r'\d')).first;

    bool hasWord(String word) =>
        RegExp('(?:^|[^a-z])$word(?:\\d|[^a-z]|\$)').hasMatch(deptSignals);

    if (prefix == 'CSE' &&
        (hasWord('cse') ||
            deptSignals.contains('computer science') ||
            deptSignals.contains('computer engineering'))) {
      return 22.0;
    }
    if (prefix == 'ICE' &&
        (hasWord('ice') ||
            deptSignals.contains('information and communication'))) {
      return 22.0;
    }
    if (prefix == 'CIE' && hasWord('cie')) {
      return 22.0;
    }
    if (prefix == 'IT' && hasWord('it')) {
      return 18.0;
    }
    if (prefix == 'CS' && hasWord('cs')) {
      return 18.0;
    }
    if (prefix == 'AI' &&
        (hasWord('ai') || deptSignals.contains('artificial intelligence'))) {
      return 20.0;
    }
    if (prefix == 'DS' &&
        (hasWord('ds') || deptSignals.contains('data science'))) {
      return 20.0;
    }
    if (prefix == 'FND' &&
        (hasWord('fnd') || deptSignals.contains('foundation'))) {
      return 20.0;
    }
    if (prefix.startsWith('SBL(L)') && deptSignals.contains('logistics')) {
      return 22.0;
    }
    if ((prefix.startsWith('SBL(B)') || prefix == 'BM') &&
        (deptSignals.contains('business') || hasWord('sbl') || hasWord('bm'))) {
      return 20.0;
    }
    if (deptSignals.contains('socie') &&
        const {'CSE', 'ICE', 'CIE', 'IT', 'CS', 'AI', 'DS'}.contains(prefix)) {
      return 12.0;
    }
    return 0.0;
  }

  static double _subjectSimilarity({
    required String normA,
    required Set<String> tokA,
    required List<String> lvlA,
    required String normB,
  }) {
    if (normA.isEmpty || normB.isEmpty) return 0.0;
    final lvlB = _extractLevels(normB);
    if (lvlA.isNotEmpty && lvlB.isNotEmpty && lvlA.join(',') != lvlB.join(',')) {
      return 0.0;
    }
    if (normA == normB) return 1.0;
    final tokB = _tokenizeSubject(normB);
    if (tokA.isEmpty || tokB.isEmpty) return 0.0;
    final overlap = tokA.where((t) => tokB.contains(t)).length;
    final maxLen = tokA.length > tokB.length ? tokA.length : tokB.length;
    var score = overlap / maxLen;
    if (score < 0.55 && (normA.contains(normB) || normB.contains(normA))) {
      final minLen = tokA.length < tokB.length ? tokA.length : tokB.length;
      if (minLen >= 1 && overlap == minLen) {
        score = 0.72;
      }
    }
    return score >= 0.55 ? score : 0.0;
  }

  static Set<String> _nameTokens(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z]+'), ' ')
        .split(' ')
        .where((t) => t.length >= 3 && t != 'prof' && t != 'dr')
        .toSet();
  }

  /// Infers the student's EduPage group (e.g. `CSE25-1`) from direct eClass
  /// hints, student cohort year (`U25...`), INS department, enrolled courses,
  /// course professors, and section numbers (`-001` / `(001)` / INS `001`).
  static String? detectStudentGroup({
    required List<ScheduleEntry> entries,
    String? studentId,
    String? insDepartment,
    List<Course> courses = const [],
    List<InsCourseGrade> insCourses = const [],
    List<String> eclassHints = const [],
  }) {
    final allClasses = getClasses(entries);
    if (allClasses.isEmpty) return null;

    // 1. Direct exact group token match (e.g. Moodle group "CSE25-1" or "CSE 25-01").
    final sortedByLen = [...allClasses]
      ..sort((a, b) => b.length.compareTo(a.length));
    final directPool = <String>[
      ...eclassHints,
      if (insDepartment != null && insDepartment.trim().isNotEmpty)
        insDepartment,
    ];
    for (final rawHint in directPool) {
      final normHint = rawHint
          .toUpperCase()
          .replaceAllMapped(
              RegExp(r'([A-Z\)])\s+(\d{2}-)'), (m) => '${m.group(1)}${m.group(2)}')
          .replaceAllMapped(RegExp(r'-0+(\d+\b)'), (m) => '-${m.group(1)}');
      for (final cls in sortedByLen) {
        final normCls = _normalizeGroupToken(cls);
        final rx =
            RegExp('(^|[^A-Z0-9])${RegExp.escape(normCls)}([^A-Z0-9]|\$)');
        if (rx.hasMatch(normHint)) {
          return cls;
        }
      }
    }

    // 2. Gather multi-signal evidence.
    final sidMatch =
        _cohortYearRx.firstMatch((studentId ?? '').trim().toUpperCase());
    final studentYear = sidMatch?.group(1);

    final sectionVotes = _extractSectionVotes(
      hints: eclassHints,
      insCourses: insCourses,
    );
    final totalVotes = sectionVotes.values.fold<int>(0, (a, b) => a + b);

    final deptSignals = [
      insDepartment ?? '',
      ...eclassHints,
      ...insCourses.map((c) => c.courseNumber),
    ].join(' ').toLowerCase();

    final activeCourses = courses.where((c) => c.isCurrent).toList();
    final targetCourses = activeCourses.isNotEmpty ? activeCourses : courses;
    final courseMeta = targetCourses.map((c) {
      final norm = _normalizeSubject(c.name);
      return (
        norm: norm,
        toks: _tokenizeSubject(norm),
        lvls: _extractLevels(norm),
        profTokens: _nameTokens(c.professor),
      );
    }).where((c) => c.norm.isNotEmpty).toList();

    final entriesByClass = <String, List<ScheduleEntry>>{};
    for (final e in entries) {
      for (final c in e.classes) {
        entriesByClass.putIfAbsent(c, () => []).add(e);
      }
    }

    String? bestClass;
    double bestScore = -1e9;
    bool bestHasEvidence = false;

    for (final cls in allClasses) {
      final clsUpper = cls.toUpperCase();
      final yrSecMatch = _classYearSecRx.firstMatch(clsUpper);
      final clsYear = yrSecMatch?.group(1);
      final clsSection =
          yrSecMatch != null ? int.tryParse(yrSecMatch.group(2)!) : null;

      double score = 0.0;
      if (studentYear != null && clsYear != null) {
        score += (clsYear == studentYear) ? 30.0 : -25.0;
      }

      final deptScore = _scoreDepartmentMatch(clsUpper, deptSignals);
      score += deptScore;

      int matchedCourses = 0;
      final clsEntries = entriesByClass[cls] ?? const <ScheduleEntry>[];
      for (final cm in courseMeta) {
        bool subjectMatched = false;
        bool profMatched = false;
        for (final e in clsEntries) {
          final eNorm = _normalizeSubject(e.subject);
          final sim = _subjectSimilarity(
            normA: cm.norm,
            tokA: cm.toks,
            lvlA: cm.lvls,
            normB: eNorm,
          );
          if (sim <= 0) continue;
          subjectMatched = true;
          if (!profMatched && cm.profTokens.isNotEmpty) {
            final teacherTokens = e.teachers.expand(_nameTokens).toSet();
            if (cm.profTokens.any(teacherTokens.contains)) {
              profMatched = true;
            }
          }
        }
        if (subjectMatched) {
          matchedCourses++;
          score += 12.0;
          if (profMatched) score += 15.0;
        }
      }

      bool matchedSection = false;
      if (clsSection != null && totalVotes > 0) {
        final v = sectionVotes[clsSection] ?? 0;
        if (v > 0) {
          matchedSection = true;
          score += 8.0 * (v / totalVotes) + 0.5 * v;
        }
      }

      final hasEvidence =
          matchedCourses > 0 || deptScore > 0 || matchedSection;
      if (score > bestScore ||
          (score == bestScore &&
              bestClass != null &&
              cls.compareTo(bestClass) < 0)) {
        bestScore = score;
        bestClass = cls;
        bestHasEvidence = hasEvidence;
      }
    }

    if (bestClass != null && bestHasEvidence && bestScore >= 25.0) {
      return bestClass;
    }
    return null;
  }

  /// Returns weekday index (`0 = Mon .. 4 = Fri`) of the course's first slot.
  static int? firstDayIndex(CourseScheduleInfo? info) {
    if (info == null || info.daySummaries.isEmpty) return null;
    for (final s in info.daySummaries) {
      final token = s.trim().split(' ').first;
      final idx = dayOrder[token];
      if (idx != null) return idx;
    }
    return null;
  }
}
