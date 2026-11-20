import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

class EclassException implements Exception {
  final String message;
  EclassException(this.message);
  @override
  String toString() => message;
}

/// Direct eClass client for https://eclass.inha.ac.kr (Moodle 3.2.2).
///
/// Uses live-verified Moodle Mobile WebService APIs wherever available:
/// - `core_webservice_get_site_info`
/// - `core_enrol_get_users_courses`
/// - `mod_assign_get_assignments` (1 fast request for all courses)
/// - `mod_assign_get_submission_status`
/// - `core_course_get_contents` (includes `ubfile` direct token URLs)
/// - `gradereport_overview_get_course_grades`
/// - `webservice/upload.php` + `mod_assign_save_submission` + `mod_assign_submit_for_grading`
///
/// Falls back to authenticated HTML session for Ubion plugins & restricted reports
/// (Attendance, per-course Grade report table, Syllabus).
class EclassService {
  static const String baseUrl = 'https://eclass.inha.ac.kr';
  // Desktop Chrome UA is required by eclass.inha.ac.kr WAF (non-browser UAs get reset).
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

  late final Dio _dio;
  late final CookieJar _cookieJar;

  String? _username;
  String? _password;
  String? _apiToken;
  int? _userId;
  bool _loggedIn = false;

  EclassService() {
    _cookieJar = CookieJar();
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        maxRedirects: 8,
        headers: {'User-Agent': _userAgent},
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    _dio.interceptors.add(CookieManager(_cookieJar));
  }

  String? get apiToken => _apiToken;

  void restoreCredentials(UserCredentials creds) {
    _username = creds.studentId;
    _password = creds.eclassPassword;
    _apiToken = creds.eclassToken;
  }

  void clearSession() {
    _cookieJar.deleteAll();
    _username = null;
    _password = null;
    _apiToken = null;
    _userId = null;
    _loggedIn = false;
  }

  // ── Auth (Moodle API Token + Web Session) ───────────────────

  Future<bool> login(String username, String password) async {
    _username = username;
    _password = password;
    _loggedIn = false;
    _userId = null;
    await _cookieJar.deleteAll();

    // 1. Try Moodle Mobile API token first (fastest & cleanest)
    final token = await fetchApiToken(refresh: true);

    // 2. Also establish web session (needed for Attendance & detailed HTML grades)
    bool webOk = false;
    try {
      final resp = await _dio.get<String>('$baseUrl/login/index.php');
      final doc = html_parser.parse(resp.data ?? '');
      final tokenInput = doc.querySelector('input[name="logintoken"]');
      final loginToken = tokenInput?.attributes['value'] ?? '';

      final resp2 = await _dio.post<String>(
        '$baseUrl/login/index.php',
        data: {
          'username': username,
          'password': password,
          'logintoken': loginToken,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final finalUrl = resp2.realUri.toString();
      final body = resp2.data ?? '';
      if (!(finalUrl.contains('login/index.php') &&
          body.contains('loginerrormessage'))) {
        webOk = true;
        _loggedIn = true;
      }
    } catch (_) {}

    return (token != null && token.isNotEmpty) || webOk;
  }

  Future<bool> ensureWebLoggedIn() async {
    if (_loggedIn) return true;
    if (_username == null || _password == null) return false;
    try {
      final resp = await _dio.get<String>('$baseUrl/login/index.php');
      final doc = html_parser.parse(resp.data ?? '');
      final tokenInput = doc.querySelector('input[name="logintoken"]');
      final loginToken = tokenInput?.attributes['value'] ?? '';
      final resp2 = await _dio.post<String>(
        '$baseUrl/login/index.php',
        data: {
          'username': _username!,
          'password': _password!,
          'logintoken': loginToken,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final finalUrl = resp2.realUri.toString();
      final body = resp2.data ?? '';
      if (finalUrl.contains('login/index.php') &&
          body.contains('loginerrormessage')) {
        return false;
      }
      _loggedIn = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Moodle Mobile WebService API ────────────────────────────

  Future<String?> fetchApiToken({bool refresh = false}) async {
    if (!refresh && _apiToken != null && _apiToken!.isNotEmpty) {
      return _apiToken;
    }
    if (_username != null && _password != null) {
      try {
        final r = await _dio.post<dynamic>(
          '$baseUrl/login/token.php',
          data: {
            'service': 'moodle_mobile_app',
            'username': _username!,
            'password': _password!,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        );
        if (r.data is Map && (r.data as Map)['token'] != null) {
          _apiToken = (r.data as Map)['token'].toString();
          return _apiToken;
        }
      } catch (_) {}
    }

    try {
      final r = await _dio.get<dynamic>(
        '$baseUrl/login/token.php',
        queryParameters: {'service': 'moodle_mobile_app'},
      );
      if (r.data is Map && (r.data as Map)['token'] != null) {
        _apiToken = (r.data as Map)['token'].toString();
        return _apiToken;
      }
    } catch (_) {}

    return _apiToken;
  }

  Future<dynamic> callWebService(
    String function,
    Map<String, dynamic> params,
  ) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      final token = await fetchApiToken(refresh: attempt == 1);
      if (token == null || token.isEmpty) {
        throw EclassException('eClass API token unavailable');
      }
      final payload = <String, dynamic>{
        'wstoken': token,
        'wsfunction': function,
        'moodlewsrestformat': 'json',
        ...params,
      };
      final r = await _dio.post<dynamic>(
        '$baseUrl/webservice/rest/server.php',
        data: payload,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final data = r.data;
      if (data is Map && data['exception'] != null) {
        if (data['errorcode'] == 'invalidtoken' && attempt == 0) {
          _apiToken = null;
          continue;
        }
        throw EclassException(
            data['message']?.toString() ?? 'eClass API error');
      }
      return data;
    }
    throw EclassException('eClass API auth failed');
  }

  Future<int?> _getUserId() async {
    if (_userId != null) return _userId;
    try {
      final info = await callWebService('core_webservice_get_site_info', {});
      if (info is Map && info['userid'] != null) {
        _userId = int.tryParse(info['userid'].toString());
        return _userId;
      }
    } catch (_) {}
    return null;
  }

  // ── Courses (JSON API + current semester detection) ─────────

  Future<List<Course>> getCourses() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Fetch active homepage course IDs (represents current semester in Ubion)
    final activeIds = <String>{};
    try {
      if (await ensureWebLoggedIn()) {
        final resp = await _dio.get<String>(baseUrl);
        final doc = html_parser.parse(resp.data ?? '');
        var links = doc.querySelectorAll('a.course_link');
        if (links.isEmpty) {
          links = doc.querySelectorAll('a[href*="course/view.php"]');
        }
        for (final a in links) {
          final href = a.attributes['href'] ?? '';
          if (!href.contains('id=')) continue;
          final cid = href.split('id=').last.split('&').first.trim();
          if (cid.isNotEmpty) activeIds.add(cid);
        }
      }
    } catch (_) {}

    // Primary: fast JSON API (core_enrol_get_users_courses + overview grades)
    try {
      final uid = await _getUserId();
      if (uid != null) {
        final rawCourses = await callWebService(
          'core_enrol_get_users_courses',
          {'userid': uid},
        );
        final overviewMap = <String, String>{};
        try {
          final ov = await callWebService(
            'gradereport_overview_get_course_grades',
            {'userid': uid},
          );
          if (ov is Map && ov['grades'] is List) {
            for (final g in ov['grades'] as List) {
              final cid = g['courseid']?.toString() ?? '';
              final gr = g['grade']?.toString() ?? '';
              if (cid.isNotEmpty && gr.isNotEmpty && gr != '-') {
                overviewMap[cid] = gr;
              }
            }
          }
        } catch (_) {}

        if (rawCourses is List && rawCourses.isNotEmpty) {
          int maxCat = 0;
          for (final c in rawCourses) {
            final cat = (c['category'] as int?) ?? 0;
            if (cat > maxCat) maxCat = cat;
          }

          final courses = <Course>[];
          for (final c in rawCourses) {
            final cid = c['id'].toString();
            final rawName =
                (c['fullname'] ?? c['shortname'] ?? '').toString().trim();
            final cleanName =
                rawName.replaceAll(RegExp(r'\[.*?\]'), '').trim();
            final cat = (c['category'] as int?) ?? 0;
            final isCur = activeIds.isNotEmpty
                ? activeIds.contains(cid)
                : (maxCat == 0 || cat == maxCat);
            if (cleanName.isNotEmpty) {
              courses.add(Course(
                id: cid,
                name: cleanName,
                category: cat,
                isCurrent: isCur,
                overviewGrade: overviewMap[cid],
                updatedAt: now,
              ));
            }
          }
          if (courses.isNotEmpty) return courses;
        }
      }
    } catch (_) {}

    // Fallback: HTML homepage scraping
    await ensureWebLoggedIn();
    final resp = await _dio.get<String>(baseUrl);
    final doc = html_parser.parse(resp.data ?? '');
    var links = doc.querySelectorAll('a.course_link');
    if (links.isEmpty) {
      links = doc.querySelectorAll('a[href*="course/view.php"]');
    }
    final seen = <String>{};
    final courses = <Course>[];
    for (final a in links) {
      final href = a.attributes['href'] ?? '';
      if (!href.contains('id=')) continue;
      final courseId = href.split('id=').last.split('&').first.trim();
      if (courseId.isEmpty || seen.contains(courseId)) continue;
      final h3 = a.querySelector('h3');
      final rawName = (h3 ?? a).text.trim();
      final name = rawName.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      if (name.isEmpty) continue;
      seen.add(courseId);
      courses.add(Course(id: courseId, name: name, updatedAt: now));
    }
    return courses;
  }

  // ── Assignments (Fast JSON API + Status + HTML fallback) ────

  /// Fetches ALL assignments for the given courseIds (or all enrolled courses if empty)
  /// in a single Moodle API call, then enriches submission status & grade.
  Future<List<Assignment>> getAssignmentsViaApi({
    List<String>? courseIds,
    Map<String, String>? courseNamesById,
    bool fetchStatus = true,
  }) async {
    final params = <String, dynamic>{};
    if (courseIds != null && courseIds.isNotEmpty) {
      for (int i = 0; i < courseIds.length; i++) {
        params['courseids[$i]'] = courseIds[i];
      }
    }

    final res = await callWebService('mod_assign_get_assignments', params);
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final out = <Assignment>[];

    if (res is! Map || res['courses'] is! List) return out;

    for (final c in res['courses'] as List) {
      final cid = c['id'].toString();
      final rawCName = (courseNamesById?[cid] ?? c['fullname'] ?? c['shortname'] ?? '')
          .toString()
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .trim();

      for (final a in (c['assignments'] as List?) ?? []) {
        final assignId = int.tryParse(a['id'].toString()) ?? 0;
        final cmid = a['cmid']?.toString();
        final name = (a['name'] ?? '').toString().trim();
        final dueTs = (a['duedate'] as int?) ?? 0;
        final dueStr = dueTs > 0 ? _formatUnixDate(dueTs) : '';

        final attachments = <AssignmentFile>[];
        for (final att in (a['introattachments'] as List?) ?? []) {
          final link = att['fileurl']?.toString() ?? '';
          if (link.isNotEmpty) {
            attachments.add(AssignmentFile(
              name: (att['filename'] ?? 'file').toString(),
              link: link,
              size: (att['filesize'] as int?) ?? 0,
            ));
          }
        }

        String status = 'No submission';
        String? grade;
        String? gradeMax;

        if (fetchStatus && assignId > 0) {
          try {
            final st = await callWebService(
              'mod_assign_get_submission_status',
              {'assignid': assignId},
            );
            if (st is Map) {
              final last = st['lastattempt'];
              if (last is Map) {
                final sub = last['submission'];
                final subStatus = sub is Map ? sub['status']?.toString() : null;
                final graded = last['graded'] == true;
                if (subStatus == 'submitted') {
                  status = graded ? 'Submitted (Graded)' : 'Submitted for grading';
                } else if (subStatus == 'draft') {
                  status = 'Draft (not submitted)';
                } else {
                  status = 'No submission';
                }
              }
              final fb = st['feedback'];
              if (fb is Map && fb['gradefordisplay'] != null) {
                final rawGrade = html_parser
                    .parseFragment(fb['gradefordisplay'].toString())
                    .text
                    ?.replaceAll('\u00A0', ' ')
                    .trim();
                if (rawGrade != null && rawGrade.isNotEmpty && rawGrade != '-') {
                  final m = RegExp(r'([\d.]+)\s*/\s*([\d.]+)').firstMatch(rawGrade);
                  if (m != null) {
                    grade = _trimZeros(m.group(1)!);
                    gradeMax = _trimZeros(m.group(2)!);
                  } else {
                    grade = rawGrade;
                  }
                }
              }
            }
          } catch (_) {}
        }

        out.add(Assignment(
          id: '$cid::$assignId',
          assignId: assignId,
          courseId: cid,
          courseName: rawCName,
          name: name,
          due: dueStr,
          dueTimestamp: dueTs,
          status: status,
          grade: grade,
          gradeMax: gradeMax,
          url: cmid != null ? '$baseUrl/mod/assign/view.php?id=$cmid' : null,
          files: attachments,
          updatedAt: nowMs,
        ));
      }
    }

    return out;
  }

  Future<List<Assignment>> getAssignments(
    String courseId,
    String courseName,
  ) async {
    try {
      return await getAssignmentsViaApi(
        courseIds: [courseId],
        courseNamesById: {courseId: courseName},
        fetchStatus: true,
      );
    } catch (_) {
      return _getAssignmentsHtmlFallback(courseId, courseName);
    }
  }

  Future<List<Assignment>> _getAssignmentsHtmlFallback(
    String courseId,
    String courseName,
  ) async {
    await ensureWebLoggedIn();
    final resp = await _dio.get<String>(
      '$baseUrl/mod/assign/index.php?id=$courseId',
    );
    final doc = html_parser.parse(resp.data ?? '');
    final table = doc.querySelector('table.generaltable');
    final tbody = table?.querySelector('tbody');
    if (tbody == null) return [];

    final now = DateTime.now().millisecondsSinceEpoch;
    final results = <Assignment>[];
    for (final row in tbody.querySelectorAll('tr')) {
      final cells = row.querySelectorAll('td');
      if (cells.length < 5) continue;
      final aTag = cells[1].querySelector('a');
      final name = cells[1].text.trim();
      if (name.isEmpty) continue;
      results.add(Assignment(
        id: '$courseId::$name',
        courseId: courseId,
        courseName: courseName,
        name: name,
        due: cells[2].text.trim(),
        status: cells[3].text.trim(),
        url: aTag?.attributes['href'],
        updatedAt: now,
      ));
    }
    return results;
  }

  String _formatUnixDate(int unixSeconds) {
    // Format in Tashkent (UTC+5)
    final dt = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true)
        .add(const Duration(hours: 5));
    final d = dt.day.toString().padLeft(2, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final h = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return '$d.$mo.${dt.year} $h:$mi';
  }

  String _trimZeros(String s) {
    if (!s.contains('.')) return s;
    return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  // ── Grades (HTML report + API overview) ─────────────────────

  Future<List<GradeItem>> getGrades(String courseId,
      {String? overviewGrade}) async {
    final grades = <GradeItem>[];
    try {
      await ensureWebLoggedIn();
      final resp = await _dio.get<String>(
        '$baseUrl/grade/report/user/index.php?id=$courseId',
      );
      final doc = html_parser.parse(resp.data ?? '');
      final table = doc.querySelector('table.user-grade');
      if (table != null) {
        for (final row in table.querySelectorAll('tr')) {
          final item = row.querySelector('.column-itemname');
          final grade = row.querySelector('td.column-grade');
          if (item != null && grade != null) {
            final name = item.text
                .replaceAll('Учитывать пустые оценки.', '')
                .trim();
            final val = grade.text.trim();
            if (val.isNotEmpty && val != '-' && val != 'Grade') {
              grades.add(GradeItem(courseId: courseId, name: name, value: val));
            }
          }
        }
      }
    } catch (_) {}

    if (grades.isEmpty &&
        overviewGrade != null &&
        overviewGrade.isNotEmpty &&
        overviewGrade != '-') {
      grades.add(GradeItem(
        courseId: courseId,
        name: 'Course Total',
        value: overviewGrade,
      ));
    }
    return grades;
  }

  // ── Attendance (Ubion HTML) ─────────────────────────────────

  Future<AttendanceData?> getAttendance(String courseId) async {
    await ensureWebLoggedIn();
    final resp = await _dio.get<String>(
      '$baseUrl/local/ubattendance/my_status.php?id=$courseId',
    );
    final doc = html_parser.parse(resp.data ?? '');
    final table = doc.querySelector('table.attendance_my');
    if (table == null) return null;

    final records = <AttendanceRecord>[];
    final tbody = table.querySelector('tbody');
    if (tbody != null) {
      for (final row in tbody.querySelectorAll('tr')) {
        final cells = row.querySelectorAll('td');
        if (cells.length >= 6) {
          records.add(AttendanceRecord(
            date: cells[0].text.trim(),
            className: cells[1].text.trim(),
            attendance: cells[2].text.trim(),
            absence: cells[3].text.trim(),
            late: cells[4].text.trim(),
            others: cells[5].text.trim(),
          ));
        }
      }
    }

    int att = 0, abs = 0, late = 0, oth = 0;
    final tfoot = table.querySelector('tfoot');
    if (tfoot != null) {
      final text = tfoot.text;
      att = _extractInt(text, 'Attendance');
      abs = _extractInt(text, 'Absence');
      late = _extractInt(text, 'Late');
      oth = _extractInt(text, 'Others');
    }

    return AttendanceData(
      courseId: courseId,
      attendanceCount: att,
      absenceCount: abs,
      lateCount: late,
      othersCount: oth,
      records: records,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  int _extractInt(String text, String key) {
    final m = RegExp('$key\\s*:\\s*(\\d+)').firstMatch(text);
    return m != null ? int.tryParse(m.group(1)!) ?? 0 : 0;
  }

  // ── Course Files (Moodle core_course_get_contents + ubfile) ─

  Future<List<CourseFile>> getCourseFiles(String courseId) async {
    final files = <CourseFile>[];
    final seen = <String>{};

    void addFile(String name, String? url, int size) {
      if (url == null || url.isEmpty || seen.contains(url)) return;
      seen.add(url);
      files.add(CourseFile(
        courseId: courseId,
        name: name,
        url: url,
        size: size,
      ));
    }

    try {
      final sections = await callWebService(
        'core_course_get_contents',
        {'courseid': courseId},
      );
      if (sections is List) {
        for (final sec in sections) {
          for (final mod in (sec['modules'] as List?) ?? []) {
            for (final c in (mod['contents'] as List?) ?? []) {
              if (c['type'] == 'file') {
                addFile(
                  (c['filename'] ?? mod['name'] ?? 'file').toString(),
                  c['fileurl']?.toString(),
                  (c['filesize'] as int?) ?? 0,
                );
              }
            }
          }
        }
      }

      try {
        final assignRes = await callWebService(
          'mod_assign_get_assignments',
          {'courseids[0]': courseId},
        );
        if (assignRes is Map) {
          for (final c in (assignRes['courses'] as List?) ?? []) {
            for (final a in (c['assignments'] as List?) ?? []) {
              for (final att in (a['introattachments'] as List?) ?? []) {
                addFile(
                  (att['filename'] ?? 'file').toString(),
                  att['fileurl']?.toString(),
                  (att['filesize'] as int?) ?? 0,
                );
              }
            }
          }
        }
      } catch (_) {}
    } catch (_) {
      await ensureWebLoggedIn();
      final resp =
          await _dio.get<String>('$baseUrl/course/view.php?id=$courseId');
      final doc = html_parser.parse(resp.data ?? '');
      for (final a in doc.querySelectorAll('a[href]')) {
        final href = a.attributes['href'] ?? '';
        if (href.contains('pluginfile.php') ||
            href.contains('mod/ubfile/view.php') ||
            href.contains('mod/resource/view.php')) {
          final resolved = Uri.parse(baseUrl).resolve(href).toString();
          final name = a.text.trim();
          if (name.isNotEmpty) addFile(name, resolved, 0);
        }
      }
    }

    return files;
  }

  // ── One-Click File Download ─────────────────────────────────

  Future<String> downloadFile(
    String url,
    String filename, {
    void Function(int received, int total)? onProgress,
  }) async {
    String downloadUrl = url;
    if (url.contains('/webservice/pluginfile.php')) {
      final token = await fetchApiToken();
      if (token != null && token.isNotEmpty && !url.contains('token=')) {
        downloadUrl = '$url${url.contains('?') ? '&' : '?'}token=$token';
      }
    } else {
      await ensureWebLoggedIn();
    }

    final dir = await getApplicationDocumentsDirectory();
    final filesDir = Directory(p.join(dir.path, 'downloads'));
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final savePath = p.join(filesDir.path, safeName);

    await _dio.download(
      downloadUrl,
      savePath,
      onReceiveProgress: onProgress,
      options: Options(
        receiveTimeout: const Duration(minutes: 3),
        followRedirects: true,
      ),
    );
    return savePath;
  }

  // ── Assignment File Submission via Moodle API ───────────────

  Future<List<OpenAssignment>> getOpenAssignments(String courseId) async {
    final res = await callWebService(
      'mod_assign_get_assignments',
      {'courseids[0]': courseId},
    );
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final out = <OpenAssignment>[];
    if (res is Map) {
      for (final c in (res['courses'] as List?) ?? []) {
        for (final a in (c['assignments'] as List?) ?? []) {
          final configs = (a['configs'] as List?) ?? [];
          bool fileEnabled = false;
          for (final cfg in configs) {
            if (cfg['plugin'] == 'file' &&
                cfg['name'] == 'enabled' &&
                cfg['value']?.toString() == '1') {
              fileEnabled = true;
            }
          }
          if (!fileEnabled || (a['nosubmissions'] == 1)) continue;
          final cutoff = (a['cutoffdate'] as int?) ?? 0;
          final start = (a['allowsubmissionsfromdate'] as int?) ?? 0;
          if ((cutoff > 0 && nowSec > cutoff) ||
              (start > 0 && nowSec < start)) {
            continue;
          }
          out.add(OpenAssignment(
            id: a['id'] as int,
            name: (a['name'] ?? '').toString(),
            dueTimestamp: (a['duedate'] as int?) ?? 0,
            drafts: a['submissiondrafts'] == 1,
          ));
        }
      }
    }
    out.sort((a, b) {
      if (a.dueTimestamp == 0 && b.dueTimestamp == 0) return 0;
      if (a.dueTimestamp == 0) return 1;
      if (b.dueTimestamp == 0) return -1;
      return a.dueTimestamp.compareTo(b.dueTimestamp);
    });
    return out;
  }

  Future<void> uploadSubmission(
    int assignmentId,
    String filePath,
    String filename, {
    bool submitForGrading = false,
  }) async {
    final token = await fetchApiToken();
    if (token == null || token.isEmpty) {
      throw EclassException('eClass API token unavailable');
    }

    // Check existing submission files so we preserve them when adding a new file
    final existing = <Map<String, String>>[];
    try {
      final st = await callWebService(
          'mod_assign_get_submission_status', {'assignid': assignmentId});
      if (st is Map) {
        final last = st['lastattempt'];
        if (last is Map && last['canedit'] == false) {
          throw EclassException('This submission can no longer be edited.');
        }
        final sub = last is Map ? last['submission'] : null;
        if (sub is Map) {
          for (final pl in (sub['plugins'] as List?) ?? []) {
            if (pl['type'] != 'file') continue;
            for (final fa in (pl['fileareas'] as List?) ?? []) {
              for (final f in (fa['files'] as List?) ?? []) {
                final fn = f['filename']?.toString() ?? '';
                final furl = f['fileurl']?.toString() ?? '';
                if (fn.isNotEmpty && furl.isNotEmpty && fn != filename) {
                  existing.add({'filename': fn, 'url': furl});
                }
              }
            }
          }
        }
      }
    } catch (e) {
      if (e is EclassException) rethrow;
    }

    final itemId = await _uploadDraft(token, filePath, filename, 0);

    // Re-attach previously uploaded files into the same draft area
    if (existing.isNotEmpty) {
      final tmpDir = await getTemporaryDirectory();
      for (final old in existing) {
        final tmpPath = p.join(tmpDir.path, 'prev_${old['filename']}');
        try {
          final url = old['url']!;
          final dlUrl = url.contains('token=')
              ? url
              : '$url${url.contains('?') ? '&' : '?'}token=$token';
          await _dio.download(dlUrl, tmpPath);
          await _uploadDraft(token, tmpPath, old['filename']!, itemId);
        } catch (_) {
        } finally {
          final f = File(tmpPath);
          if (await f.exists()) await f.delete();
        }
      }
    }

    final warnings = await callWebService('mod_assign_save_submission', {
      'assignmentid': assignmentId,
      'plugindata[files_filemanager]': itemId,
    });
    if (warnings is List && warnings.isNotEmpty) {
      final first = warnings.first;
      final msg =
          first is Map ? first['message']?.toString() : first.toString();
      throw EclassException(msg ?? 'Submission rejected');
    }

    if (submitForGrading) {
      final submitWarnings = await callWebService(
        'mod_assign_submit_for_grading',
        {'assignmentid': assignmentId, 'acceptsubmissionstatement': 1},
      );
      if (submitWarnings is List && submitWarnings.isNotEmpty) {
        final first = submitWarnings.first;
        final msg =
            first is Map ? first['message']?.toString() : first.toString();
        throw EclassException(msg ?? 'Submit for grading rejected');
      }
    }
  }

  Future<int> _uploadDraft(
    String token,
    String filePath,
    String filename,
    int itemId,
  ) async {
    final formData = FormData.fromMap({
      'token': token,
      'filearea': 'draft',
      'itemid': itemId,
      'file_1': await MultipartFile.fromFile(filePath, filename: filename),
    });

    final uploadResp = await _dio.post<dynamic>(
      '$baseUrl/webservice/upload.php',
      data: formData,
    );
    final res = uploadResp.data;
    if (res is Map && (res['error'] != null || res['exception'] != null)) {
      throw EclassException(
          (res['error'] ?? res['message'] ?? 'Upload rejected').toString());
    }
    if (res is! List || res.isEmpty || res.first['itemid'] == null) {
      throw EclassException('Unexpected upload response from eClass');
    }
    return int.parse(res.first['itemid'].toString());
  }

  static String syllabusUrl(String courseId) =>
      '$baseUrl/local/ubion/setting/syllabus.php?id=$courseId';
}
