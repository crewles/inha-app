import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

enum LogLevel { info, warning, error, crash }

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? details;

  const LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.details,
  });

  String formatLine() {
    final lvl = level.name.toUpperCase();
    final base = '[${timestamp.toIso8601String()}] [$lvl] [$tag] $message';
    if (details != null && details!.isNotEmpty) {
      return '$base\n  $details';
    }
    return base;
  }

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'level': level.name,
        'tag': tag,
        'message': message,
        if (details != null) 'details': details,
      };

  factory LogEntry.fromJson(Map<String, dynamic> m) {
    final lvlStr = (m['level'] ?? 'info').toString();
    final level = LogLevel.values.firstWhere(
      (e) => e.name == lvlStr,
      orElse: () => LogLevel.info,
    );
    return LogEntry(
      timestamp:
          DateTime.tryParse((m['ts'] ?? '').toString()) ?? DateTime.now(),
      level: level,
      tag: (m['tag'] ?? 'APP').toString(),
      message: (m['message'] ?? '').toString(),
      details: m['details']?.toString(),
    );
  }
}

class AppLogger extends ChangeNotifier {
  AppLogger._();
  static final AppLogger instance = AppLogger._();

  static const int _maxEntries = 300;
  static const String _fileName = 'app_logs.json';

  static final RegExp _secretKvRx = RegExp(
    r'(password|eclass_password|ins_password|txtpw|wstoken|token|moodlesession|asp\.net_sessionid|sesskey|draftitemid|cookie|authorization)(\s*[=:]\s*["\x27]?|\s+)([^\s&",}\]\x27]+)',
    caseSensitive: false,
  );
  static final RegExp _hexTokenRx = RegExp(r'\b[a-fA-F0-9]{32}\b');
  static final RegExp _studentIdRx = RegExp(r'\b[uU]\d{7}\b');

  bool enabled = false;
  bool hasPendingCrashPrompt = false;
  LogEntry? lastCrashEntry;
  final List<LogEntry> _entries = [];
  bool _isRecordingCrash = false;
  Future<void> _persistQueue = Future.value();

  @visibleForTesting
  bool persistToDisk = true;

  void _notifySafely() {
    if (!hasListeners) return;
    SchedulerPhase? phase;
    try {
      phase = SchedulerBinding.instance.schedulerPhase;
    } catch (_) {}
    if (phase == SchedulerPhase.persistentCallbacks) {
      try {
        SchedulerBinding.instance.addPostFrameCallback((_) {
          if (hasListeners) notifyListeners();
        });
        return;
      } catch (_) {}
    }
    notifyListeners();
  }

  List<LogEntry> get entries => List.unmodifiable(_entries.reversed);

  /// Scrubs passwords, tokens, session cookies, and student IDs before logging.
  static String sanitize(String input) {
    if (input.isEmpty) return input;
    var out = input.replaceAllMapped(_secretKvRx, (m) {
      return '${m.group(1)}${m.group(2)}***';
    });
    out = out.replaceAll(_hexTokenRx, '***');
    out = out.replaceAll(_studentIdRx, 'U*******');
    return out;
  }

  void info(String tag, String message) {
    if (!enabled) return;
    _append(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        tag: sanitize(tag),
        message: sanitize(message),
      ),
    );
  }

  void warn(String tag, String message) {
    if (!enabled) return;
    _append(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.warning,
        tag: sanitize(tag),
        message: sanitize(message),
      ),
    );
  }

  void error(String tag, String message, [Object? err]) {
    if (!enabled) return;
    _append(
      LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.error,
        tag: sanitize(tag),
        message: sanitize(message),
        details: err == null ? null : sanitize(err.toString()),
      ),
    );
  }

  Future<void> recordCrash(
    Object error, [
    StackTrace? stack,
    String tag = 'CRASH',
  ]) async {
    if (_isRecordingCrash) return;
    _isRecordingCrash = true;
    try {
      final stackStr = stack?.toString().trim() ?? '';
      final shortStack = stackStr.length > 1500
          ? '${stackStr.substring(0, 1500)}...'
          : stackStr;
      final entry = LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.crash,
        tag: sanitize(tag),
        message: sanitize(error.toString()),
        details: shortStack.isEmpty ? null : sanitize(shortStack),
      );
      lastCrashEntry = entry;
      hasPendingCrashPrompt = true;
      _addToMemory(entry);
      _notifySafely();
      await _persist();
    } finally {
      _isRecordingCrash = false;
    }
  }

  Future<void> init({required bool enabled}) async {
    this.enabled = enabled;
    if (!persistToDisk) return;
    try {
      final file = await _logFile();
      if (await file.exists()) {
        final raw = await file.readAsString();
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          hasPendingCrashPrompt = decoded['pendingCrashPrompt'] == true;
          final list = (decoded['entries'] as List?) ?? const [];
          _entries.clear();
          for (final item in list) {
            if (item is Map) {
              _entries.add(LogEntry.fromJson(Map<String, dynamic>.from(item)));
            }
          }
          for (int i = _entries.length - 1; i >= 0; i--) {
            if (_entries[i].level == LogLevel.crash) {
              lastCrashEntry = _entries[i];
              break;
            }
          }
          _notifySafely();
        }
      }
    } catch (_) {}
  }

  Future<void> dismissCrashPrompt() async {
    hasPendingCrashPrompt = false;
    _notifySafely();
    await _persist();
  }

  Future<void> clear() async {
    _entries.clear();
    hasPendingCrashPrompt = false;
    lastCrashEntry = null;
    _notifySafely();
    if (!persistToDisk) return;
    _persistQueue = _persistQueue.then((_) async {
      try {
        final file = await _logFile();
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    });
    await _persistQueue;
  }

  String exportText() {
    if (_entries.isEmpty) return '';
    return entries.map((e) => e.formatLine()).join('\n');
  }

  static String _trimSingleLine(String input, int maxLen) {
    final collapsed = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.length <= maxLen) return collapsed;
    if (maxLen <= 3) return collapsed.substring(0, maxLen);
    return '${collapsed.substring(0, maxLen - 3)}...';
  }

  /// Builds a sanitized Markdown bug/crash report kept within [maxLength]
  /// so it fits safely inside a GitHub `issues/new` URL query parameter.
  String buildCrashReportMarkdown({
    required String appVersion,
    String? platformOverride,
    int maxLength = 2600,
  }) {
    final platform = platformOverride ??
        (kIsWeb
            ? 'web'
            : '${Platform.operatingSystem} (${_trimSingleLine(sanitize(Platform.operatingSystemVersion), 80)})');
    final buf = StringBuffer()
      ..writeln('## Environment')
      ..writeln('- **App version:** $appVersion')
      ..writeln('- **Platform:** $platform')
      ..writeln('- **Time (UTC):** ${DateTime.now().toUtc().toIso8601String()}')
      ..writeln()
      ..writeln('## What happened')
      ..writeln('<!-- Describe what you were doing right before the error (optional) -->');

    final crash = lastCrashEntry;
    if (crash != null) {
      final rawCrash = crash.formatLine();
      final crashLimit = (maxLength - 360).clamp(400, 1400);
      final crashText = rawCrash.length > crashLimit
          ? '${rawCrash.substring(0, crashLimit - 3)}...'
          : rawCrash;
      buf
        ..writeln()
        ..writeln('## Crash Details')
        ..writeln('```text')
        ..writeln(crashText)
        ..writeln('```');
    }

    final recentSource =
        _entries.where((e) => !identical(e, crash)).toList();
    if (recentSource.isNotEmpty) {
      final start = recentSource.length > 12 ? recentSource.length - 12 : 0;
      final recent = recentSource.sublist(start);
      const header = '\n## Recent Logs\n```text\n';
      const footer = '```';
      if (buf.length + header.length + footer.length < maxLength) {
        final logBuf = StringBuffer();
        for (final entry in recent) {
          final line = '${entry.formatLine()}\n';
          if (buf.length + header.length + logBuf.length + line.length + footer.length >
              maxLength) {
            break;
          }
          logBuf.write(line);
        }
        if (logBuf.isNotEmpty) {
          buf
            ..write(header)
            ..write(logBuf.toString())
            ..write(footer);
        }
      }
    }

    final result = buf.toString().trimRight();
    return result.length <= maxLength ? result : result.substring(0, maxLength);
  }

  /// Builds a pre-filled GitHub `issues/new` URI with sanitized crash context.
  Uri buildGithubIssueUri({
    required String repoWebUrl,
    required String appVersion,
    String? platformOverride,
  }) {
    final crash = lastCrashEntry;
    final title = crash != null
        ? '[Crash] ${_trimSingleLine(crash.message, 72)}'
        : '[Bug] Diagnostic report (v$appVersion)';
    final baseUri = Uri.parse('$repoWebUrl/issues/new');
    Uri makeUri(int maxBodyLen) => baseUri.replace(
          queryParameters: {
            'title': title,
            'labels': 'bug',
            'body': buildCrashReportMarkdown(
              appVersion: appVersion,
              platformOverride: platformOverride,
              maxLength: maxBodyLen,
            ),
          },
        );
    final uri = makeUri(2600);
    if (uri.toString().length <= 7000) return uri;
    return makeUri(1800);
  }

  void _append(LogEntry entry) {
    _addToMemory(entry);
    _notifySafely();
    _persist();
  }

  void _addToMemory(LogEntry entry) {
    _entries.add(entry);
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }

  Future<File> _logFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, _fileName));
  }

  Future<void> _persist() {
    if (!persistToDisk) return Future.value();
    final payload = jsonEncode({
      'pendingCrashPrompt': hasPendingCrashPrompt,
      'entries': _entries.map((e) => e.toJson()).toList(),
    });
    _persistQueue = _persistQueue.then((_) async {
      try {
        final file = await _logFile();
        final tmpFile = File('${file.path}.tmp');
        await tmpFile.writeAsString(payload, flush: true);
        if (await file.exists()) {
          await file.delete();
        }
        await tmpFile.rename(file.path);
      } catch (_) {}
    });
    return _persistQueue;
  }
}
