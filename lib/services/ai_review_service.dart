import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

import '../models/models.dart';

class AiProviderPreset {
  final String id;
  final String label;
  final String defaultBaseUrl;
  final String defaultModel;
  final List<String> suggestedModels;
  final bool supportsPdf;
  final bool isCustom;

  const AiProviderPreset({
    required this.id,
    required this.label,
    required this.defaultBaseUrl,
    required this.defaultModel,
    required this.suggestedModels,
    this.supportsPdf = false,
    this.isCustom = false,
  });
}

class AiServiceException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  const AiServiceException(
    this.message, {
    this.statusCode,
    this.code,
  });

  @override
  String toString() => message;
}

class AiAttachment {
  final String name;
  final String role; // 'spec' | 'submission'
  final int sizeBytes;
  final String? textContent;
  final String? base64Data;
  final String? mimeType;
  final String? skippedReason;

  const AiAttachment({
    required this.name,
    required this.role,
    this.sizeBytes = 0,
    this.textContent,
    this.base64Data,
    this.mimeType,
    this.skippedReason,
  });

  bool get isIncluded =>
      skippedReason == null && (textContent != null || base64Data != null);

  bool get isBinary => base64Data != null;

  static const int maxTextChars = 40000;
  static const int maxImageBytes = 4 * 1024 * 1024;
  static const int maxPdfBytes = 8 * 1024 * 1024;
  static const int maxArchiveBytes = 10 * 1024 * 1024;
  static const int maxRawTextReadBytes = 2 * 1024 * 1024;

  static const Set<String> _textExtensions = {
    '.txt',
    '.md',
    '.markdown',
    '.csv',
    '.json',
    '.xml',
    '.yaml',
    '.yml',
    '.html',
    '.htm',
    '.css',
    '.js',
    '.jsx',
    '.ts',
    '.tsx',
    '.dart',
    '.py',
    '.java',
    '.kt',
    '.kts',
    '.c',
    '.h',
    '.cpp',
    '.hpp',
    '.cc',
    '.cs',
    '.go',
    '.rs',
    '.rb',
    '.php',
    '.sql',
    '.sh',
    '.bash',
    '.zsh',
    '.ps1',
    '.r',
    '.m',
    '.swift',
    '.tex',
    '.log',
    '.ini',
    '.cfg',
    '.conf',
    '.toml',
    '.gradle',
    '.properties',
  };

  static const Map<String, String> _imageMimeTypes = {
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.webp': 'image/webp',
  };

  static Future<AiAttachment> fromFile(
    String path, {
    required String role,
    required bool supportsPdf,
  }) async {
    final name = p.basename(path);
    final ext = p.extension(name).toLowerCase();
    final file = File(path);
    if (!await file.exists()) {
      return AiAttachment(
        name: name,
        role: role,
        skippedReason: 'file_missing',
      );
    }

    final sizeBytes = await file.length();

    if (_textExtensions.contains(ext)) {
      if (sizeBytes > maxRawTextReadBytes) {
        return AiAttachment(
          name: name,
          role: role,
          sizeBytes: sizeBytes,
          skippedReason: 'too_large',
        );
      }
      final bytes = await file.readAsBytes();
      String text;
      try {
        text = utf8.decode(bytes);
      } catch (_) {
        text = latin1.decode(bytes);
      }
      if (text.length > maxTextChars) {
        text = '${text.substring(0, maxTextChars)}\n... [truncated]';
      }
      return AiAttachment(
        name: name,
        role: role,
        sizeBytes: sizeBytes,
        textContent: text,
        mimeType: 'text/plain',
      );
    }

    final imgMime = _imageMimeTypes[ext];
    if (imgMime != null) {
      if (sizeBytes > maxImageBytes) {
        return AiAttachment(
          name: name,
          role: role,
          sizeBytes: sizeBytes,
          skippedReason: 'too_large',
        );
      }
      final bytes = await file.readAsBytes();
      return AiAttachment(
        name: name,
        role: role,
        sizeBytes: sizeBytes,
        base64Data: base64Encode(bytes),
        mimeType: imgMime,
      );
    }

    if (ext == '.pdf') {
      if (!supportsPdf) {
        return AiAttachment(
          name: name,
          role: role,
          sizeBytes: sizeBytes,
          skippedReason: 'pdf_requires_gemini',
        );
      }
      if (sizeBytes > maxPdfBytes) {
        return AiAttachment(
          name: name,
          role: role,
          sizeBytes: sizeBytes,
          skippedReason: 'too_large',
        );
      }
      final bytes = await file.readAsBytes();
      return AiAttachment(
        name: name,
        role: role,
        sizeBytes: sizeBytes,
        base64Data: base64Encode(bytes),
        mimeType: 'application/pdf',
      );
    }

    if (ext == '.docx') {
      if (sizeBytes > maxArchiveBytes) {
        return AiAttachment(
          name: name,
          role: role,
          sizeBytes: sizeBytes,
          skippedReason: 'too_large',
        );
      }
      final bytes = await file.readAsBytes();
      final extracted = _extractDocxText(bytes);
      if (extracted == null || extracted.trim().isEmpty) {
        return AiAttachment(
          name: name,
          role: role,
          sizeBytes: sizeBytes,
          skippedReason: 'unsupported_format',
        );
      }
      return AiAttachment(
        name: name,
        role: role,
        sizeBytes: sizeBytes,
        textContent: _capText(extracted),
        mimeType: 'text/plain',
      );
    }

    if (ext == '.zip') {
      if (sizeBytes > maxArchiveBytes) {
        return AiAttachment(
          name: name,
          role: role,
          sizeBytes: sizeBytes,
          skippedReason: 'too_large',
        );
      }
      final bytes = await file.readAsBytes();
      final extracted = _extractZipText(bytes);
      if (extracted == null || extracted.trim().isEmpty) {
        return AiAttachment(
          name: name,
          role: role,
          sizeBytes: sizeBytes,
          skippedReason: 'unsupported_format',
        );
      }
      return AiAttachment(
        name: name,
        role: role,
        sizeBytes: sizeBytes,
        textContent: extracted,
        mimeType: 'text/plain',
      );
    }

    return AiAttachment(
      name: name,
      role: role,
      sizeBytes: sizeBytes,
      skippedReason: 'unsupported_format',
    );
  }

  static String _capText(String text) {
    if (text.length <= maxTextChars) return text;
    return '${text.substring(0, maxTextChars)}\n... [truncated]';
  }

  static String? _extractDocxText(Uint8List bytes) {
    final entries = _readZipEntries(bytes);
    for (final entry in entries) {
      if (entry.name.toLowerCase() == 'word/document.xml') {
        try {
          final xmlStr = utf8.decode(entry.bytes, allowMalformed: true);
          final doc = XmlDocument.parse(xmlStr);
          final lines = <String>[];

          void collectParagraphText(XmlNode node, XmlElement rootP, StringBuffer sb) {
            if (node is XmlElement) {
              final local = node.name.local;
              if (node != rootP && local == 'p') return;
              if (local == 't') {
                sb.write(node.innerText);
                return;
              }
              if (local == 'tab') {
                sb.write('\t');
                return;
              }
              if (local == 'br' || local == 'cr') {
                sb.write('\n');
                return;
              }
              for (final child in node.children) {
                collectParagraphText(child, rootP, sb);
              }
            }
          }

          for (final pEl
              in doc.descendants.whereType<XmlElement>().where((e) => e.name.local == 'p')) {
            final sb = StringBuffer();
            collectParagraphText(pEl, pEl, sb);
            final line = sb.toString().trim();
            if (line.isNotEmpty) {
              lines.add(line);
            }
          }
          if (lines.isEmpty) return null;
          return lines.join('\n');
        } catch (_) {
          return null;
        }
      }
    }
    return null;
  }

  static String? _extractZipText(Uint8List bytes) {
    final entries = _readZipEntries(bytes);
    if (entries.isEmpty) return null;

    const ignoredSegments = {
      '__macosx',
      '.git',
      'node_modules',
      'build',
      '.gradle',
      '.idea',
    };

    final buf = StringBuffer();
    for (final entry in entries) {
      final normalized = entry.name.replaceAll('\\', '/');
      final segments = normalized
          .toLowerCase()
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList();
      if (segments.any(ignoredSegments.contains)) continue;

      final ext = p.extension(entry.name).toLowerCase();
      String? content;
      if (ext == '.docx') {
        content = _extractDocxText(entry.bytes);
      } else if (_textExtensions.contains(ext)) {
        try {
          content = utf8.decode(entry.bytes);
        } catch (_) {
          content = latin1.decode(entry.bytes);
        }
      }
      if (content == null || content.trim().isEmpty) continue;

      buf.writeln('// === ${entry.name} ===');
      buf.writeln(content.trimRight());
      buf.writeln();
      if (buf.length >= maxTextChars) break;
    }

    final out = buf.toString().trim();
    if (out.isEmpty) return null;
    return _capText(out);
  }

  static List<({String name, Uint8List bytes})> _readZipEntries(
      Uint8List bytes) {
    if (bytes.length < 22) return const [];
    final bd = ByteData.sublistView(bytes);

    final minOffset =
        bytes.length > 65557 ? bytes.length - 65557 : 0;
    int eocdOffset = -1;
    for (int i = bytes.length - 22; i >= minOffset; i--) {
      if (bd.getUint32(i, Endian.little) == 0x06054b50) {
        final commentLen = bd.getUint16(i + 20, Endian.little);
        if (i + 22 + commentLen == bytes.length) {
          eocdOffset = i;
          break;
        }
      }
    }
    if (eocdOffset == -1) return const [];

    final entryCount = bd.getUint16(eocdOffset + 10, Endian.little);
    final cdOffset = bd.getUint32(eocdOffset + 16, Endian.little);
    if (cdOffset >= bytes.length) return const [];

    final result = <({String name, Uint8List bytes})>[];
    int pos = cdOffset;
    for (int idx = 0; idx < entryCount && pos + 46 <= bytes.length; idx++) {
      if (bd.getUint32(pos, Endian.little) != 0x02014b50) break;

      final method = bd.getUint16(pos + 10, Endian.little);
      final compSize = bd.getUint32(pos + 20, Endian.little);
      final uncompSize = bd.getUint32(pos + 24, Endian.little);
      final nameLen = bd.getUint16(pos + 28, Endian.little);
      final extraLen = bd.getUint16(pos + 30, Endian.little);
      final commentLen = bd.getUint16(pos + 32, Endian.little);
      final localOffset = bd.getUint32(pos + 42, Endian.little);

      if (pos + 46 + nameLen > bytes.length) break;
      final name = utf8.decode(
        bytes.sublist(pos + 46, pos + 46 + nameLen),
        allowMalformed: true,
      );
      pos += 46 + nameLen + extraLen + commentLen;

      if (name.endsWith('/')) continue;
      if (compSize > maxArchiveBytes || uncompSize > maxArchiveBytes) continue;
      if (localOffset + 30 > bytes.length) continue;
      if (bd.getUint32(localOffset, Endian.little) != 0x04034b50) continue;

      final lNameLen = bd.getUint16(localOffset + 26, Endian.little);
      final lExtraLen = bd.getUint16(localOffset + 28, Endian.little);
      final dataStart = localOffset + 30 + lNameLen + lExtraLen;
      if (dataStart < 0 || dataStart + compSize > bytes.length) continue;

      final slice = bytes.sublist(dataStart, dataStart + compSize);
      try {
        if (method == 0) {
          result.add((name: name, bytes: slice));
        } else if (method == 8) {
          final decoded = ZLibDecoder(raw: true).convert(slice);
          result.add((name: name, bytes: Uint8List.fromList(decoded)));
        }
      } catch (_) {
        // Skip corrupted or unsupported entry.
      }
    }
    return result;
  }
}

class AiReviewService {
  static const List<AiProviderPreset> presets = [
    AiProviderPreset(
      id: 'gemini',
      label: 'Google Gemini',
      defaultBaseUrl: 'https://generativelanguage.googleapis.com',
      defaultModel: 'gemini-2.5-flash',
      suggestedModels: [
        'gemini-2.5-flash',
        'gemini-2.5-pro',
        'gemini-2.0-flash',
      ],
      supportsPdf: true,
    ),
    AiProviderPreset(
      id: 'openai',
      label: 'OpenAI',
      defaultBaseUrl: 'https://api.openai.com/v1',
      defaultModel: 'gpt-4o-mini',
      suggestedModels: [
        'gpt-4o-mini',
        'gpt-4o',
        'o4-mini',
      ],
    ),
    AiProviderPreset(
      id: 'openrouter',
      label: 'OpenRouter',
      defaultBaseUrl: 'https://openrouter.ai/api/v1',
      defaultModel: 'google/gemini-2.0-flash-exp:free',
      suggestedModels: [
        'google/gemini-2.0-flash-exp:free',
        'meta-llama/llama-3.3-70b-instruct:free',
        'openai/gpt-4o-mini',
      ],
    ),
    AiProviderPreset(
      id: 'groq',
      label: 'Groq',
      defaultBaseUrl: 'https://api.groq.com/openai/v1',
      defaultModel: 'llama-3.3-70b-versatile',
      suggestedModels: [
        'llama-3.3-70b-versatile',
        'llama-3.1-8b-instant',
      ],
    ),
    AiProviderPreset(
      id: 'custom',
      label: 'Custom',
      defaultBaseUrl: '',
      defaultModel: '',
      suggestedModels: [],
      isCustom: true,
    ),
  ];

  static AiProviderPreset presetFor(String id) {
    return presets.firstWhere(
      (p) => p.id == id,
      orElse: () => presets.first,
    );
  }

  final Dio _dio;

  AiReviewService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 25),
                receiveTimeout: const Duration(seconds: 90),
                sendTimeout: const Duration(seconds: 60),
                validateStatus: (status) => status != null && status < 600,
              ),
            );

  static String resolveBaseUrl(AppSettings settings) {
    final preset = presetFor(settings.aiProvider);
    final raw = preset.isCustom
        ? settings.aiBaseUrl.trim()
        : (settings.aiBaseUrl.trim().isNotEmpty
            ? settings.aiBaseUrl.trim()
            : preset.defaultBaseUrl);
    return raw.replaceAll(RegExp(r'/+$'), '');
  }

  static ({String systemPrompt, String userPrompt}) buildPrompts({
    required Assignment assignment,
    required AiCheckMode mode,
    required String language,
    required List<AiAttachment> attachments,
    String pastedSolution = '',
  }) {
    final outLang = language == 'ru' ? 'Russian' : 'English';
    final modeInstructions = switch (mode) {
      AiCheckMode.requirements =>
        'Focus on checking every explicit and implicit requirement in the assignment description and attached specification.',
      AiCheckMode.bugsAndEdgeCases =>
        'Focus on finding logic bugs, boundary/edge cases, runtime failures, formatting errors, and missing validations.',
      AiCheckMode.strictGrader =>
        'Evaluate strictly like a university grader against max points (or 100 if unspecified), noting exact reasons points could be deducted.',
    };

    final systemPrompt = '''
You are an academic pre-submission homework reviewer for a university student.
Your job is to verify the student's work against the assignment prompt and specifications, identify gaps, errors, or edge cases, and give actionable hints.
Academic integrity rule: DO NOT write or rewrite the complete homework solution for the student; point out what is missing or broken and how they can fix it themselves.
$modeInstructions
Write all human-readable text in $outLang.
Respond ONLY with a valid JSON object matching this exact schema (no markdown fences, no extra text):
{
  "summary": "2-4 sentence overall readiness summary",
  "estimated_score": "string like '17/20' or null if impossible to estimate",
  "checklist": [
    {"requirement": "short requirement title", "status": "met|partial|missing", "note": "brief evidence or gap"}
  ],
  "issues": ["concrete bug, mistake, or missing requirement"],
  "suggestions": ["actionable next step before submitting"]
}
'''.trim();

    final buf = StringBuffer();
    if (assignment.courseName.isNotEmpty) {
      buf.writeln('Course: ${assignment.courseName}');
    }
    buf.writeln('Assignment: ${assignment.name}');
    if (assignment.due.isNotEmpty) {
      buf.writeln('Deadline: ${assignment.due}');
    }
    if (assignment.effectiveMaxPoints != null) {
      buf.writeln('Max Points: ${assignment.effectiveMaxPoints}');
    }
    buf.writeln('\n--- ASSIGNMENT INSTRUCTIONS ---');
    buf.writeln(
      assignment.intro.trim().isNotEmpty
          ? assignment.intro.trim()
          : '(No written description provided in eClass.)',
    );

    final specTexts =
        attachments.where((a) => a.role == 'spec' && a.textContent != null);
    for (final spec in specTexts) {
      buf.writeln('\n--- SPEC FILE: ${spec.name} ---');
      buf.writeln(spec.textContent);
    }

    final subTexts = attachments
        .where((a) => a.role == 'submission' && a.textContent != null);
    for (final sub in subTexts) {
      buf.writeln('\n--- STUDENT SUBMISSION FILE: ${sub.name} ---');
      buf.writeln(sub.textContent);
    }

    if (pastedSolution.trim().isNotEmpty) {
      buf.writeln('\n--- PASTED STUDENT SOLUTION ---');
      buf.writeln(pastedSolution.trim());
    }

    final binaries = attachments.where((a) => a.isBinary).toList();
    if (binaries.isNotEmpty) {
      buf.writeln('\n--- ATTACHED BINARY FILES ---');
      for (final b in binaries) {
        buf.writeln('- ${b.name} (${b.role}, ${b.mimeType})');
      }
    }

    return (systemPrompt: systemPrompt, userPrompt: buf.toString().trim());
  }

  static AiReviewResult parseReviewResponse(
    String rawText, {
    required String assignmentId,
    required AiCheckMode mode,
    required String provider,
    required String model,
  }) {
    final cleaned = _extractJsonObject(rawText);
    if (cleaned != null) {
      try {
        final decoded = jsonDecode(cleaned);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final summary = (map['summary'] ?? '').toString().trim();
          final rawScore = map['estimated_score'];
          final estimatedScore =
              rawScore == null || rawScore.toString().trim().isEmpty
                  ? null
                  : rawScore.toString().trim();

          final checklist = <AiRequirementItem>[];
          final rawChecklist = map['checklist'];
          if (rawChecklist is List) {
            for (final item in rawChecklist) {
              if (item is Map) {
                final parsed = AiRequirementItem.fromJson(
                    Map<String, dynamic>.from(item));
                if (parsed.requirement.isNotEmpty) {
                  checklist.add(parsed);
                }
              }
            }
          }

          final issues = <String>[];
          final rawIssues = map['issues'];
          if (rawIssues is List) {
            for (final item in rawIssues) {
              final text = item.toString().trim();
              if (text.isNotEmpty) issues.add(text);
            }
          }

          final suggestions = <String>[];
          final rawSuggestions = map['suggestions'];
          if (rawSuggestions is List) {
            for (final item in rawSuggestions) {
              final text = item.toString().trim();
              if (text.isNotEmpty) suggestions.add(text);
            }
          }

          final result = AiReviewResult(
            assignmentId: assignmentId,
            mode: mode,
            provider: provider,
            model: model,
            summary: summary,
            estimatedScore: estimatedScore,
            checklist: checklist,
            issues: issues,
            suggestions: suggestions,
            rawMarkdown: rawText.trim(),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          if (result.hasStructuredContent) {
            return result;
          }
        }
      } catch (_) {
        // Fall through to raw markdown fallback.
      }
    }

    return AiReviewResult(
      assignmentId: assignmentId,
      mode: mode,
      provider: provider,
      model: model,
      rawMarkdown: rawText.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  static String? _extractJsonObject(String input) {
    var text = input.trim();
    if (text.isEmpty) return null;

    final fenceMatch =
        RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```', caseSensitive: false)
            .firstMatch(text);
    if (fenceMatch != null) {
      text = fenceMatch.group(1)!.trim();
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    return text.substring(start, end + 1);
  }

  Future<String> testConnection(AppSettings settings) async {
    _validateSettings(settings);
    final text = await _sendCompletion(
      settings: settings,
      systemPrompt: 'You are a connectivity probe.',
      userPrompt: 'Reply with OK.',
      attachments: const [],
      maxTokens: 256,
      expectJson: false,
    );
    return text.trim().isEmpty ? 'OK' : text.trim();
  }

  Future<AiReviewResult> reviewHomework({
    required AppSettings settings,
    required Assignment assignment,
    required AiCheckMode mode,
    required List<AiAttachment> attachments,
    String pastedSolution = '',
  }) async {
    _validateSettings(settings);
    final included = attachments.where((a) => a.isIncluded).toList();
    final prompts = buildPrompts(
      assignment: assignment,
      mode: mode,
      language: settings.language,
      attachments: included,
      pastedSolution: pastedSolution,
    );

    final raw = await _sendCompletion(
      settings: settings,
      systemPrompt: prompts.systemPrompt,
      userPrompt: prompts.userPrompt,
      attachments: included,
      maxTokens: 8192,
      expectJson: true,
    );

    return parseReviewResponse(
      raw,
      assignmentId: assignment.id,
      mode: mode,
      provider: settings.aiProvider,
      model: settings.aiModel.trim(),
    );
  }

  void _validateSettings(AppSettings settings) {
    if (settings.aiApiKey.trim().isEmpty) {
      throw const AiServiceException(
        'API key is missing. Add your key in Settings.',
        code: 'config',
      );
    }
    if (settings.aiModel.trim().isEmpty) {
      throw const AiServiceException(
        'Model name is missing. Specify a model in Settings.',
        code: 'config',
      );
    }
    final baseUrl = resolveBaseUrl(settings);
    final uri = Uri.tryParse(baseUrl);
    if (baseUrl.isEmpty ||
        uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      throw const AiServiceException(
        'Invalid Base URL. Use a valid http(s) endpoint.',
        code: 'config',
      );
    }
  }

  Future<String> _sendCompletion({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    required List<AiAttachment> attachments,
    required int maxTokens,
    bool expectJson = false,
  }) async {
    if (settings.aiProvider == 'gemini') {
      return _sendGemini(
        settings: settings,
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        attachments: attachments,
        maxTokens: maxTokens,
        expectJson: expectJson,
      );
    }
    return _sendOpenAiCompatible(
      settings: settings,
      systemPrompt: systemPrompt,
      userPrompt: userPrompt,
      attachments: attachments,
      maxTokens: maxTokens,
      expectJson: expectJson,
    );
  }

  Future<String> _sendGemini({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    required List<AiAttachment> attachments,
    required int maxTokens,
    bool expectJson = false,
  }) async {
    final baseUrl = resolveBaseUrl(settings);
    final model = Uri.encodeComponent(settings.aiModel.trim());
    final url = '$baseUrl/v1beta/models/$model:generateContent';

    final parts = <Map<String, dynamic>>[
      {'text': userPrompt},
      for (final att in attachments)
        if (att.isBinary && att.base64Data != null && att.mimeType != null)
          {
            'inlineData': {
              'mimeType': att.mimeType,
              'data': att.base64Data,
            },
          },
    ];

    final body = {
      'systemInstruction': {
        'parts': [
          {'text': systemPrompt},
        ],
      },
      'contents': [
        {
          'role': 'user',
          'parts': parts,
        },
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': maxTokens,
        if (expectJson) 'responseMimeType': 'application/json',
      },
    };

    try {
      final res = await _dio.post<dynamic>(
        url,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': settings.aiApiKey.trim(),
          },
        ),
      );
      _throwIfErrorResponse(res);
      final data = _decodeJsonMap(res.data);
      final candidates = data['candidates'];
      if (candidates is List && candidates.isNotEmpty) {
        final first = candidates.first;
        if (first is Map) {
          final content = first['content'];
          if (content is Map && content['parts'] is List) {
            final textParts = (content['parts'] as List)
                .whereType<Map>()
                .map((p) => (p['text'] ?? '').toString())
                .where((t) => t.isNotEmpty)
                .join('\n');
            if (textParts.trim().isNotEmpty) {
              return textParts;
            }
          }
        }
      }
      throw const AiServiceException(
        'The AI model returned an empty response.',
        code: 'empty_response',
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<String> _sendOpenAiCompatible({
    required AppSettings settings,
    required String systemPrompt,
    required String userPrompt,
    required List<AiAttachment> attachments,
    required int maxTokens,
    bool expectJson = false,
  }) async {
    final baseUrl = resolveBaseUrl(settings);
    final url = baseUrl.endsWith('/chat/completions')
        ? baseUrl
        : '$baseUrl/chat/completions';

    final imageAttachments = attachments
        .where((a) =>
            a.isBinary &&
            a.base64Data != null &&
            (a.mimeType?.startsWith('image/') ?? false))
        .toList();

    final dynamic userContent = imageAttachments.isEmpty
        ? userPrompt
        : <Map<String, dynamic>>[
            {'type': 'text', 'text': userPrompt},
            for (final img in imageAttachments)
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:${img.mimeType};base64,${img.base64Data}',
                },
              },
          ];

    final clampedTokens = maxTokens > 4096 ? 4096 : maxTokens;
    final body = {
      'model': settings.aiModel.trim(),
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContent},
      ],
      'temperature': 0.2,
      'max_tokens': clampedTokens,
    };

    try {
      final res = await _dio.post<dynamic>(
        url,
        data: body,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${settings.aiApiKey.trim()}',
          },
        ),
      );
      _throwIfErrorResponse(res);
      final data = _decodeJsonMap(res.data);
      final choices = data['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = first['message'];
          if (message is Map) {
            final content = message['content'];
            if (content is String && content.trim().isNotEmpty) {
              return content;
            }
            if (content is List) {
              final text = content
                  .whereType<Map>()
                  .map((p) => (p['text'] ?? '').toString())
                  .where((t) => t.isNotEmpty)
                  .join('\n');
              if (text.trim().isNotEmpty) return text;
            }
          }
        }
      }
      throw const AiServiceException(
        'The AI model returned an empty response.',
        code: 'empty_response',
      );
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Map<String, dynamic> _decodeJsonMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String && raw.trim().isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const AiServiceException(
      'Unexpected response format from AI provider.',
      code: 'bad_response',
    );
  }

  void _throwIfErrorResponse(Response<dynamic> res) {
    final code = res.statusCode ?? 0;
    if (code < 400) return;

    String? providerMsg;
    try {
      final map = _decodeJsonMap(res.data);
      final err = map['error'];
      if (err is Map && err['message'] != null) {
        providerMsg = err['message'].toString().trim();
      } else if (map['message'] != null) {
        providerMsg = map['message'].toString().trim();
      }
    } catch (_) {}

    throw _buildStatusException(code, providerMsg);
  }

  AiServiceException _mapDioException(DioException e) {
    if (e.response != null) {
      final code = e.response!.statusCode ?? 0;
      String? providerMsg;
      try {
        final map = _decodeJsonMap(e.response!.data);
        final err = map['error'];
        if (err is Map && err['message'] != null) {
          providerMsg = err['message'].toString().trim();
        }
      } catch (_) {}
      if (code >= 400) {
        return _buildStatusException(code, providerMsg);
      }
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const AiServiceException(
        'Request timed out. Try smaller files or check your connection.',
        code: 'timeout',
      );
    }
    return const AiServiceException(
      'Network error while contacting the AI provider.',
      code: 'network',
    );
  }

  AiServiceException _buildStatusException(int status, String? providerMsg) {
    final suffix = (providerMsg != null && providerMsg.isNotEmpty)
        ? ' ($providerMsg)'
        : '';
    return switch (status) {
      401 => AiServiceException(
          'Invalid API key (401). Check your key in Settings.$suffix',
          statusCode: status,
          code: 'unauthorized',
        ),
      403 => AiServiceException(
          'Access denied (403). Verify key permissions or region access.$suffix',
          statusCode: status,
          code: 'forbidden',
        ),
      404 => AiServiceException(
          'Model or endpoint not found (404). Check model name and Base URL.$suffix',
          statusCode: status,
          code: 'not_found',
        ),
      429 => AiServiceException(
          'Rate limit or quota exceeded (429). Try again later or check provider billing.$suffix',
          statusCode: status,
          code: 'rate_limited',
        ),
      400 || 413 => AiServiceException(
          'Provider rejected the request ($status) — payload may be too large or attachment unsupported.$suffix',
          statusCode: status,
          code: 'bad_request',
        ),
      _ => AiServiceException(
          'AI provider returned HTTP $status.$suffix',
          statusCode: status,
          code: 'http_$status',
        ),
    };
  }
}
