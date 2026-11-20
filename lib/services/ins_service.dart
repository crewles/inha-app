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

/// Direct INS (http://ins.inha.uz) client — NO proxy used.
class InsService {
  static const String baseUrl = 'http://ins.inha.uz';
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept-Language': 'ru-RU,ru;q=0.9,en-US;q=0.8,en;q=0.7',
  };

  Dio _createDio(CookieJar jar) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        followRedirects: true,
        maxRedirects: 8,
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

    // 1. Login to INS
    final loginUrl = '$baseUrl/ITIS/Start.aspx';
    final r1 = await dio.get<String>(loginUrl);
    final doc1 = html_parser.parse(r1.data ?? '');

    String field(String name) =>
        doc1.querySelector('input[name="$name"]')?.attributes['value'] ?? '';

    final r2 = await dio.post<String>(
      loginUrl,
      data: {
        '__VIEWSTATE': field('__VIEWSTATE'),
        '__VIEWSTATEGENERATOR': field('__VIEWSTATEGENERATOR'),
        '__EVENTVALIDATION': field('__EVENTVALIDATION'),
        'txtInhaID': studentId,
        'txtPW': insPassword,
        'btnLogin': 'Login',
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final finalUrl = r2.realUri.toString().toLowerCase();
    final body = (r2.data ?? '').toLowerCase();
    if (finalUrl.contains('start.aspx') && !body.contains('logout')) {
      return null;
    }

    // 2. Fetch rank from MarkView.aspx
    String? rank;
    try {
      final rRank = await dio.get<String>(
        '$baseUrl/ITIS/STD/SJ/SJ_51001/MarkView.aspx',
      );
      final rankDoc = html_parser.parse(rRank.data ?? '');
      final rankSpan = rankDoc.querySelector('span#lbRank');
      if (rankSpan != null && rankSpan.text.trim().isNotEmpty) {
        rank = rankSpan.text.trim();
      }
    } catch (_) {}

    // 3. Try XML via MarkView_rpx.aspx -> MarkView_xml.aspx
    try {
      final rFrame = await dio.get<String>(
        '$baseUrl/ITIS/STD/SJ/SJ_51001/MarkView_rpx.aspx?gubun=inform',
      );
      final xmlUrl = _extractXmlUrl(rFrame.data ?? '');
      if (xmlUrl != null) {
        final rXml = await dio.get<List<int>>(
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
    return _fetchHtmlFallback(dio, rank: rank);
  }

  String? _extractXmlUrl(String html) {
    final m = RegExp(
      r'''ViewerReportInForm\(\s*["']([^"']+)["']\s*,\s*["']([^"']+)["']''',
    ).firstMatch(html);
    if (m == null) return null;
    final endpoint = m.group(2)!;
    return '$baseUrl/ITIS/STD/SJ/SJ_51001/$endpoint';
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

      final gpaInfo = <String, String>{
        'gpa': getText(main, 'COM_PYUNG'),
        'credits_attempted': getText(main, 'COM_CREDIT'),
        'credits_acquired': getText(main, 'SIN_CREDIT'),
        'total_score': getText(main, 'TOT_JUM'),
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
          credit: getText(mark, 'CREDIT'),
          grade: grade.isEmpty ? 'none' : grade,
          courseType: getText(mark, 'JONG_AKNAME'),
          semester: getText(mark, 'DISPLAY_YEARTERM'),
          yearterm: getText(mark, 'YEARTERM'),
        ));
      }

      if (courses.isEmpty) return null;
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

  Future<InsGradeData?> _fetchHtmlFallback(Dio dio, {String? rank}) async {
    try {
      final r = await dio.get<String>(
        '$baseUrl/ITIS/STD/SU/SU_21001/pyungka_kwamok_list.aspx',
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
