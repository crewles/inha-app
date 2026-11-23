import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';
import 'http_redirects.dart';

class EclassException implements Exception {
  final String message;
  EclassException(this.message);
  @override
  String toString() => message;
}

class _InvalidTokenUploadException extends EclassException {
  _InvalidTokenUploadException(super.message);
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
  final List<String> _currentCourseRawHints = [];

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
    _currentCourseRawHints.clear();
  }

  // ── Auth (Moodle API Token + Web Session) ───────────────────

  Future<bool> login(String username, String password) async {
    _username = username;
    _password = password;
    _loggedIn = false;
    _userId = null;
    _currentCourseRawHints.clear();
    await _cookieJar.deleteAll();

    // 1. Try Moodle Mobile API token first (fastest & cleanest)
    final token = await fetchApiToken(refresh: true);

    // 2. Also establish web session (needed for Attendance & detailed HTML grades)
    final webOk = await _loginWeb(username, password);

    return (token != null && token.isNotEmpty) || webOk;
  }

  Future<bool> ensureWebLoggedIn() async {
    if (_loggedIn) return true;
    if (_username == null || _password == null) return false;
    return _loginWeb(_username!, _password!);
  }

  Future<bool> _loginWeb(String username, String password) async {
    try {
      final getRes = await requestWithRedirects<String>(
        _dio,
        '$baseUrl/login/index.php',
        options: Options(responseType: ResponseType.plain),
      );
      final body1 = getRes.data ?? '';
      if (!_isLoginPage(getRes.finalUri, body1)) {
        _loggedIn = true;
        return true;
      }

      final doc = html_parser.parse(body1);
      final form = doc.querySelector('form.form-login') ??
          doc.querySelector('form[action*="login"]') ??
          doc.querySelector('form');
      final actionRaw = form?.attributes['action'];
      final actionUri = (actionRaw != null && actionRaw.isNotEmpty)
          ? getRes.finalUri.resolve(actionRaw)
          : Uri.parse('$baseUrl/login/index.php');

      final payload = <String, String>{};
      if (form != null) {
        for (final input in form.querySelectorAll('input[name]')) {
          final name = input.attributes['name'] ?? '';
          if (name.isEmpty) continue;
          final type = (input.attributes['type'] ?? 'text').toLowerCase();
          if (type == 'hidden' || (type == 'submit' && name == 'loginbutton')) {
            payload[name] = input.attributes['value'] ?? '';
          }
        }
      }
      payload['username'] = username;
      payload['password'] = password;
      payload.putIfAbsent('loginbutton', () => 'Log in');

      final postRes = await requestWithRedirects<String>(
        _dio,
        actionUri.toString(),
        method: 'POST',
        data: payload,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.plain,
        ),
      );

      final body2 = postRes.data ?? '';
      if (_isLoginPage(postRes.finalUri, body2)) {
        _loggedIn = false;
        return false;
      }
      _loggedIn = true;
      return true;
    } catch (_) {
      _loggedIn = false;
      return false;
    }
  }

  bool _isLoginPage(Uri uri, String body) {
    final path = uri.path.toLowerCase();
    if (path.contains('/login')) return true;
    if (body.contains('loginerrormessage')) return true;
    final doc = html_parser.parse(body);
    return doc.querySelector('input[name="password"]') != null &&
        doc.querySelector('input[name="username"]') != null;
  }

  Future<RedirectResponse<String>> _getAuthedHtml(String url) async {
    await ensureWebLoggedIn();
    var res = await requestWithRedirects<String>(
      _dio,
      url,
      options: Options(responseType: ResponseType.plain),
    );
    if (_isLoginPage(res.finalUri, res.data ?? '') &&
        _username != null &&
        _password != null) {
      _loggedIn = false;
      await _cookieJar.deleteAll();
      if (await _loginWeb(_username!, _password!)) {
        res = await requestWithRedirects<String>(
          _dio,
          url,
          options: Options(responseType: ResponseType.plain),
        );
      }
    }
    return res;
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

  static bool isCustomAvatarUrl(String? url) {
    if (url == null) return false;
    final clean = url.trim();
    if (clean.isEmpty) return false;
    if (clean.contains('/theme/image.php/')) return false;
    final pathOnly = clean.split('?').first;
    if (pathOnly.endsWith('/u/f1') ||
        pathOnly.endsWith('/u/f2') ||
        pathOnly.endsWith('/u/f3')) {
      return false;
    }
    return clean.startsWith('http://') || clean.startsWith('https://');
  }

  static bool _hasValidImageMagicBytes(List<int> bytes) {
    if (bytes.length < 12) return false;
    final isJpeg = bytes[0] == 0xFF && bytes[1] == 0xD8;
    final isPng = bytes[0] == 0x89 && bytes[1] == 0x50;
    final isGif = bytes[0] == 0x47 && bytes[1] == 0x49;
    final isWebp = bytes[0] == 0x52 && bytes[1] == 0x49;
    return isJpeg || isPng || isGif || isWebp;
  }

  Future<String?> fetchProfilePhotoUrl() async {
    try {
      final info = await callWebService('core_webservice_get_site_info', {});
      if (info is Map) {
        if (info['userid'] != null) {
          _userId = int.tryParse(info['userid'].toString());
        }
        final pic = info['userpictureurl']?.toString() ?? '';
        if (isCustomAvatarUrl(pic)) return pic;
      }
    } catch (_) {}

    try {
      if (await ensureWebLoggedIn()) {
        final resp = await _getAuthedHtml(baseUrl);
        final doc = html_parser.parse(resp.data ?? '');
        final src = doc.querySelector('img.userpicture')?.attributes['src'];
        if (isCustomAvatarUrl(src)) return src;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> downloadProfilePhoto(String savePath) async {
    final url = await fetchProfilePhotoUrl();
    if (url == null) return null;

    final candidates = <String>[];
    final token = _apiToken;
    if (token != null &&
        token.isNotEmpty &&
        url.contains('/pluginfile.php/') &&
        !url.contains('/webservice/pluginfile.php/')) {
      final wsUrl =
          url.replaceFirst('/pluginfile.php/', '/webservice/pluginfile.php/');
      final sep = wsUrl.contains('?') ? '&' : '?';
      candidates.add('$wsUrl${sep}token=$token');
    }
    candidates.add(url);

    for (final dlUrl in candidates) {
      try {
        if (!dlUrl.contains('token=')) {
          await ensureWebLoggedIn();
        }
        final resp = await _dio.get<List<int>>(
          dlUrl,
          options: Options(responseType: ResponseType.bytes),
        );
        final bytes = resp.data;
        if (resp.statusCode == 200 &&
            bytes != null &&
            bytes.length > 200 &&
            _hasValidImageMagicBytes(bytes)) {
          final file = File(savePath);
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes, flush: true);
          return savePath;
        }
      } catch (_) {}
    }
    return null;
  }

  // ── eClass Private Files (/user/files.php & user/private) ──

  static String _normalizePrivatePath(String raw) {
    var s = raw.trim();
    if (s.isEmpty || s == '/') return '/';
    if (!s.startsWith('/')) s = '/$s';
    if (!s.endsWith('/')) s = '$s/';
    return s;
  }

  static int _parseHumanFileSize(String raw) {
    final m = RegExp(
      r'([0-9]+(?:[.,][0-9]+)?)\s*(bytes?|b|kb|kib|mb|mib|gb|gib)?',
      caseSensitive: false,
    ).firstMatch(raw.trim());
    if (m == null) return 0;
    final numVal = double.tryParse(m.group(1)!.replaceAll(',', '.')) ?? 0;
    if (numVal <= 0) return 0;
    final unit = (m.group(2) ?? '').toLowerCase();
    if (unit.startsWith('g')) return (numVal * 1024 * 1024 * 1024).round();
    if (unit.startsWith('m')) return (numVal * 1024 * 1024).round();
    if (unit.startsWith('k')) return (numVal * 1024).round();
    return numVal.round();
  }

  static ({List<EclassPrivateFile> files, Set<String> folderPaths})
      _parseFilemanagerListDetailed(
    List<dynamic> rawList, {
    String defaultPath = '/',
  }) {
    final files = <EclassPrivateFile>[];
    final folderPaths = <String>{};
    final normalizedDefault = _normalizePrivatePath(defaultPath);

    for (final item in rawList) {
      if (item is! Map) continue;
      final typeStr = (item['type'] ?? '').toString().trim().toLowerCase();
      final isDir = item['isdir'] == true || typeStr == 'folder';
      final rawFilename =
          (item['filename'] ?? item['fullname'] ?? '').toString().trim();

      if (isDir || rawFilename == '.') {
        var folderPath =
            (item['path'] ?? item['filepath'] ?? '').toString().trim();
        if (folderPath.isEmpty ||
            _normalizePrivatePath(folderPath) == normalizedDefault) {
          final folderName =
              (item['fullname'] ?? rawFilename).toString().trim();
          if (folderName.isNotEmpty && folderName != '.') {
            folderPath = '$normalizedDefault$folderName/';
          }
        }
        final normFolder = _normalizePrivatePath(folderPath);
        if (normFolder != '/') {
          folderPaths.add(normFolder);
        }
        final children = item['children'];
        if (children is List && children.isNotEmpty) {
          final sub = _parseFilemanagerListDetailed(
            children,
            defaultPath: normFolder,
          );
          files.addAll(sub.files);
          folderPaths.addAll(sub.folderPaths);
        }
        continue;
      }

      if (rawFilename.isEmpty) continue;
      final filepath = _normalizePrivatePath(
        (item['filepath'] ?? normalizedDefault).toString(),
      );
      final sizeText = (item['filesize'] ?? '').toString().trim();
      final rawNumSize =
          int.tryParse((item['rawsize'] ?? item['size'] ?? '').toString());
      final size = (rawNumSize != null && rawNumSize > 0)
          ? rawNumSize
          : _parseHumanFileSize(sizeText);
      final modifiedAt = int.tryParse(
            (item['timemodified'] ?? item['datemodified'] ?? '0').toString(),
          ) ??
          0;
      var modifiedText = (item['datemodified_f'] ??
              item['date'] ??
              item['datemodifiedFormatted'] ??
              '')
          .toString()
          .trim();
      if (modifiedText.isEmpty && modifiedAt > 0) {
        modifiedText = _formatUnixDate(modifiedAt);
      }
      var downloadUrl =
          (item['url'] ?? item['fileurl'] ?? '').toString().trim();
      if (downloadUrl.isNotEmpty && !downloadUrl.startsWith('http')) {
        downloadUrl = Uri.parse(baseUrl).resolve(downloadUrl).toString();
      }
      final fileType =
          (item['mimetype'] ?? item['type'] ?? '').toString().trim();

      files.add(EclassPrivateFile(
        id: '$filepath$rawFilename',
        filename: rawFilename,
        filepath: filepath,
        size: size,
        sizeText: sizeText,
        modifiedAt: modifiedAt,
        modifiedText: modifiedText,
        downloadUrl: downloadUrl,
        fileType: fileType,
      ));
    }

    return (files: files, folderPaths: folderPaths);
  }

  @visibleForTesting
  static List<EclassPrivateFile> parseFilemanagerList(
    List<dynamic> rawList, {
    String defaultPath = '/',
  }) =>
      _parseFilemanagerListDetailed(rawList, defaultPath: defaultPath).files;

  static ({
    List<EclassPrivateFile> files,
    Set<String> folderPaths,
    String? itemId,
    String? clientId,
    String? sesskey,
  }) _parsePrivateFilesHtmlDetailed(String html) {
    final files = <EclassPrivateFile>[];
    final folderPaths = <String>{};
    String? itemId;
    String? clientId;

    var searchFrom = 0;
    const marker = 'M.form_filemanager.init(';
    while (true) {
      final idx = html.indexOf(marker, searchFrom);
      if (idx < 0) break;
      final braceIdx = html.indexOf('{', idx + marker.length);
      if (braceIdx < 0) break;
      final jsonStr = _extractBalancedJsonObject(html, braceIdx);
      searchFrom = idx + marker.length;
      if (jsonStr == null) continue;
      try {
        final cfg = jsonDecode(jsonStr);
        if (cfg is! Map) continue;
        itemId ??= cfg['itemid']?.toString();
        clientId ??= cfg['client_id']?.toString();
        final list = cfg['list'];
        if (list is List) {
          final parsed = _parseFilemanagerListDetailed(
            list,
            defaultPath: (cfg['filepath'] ?? '/').toString(),
          );
          files.addAll(parsed.files);
          folderPaths.addAll(parsed.folderPaths);
        }
      } catch (_) {}
    }

    String? sesskey =
        RegExp(r'"sesskey"\s*:\s*"([^"]+)"').firstMatch(html)?.group(1);
    dom.Document? cachedDoc;
    if (sesskey == null || sesskey.isEmpty) {
      cachedDoc = html_parser.parse(html);
      sesskey = cachedDoc
          .querySelector('input[name="sesskey"]')
          ?.attributes['value']
          ?.trim();
    }

    if (files.isEmpty) {
      cachedDoc ??= html_parser.parse(html);
      final seenUrls = <String>{};
      for (final a in cachedDoc.querySelectorAll(
        'a[href*="draftfile.php"], a[href*="pluginfile.php"]',
      )) {
        final href = (a.attributes['href'] ?? '').trim();
        if (href.isEmpty) continue;
        final resolved = Uri.parse(baseUrl).resolve(href).toString();
        if (!seenUrls.add(resolved)) continue;
        var name = a.text.replaceAll('\u00A0', ' ').trim();
        if (name.isEmpty) {
          name = Uri.tryParse(resolved)?.pathSegments.last ?? '';
        }
        if (name.isEmpty) continue;
        files.add(EclassPrivateFile(
          id: '/$name',
          filename: name,
          filepath: '/',
          downloadUrl: resolved,
        ));
      }
    }

    return (
      files: files,
      folderPaths: folderPaths,
      itemId: itemId,
      clientId: clientId,
      sesskey: sesskey,
    );
  }

  @visibleForTesting
  static List<EclassPrivateFile> parsePrivateFilesHtml(String html) =>
      _parsePrivateFilesHtmlDetailed(html).files;

  Future<List<EclassPrivateFile>> getPrivateFiles() async {
    final byId = <String, EclassPrivateFile>{};
    var anySourceSucceeded = false;

    void mergeAll(Iterable<EclassPrivateFile> items, {bool preferNew = false}) {
      for (final f in items) {
        final existing = byId[f.id];
        if (existing == null) {
          byId[f.id] = f;
        } else if (preferNew) {
          byId[f.id] = EclassPrivateFile(
            id: f.id,
            filename: f.filename,
            filepath: f.filepath,
            size: f.size > 0 ? f.size : existing.size,
            sizeText:
                f.sizeText.isNotEmpty ? f.sizeText : existing.sizeText,
            modifiedAt:
                f.modifiedAt > 0 ? f.modifiedAt : existing.modifiedAt,
            modifiedText: f.modifiedText.isNotEmpty
                ? f.modifiedText
                : existing.modifiedText,
            downloadUrl:
                f.downloadUrl.isNotEmpty ? f.downloadUrl : existing.downloadUrl,
            fileType: f.fileType.isNotEmpty ? f.fileType : existing.fileType,
          );
        }
      }
    }

    // 1. Fetch eClass web Private Files page (/user/files.php) + subfolders
    try {
      final resp = await _getAuthedHtml('$baseUrl/user/files.php');
      final html = resp.data ?? '';
      if (!_isLoginPage(resp.finalUri, html)) {
        anySourceSucceeded = true;
        final parsed = _parsePrivateFilesHtmlDetailed(html);
        mergeAll(parsed.files);

        final sesskey = parsed.sesskey;
        final clientId = parsed.clientId;
        final itemId = parsed.itemId;
        if (sesskey != null &&
            sesskey.isNotEmpty &&
            clientId != null &&
            clientId.isNotEmpty &&
            itemId != null &&
            itemId.isNotEmpty &&
            parsed.folderPaths.isNotEmpty) {
          final queue = List<String>.from(parsed.folderPaths);
          final visited = <String>{'/'};
          while (queue.isNotEmpty && visited.length < 24) {
            final folderPath = queue.removeAt(0);
            if (!visited.add(folderPath)) continue;
            try {
              final ajaxResp = await _dio.post<dynamic>(
                '$baseUrl/repository/draftfiles_ajax.php?action=list',
                data: {
                  'sesskey': sesskey,
                  'client_id': clientId,
                  'itemid': itemId,
                  'filepath': folderPath,
                },
                options: Options(
                  contentType: Headers.formUrlEncodedContentType,
                  responseType: ResponseType.plain,
                ),
              );
              final rawText = (ajaxResp.data?.toString() ?? '').trim();
              if (rawText.isEmpty) continue;
              final decoded = jsonDecode(rawText);
              if (decoded is Map && decoded['list'] is List) {
                final sub = _parseFilemanagerListDetailed(
                  decoded['list'] as List,
                  defaultPath: folderPath,
                );
                mergeAll(sub.files);
                for (final p in sub.folderPaths) {
                  if (!visited.contains(p)) queue.add(p);
                }
              }
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // 2. Supplement/upgrade URLs with Moodle WS core_files_get_files (user/private)
    if (_apiToken != null || (_username != null && _password != null)) {
      try {
        final uid = await _getUserId();
        final queue = <String>['/'];
        final visited = <String>{};
        while (queue.isNotEmpty && visited.length < 24) {
          final path = queue.removeAt(0);
          if (!visited.add(path)) continue;
          final params = <String, dynamic>{
            'contextid': -1,
            'component': 'user',
            'filearea': 'private',
            'itemid': 0,
            'filepath': path,
            'filename': '',
            if (uid != null) 'contextlevel': 'user',
            if (uid != null) 'instanceid': uid,
          };
          final res = await callWebService('core_files_get_files', params);
          if (res is! Map) break;
          anySourceSucceeded = true;
          final rawFiles = (res['files'] as List?) ?? const [];
          for (final item in rawFiles) {
            if (item is! Map) continue;
            final isDir = item['isdir'] == true;
            final name = (item['filename'] ?? '').toString().trim();
            final fpath = _normalizePrivatePath(
              (item['filepath'] ?? path).toString(),
            );
            if (isDir) {
              if (fpath != '/' && !visited.contains(fpath)) {
                queue.add(fpath);
              } else if (name.isNotEmpty && name != '.') {
                final candidate = '$fpath$name/';
                if (!visited.contains(candidate)) queue.add(candidate);
              }
              continue;
            }
            if (name.isEmpty || name == '.') continue;
            final size = int.tryParse((item['filesize'] ?? '0').toString()) ?? 0;
            final modified =
                int.tryParse((item['timemodified'] ?? '0').toString()) ?? 0;
            final url = (item['url'] ?? '').toString().trim();
            final mime = (item['mimetype'] ?? '').toString().trim();
            mergeAll([
              EclassPrivateFile(
                id: '$fpath$name',
                filename: name,
                filepath: fpath,
                size: size,
                modifiedAt: modified,
                modifiedText: modified > 0 ? _formatUnixDate(modified) : '',
                downloadUrl: url,
                fileType: mime,
              ),
            ], preferNew: true);
          }
        }
      } catch (_) {}
    }

    if (!anySourceSucceeded) {
      throw EclassException('Could not reach eClass Private Files');
    }

    final out = byId.values.toList();
    out.sort((a, b) {
      final cmp = b.modifiedAt.compareTo(a.modifiedAt);
      if (cmp != 0) return cmp;
      return a.filename.toLowerCase().compareTo(b.filename.toLowerCase());
    });
    return out;
  }

  Future<String> downloadPrivateFile(
    EclassPrivateFile file, {
    void Function(int received, int total)? onProgress,
  }) async {
    Future<bool> looksLikeHtmlError(String path) async {
      final lower = file.filename.toLowerCase();
      if (lower.endsWith('.html') || lower.endsWith('.htm')) return false;
      try {
        final bytes = await File(path).openRead(0, 128).fold<List<int>>(
          <int>[],
          (prev, chunk) => prev..addAll(chunk),
        );
        final head = String.fromCharCodes(bytes).trimLeft().toLowerCase();
        return head.startsWith('<!doctype html') ||
            head.startsWith('<html');
      } catch (_) {
        return false;
      }
    }

    if (file.downloadUrl.isNotEmpty) {
      try {
        final saved = await downloadFile(
          file.downloadUrl,
          file.filename,
          onProgress: onProgress,
        );
        if (!await looksLikeHtmlError(saved)) {
          return saved;
        }
      } catch (_) {}
    }

    final refreshed = await getPrivateFiles();
    final match = refreshed.cast<EclassPrivateFile?>().firstWhere(
          (f) =>
              f?.id == file.id ||
              f?.filename.toLowerCase() == file.filename.toLowerCase(),
          orElse: () => null,
        );
    if (match == null || match.downloadUrl.isEmpty) {
      throw EclassException('Private file URL unavailable for ${file.filename}');
    }
    return downloadFile(
      match.downloadUrl,
      match.filename,
      onProgress: onProgress,
    );
  }

  // ── Courses (JSON API + current semester detection) ─────────

  String _unescapeText(String raw) {
    if (!raw.contains('&')) return raw.trim();
    return (html_parser.parseFragment(raw).text ?? raw)
        .replaceAll('\u00A0', ' ')
        .trim();
  }

  String _extractProfessor(dom.Element link) {
    dom.Element? node = link.parent;
    for (var depth = 0; depth < 4 && node != null; depth++) {
      final profEl = node.querySelector('.prof');
      if (profEl != null) {
        var raw = profEl.text
            .replaceAll('\u00A0', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        raw = raw.replaceFirst(
          RegExp(r'^(Professor|Prof\.|Lecturer|교수)\s*:\s*',
              caseSensitive: false),
          '',
        );
        return raw.trim();
      }
      node = node.parent;
    }
    return '';
  }

  Future<List<Course>> getCourses() async {
    final now = DateTime.now().millisecondsSinceEpoch;

    // Fetch active homepage course IDs (represents current semester in Ubion)
    final activeIds = <String>{};
    final profMap = <String, String>{};
    try {
      final resp = await _getAuthedHtml(baseUrl);
      if (!_isLoginPage(resp.finalUri, resp.data ?? '')) {
        final doc = html_parser.parse(resp.data ?? '');
        var links = doc.querySelectorAll('a.course_link');
        if (links.isEmpty) {
          links = doc.querySelectorAll('a[href*="course/view.php"]');
        }
        for (final a in links) {
          final href = a.attributes['href'] ?? '';
          if (!href.contains('id=')) continue;
          final cid = href.split('id=').last.split('&').first.trim();
          if (cid.isEmpty) continue;
          activeIds.add(cid);
          final prof = _extractProfessor(a);
          if (prof.isNotEmpty) profMap[cid] = prof;
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
          final apiHints = <String>[];
          for (final c in rawCourses) {
            final cid = c['id'].toString();
            final rawName = _unescapeText(
                (c['fullname'] ?? c['shortname'] ?? '').toString());
            final shortName = _unescapeText((c['shortname'] ?? '').toString());
            final idNumber = _unescapeText((c['idnumber'] ?? '').toString());
            final cleanName = rawName.replaceAll(RegExp(r'\[.*?\]'), '').trim();
            final cat = (c['category'] as int?) ?? 0;
            final isCur = activeIds.isNotEmpty
                ? activeIds.contains(cid)
                : (maxCat == 0 || cat == maxCat);
            if (isCur) {
              if (rawName.isNotEmpty) apiHints.add(rawName);
              if (shortName.isNotEmpty) apiHints.add(shortName);
              if (idNumber.isNotEmpty) apiHints.add(idNumber);
            }
            if (cleanName.isNotEmpty) {
              courses.add(Course(
                id: cid,
                name: cleanName,
                category: cat,
                isCurrent: isCur,
                overviewGrade: overviewMap[cid],
                professor: profMap[cid] ?? '',
                updatedAt: now,
              ));
            }
          }
          if (courses.isNotEmpty) {
            _currentCourseRawHints
              ..clear()
              ..addAll(apiHints);
            return courses;
          }
        }
      }
    } catch (_) {}

    // Fallback: HTML homepage scraping
    final resp = await _getAuthedHtml(baseUrl);
    final doc = html_parser.parse(resp.data ?? '');
    var links = doc.querySelectorAll('a.course_link');
    if (links.isEmpty) {
      links = doc.querySelectorAll('a[href*="course/view.php"]');
    }
    final seen = <String>{};
    final courses = <Course>[];
    final htmlHints = <String>[];
    for (final a in links) {
      final href = a.attributes['href'] ?? '';
      if (!href.contains('id=')) continue;
      final courseId = href.split('id=').last.split('&').first.trim();
      if (courseId.isEmpty || seen.contains(courseId)) continue;
      final h3 = a.querySelector('h3');
      final rawName = _unescapeText((h3 ?? a).text);
      final name = rawName.replaceAll(RegExp(r'\[.*?\]'), '').trim();
      if (name.isEmpty) continue;
      if (rawName.isNotEmpty) htmlHints.add(rawName);
      seen.add(courseId);
      courses.add(Course(
        id: courseId,
        name: name,
        professor: profMap[courseId] ?? _extractProfessor(a),
        updatedAt: now,
      ));
    }
    if (courses.isNotEmpty) {
      _currentCourseRawHints
        ..clear()
        ..addAll(htmlHints);
    }
    return courses;
  }

  /// Collects raw course names/codes, Moodle course groups, and user profile
  /// fields to help infer the student's EduPage section (e.g. `CSE25-1`).
  Future<List<String>> fetchStudentGroupHints() async {
    final hints = <String>{
      for (final h in _currentCourseRawHints)
        if (h.trim().isNotEmpty) h.trim(),
    };

    try {
      final uid = await _getUserId();
      if (uid != null) {
        try {
          final grpRes = await callWebService(
            'core_group_get_course_user_groups',
            {'userid': uid},
          );
          if (grpRes is Map && grpRes['groups'] is List) {
            for (final g in grpRes['groups'] as List) {
              if (g is! Map) continue;
              final name = _unescapeText((g['name'] ?? '').toString());
              final desc = _htmlToPlainText((g['description'] ?? '').toString());
              if (name.isNotEmpty) hints.add(name);
              if (desc.isNotEmpty) hints.add(desc);
            }
          }
        } catch (_) {}

        try {
          final userRes = await callWebService(
            'core_user_get_users_by_field',
            {'field': 'id', 'values[0]': uid},
          );
          if (userRes is List) {
            for (final u in userRes) {
              if (u is! Map) continue;
              for (final key in const ['department', 'institution']) {
                final v = _unescapeText((u[key] ?? '').toString());
                if (v.isNotEmpty) hints.add(v);
              }
              final desc = _htmlToPlainText((u['description'] ?? '').toString());
              if (desc.isNotEmpty) hints.add(desc);
              if (u['customfields'] is List) {
                for (final cf in u['customfields'] as List) {
                  if (cf is! Map) continue;
                  final v = _htmlToPlainText((cf['value'] ?? '').toString());
                  if (v.isNotEmpty) hints.add(v);
                }
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}

    return hints.toList();
  }

  // ── Assignments (Fast JSON API + Status + HTML fallback) ────

  String _htmlToPlainText(String rawHtml) {
    if (rawHtml.trim().isEmpty) return '';
    final normalized = rawHtml
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(
            RegExp(r'</(p|div|li|tr|h[1-6])>', caseSensitive: false), '\n');
    final text = html_parser.parseFragment(normalized).text ?? '';
    return text
        .replaceAll('\u00A0', ' ')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  /// Fetches ALL assignments for the given courseIds (or all enrolled courses if empty)
  /// in a single Moodle API call, then enriches submission status, files, intro & grade.
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
      final rawCName = _unescapeText(
              (courseNamesById?[cid] ?? c['fullname'] ?? c['shortname'] ?? '')
                  .toString())
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .trim();

      for (final a in (c['assignments'] as List?) ?? []) {
        final assignId = int.tryParse(a['id'].toString()) ?? 0;
        final cmid = a['cmid']?.toString();
        final name = _unescapeText((a['name'] ?? '').toString());
        final dueTs = (a['duedate'] as int?) ?? 0;
        final cutoffTs = (a['cutoffdate'] as int?) ?? 0;
        final dueStr = dueTs > 0 ? _formatUnixDate(dueTs) : '';
        final intro = _htmlToPlainText((a['intro'] ?? '').toString());
        final rawMaxGrade = num.tryParse(a['grade']?.toString() ?? '');
        final maxPoints = (rawMaxGrade != null && rawMaxGrade > 0)
            ? _trimZeros(rawMaxGrade.toString())
            : null;

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
        final submittedFiles = <AssignmentFile>[];
        var feedbackComment = '';
        var isGradedFlag = false;

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
                isGradedFlag = last['graded'] == true;
                if (subStatus == 'submitted') {
                  status = isGradedFlag
                      ? 'Submitted (Graded)'
                      : 'Submitted for grading';
                } else if (subStatus == 'draft') {
                  status = 'Draft (not submitted)';
                } else {
                  status = isGradedFlag ? 'Graded' : 'No submission';
                }

                if (sub is Map) {
                  for (final pl in (sub['plugins'] as List?) ?? []) {
                    if (pl is! Map || pl['type'] != 'file') continue;
                    for (final fa in (pl['fileareas'] as List?) ?? []) {
                      if (fa is! Map) continue;
                      for (final f in (fa['files'] as List?) ?? []) {
                        if (f is! Map) continue;
                        final furl = f['fileurl']?.toString() ?? '';
                        if (furl.isNotEmpty) {
                          submittedFiles.add(AssignmentFile(
                            name: (f['filename'] ?? 'file').toString(),
                            link: furl,
                            size: (f['filesize'] as int?) ?? 0,
                          ));
                        }
                      }
                    }
                  }
                }
              }
              final fb = st['feedback'];
              if (fb is Map) {
                if (fb['gradefordisplay'] != null) {
                  final rawGrade = html_parser
                      .parseFragment(fb['gradefordisplay'].toString())
                      .text
                      ?.replaceAll('\u00A0', ' ')
                      .trim();
                  if (rawGrade != null &&
                      rawGrade.isNotEmpty &&
                      rawGrade != '-') {
                    final m =
                        RegExp(r'([\d.]+)\s*/\s*([\d.]+)').firstMatch(rawGrade);
                    if (m != null) {
                      grade = _trimZeros(m.group(1)!);
                      gradeMax = _trimZeros(m.group(2)!);
                    } else {
                      grade = rawGrade;
                    }
                  }
                }
                for (final pl in (fb['plugins'] as List?) ?? []) {
                  if (pl is! Map || pl['type'] != 'comments') continue;
                  for (final ef in (pl['editorfields'] as List?) ?? []) {
                    if (ef is! Map) continue;
                    final parsed =
                        _htmlToPlainText((ef['text'] ?? '').toString());
                    if (parsed.isNotEmpty) {
                      feedbackComment = feedbackComment.isEmpty
                          ? parsed
                          : '$feedbackComment\n$parsed';
                    }
                  }
                }
              }
              if (grade != null && grade.isNotEmpty) {
                if (status == 'Submitted for grading') {
                  status = 'Submitted (Graded)';
                } else if (status == 'No submission') {
                  status = 'Graded';
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
          intro: intro,
          maxPoints: maxPoints,
          cutoffTimestamp: cutoffTs,
          submittedFiles: submittedFiles,
          feedbackComment: feedbackComment,
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
    final resp = await _getAuthedHtml(
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

  static String _formatUnixDate(int unixSeconds) {
    // Format in Tashkent (UTC+5)
    final dt =
        DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000, isUtc: true)
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

  // ── Grades (HTML report + API fallback) ─────────────────────

  String _cleanCellText(dom.Element? el) {
    if (el == null) return '';
    final buf = StringBuffer();
    void walk(dom.Node node) {
      if (node is dom.Text) {
        buf.write(node.text);
        return;
      }
      if (node is dom.Element) {
        final cls = node.classes;
        if (cls.contains('accesshide') || cls.contains('sr-only')) return;
        for (final child in node.nodes) {
          walk(child);
        }
      }
    }

    walk(el);
    return buf
        .toString()
        .replaceAll('\u00A0', ' ')
        .replaceAll('Учитывать пустые оценки.', '')
        .replaceAll('Aggregate only non-empty grades.', '')
        .replaceAll('Include empty grades.', '')
        .replaceAll('Simple weighted mean of grades.', '')
        .replaceAll('Weighted mean of grades.', '')
        .replaceAll('Natural.', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<List<GradeItem>> getGrades(String courseId,
      {String? overviewGrade}) async {
    final grades = <GradeItem>[];
    try {
      final resp = await _getAuthedHtml(
        '$baseUrl/grade/report/user/index.php?id=$courseId',
      );
      if (!_isLoginPage(resp.finalUri, resp.data ?? '')) {
        final doc = html_parser.parse(resp.data ?? '');
        final table = doc.querySelector('table.user-grade');
        if (table != null) {
          var currentCategory = '';
          final tbody = table.querySelector('tbody') ?? table;
          for (final row in tbody.querySelectorAll('tr')) {
            if (row.parent?.localName == 'thead') continue;
            final itemCell = row.querySelector('.column-itemname');
            if (itemCell == null) continue;

            final name = _cleanCellText(itemCell)
                .replaceFirst(RegExp(r'^[∑\u2211]\s*'), '')
                .trim();
            if (name.isEmpty || name == 'Grade item') continue;

            final gradeCell = row.querySelector('td.column-grade');
            final weightCell = row.querySelector('td.column-weight');
            final rangeCell = row.querySelector('td.column-range');
            final pctCell = row.querySelector('td.column-percentage');

            final val = _cleanCellText(gradeCell);
            final weight = _cleanCellText(weightCell);
            final range = _cleanCellText(rangeCell);
            final pct = _cleanCellText(pctCell);

            if (val == 'Grade' ||
                weight == 'Calculated weight' ||
                range == 'Range') {
              continue;
            }

            final itemClasses = itemCell.classes;
            final rowClasses = row.classes;
            final isLevel1 =
                itemClasses.contains('level1') || rowClasses.contains('level1');
            final lowerName = name.toLowerCase();
            final isExplicitCourseTotal =
                lowerName.startsWith('course total') ||
                    lowerName.startsWith('итого за курс') ||
                    name.contains('강좌 총점');

            final isSum = !isExplicitCourseTotal &&
                (RegExp(r'\bSUM$', caseSensitive: false).hasMatch(name) ||
                    lowerName.contains('category total') ||
                    name.contains('합계') ||
                    (!isLevel1 &&
                        (itemClasses.contains('baggb') ||
                            rowClasses.contains('baggb'))));

            final isTotal = isExplicitCourseTotal ||
                (!isSum &&
                    (itemClasses.contains('baggt') ||
                        rowClasses.contains('baggt') ||
                        (isLevel1 &&
                            (itemClasses.contains('baggb') ||
                                rowClasses.contains('baggb')))));

            final isCategoryFolder = !isTotal &&
                !isSum &&
                gradeCell == null &&
                (itemClasses.contains('category') ||
                    rowClasses.contains('category') ||
                    (weightCell == null && rangeCell == null));

            if (isCategoryFolder) {
              currentCategory = isLevel1 ? '' : name;
              continue;
            }

            if (isTotal) {
              grades.add(GradeItem(
                courseId: courseId,
                name: name,
                value: val.isEmpty ? '-' : val,
                category: '',
                weight: weight,
                range: range,
                percentage: pct,
                itemType: 'total',
              ));
              currentCategory = '';
              continue;
            }

            if (isSum) {
              final derivedCat = currentCategory.isNotEmpty
                  ? currentCategory
                  : name
                      .replaceAll(
                          RegExp(r'\s*\bSUM$', caseSensitive: false), '')
                      .replaceAll(
                          RegExp(r'\s*Category total$', caseSensitive: false),
                          '')
                      .trim();
              grades.add(GradeItem(
                courseId: courseId,
                name: name,
                value: val.isEmpty ? '-' : val,
                category: derivedCat,
                weight: weight,
                range: range,
                percentage: pct,
                itemType: 'sum',
              ));
              currentCategory = '';
              continue;
            }

            grades.add(GradeItem(
              courseId: courseId,
              name: name,
              value: val.isEmpty ? '-' : val,
              category: currentCategory,
              weight: weight,
              range: range,
              percentage: pct,
              itemType: 'item',
            ));
          }
        }
      }
    } catch (_) {}

    // Fallback 1: Moodle Mobile API per-course grade items
    if (grades.isEmpty) {
      try {
        final uid = await _getUserId();
        if (uid != null) {
          final res = await callWebService(
            'gradereport_user_get_grade_items',
            {'courseid': courseId, 'userid': uid},
          );
          if (res is Map && res['usergrades'] is List) {
            final ugs = res['usergrades'] as List;
            if (ugs.isNotEmpty && ugs.first is Map) {
              final items = (ugs.first['gradeitems'] as List?) ?? [];
              for (final raw in items) {
                if (raw is! Map) continue;
                final rawType = (raw['itemtype'] ?? '').toString();
                final name = (raw['itemname'] ??
                        (rawType == 'course' ? 'Course total' : 'Category'))
                    .toString()
                    .trim();
                final val = (raw['gradeformatted'] ?? '-').toString().trim();
                final weight = (raw['weightformatted'] ?? '').toString().trim();
                final pct =
                    (raw['percentageformatted'] ?? '').toString().trim();
                final minG = raw['grademin']?.toString() ?? '0';
                final maxG = raw['grademax']?.toString() ?? '0';
                final range = '$minG-$maxG';
                final itemType = rawType == 'course'
                    ? 'total'
                    : (rawType == 'category' ? 'sum' : 'item');
                if (name.isNotEmpty) {
                  grades.add(GradeItem(
                    courseId: courseId,
                    name: name,
                    value: val.isEmpty ? '-' : val,
                    weight: weight,
                    range: range,
                    percentage: pct,
                    itemType: itemType,
                  ));
                }
              }
            }
          }
        }
      } catch (_) {}
    }

    if (grades.isEmpty &&
        overviewGrade != null &&
        overviewGrade.isNotEmpty &&
        overviewGrade != '-') {
      grades.add(GradeItem(
        courseId: courseId,
        name: 'Course Total',
        value: overviewGrade,
        itemType: 'total',
      ));
    }
    return grades;
  }

  // ── Attendance (Ubion HTML) ─────────────────────────────────

  Future<AttendanceData?> getAttendance(String courseId) async {
    final resp = await _getAuthedHtml(
      '$baseUrl/local/ubattendance/my_status.php?id=$courseId',
    );
    if (_isLoginPage(resp.finalUri, resp.data ?? '')) return null;
    final doc = html_parser.parse(resp.data ?? '');
    final table = doc.querySelector('table.attendance_my') ??
        doc.querySelector('.attendance_my table') ??
        doc.querySelector('table.generaltable');
    if (table == null) return null;

    final records = <AttendanceRecord>[];
    final tbody = table.querySelector('tbody');
    final rows = tbody != null
        ? tbody.querySelectorAll('tr')
        : table
            .querySelectorAll('tr')
            .where((tr) =>
                tr.parent?.localName != 'thead' &&
                tr.parent?.localName != 'tfoot')
            .toList();

    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length >= 6) {
        final date = _cleanCellText(cells[0]);
        final clsName = _cleanCellText(cells[1]);
        if (date.isEmpty && clsName.isEmpty) continue;
        if (date.toLowerCase().startsWith('total') || date.startsWith('합계')) {
          continue;
        }
        records.add(AttendanceRecord(
          date: date,
          className: clsName,
          attendance: _cleanCellText(cells[2]),
          absence: _cleanCellText(cells[3]),
          late: _cleanCellText(cells[4]),
          others: _cleanCellText(cells[5]),
        ));
      }
    }

    int att = 0, abs = 0, late = 0, oth = 0;
    final tfoot = table.querySelector('tfoot');
    if (tfoot != null) {
      final text = tfoot.text.replaceAll('\u00A0', ' ');
      att = _extractInt(text, ['Attendance', '출석', 'Присут']);
      abs = _extractInt(text, ['Absence', 'Absent', '결석', 'Отсут']);
      late = _extractInt(text, ['Late', '지각', 'Опозд']);
      oth = _extractInt(text, ['Others', 'Other', '기타', 'Проч']);
    }

    if (att + abs + late + oth == 0 && records.isNotEmpty) {
      for (final r in records) {
        if (AttendanceRecord.isCellMarked(r.attendance)) {
          att++;
        } else if (AttendanceRecord.isCellMarked(r.absence)) {
          abs++;
        } else if (AttendanceRecord.isCellMarked(r.late)) {
          late++;
        } else if (AttendanceRecord.isCellMarked(r.others)) {
          oth++;
        }
      }
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

  int _extractInt(String text, List<String> keys) {
    for (final key in keys) {
      final m =
          RegExp('$key\\s*:\\s*(\\d+)', caseSensitive: false).firstMatch(text);
      if (m != null) {
        return int.tryParse(m.group(1)!) ?? 0;
      }
    }
    return 0;
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
      final resp =
          await _getAuthedHtml('$baseUrl/course/view.php?id=$courseId');
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
    final dir = await getApplicationDocumentsDirectory();
    final filesDir = Directory(p.join(dir.path, 'downloads'));
    if (!await filesDir.exists()) {
      await filesDir.create(recursive: true);
    }

    final safeName = filename.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final savePath = p.join(filesDir.path, safeName);

    if (url.contains('/webservice/pluginfile.php')) {
      String downloadUrl = url;
      final token = await fetchApiToken();
      if (token != null && token.isNotEmpty && !url.contains('token=')) {
        downloadUrl = '$url${url.contains('?') ? '&' : '?'}token=$token';
      }
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

    await ensureWebLoggedIn();
    var res = await requestWithRedirects<List<int>>(
      _dio,
      url,
      onReceiveProgress: onProgress,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    if (res.finalUri.path.toLowerCase().contains('/login') &&
        _username != null &&
        _password != null) {
      _loggedIn = false;
      await _cookieJar.deleteAll();
      if (await _loginWeb(_username!, _password!)) {
        res = await requestWithRedirects<List<int>>(
          _dio,
          url,
          onReceiveProgress: onProgress,
          options: Options(
            responseType: ResponseType.bytes,
            receiveTimeout: const Duration(minutes: 3),
          ),
        );
      }
    }
    if (res.finalUri.path.toLowerCase().contains('/login')) {
      throw EclassException('Session expired while downloading $filename');
    }
    final bytes = res.data;
    if (bytes == null || bytes.isEmpty) {
      throw EclassException('Empty download response for $filename');
    }
    await File(savePath).writeAsBytes(bytes, flush: true);
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

  /// Parses Moodle's `webservice/upload.php` response (often served as `text/plain`).
  static int parseUploadResponse(dynamic raw) {
    dynamic decoded = raw;
    if (raw is String) {
      var text = raw.trim();
      if (text.isEmpty) {
        throw EclassException('Empty upload response from eClass');
      }
      if (!text.startsWith('[') && !text.startsWith('{')) {
        final arrIdx = text.indexOf('[');
        final objIdx = text.indexOf('{');
        final starts = [arrIdx, objIdx].where((i) => i >= 0).toList();
        if (starts.isNotEmpty) {
          starts.sort();
          text = text.substring(starts.first);
        }
      }
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        throw EclassException('Unexpected upload response from eClass');
      }
    }

    if (decoded is Map) {
      final errorCode = decoded['errorcode']?.toString();
      final errText = decoded['error'] ?? decoded['message'];
      if (errorCode == 'invalidtoken') {
        throw _InvalidTokenUploadException(
            (errText ?? 'Invalid token').toString());
      }
      if (errText != null || decoded['exception'] != null) {
        throw EclassException((errText ?? 'Upload rejected').toString());
      }
      throw EclassException('Unexpected upload response from eClass');
    }

    if (decoded is List) {
      if (decoded.isEmpty) {
        throw EclassException('Empty upload response from eClass');
      }
      final first = decoded.first;
      if (first is Map) {
        final itemErr = first['error'] ?? first['errortype'];
        if (itemErr != null && itemErr.toString().trim().isNotEmpty) {
          if (first['errorcode']?.toString() == 'invalidtoken') {
            throw _InvalidTokenUploadException(itemErr.toString());
          }
          throw EclassException(itemErr.toString());
        }
        final rawId = first['itemid'];
        final parsed = rawId == null ? null : int.tryParse(rawId.toString());
        if (parsed != null) {
          return parsed;
        }
      }
      throw EclassException('Unexpected upload response from eClass');
    }

    throw EclassException('Unexpected upload response from eClass');
  }

  Future<({String? cmid, int? maxFiles, bool onlineTextEnabled})>
      _getAssignmentMeta(int assignmentId) async {
    try {
      final res = await callWebService('mod_assign_get_assignments', {});
      if (res is Map) {
        for (final c in (res['courses'] as List?) ?? []) {
          for (final a in (c['assignments'] as List?) ?? []) {
            if (int.tryParse(a['id']?.toString() ?? '') != assignmentId) {
              continue;
            }
            final cmid = a['cmid']?.toString();
            int? maxFiles;
            var onlineTextEnabled = false;
            for (final cfg in (a['configs'] as List?) ?? []) {
              if (cfg is! Map) continue;
              final plugin = cfg['plugin']?.toString();
              final name = cfg['name']?.toString();
              final val = cfg['value']?.toString();
              if (plugin == 'file' && name == 'maxfilesubmissions') {
                maxFiles = int.tryParse(val ?? '');
              } else if (plugin == 'onlinetext' &&
                  name == 'enabled' &&
                  val == '1') {
                onlineTextEnabled = true;
              }
            }
            return (
              cmid: cmid,
              maxFiles: maxFiles,
              onlineTextEnabled: onlineTextEnabled,
            );
          }
        }
      }
    } catch (_) {}
    return (cmid: null, maxFiles: null, onlineTextEnabled: false);
  }

  static String? _extractCmidFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    final parsed = Uri.tryParse(url);
    final id = parsed?.queryParameters['id']?.trim();
    if (id != null && id.isNotEmpty) return id;
    return null;
  }

  Future<void> uploadSubmission(
    int assignmentId,
    String filePath,
    String filename, {
    bool submitForGrading = false,
    String? assignmentUrl,
  }) async {
    // Check existing submission files & online text before uploading
    final existing = <Map<String, String>>[];
    var hasOnlineTextPlugin = false;
    var existingOnlineText = '';
    var existingOnlineTextFormat = 1;
    var hardLocked = false;

    try {
      final st = await callWebService(
          'mod_assign_get_submission_status', {'assignid': assignmentId});
      if (st is Map) {
        final last = st['lastattempt'];
        if (last is Map && last['canedit'] == false) {
          hardLocked = true;
          throw EclassException('This submission can no longer be edited.');
        }
        final sub = last is Map ? last['submission'] : null;
        if (sub is Map) {
          for (final pl in (sub['plugins'] as List?) ?? []) {
            if (pl is! Map) continue;
            final type = pl['type']?.toString();
            if (type == 'file') {
              for (final fa in (pl['fileareas'] as List?) ?? []) {
                if (fa is! Map) continue;
                for (final f in (fa['files'] as List?) ?? []) {
                  if (f is! Map) continue;
                  final fn = f['filename']?.toString() ?? '';
                  final furl = f['fileurl']?.toString() ?? '';
                  if (fn.isNotEmpty && furl.isNotEmpty && fn != filename) {
                    existing.add({'filename': fn, 'url': furl});
                  }
                }
              }
            } else if (type == 'onlinetext') {
              hasOnlineTextPlugin = true;
              final fields = (pl['editorfields'] as List?) ?? [];
              if (fields.isNotEmpty && fields.first is Map) {
                final firstField = fields.first as Map;
                existingOnlineText = firstField['text']?.toString() ?? '';
                existingOnlineTextFormat =
                    int.tryParse(firstField['format']?.toString() ?? '') ?? 1;
              }
            }
          }
        }
      }
    } catch (e) {
      if (hardLocked) rethrow;
    }

    final meta = await _getAssignmentMeta(assignmentId);
    if (meta.onlineTextEnabled) {
      hasOnlineTextPlugin = true;
    }
    final effectiveCmid = _extractCmidFromUrl(assignmentUrl) ?? meta.cmid;

    try {
      final itemId = await _uploadDraft(filePath, filename, 0);

      // Re-attach previous files only when assignment allows multiple files
      final maxFiles = meta.maxFiles;
      if (existing.isNotEmpty && maxFiles != null && maxFiles > 1) {
        final token = await fetchApiToken();
        if (token != null && token.isNotEmpty) {
          final tmpDir = await getTemporaryDirectory();
          for (final old in existing.take(maxFiles - 1)) {
            final safeName = p.basename(old['filename']!);
            final tmpPath = p.join(tmpDir.path, 'prev_$safeName');
            try {
              final url = old['url']!;
              final dlUrl = url.contains('token=')
                  ? url
                  : '$url${url.contains('?') ? '&' : '?'}token=$token';
              await _dio.download(dlUrl, tmpPath);
              await _uploadDraft(tmpPath, old['filename']!, itemId);
            } catch (_) {
            } finally {
              final f = File(tmpPath);
              if (await f.exists()) await f.delete();
            }
          }
        }
      }

      final saveParams = <String, dynamic>{
        'assignmentid': assignmentId,
        'plugindata[files_filemanager]': itemId,
      };
      if (hasOnlineTextPlugin) {
        saveParams['plugindata[onlinetext_editor][text]'] = existingOnlineText;
        saveParams['plugindata[onlinetext_editor][format]'] =
            existingOnlineTextFormat;
        saveParams['plugindata[onlinetext_editor][itemid]'] = 0;
      }

      dynamic warnings;
      try {
        warnings =
            await callWebService('mod_assign_save_submission', saveParams);
      } on EclassException catch (e) {
        if (!hasOnlineTextPlugin &&
            e.message.toLowerCase().contains('onlinetext')) {
          saveParams['plugindata[onlinetext_editor][text]'] =
              existingOnlineText;
          saveParams['plugindata[onlinetext_editor][format]'] =
              existingOnlineTextFormat;
          saveParams['plugindata[onlinetext_editor][itemid]'] = 0;
          warnings =
              await callWebService('mod_assign_save_submission', saveParams);
        } else {
          rethrow;
        }
      }

      if (warnings is List && warnings.isNotEmpty) {
        final first = warnings.first;
        final msg = first is Map
            ? (first['message'] ?? first['warningcode'])?.toString()
            : first.toString();
        throw EclassException(msg ?? 'Submission rejected');
      }

      if (submitForGrading) {
        var shouldSubmit = true;
        try {
          final afterSt = await callWebService(
            'mod_assign_get_submission_status',
            {'assignid': assignmentId},
          );
          if (afterSt is Map) {
            final last = afterSt['lastattempt'];
            if (last is Map) {
              final sub = last['submission'];
              final subStatus = sub is Map ? sub['status']?.toString() : null;
              final canSubmit = last['cansubmit'] == true;
              if (subStatus == 'submitted' || !canSubmit) {
                shouldSubmit = false;
              }
            }
          }
        } catch (_) {}

        if (shouldSubmit) {
          final submitWarnings = await callWebService(
            'mod_assign_submit_for_grading',
            {'assignmentid': assignmentId, 'acceptsubmissionstatement': 1},
          );
          if (submitWarnings is List && submitWarnings.isNotEmpty) {
            final first = submitWarnings.first;
            final msg = first is Map
                ? (first['message'] ?? first['warningcode'])?.toString()
                : first.toString();
            throw EclassException(msg ?? 'Submit for grading rejected');
          }
        }
      }
    } catch (e) {
      if (effectiveCmid != null &&
          effectiveCmid.isNotEmpty &&
          await ensureWebLoggedIn()) {
        await _uploadSubmissionViaWeb(
          effectiveCmid,
          filePath,
          filename,
          submitForGrading: submitForGrading,
        );
        return;
      }
      rethrow;
    }
  }

  /// Finalizes an already-saved draft assignment submission for grading.
  Future<void> submitExistingDraft(int assignmentId) async {
    final st = await callWebService(
      'mod_assign_get_submission_status',
      {'assignid': assignmentId},
    );
    if (st is! Map) {
      throw EclassException('Could not check submission status');
    }
    final last = st['lastattempt'];
    if (last is! Map) {
      throw EclassException('Could not check submission status');
    }
    final sub = last['submission'];
    final subStatus = sub is Map ? sub['status']?.toString() : null;
    if (subStatus == 'submitted') return;
    if (last['cansubmit'] != true) {
      throw EclassException('This submission cannot be finalized right now.');
    }
    final submitWarnings = await callWebService(
      'mod_assign_submit_for_grading',
      {'assignmentid': assignmentId, 'acceptsubmissionstatement': 1},
    );
    if (submitWarnings is List && submitWarnings.isNotEmpty) {
      final first = submitWarnings.first;
      final msg = first is Map
          ? (first['message'] ?? first['warningcode'])?.toString()
          : first.toString();
      throw EclassException(msg ?? 'Submit for grading rejected');
    }
  }

  Future<int> _uploadDraft(
    String filePath,
    String filename,
    int itemId,
  ) async {
    for (int attempt = 0; attempt < 2; attempt++) {
      final token = await fetchApiToken(refresh: attempt == 1);
      if (token == null || token.isEmpty) {
        throw EclassException('eClass API token unavailable');
      }
      final formData = FormData.fromMap({
        'token': token,
        'filearea': 'draft',
        'filepath': '/',
        'itemid': itemId,
        'file_1': await MultipartFile.fromFile(filePath, filename: filename),
      });

      final uploadResp = await _dio.post<dynamic>(
        '$baseUrl/webservice/upload.php',
        data: formData,
        options: Options(responseType: ResponseType.plain),
      );
      try {
        return parseUploadResponse(uploadResp.data);
      } on _InvalidTokenUploadException {
        if (attempt == 0) {
          _apiToken = null;
          continue;
        }
        rethrow;
      }
    }
    throw EclassException('eClass API auth failed');
  }

  static String? _extractBalancedJsonObject(String source, int startIdx) {
    if (startIdx < 0 || startIdx >= source.length || source[startIdx] != '{') {
      return null;
    }
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (int i = startIdx; i < source.length; i++) {
      final ch = source[i];
      if (escaped) {
        escaped = false;
        continue;
      }
      if (inString) {
        if (ch == r'\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          return source.substring(startIdx, i + 1);
        }
      }
    }
    return null;
  }

  Future<void> _uploadSubmissionViaWeb(
    String cmid,
    String filePath,
    String filename, {
    bool submitForGrading = false,
  }) async {
    final editUrl =
        '$baseUrl/mod/assign/view.php?id=$cmid&action=editsubmission';
    final editResp = await _getAuthedHtml(editUrl);
    final html = editResp.data ?? '';
    if (_isLoginPage(editResp.finalUri, html)) {
      throw EclassException('eClass web session expired');
    }

    final initMarker = html.indexOf('M.form_filemanager.init(');
    if (initMarker < 0) {
      throw EclassException('File upload form unavailable for this assignment');
    }
    final braceIdx = html.indexOf('{', initMarker);
    final jsonStr = _extractBalancedJsonObject(html, braceIdx);
    if (jsonStr == null) {
      throw EclassException('Could not parse assignment file manager config');
    }

    final fmCfg = jsonDecode(jsonStr) as Map<String, dynamic>;
    final itemId = fmCfg['itemid']?.toString() ?? '';
    final clientId = fmCfg['client_id']?.toString() ?? '';
    final ctxId = (fmCfg['context'] is Map)
        ? (fmCfg['context'] as Map)['id']?.toString() ?? ''
        : '';
    final author = fmCfg['author']?.toString() ?? 'Student';
    final maxFiles = int.tryParse(fmCfg['maxfiles']?.toString() ?? '');
    final existingList = (fmCfg['list'] as List?) ?? const [];

    String? uploadRepoId;
    final fp = fmCfg['filepicker'];
    if (fp is Map && fp['repositories'] is Map) {
      for (final entry in (fp['repositories'] as Map).entries) {
        final v = entry.value;
        if (v is Map && v['type'] == 'upload') {
          uploadRepoId = (v['id'] ?? entry.key).toString();
          break;
        }
      }
    }

    final doc = html_parser.parse(html);
    final form = doc.querySelector('form[action*="view.php"]') ??
        doc.querySelector('form.mform');
    if (form == null) {
      throw EclassException('Submission form missing on eClass page');
    }

    final payload = <String, String>{};
    for (final inp in form.querySelectorAll('input[name]')) {
      final name = inp.attributes['name'] ?? '';
      if (name.isEmpty) continue;
      final type = (inp.attributes['type'] ?? 'text').toLowerCase();
      if (type == 'hidden') {
        payload[name] = inp.attributes['value'] ?? '';
      }
    }
    final textarea =
        form.querySelector('textarea[name="onlinetext_editor[text]"]');
    if (textarea != null) {
      payload['onlinetext_editor[text]'] = textarea.text;
    }

    final sessMatch = RegExp(r'"sesskey":"([^"]+)"').firstMatch(html);
    final sesskey = sessMatch?.group(1) ?? payload['sesskey'] ?? '';
    if (itemId.isEmpty ||
        clientId.isEmpty ||
        ctxId.isEmpty ||
        uploadRepoId == null ||
        sesskey.isEmpty) {
      throw EclassException('Missing required Moodle upload parameters');
    }

    // If single-file limit already reached in draft area, clear old draft file first.
    if (maxFiles == 1 && existingList.isNotEmpty) {
      for (final old in existingList) {
        if (old is! Map) continue;
        final oldName = old['filename']?.toString() ?? '';
        final oldPath = old['filepath']?.toString() ?? '/';
        if (oldName.isEmpty) continue;
        try {
          await _dio.post<dynamic>(
            '$baseUrl/repository/draftfiles_ajax.php?action=delete',
            data: {
              'sesskey': sesskey,
              'client_id': clientId,
              'draftitemid': itemId,
              'filepath': oldPath,
              'filename': oldName,
            },
            options: Options(
              contentType: Headers.formUrlEncodedContentType,
              responseType: ResponseType.plain,
            ),
          );
        } catch (_) {}
      }
    }

    final uploadForm = FormData.fromMap({
      'repo_id': uploadRepoId,
      'itemid': itemId,
      'ctx_id': ctxId,
      'client_id': clientId,
      'sesskey': sesskey,
      'savepath': '/',
      'title': filename,
      'author': author,
      'license': 'allrightsreserved',
      'repo_upload_file':
          await MultipartFile.fromFile(filePath, filename: filename),
    });

    final repoResp = await _dio.post<dynamic>(
      '$baseUrl/repository/repository_ajax.php?action=upload',
      data: uploadForm,
      options: Options(responseType: ResponseType.plain),
    );
    final repoRaw = (repoResp.data?.toString() ?? '').trim();
    if (repoRaw.isNotEmpty) {
      try {
        final repoDecoded = jsonDecode(repoRaw);
        if (repoDecoded is Map && repoDecoded['error'] != null) {
          throw EclassException(repoDecoded['error'].toString());
        }
      } on FormatException {
        throw EclassException('Unexpected web upload response from eClass');
      }
    }

    payload['files_filemanager'] = itemId;
    payload['submitbutton'] =
        form.querySelector('input[name="submitbutton"]')?.attributes['value'] ??
            'Save changes';

    final actionRaw = form.attributes['action'] ?? '';
    final actionUri = actionRaw.isNotEmpty
        ? editResp.finalUri.resolve(actionRaw)
        : Uri.parse('$baseUrl/mod/assign/view.php');

    final saveResp = await requestWithRedirects<String>(
      _dio,
      actionUri.toString(),
      method: 'POST',
      data: payload,
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
        responseType: ResponseType.plain,
      ),
    );
    final saveHtml = saveResp.data ?? '';
    if (saveResp.finalUri.queryParameters['action'] == 'editsubmission') {
      final errEl = html_parser.parse(saveHtml).querySelector('.mform .error');
      if (errEl != null && errEl.text.trim().isNotEmpty) {
        throw EclassException(errEl.text.trim());
      }
    }

    if (submitForGrading) {
      final viewResp =
          await _getAuthedHtml('$baseUrl/mod/assign/view.php?id=$cmid');
      final viewDoc = html_parser.parse(viewResp.data ?? '');
      final hasSubmitBtn = viewDoc.querySelector(
            'form input[name="action"][value="submit"]',
          ) !=
          null;
      if (hasSubmitBtn) {
        final confirmResp = await _getAuthedHtml(
            '$baseUrl/mod/assign/view.php?id=$cmid&action=submit');
        final confirmDoc = html_parser.parse(confirmResp.data ?? '');
        final cForm = confirmDoc.querySelector('form[action*="view.php"]') ??
            confirmDoc.querySelector('form.mform');
        if (cForm != null) {
          final cPayload = <String, String>{};
          for (final inp in cForm.querySelectorAll('input[name]')) {
            final name = inp.attributes['name'] ?? '';
            if (name.isEmpty) continue;
            final type = (inp.attributes['type'] ?? 'text').toLowerCase();
            if (type == 'hidden') {
              cPayload[name] = inp.attributes['value'] ?? '';
            } else if (type == 'checkbox' && name.contains('statement')) {
              cPayload[name] = inp.attributes['value'] ?? '1';
            }
          }
          cPayload['submitbutton'] = cForm
                  .querySelector('input[name="submitbutton"]')
                  ?.attributes['value'] ??
              'Continue';
          final cAction = cForm.attributes['action'] ?? '';
          final cUri = cAction.isNotEmpty
              ? confirmResp.finalUri.resolve(cAction)
              : Uri.parse('$baseUrl/mod/assign/view.php');
          await requestWithRedirects<String>(
            _dio,
            cUri.toString(),
            method: 'POST',
            data: cPayload,
            options: Options(
              contentType: Headers.formUrlEncodedContentType,
              responseType: ResponseType.plain,
            ),
          );
        }
      }
    }
  }

  static String syllabusUrl(String courseId) =>
      '$baseUrl/local/ubion/setting/syllabus.php?id=$courseId';

  // ── Syllabus Evaluation Weights Parser ──────────────────────

  static const _weightKeywords = <String, String>{
    'attendance': 'Attendance',
    'attend': 'Attendance',
    '출석': 'Attendance',
    'midtermexam': 'Midterm',
    'midterm': 'Midterm',
    'midexam': 'Midterm',
    '중간고사': 'Midterm',
    '중간': 'Midterm',
    'finalexam': 'Final',
    'finalterm': 'Final',
    'final': 'Final',
    '기말고사': 'Final',
    '기말': 'Final',
    'assignments': 'Assignments',
    'assignment': 'Assignments',
    'homework': 'Assignments',
    'report': 'Assignments',
    '과제': 'Assignments',
    'quizzes': 'Quiz',
    'quiz': 'Quiz',
    '퀴즈': 'Quiz',
    'termproject': 'Project',
    'teamproject': 'Project',
    'project': 'Project',
    '프로젝트': 'Project',
    'laboratory': 'Lab',
    'labwork': 'Lab',
    'lab': 'Lab',
    'practice': 'Lab',
    'practical': 'Lab',
    'experiment': 'Lab',
    '실습': 'Lab',
    '실험': 'Lab',
    'presentation': 'Presentation',
    'seminar': 'Presentation',
    '발표': 'Presentation',
    'discussion': 'Discussion',
    'debate': 'Discussion',
    '토론': 'Discussion',
    'participation': 'Participation',
    'activity': 'Participation',
    '참여': 'Participation',
    'others': 'Other',
    'other': 'Other',
    'etc': 'Other',
    '기타': 'Other',
  };

  static String _normalizeWeightKey(String raw) {
    return raw
        .replaceAll('\u00A0', ' ')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s\-–—_./()\[\]:,]+'), '');
  }

  static bool _isTotalOrMetaHeader(String raw) {
    final cleaned = raw.replaceAll('\u00A0', ' ').trim();
    if (cleaned.isEmpty || cleaned.length > 48) return true;
    final lower = cleaned.toLowerCase();
    final norm = _normalizeWeightKey(cleaned);
    if (norm.isEmpty) return true;
    if (norm == '계' ||
        norm == '비율' ||
        norm == '구분' ||
        norm == '항목' ||
        norm == '점수') {
      return true;
    }
    return lower.contains('total') ||
        norm == 'sum' ||
        lower.contains('합계') ||
        lower.contains('총계') ||
        lower.contains('evaluation') ||
        norm == 'ratio' ||
        norm == 'category' ||
        norm == 'item';
  }

  static String? _matchWeightLabel(String raw) {
    if (_isTotalOrMetaHeader(raw)) return null;
    final norm = _normalizeWeightKey(raw);
    for (final entry in _weightKeywords.entries) {
      if (norm.contains(entry.key)) return entry.value;
    }
    return null;
  }

  static String? _cleanCustomWeightLabel(String raw) {
    if (_isTotalOrMetaHeader(raw)) return null;
    var cleaned =
        raw.replaceAll('\u00A0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    cleaned = cleaned.replaceAll(RegExp(r'^[:\-•]+|[:\-•]+$'), '').trim();
    if (cleaned.isEmpty || cleaned.length > 28) return null;
    if (!RegExp(r'[A-Za-z가-힣А-Яа-я]').hasMatch(cleaned)) return null;
    if (RegExp(r'^[0-9.,%\s]+$').hasMatch(cleaned)) return null;
    return cleaned;
  }

  static double? _extractWeightPercent(String raw) {
    final cleaned = raw.replaceAll('\u00A0', ' ').trim();
    if (cleaned.isEmpty) return null;
    final m = RegExp(r'^([0-9]+(?:[.,][0-9]+)?)\s*%?$').firstMatch(cleaned);
    if (m == null) return null;
    final val = double.tryParse(m.group(1)!.replaceAll(',', '.'));
    if (val == null || val <= 0 || val > 100) return null;
    return val;
  }

  static List<SyllabusWeight> _pickBestCandidate(
    List<List<SyllabusWeight>> candidates,
  ) {
    List<SyllabusWeight>? best;
    double bestScore = double.infinity;
    for (final cand in candidates) {
      if (cand.length < 2) continue;
      final sum = cand.fold<double>(0, (acc, e) => acc + e.percentage);
      if (sum < 50 || sum > 105) continue;
      final near100Penalty = (sum >= 95 && sum <= 105) ? 0.0 : 50.0;
      final score = (sum - 100.0).abs() + near100Penalty - cand.length * 0.01;
      if (score < bestScore) {
        bestScore = score;
        best = cand;
      }
    }
    return best ?? const [];
  }

  @visibleForTesting
  static List<SyllabusWeight> parseSyllabusWeightsHtml(
    String html,
    String courseId,
  ) {
    if (html.trim().isEmpty) return const [];
    final doc = html_parser.parse(html);
    final candidates = <List<SyllabusWeight>>[];

    // 1. Scan tables (horizontal header+row with rowspan support, or vertical key-value rows)
    for (final table in doc.querySelectorAll('table')) {
      final rows = table.querySelectorAll('tr');
      if (rows.length < 2) continue;

      // Pass A: Horizontal layout
      for (int r = 0; r < rows.length - 1; r++) {
        final rawHeaders = rows[r].querySelectorAll('th, td');
        final valCells = rows[r + 1].querySelectorAll('td, th');
        if (rawHeaders.length < 2 || valCells.length < 2) continue;

        final headerVariants = <List<dom.Element>>[rawHeaders];
        if (rawHeaders.length > valCells.length) {
          final withoutRowspan = rawHeaders.where((cell) {
            final rs = int.tryParse(cell.attributes['rowspan'] ?? '1') ?? 1;
            return rs <= 1;
          }).toList();
          if (withoutRowspan.length >= 2) {
            headerVariants.insert(0, withoutRowspan);
          }
          headerVariants.add(
            rawHeaders.sublist(rawHeaders.length - valCells.length),
          );
        }

        for (final headerCells in headerVariants) {
          final len = headerCells.length < valCells.length
              ? headerCells.length
              : valCells.length;
          int knownCount = 0;
          final items = <SyllabusWeight>[];
          for (int c = 0; c < len; c++) {
            final headerText = headerCells[c].text;
            final known = _matchWeightLabel(headerText);
            final pct = _extractWeightPercent(valCells[c].text);
            if (pct == null) continue;
            if (known != null) {
              knownCount++;
              items.add(SyllabusWeight(
                courseId: courseId,
                label: known,
                percentage: pct,
              ));
            } else {
              final custom = _cleanCustomWeightLabel(headerText);
              if (custom != null) {
                items.add(SyllabusWeight(
                  courseId: courseId,
                  label: custom,
                  percentage: pct,
                ));
              }
            }
          }
          if (knownCount >= 2 && items.length >= 2) {
            candidates.add(items);
          }
        }
      }

      // Pass B: Vertical layout (each row has label in col 0 and percentage in col 1..k)
      int verticalKnownCount = 0;
      final verticalMatched = <SyllabusWeight>[];
      for (final row in rows) {
        final cells = row.querySelectorAll('th, td');
        if (cells.length < 2) continue;
        final known = _matchWeightLabel(cells[0].text);
        final label = known ?? _cleanCustomWeightLabel(cells[0].text);
        if (label == null) continue;
        double? pct;
        for (int c = 1; c < cells.length; c++) {
          pct = _extractWeightPercent(cells[c].text);
          if (pct != null) break;
        }
        if (pct != null) {
          if (known != null) verticalKnownCount++;
          verticalMatched.add(SyllabusWeight(
            courseId: courseId,
            label: label,
            percentage: pct,
          ));
        }
      }
      if (verticalKnownCount >= 2 && verticalMatched.length >= 2) {
        candidates.add(verticalMatched);
      }
    }

    final bestFromTable = _pickBestCandidate(candidates);
    if (bestFromTable.isNotEmpty) return bestFromTable;

    // 2. Inline text fallback: "Mid-term: 35%", "Final (40%)"
    final bodyText = (doc.body?.text ?? html).replaceAll('\u00A0', ' ');
    final inline = <String, SyllabusWeight>{};
    final rx = RegExp(
      r'([A-Za-z가-힣][A-Za-z가-힣\s\-]{1,22}?)\s*[:\(\-]?\s*([0-9]+(?:\.[0-9]+)?)\s*%',
    );
    for (final m in rx.allMatches(bodyText)) {
      final label = _matchWeightLabel(m.group(1) ?? '');
      final pct = double.tryParse(m.group(2) ?? '');
      if (label != null && pct != null && pct > 0 && pct <= 100) {
        inline.putIfAbsent(
          label,
          () => SyllabusWeight(
            courseId: courseId,
            label: label,
            percentage: pct,
          ),
        );
      }
    }
    return _pickBestCandidate([inline.values.toList()]);
  }

  Future<List<SyllabusWeight>> getSyllabusWeights(String courseId) async {
    try {
      final resp = await _getAuthedHtml(syllabusUrl(courseId));
      if (_isLoginPage(resp.finalUri, resp.data ?? '')) return const [];
      return parseSyllabusWeightsHtml(resp.data ?? '', courseId);
    } catch (_) {
      return const [];
    }
  }
}
