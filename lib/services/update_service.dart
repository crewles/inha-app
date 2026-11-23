import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/models.dart';

enum UpdateCheckStatus { available, upToDate, unavailable, error }

class UpdateCheckResult {
  final UpdateCheckStatus status;
  final AppReleaseInfo? release;
  final String? errorMessage;

  const UpdateCheckResult({
    required this.status,
    this.release,
    this.errorMessage,
  });
}

/// Checks GitHub Releases for `crewles/inha-app` and bridges native Android
/// platform actions (APK installer, home-screen widget updates/pinning).
class UpdateService {
  static const String currentVersion = '1.2.1';
  static const String repoOwner = 'crewles';
  static const String repoName = 'inha-app';
  static const String latestReleaseApi =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const String repoWebUrl = 'https://github.com/$repoOwner/$repoName';
  static const String releasesWebUrl =
      'https://github.com/$repoOwner/$repoName/releases';

  static const MethodChannel _platformChannel =
      MethodChannel('uz.inha.inhahub/app_platform');

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      validateStatus: (_) => true,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'InhaApp/$currentVersion',
      },
    ),
  );

  /// Compares two semantic version strings (`v1.0.3+4` vs `1.0.2`).
  /// Returns `> 0` if [a] > [b], `< 0` if [a] < [b], `0` if equal.
  static int compareVersions(String a, String b) {
    List<int> parse(String raw) {
      var clean = raw.trim();
      if (clean.startsWith('v') || clean.startsWith('V')) {
        clean = clean.substring(1);
      }
      clean = clean.split('+').first.split('-').first;
      return clean
          .split('.')
          .map((part) => int.tryParse(part.trim()) ?? 0)
          .toList();
    }

    final pa = parse(a);
    final pb = parse(b);
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (int i = 0; i < len; i++) {
      final va = i < pa.length ? pa[i] : 0;
      final vb = i < pb.length ? pb[i] : 0;
      if (va != vb) return va.compareTo(vb);
    }
    return 0;
  }

  Future<UpdateCheckResult> checkForUpdate() async {
    try {
      final resp = await _dio.get<dynamic>(latestReleaseApi);
      final code = resp.statusCode ?? 0;
      if (code == 404 || code == 403) {
        return const UpdateCheckResult(status: UpdateCheckStatus.unavailable);
      }
      if (code != 200 || resp.data is! Map) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.error,
          errorMessage: 'HTTP $code',
        );
      }

      final data = Map<String, dynamic>.from(resp.data as Map);
      final tag = (data['tag_name'] ?? '').toString().trim();
      final name = (data['name'] ?? tag).toString().trim();
      final body = (data['body'] ?? '').toString().trim();
      final htmlUrl = (data['html_url'] ?? releasesWebUrl).toString().trim();

      String? apkUrl;
      String? apkName;
      int apkSize = 0;
      final assets = (data['assets'] as List?) ?? [];
      for (final asset in assets) {
        if (asset is! Map) continue;
        final aName = (asset['name'] ?? '').toString();
        final dlUrl = (asset['browser_download_url'] ?? '').toString();
        final aSize = (asset['size'] as int?) ?? 0;
        if (!aName.toLowerCase().endsWith('.apk') || dlUrl.isEmpty) continue;
        if (apkUrl == null || aName.toLowerCase().contains('arm64')) {
          apkUrl = dlUrl;
          apkName = aName;
          apkSize = aSize;
          if (aName.toLowerCase().contains('arm64')) break;
        }
      }

      final cleanTag =
          tag.startsWith('v') || tag.startsWith('V') ? tag.substring(1) : tag;
      final info = AppReleaseInfo(
        version: cleanTag.isNotEmpty ? cleanTag : tag,
        tagName: tag,
        title: name,
        notes: body,
        htmlUrl: htmlUrl,
        apkUrl: apkUrl,
        apkName: apkName,
        apkSize: apkSize,
      );

      if (tag.isNotEmpty && compareVersions(tag, currentVersion) > 0) {
        return UpdateCheckResult(
          status: UpdateCheckStatus.available,
          release: info,
        );
      }
      return UpdateCheckResult(
        status: UpdateCheckStatus.upToDate,
        release: info,
      );
    } catch (e) {
      return UpdateCheckResult(
        status: UpdateCheckStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<String> downloadApk(
    AppReleaseInfo release, {
    void Function(int received, int total)? onProgress,
  }) async {
    final url = release.apkUrl;
    if (url == null || url.isEmpty) {
      throw Exception('APK asset not found in release ${release.tagName}');
    }
    final tempDir = await getTemporaryDirectory();
    final updatesDir = Directory(p.join(tempDir.path, 'updates'));
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }
    final fileName = release.apkName?.isNotEmpty == true
        ? release.apkName!
        : 'inha-app-${release.version}.apk';
    final outPath = p.join(updatesDir.path, fileName);

    await _dio.download(
      url,
      outPath,
      onReceiveProgress: onProgress,
      options: Options(receiveTimeout: const Duration(minutes: 5)),
    );
    return outPath;
  }

  static Future<bool> installApk(String filePath) async {
    try {
      final res = await _platformChannel
          .invokeMethod<bool>('installApk', {'path': filePath});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> refreshHomeWidgets() async {
    try {
      await _platformChannel.invokeMethod<bool>('updateWidgets');
    } catch (_) {}
  }

  static Future<bool> requestPinWidget(String widgetKey) async {
    try {
      final res = await _platformChannel
          .invokeMethod<bool>('requestPinWidget', {'widget': widgetKey});
      return res ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<int?> getInitialTab() async {
    try {
      return await _platformChannel.invokeMethod<int>('getInitialTab');
    } catch (_) {
      return null;
    }
  }

  static void setOnOpenTabHandler(void Function(int tabIndex) onOpenTab) {
    try {
      _platformChannel.setMethodCallHandler((call) async {
        if (call.method == 'openTab' && call.arguments is int) {
          onOpenTab(call.arguments as int);
        }
      });
    } catch (_) {}
  }
}
