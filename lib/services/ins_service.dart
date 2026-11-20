import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:xml/xml.dart';

import '../models/models.dart';
import 'http_redirects.dart';

class InsException implements Exception {
  final String message;
  InsException(this.message);
  @override
  String toString() => message;
}

/// Direct INS (ins.inha.uz) client — NO proxy used.
class InsService {
  static const String baseUrl = 'http://ins.inha.uz';
  static const String httpsBaseUrl = 'https://ins.inha.uz';
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  Dio _createDio(CookieJar jar) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: false,
        maxRedirects: 10,
        headers: _headers,
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (_, __, ___) => true;
        return client;
      },
    );
    dio.interceptors.add(CookieManager(jar));
    return dio;
  }

  Future<InsGradeData?> fetchGradesAndTranscript(
    String studentId,
    String insPassword,
  ) async {
    final jar = CookieJar();
    final dio = _createDio(jar);

    // 1. Fetch login page (try HTTP first, fallback to HTTPS on socket failure).
    late RedirectResponse<String> r1;
    try {
      r1 = await requestWithRedirects<String>(
        dio,
        '$baseUrl/ITIS/Start.aspx',
        options: Options(responseType: ResponseType.plain),
      );
    } catch (e) {
      try {
        r1 = await requestWithRedirects<String>(
          dio,
          '$httpsBaseUrl/ITIS/Start.aspx',
          options: Options(responseType: ResponseType.plain),
        );
      } catch (e2) {
        throw InsException('INS connection failed: $e2');
      }
    }

    final doc1 = html_parser.parse(r1.data ?? '');
    final form = doc1.querySelector('form');
    final actionRaw = form?.attributes['action'];
    final postUri = (actionRaw != null && actionRaw.isNotEmpty)
        ? r1.finalUri.resolve(actionRaw)
        : r1.finalUri;

    final payload = <String, String>{};
    for (final input in doc1.querySelectorAll('input[name]')) {
      final name = input.attributes['name'] ?? '';
      if (name.isEmpty) continue;
      final type = (input.attributes['type'] ?? 'text').toLowerCase();
      if (type == 'submit' || type == 'button' || type == 'reset') continue;
      payload[name] = input.attributes['value'] ?? '';
    }
    payload['txtInhaID'] = studentId.trim().toUpperCase();
    payload['txtPW'] = insPassword;
    payload['btnLogin'] =
        doc1.querySelector('input[name="btnLogin"]')?.attributes['value'] ?? '';

    final r2 = await requestWithRedirects<String>(
      dio,
      postUri.toString(),
      method: 'POST',
      data: payload,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
      ),
    );

    final body2 = r2.data ?? '';
    final doc2 = html_parser.parse(body2);
    final errMsg = doc2
            .querySelector('input[name="errorMessage"]')
            ?.attributes['value']
            ?.trim() ??
        '';
    if (errMsg.isNotEmpty) {
      throw InsException(errMsg);
    }

    // Handle JS redirect if Start.aspx emits window.location / location.href
    var authedUri = r2.finalUri;
    if (doc2.querySelector('input[name="txtPW"]') == null) {
      final jsRedirect = RegExp(
        r'''(?:window\.|top\.|self\.)?location(?:\.href)?\s*=\s*["']([^"']+)["']''',
        caseSensitive: false,
      ).firstMatch(body2);
      if (jsRedirect != null) {
        final nextTarget = jsRedirect.group(1)!.trim();
        if (nextTarget.isNotEmpty &&
            !nextTarget.toLowerCase().contains('start.aspx')) {
          final rNext = await requestWithRedirects<String>(
            dio,
            r2.finalUri.resolve(nextTarget).toString(),
            options: Options(responseType: ResponseType.plain),
          );
          authedUri = rNext.finalUri;
        }
      }
    }

    if (authedUri.path.toLowerCase().contains('start.aspx') &&
        doc2.querySelector('input[name="txtPW"]') != null &&
        !body2.toLowerCase().contains('logout')) {
      final alertMatch =
          RegExp(r'''alert\(\s*["']([^"']+)["']\s*\)''').firstMatch(body2);
      throw InsException(
        alertMatch != null
            ? alertMatch.group(1)!
            : 'Invalid student ID or INS password',
      );
    }

    final origin =
        '${authedUri.scheme}://${authedUri.host}${authedUri.hasPort ? ':${authedUri.port}' : ''}';

    // 2. Fetch rank from MarkView.aspx
    String? rank;
    try {
      final rRank = await requestWithRedirects<String>(
        dio,
        '$origin/ITIS/STD/SJ/SJ_51001/MarkView.aspx',
        options: Options(responseType: ResponseType.plain),
      );
      final rankDoc = html_parser.parse(rRank.data ?? '');
      final rankSpan = rankDoc.querySelector('span#lbRank');
      if (rankSpan != null && rankSpan.text.trim().isNotEmpty) {
        rank = rankSpan.text.trim();
      }
    } catch (_) {}

    // 3. Try XML via MarkView_rpx.aspx -> MarkView_xml.aspx
    try {
      final rFrame = await requestWithRedirects<String>(
        dio,
        '$origin/ITIS/STD/SJ/SJ_51001/MarkView_rpx.aspx?gubun=inform',
        options: Options(responseType: ResponseType.plain),
      );
      final xmlUrl = _extractXmlUrl(rFrame.data ?? '', rFrame.finalUri);
      if (xmlUrl != null) {
        final rXml = await requestWithRedirects<List<int>>(
          dio,
          xmlUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = rXml.data ?? [];
        final xmlText = _decodeEucKrOrUtf8(bytes);
        final parsed = _parseGradesXml(xmlText, rank: rank);
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    // 4. HTML fallback: pyungka_kwamok_list.aspx
    return _fetchHtmlFallback(dio, origin, rank: rank);
  }

  String? _extractXmlUrl(String html, Uri baseUri) {
    final m = RegExp(
      r'''ViewerReportInForm\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']''',
    ).firstMatch(html);
    if (m == null) return null;
    final endpoint = m.group(2)!.trim();
    return baseUri.resolve(endpoint).toString();
  }

  String _decodeEucKrOrUtf8(List<int> bytes) {
    try {
      return eucKr.decode(bytes);
    } catch (_) {
      return utf8.decode(bytes, allowMalformed: true);
    }
  }

  InsGradeData? _parseGradesXml(String xmlText, {String? rank}) {
    if (xmlText.trim().length < 20) return null;
    try {
      final doc = XmlDocument.parse(xmlText);
      final mainNodes = doc.findAllElements('MAIN');
      if (mainNodes.isEmpty) return null;
      final main = mainNodes.first;

      String getText(XmlElement el, String tag) {
        final found = el.findElements(tag);
        return found.isEmpty ? '' : found.first.innerText.trim();
      }

      final studentInfo = <String, String>{
        'id': getText(main, 'STNO'),
        'name': getText(main, 'KNAME'),
        'dept': getText(main, 'DEPT_KNAME'),
        'grade_year': getText(main, 'GRADE'),
        if (rank != null && rank.isNotEmpty) 'rank': rank,
      };

      String cleanGpa(String raw) {
        final v = double.tryParse(raw.trim().replaceAll(',', '.'));
        return v == null ? raw.trim() : v.toStringAsFixed(2);
      }

      String cleanNum(String raw) {
        final v = double.tryParse(raw.trim().replaceAll(',', '.'));
        if (v == null) return raw.trim();
        if (v == v.roundToDouble()) return v.round().toString();
        return v
            .toStringAsFixed(2)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
      }

      final gpaInfo = <String, String>{
        'gpa': cleanGpa(getText(main, 'COM_PYUNG')),
        'credits_attempted': cleanNum(getText(main, 'COM_CREDIT')),
        'credits_acquired': cleanNum(getText(main, 'SIN_CREDIT')),
        'total_score': cleanNum(getText(main, 'TOT_JUM')),
      };

      final courses = <InsCourseGrade>[];
      for (final mark in main.findElements('MARK')) {
        final title = getText(mark, 'KWAMOK_KNAME');
        final number = getText(mark, 'HAKSU_NO');
        if (title.isEmpty && number.isEmpty) continue;
        final grade = getText(mark, 'MARKS');
        courses.add(InsCourseGrade(
          courseNumber: number,
          title: title,
          credit: cleanNum(getText(mark, 'CREDIT')),
          grade: grade.isEmpty ? 'none' : grade,
          courseType: getText(mark, 'JONG_AKNAME'),
          semester: getText(mark, 'DISPLAY_YEARTERM'),
          yearterm: getText(mark, 'YEARTERM'),
        ));
      }

      final hasStudent = studentInfo['id']?.isNotEmpty == true ||
          studentInfo['name']?.isNotEmpty == true;
      if (courses.isEmpty && !hasStudent) return null;
      return InsGradeData(
        courses: courses,
        gpaInfo: gpaInfo,
        studentInfo: studentInfo,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  Future<InsGradeData?> _fetchHtmlFallback(
    Dio dio,
    String origin, {
    String? rank,
  }) async {
    try {
      final r = await requestWithRedirects<String>(
        dio,
        '$origin/ITIS/STD/SU/SU_21001/pyungka_kwamok_list.aspx',
        options: Options(responseType: ResponseType.plain),
      );
      final doc = html_parser.parse(r.data ?? '');
      final table = doc.querySelector('table#dgList') ??
          doc.querySelector('table.TableStyle01');
      if (table == null) return null;

      final rows = table.querySelectorAll('tr');
      final courses = <InsCourseGrade>[];
      for (int i = 1; i < rows.length; i++) {
        final cells = rows[i].querySelectorAll('td');
        if (cells.length < 7) continue;
        final gradeLink = cells[6].querySelector('a');
        final grade = (gradeLink != null && gradeLink.text.contains('Eval'))
            ? 'Eval'
            : cells[6].text.trim();
        courses.add(InsCourseGrade(
          courseNumber: cells[0].text.trim(),
          classNumber: cells[1].text.trim(),
          title: cells[2].text.trim(),
          professor: cells[3].text.trim(),
          courseType: cells[4].text.trim(),
          credit: cells[5].text.trim(),
          grade: grade,
        ));
      }

      final gpaInfo = <String, String>{};
      for (final span in doc.querySelectorAll('span')) {
        final sid = span.attributes['id'] ?? '';
        if (sid.contains('lblScore1')) {
          gpaInfo['credits_attempted'] = span.text.trim();
        } else if (sid.contains('lblScore2')) {
          gpaInfo['credits_acquired'] = span.text.trim();
        } else if (sid.contains('lblScore3')) {
          gpaInfo['gpa'] = span.text.trim();
        }
      }

      if (courses.isEmpty) return null;
      return InsGradeData(
        courses: courses,
        gpaInfo: gpaInfo,
        studentInfo: {if (rank != null && rank.isNotEmpty) 'rank': rank},
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }
}
