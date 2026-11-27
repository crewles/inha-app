import 'dart:convert';

class UserCredentials {
  final String studentId;
  final String eclassPassword;
  final String? insPassword;
  final String? eclassToken;

  const UserCredentials({
    required this.studentId,
    required this.eclassPassword,
    this.insPassword,
    this.eclassToken,
  });

  /// Password used when authenticating to INS (`ins.inha.uz`): uses the
  /// optional override if configured, otherwise falls back to [eclassPassword].
  String get effectiveInsPassword {
    final override = insPassword?.trim();
    if (override != null && override.isNotEmpty) return override;
    return eclassPassword;
  }

  UserCredentials copyWith({
    String? studentId,
    String? eclassPassword,
    String? insPassword,
    bool clearInsPassword = false,
    String? eclassToken,
    bool clearToken = false,
  }) {
    return UserCredentials(
      studentId: studentId ?? this.studentId,
      eclassPassword: eclassPassword ?? this.eclassPassword,
      insPassword: clearInsPassword ? null : (insPassword ?? this.insPassword),
      eclassToken: clearToken ? null : (eclassToken ?? this.eclassToken),
    );
  }
}

class Course {
  final String id;
  final String name;
  final int category;
  final bool isCurrent;
  final String? overviewGrade;
  final String professor;
  final int updatedAt;

  const Course({
    required this.id,
    required this.name,
    this.category = 0,
    this.isCurrent = true,
    this.overviewGrade,
    this.professor = '',
    this.updatedAt = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'is_current': isCurrent ? 1 : 0,
        'overview_grade': overviewGrade,
        'professor': professor,
        'updated_at': updatedAt,
      };

  factory Course.fromMap(Map<String, dynamic> m) => Course(
        id: m['id'] as String,
        name: m['name'] as String,
        category: (m['category'] as int?) ?? 0,
        isCurrent: ((m['is_current'] as int?) ?? 1) == 1,
        overviewGrade: m['overview_grade'] as String?,
        professor: (m['professor'] as String?) ?? '',
        updatedAt: (m['updated_at'] as int?) ?? 0,
      );
}

class AssignmentFile {
  final String name;
  final String link;
  final int size;

  const AssignmentFile({
    required this.name,
    required this.link,
    this.size = 0,
  });

  Map<String, dynamic> toJson() => {'name': name, 'link': link, 'size': size};

  factory AssignmentFile.fromJson(Map<String, dynamic> j) => AssignmentFile(
        name: (j['name'] as String?) ?? 'file',
        link: (j['link'] as String?) ?? '',
        size: (j['size'] as int?) ?? 0,
      );
}

class Assignment {
  final String id;
  final int? assignId;
  final String courseId;
  final String courseName;
  final String name;
  final String due;
  final int dueTimestamp; // Unix seconds (0 if no due date)
  final String status;
  final String? grade;
  final String? gradeMax;
  final String? url;
  final List<AssignmentFile> files;
  final String intro;
  final String? maxPoints;
  final int cutoffTimestamp;
  final List<AssignmentFile> submittedFiles;
  final String feedbackComment;
  final int updatedAt;

  const Assignment({
    required this.id,
    this.assignId,
    required this.courseId,
    required this.courseName,
    required this.name,
    required this.due,
    this.dueTimestamp = 0,
    required this.status,
    this.grade,
    this.gradeMax,
    this.url,
    this.files = const [],
    this.intro = '',
    this.maxPoints,
    this.cutoffTimestamp = 0,
    this.submittedFiles = const [],
    this.feedbackComment = '',
    this.updatedAt = 0,
  });

  bool get hasGrade => grade != null && grade!.trim().isNotEmpty;

  bool get isDraft {
    final s = status.toLowerCase();
    return s.contains('draft') || s.contains('черновик');
  }

  bool get isSubmitted {
    if (hasGrade) return true;
    if (isDraft) return false;
    final s = status.toLowerCase();
    if (s.contains('not submitted') || s.contains('не сдано')) return false;
    return s.contains('submitted') ||
        s.contains('сдано') ||
        s.contains('отправлено') ||
        s.contains('graded');
  }

  bool get isGradedOnly {
    if (!hasGrade) return false;
    final s = status.toLowerCase();
    return !s.contains('submitted') &&
        !s.contains('сдано') &&
        !s.contains('отправлено');
  }

  static List<Assignment> sortForDisplay(
    List<Assignment> items, {
    required bool pendingMode,
    int? nowSec,
  }) {
    final now = nowSec ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    final sorted = List<Assignment>.from(items);
    sorted.sort((a, b) {
      if (pendingMode) {
        final aGroup = a.dueTimestamp >= now ? 0 : (a.dueTimestamp > 0 ? 1 : 2);
        final bGroup = b.dueTimestamp >= now ? 0 : (b.dueTimestamp > 0 ? 1 : 2);
        if (aGroup != bGroup) return aGroup.compareTo(bGroup);
        if (aGroup == 0) {
          final cmp = a.dueTimestamp.compareTo(b.dueTimestamp);
          if (cmp != 0) return cmp;
        } else if (aGroup == 1) {
          final cmp = b.dueTimestamp.compareTo(a.dueTimestamp);
          if (cmp != 0) return cmp;
        }
        return (b.assignId ?? 0).compareTo(a.assignId ?? 0);
      } else {
        if (a.dueTimestamp > 0 && b.dueTimestamp > 0) {
          final cmp = b.dueTimestamp.compareTo(a.dueTimestamp);
          if (cmp != 0) return cmp;
        } else if (a.dueTimestamp > 0) {
          return -1;
        } else if (b.dueTimestamp > 0) {
          return 1;
        }
        return (b.assignId ?? 0).compareTo(a.assignId ?? 0);
      }
    });
    return sorted;
  }

  String? get effectiveMaxPoints {
    if (gradeMax != null && gradeMax!.isNotEmpty) return gradeMax;
    if (maxPoints != null && maxPoints!.isNotEmpty) return maxPoints;
    return null;
  }

  String? get gradeDisplay {
    if (grade == null || grade!.isEmpty) return null;
    if (gradeMax != null && gradeMax!.isNotEmpty) {
      return '$grade / $gradeMax';
    }
    return grade;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'assign_id': assignId,
        'course_id': courseId,
        'course_name': courseName,
        'name': name,
        'due': due,
        'due_timestamp': dueTimestamp,
        'status': status,
        'grade': grade,
        'grade_max': gradeMax,
        'url': url,
        'files_json': jsonEncode(files.map((f) => f.toJson()).toList()),
        'intro': intro,
        'max_points': maxPoints,
        'cutoff_timestamp': cutoffTimestamp,
        'submitted_files_json':
            jsonEncode(submittedFiles.map((f) => f.toJson()).toList()),
        'feedback_comment': feedbackComment,
        'updated_at': updatedAt,
      };

  factory Assignment.fromMap(Map<String, dynamic> m) {
    List<AssignmentFile> parseFiles(String? raw) {
      if (raw == null || raw.isEmpty) return const [];
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        return list
            .map((e) => AssignmentFile.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return const [];
      }
    }

    return Assignment(
      id: m['id'] as String,
      assignId: m['assign_id'] as int?,
      courseId: m['course_id'] as String,
      courseName: (m['course_name'] as String?) ?? '',
      name: m['name'] as String,
      due: (m['due'] as String?) ?? '',
      dueTimestamp: (m['due_timestamp'] as int?) ?? 0,
      status: (m['status'] as String?) ?? '',
      grade: m['grade'] as String?,
      gradeMax: m['grade_max'] as String?,
      url: m['url'] as String?,
      files: parseFiles(m['files_json'] as String?),
      intro: (m['intro'] as String?) ?? '',
      maxPoints: m['max_points'] as String?,
      cutoffTimestamp: (m['cutoff_timestamp'] as int?) ?? 0,
      submittedFiles: parseFiles(m['submitted_files_json'] as String?),
      feedbackComment: (m['feedback_comment'] as String?) ?? '',
      updatedAt: (m['updated_at'] as int?) ?? 0,
    );
  }
}

class OpenAssignment {
  final int id;
  final String name;
  final int dueTimestamp;
  final bool drafts;

  const OpenAssignment({
    required this.id,
    required this.name,
    required this.dueTimestamp,
    required this.drafts,
  });
}

class GradeItem {
  final String courseId;
  final String name;
  final String value;
  final String category;
  final String weight;
  final String range;
  final String percentage;

  /// One of `'category'`, `'item'`, `'sum'`, or `'total'`.
  final String itemType;

  const GradeItem({
    required this.courseId,
    required this.name,
    required this.value,
    this.category = '',
    this.weight = '',
    this.range = '',
    this.percentage = '',
    this.itemType = 'item',
  });

  bool get isTotal => itemType == 'total';
  bool get isSum => itemType == 'sum';
  bool get isCategory => itemType == 'category';
  bool get isItem => itemType == 'item';

  Map<String, dynamic> toMap() => {
        'course_id': courseId,
        'name': name,
        'value': value,
        'category': category,
        'weight': weight,
        'range_str': range,
        'percentage': percentage,
        'item_type': itemType,
      };

  factory GradeItem.fromMap(Map<String, dynamic> m) => GradeItem(
        courseId: m['course_id'] as String,
        name: m['name'] as String,
        value: m['value'] as String,
        category: (m['category'] as String?) ?? '',
        weight: (m['weight'] as String?) ?? '',
        range: (m['range_str'] as String?) ?? '',
        percentage: (m['percentage'] as String?) ?? '',
        itemType: (m['item_type'] as String?) ?? 'item',
      );
}

class AttendanceRecord {
  final String date;
  final String className;
  final String attendance;
  final String absence;
  final String late;
  final String others;

  const AttendanceRecord({
    required this.date,
    required this.className,
    required this.attendance,
    required this.absence,
    required this.late,
    required this.others,
  });

  static bool isCellMarked(String raw) {
    final cleaned = raw.replaceAll('\u00A0', '').trim();
    if (cleaned.isEmpty) return false;
    return cleaned != '-' && cleaned != '—' && cleaned != '0';
  }

  String get statusType {
    if (isCellMarked(attendance)) return 'present';
    if (isCellMarked(absence)) return 'absent';
    if (isCellMarked(late)) return 'late';
    return 'other';
  }

  Map<String, dynamic> toJson() => {
        'date': date,
        'class': className,
        'attendance': attendance,
        'absence': absence,
        'late': late,
        'others': others,
      };

  factory AttendanceRecord.fromJson(Map<String, dynamic> j) => AttendanceRecord(
        date: (j['date'] as String?) ?? '',
        className: (j['class'] as String?) ?? '',
        attendance: (j['attendance'] as String?) ?? '',
        absence: (j['absence'] as String?) ?? '',
        late: (j['late'] as String?) ?? '',
        others: (j['others'] as String?) ?? '',
      );
}

class AttendanceData {
  final String courseId;
  final int attendanceCount;
  final int absenceCount;
  final int lateCount;
  final int othersCount;
  final List<AttendanceRecord> records;
  final int updatedAt;

  const AttendanceData({
    required this.courseId,
    required this.attendanceCount,
    required this.absenceCount,
    required this.lateCount,
    required this.othersCount,
    required this.records,
    this.updatedAt = 0,
  });

  int get total => attendanceCount + absenceCount + lateCount + othersCount;
  double get percentage => total > 0 ? (attendanceCount / total) * 100.0 : 0.0;

  Map<String, dynamic> toMap() => {
        'course_id': courseId,
        'attendance_count': attendanceCount,
        'absence_count': absenceCount,
        'late_count': lateCount,
        'others_count': othersCount,
        'records_json': jsonEncode(records.map((r) => r.toJson()).toList()),
        'updated_at': updatedAt,
      };

  factory AttendanceData.fromMap(Map<String, dynamic> m) {
    List<AttendanceRecord> recs = [];
    final raw = m['records_json'] as String?;
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        recs = list
            .map((e) => AttendanceRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }
    return AttendanceData(
      courseId: m['course_id'] as String,
      attendanceCount: (m['attendance_count'] as int?) ?? 0,
      absenceCount: (m['absence_count'] as int?) ?? 0,
      lateCount: (m['late_count'] as int?) ?? 0,
      othersCount: (m['others_count'] as int?) ?? 0,
      records: recs,
      updatedAt: (m['updated_at'] as int?) ?? 0,
    );
  }
}

class CourseFile {
  final int? id;
  final String courseId;
  final String name;
  final String url;
  final int size;
  final String? localPath;

  const CourseFile({
    this.id,
    required this.courseId,
    required this.name,
    required this.url,
    this.size = 0,
    this.localPath,
  });

  CourseFile copyWith({String? localPath}) => CourseFile(
        id: id,
        courseId: courseId,
        name: name,
        url: url,
        size: size,
        localPath: localPath ?? this.localPath,
      );

  Map<String, dynamic> toMap() => {
        'course_id': courseId,
        'name': name,
        'url': url,
        'size': size,
        'local_path': localPath,
      };

  factory CourseFile.fromMap(Map<String, dynamic> m) => CourseFile(
        id: m['id'] as int?,
        courseId: m['course_id'] as String,
        name: m['name'] as String,
        url: m['url'] as String,
        size: (m['size'] as int?) ?? 0,
        localPath: m['local_path'] as String?,
      );
}

class InsCourseGrade {
  final String courseNumber;
  final String title;
  final String credit;
  final String grade;
  final String courseType;
  final String semester;
  final String yearterm;
  final String professor;
  final String classNumber;

  const InsCourseGrade({
    required this.courseNumber,
    required this.title,
    required this.credit,
    required this.grade,
    this.courseType = '',
    this.semester = '',
    this.yearterm = '',
    this.professor = '',
    this.classNumber = '',
  });

  Map<String, dynamic> toMap() => {
        'course_number': courseNumber,
        'title': title,
        'credit': credit,
        'grade': grade,
        'course_type': courseType,
        'semester': semester,
        'yearterm': yearterm,
        'professor': professor,
        'class_number': classNumber,
      };

  factory InsCourseGrade.fromMap(Map<String, dynamic> m) => InsCourseGrade(
        courseNumber: (m['course_number'] as String?) ?? '',
        title: (m['title'] as String?) ?? '',
        credit: (m['credit'] as String?) ?? '',
        grade: (m['grade'] as String?) ?? '',
        courseType: (m['course_type'] as String?) ?? '',
        semester: (m['semester'] as String?) ?? '',
        yearterm: (m['yearterm'] as String?) ?? '',
        professor: (m['professor'] as String?) ?? '',
        classNumber: (m['class_number'] as String?) ?? '',
      );
}

class InsGradeData {
  final List<InsCourseGrade> courses;
  final Map<String, String> gpaInfo;
  final Map<String, String> studentInfo;
  final int updatedAt;

  const InsGradeData({
    required this.courses,
    required this.gpaInfo,
    required this.studentInfo,
    this.updatedAt = 0,
  });
}

class ScheduleEntry {
  final String cardId;
  final String lessonId;
  final List<String> days;
  final String periodStart;
  final String periodEnd;
  final String subject;
  final List<String> teachers;
  final List<String> classes;
  final List<String> classrooms;
  final int durationPeriods;

  const ScheduleEntry({
    required this.cardId,
    required this.lessonId,
    required this.days,
    required this.periodStart,
    required this.periodEnd,
    required this.subject,
    required this.teachers,
    required this.classes,
    required this.classrooms,
    this.durationPeriods = 1,
  });

  Map<String, dynamic> toMap() => {
        'card_id': cardId,
        'lesson_id': lessonId,
        'days_json': jsonEncode(days),
        'period_start': periodStart,
        'period_end': periodEnd,
        'subject': subject,
        'teachers_json': jsonEncode(teachers),
        'classes_json': jsonEncode(classes),
        'classrooms_json': jsonEncode(classrooms),
        'duration_periods': durationPeriods,
      };

  factory ScheduleEntry.fromMap(Map<String, dynamic> m) => ScheduleEntry(
        cardId: m['card_id'] as String,
        lessonId: (m['lesson_id'] as String?) ?? '',
        days:
            List<String>.from(jsonDecode((m['days_json'] as String?) ?? '[]')),
        periodStart: (m['period_start'] as String?) ?? '',
        periodEnd: (m['period_end'] as String?) ?? '',
        subject: (m['subject'] as String?) ?? '',
        teachers: List<String>.from(
            jsonDecode((m['teachers_json'] as String?) ?? '[]')),
        classes: List<String>.from(
            jsonDecode((m['classes_json'] as String?) ?? '[]')),
        classrooms: List<String>.from(
            jsonDecode((m['classrooms_json'] as String?) ?? '[]')),
        durationPeriods: (m['duration_periods'] as int?) ?? 1,
      );
}

class AppSettings {
  final String themeMode; // system | light | dark
  final bool dynamicColor;
  final String language; // ru | en
  final bool hideSubmitted;
  final bool showAllCourses;
  final bool notifyAssignments;
  final bool notifyGrades;
  final bool notifyTimetable;
  final int reminderOffsetMinutes;
  final bool bgSyncEnabled;
  final int bgSyncIntervalHours;
  final String timetableGroup;
  final bool timetableGroupAutoDetected;
  final int lastSyncAt;
  final bool hapticsEnabled;
  final bool diagnosticsEnabled;
  final String aiProvider; // gemini | openai | openrouter | groq | custom
  final String aiBaseUrl;
  final String aiApiKey;
  final String aiModel;

  const AppSettings({
    this.themeMode = 'system',
    this.dynamicColor = true,
    this.language = 'ru',
    this.hideSubmitted = false,
    this.showAllCourses = false,
    this.notifyAssignments = true,
    this.notifyGrades = true,
    this.notifyTimetable = true,
    this.reminderOffsetMinutes = 15,
    this.bgSyncEnabled = true,
    this.bgSyncIntervalHours = 2,
    this.timetableGroup = '',
    this.timetableGroupAutoDetected = false,
    this.lastSyncAt = 0,
    this.hapticsEnabled = true,
    this.diagnosticsEnabled = false,
    this.aiProvider = 'gemini',
    this.aiBaseUrl = '',
    this.aiApiKey = '',
    this.aiModel = 'gemini-2.5-flash',
  });

  bool get isAiConfigured =>
      aiApiKey.trim().isNotEmpty &&
      aiModel.trim().isNotEmpty &&
      (aiProvider != 'custom' || aiBaseUrl.trim().isNotEmpty);

  AppSettings copyWith({
    String? themeMode,
    bool? dynamicColor,
    String? language,
    bool? hideSubmitted,
    bool? showAllCourses,
    bool? notifyAssignments,
    bool? notifyGrades,
    bool? notifyTimetable,
    int? reminderOffsetMinutes,
    bool? bgSyncEnabled,
    int? bgSyncIntervalHours,
    String? timetableGroup,
    bool? timetableGroupAutoDetected,
    int? lastSyncAt,
    bool? hapticsEnabled,
    bool? diagnosticsEnabled,
    String? aiProvider,
    String? aiBaseUrl,
    String? aiApiKey,
    String? aiModel,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      dynamicColor: dynamicColor ?? this.dynamicColor,
      language: language ?? this.language,
      hideSubmitted: hideSubmitted ?? this.hideSubmitted,
      showAllCourses: showAllCourses ?? this.showAllCourses,
      notifyAssignments: notifyAssignments ?? this.notifyAssignments,
      notifyGrades: notifyGrades ?? this.notifyGrades,
      notifyTimetable: notifyTimetable ?? this.notifyTimetable,
      reminderOffsetMinutes:
          reminderOffsetMinutes ?? this.reminderOffsetMinutes,
      bgSyncEnabled: bgSyncEnabled ?? this.bgSyncEnabled,
      bgSyncIntervalHours: bgSyncIntervalHours ?? this.bgSyncIntervalHours,
      timetableGroup: timetableGroup ?? this.timetableGroup,
      timetableGroupAutoDetected:
          timetableGroupAutoDetected ?? this.timetableGroupAutoDetected,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      diagnosticsEnabled: diagnosticsEnabled ?? this.diagnosticsEnabled,
      aiProvider: aiProvider ?? this.aiProvider,
      aiBaseUrl: aiBaseUrl ?? this.aiBaseUrl,
      aiApiKey: aiApiKey ?? this.aiApiKey,
      aiModel: aiModel ?? this.aiModel,
    );
  }
}

class SyllabusWeight {
  final String courseId;
  final String label;
  final double percentage;

  const SyllabusWeight({
    required this.courseId,
    required this.label,
    required this.percentage,
  });

  Map<String, dynamic> toMap() => {
        'course_id': courseId,
        'label': label,
        'percentage': percentage,
      };

  factory SyllabusWeight.fromMap(Map<String, dynamic> m) => SyllabusWeight(
        courseId: (m['course_id'] as String?) ?? '',
        label: (m['label'] as String?) ?? '',
        percentage: (m['percentage'] as num?)?.toDouble() ?? 0.0,
      );
}

class AppReleaseInfo {
  final String version;
  final String tagName;
  final String title;
  final String notes;
  final String htmlUrl;
  final String? apkUrl;
  final String? apkName;
  final int apkSize;

  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.notes,
    required this.htmlUrl,
    this.apkUrl,
    this.apkName,
    this.apkSize = 0,
  });
}

/// Matched timetable summary for a course (from EduPage entries).
class CourseScheduleInfo {
  final String teacher;
  final List<String> classrooms;
  final List<String> daySummaries;

  const CourseScheduleInfo({
    this.teacher = '',
    this.classrooms = const [],
    this.daySummaries = const [],
  });

  String get classroomSummary => classrooms.join(', ');
  String get scheduleSummary => daySummaries.join(', ');
}

class LocalDraft {
  final int? id;
  final String assignmentId;
  final int? assignId;
  final String courseId;
  final String courseName;
  final String assignmentName;
  final String due;
  final int dueTimestamp;
  final String? assignmentUrl;
  final String filePath;
  final String fileName;
  final int fileSize;
  final int updatedAt;

  const LocalDraft({
    this.id,
    required this.assignmentId,
    this.assignId,
    required this.courseId,
    required this.courseName,
    required this.assignmentName,
    this.due = '',
    this.dueTimestamp = 0,
    this.assignmentUrl,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    required this.updatedAt,
  });

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'assignment_id': assignmentId,
        'assign_id': assignId,
        'course_id': courseId,
        'course_name': courseName,
        'assignment_name': assignmentName,
        'due': due,
        'due_timestamp': dueTimestamp,
        'assignment_url': assignmentUrl,
        'file_path': filePath,
        'file_name': fileName,
        'file_size': fileSize,
        'updated_at': updatedAt,
      };

  factory LocalDraft.fromMap(Map<String, Object?> m) => LocalDraft(
        id: m['id'] as int?,
        assignmentId: (m['assignment_id'] as String?) ?? '',
        assignId: m['assign_id'] as int?,
        courseId: (m['course_id'] as String?) ?? '',
        courseName: (m['course_name'] as String?) ?? '',
        assignmentName: (m['assignment_name'] as String?) ?? '',
        due: (m['due'] as String?) ?? '',
        dueTimestamp: (m['due_timestamp'] as int?) ?? 0,
        assignmentUrl: m['assignment_url'] as String?,
        filePath: (m['file_path'] as String?) ?? '',
        fileName: (m['file_name'] as String?) ?? '',
        fileSize: (m['file_size'] as int?) ?? 0,
        updatedAt: (m['updated_at'] as int?) ?? 0,
      );
}

class EclassPrivateFile {
  final String id;
  final String filename;
  final String filepath;
  final int size;
  final String sizeText;
  final int modifiedAt;
  final String modifiedText;
  final String downloadUrl;
  final String fileType;

  const EclassPrivateFile({
    required this.id,
    required this.filename,
    this.filepath = '/',
    this.size = 0,
    this.sizeText = '',
    this.modifiedAt = 0,
    this.modifiedText = '',
    this.downloadUrl = '',
    this.fileType = '',
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'filename': filename,
        'filepath': filepath,
        'size': size,
        'size_text': sizeText,
        'modified_at': modifiedAt,
        'modified_text': modifiedText,
        'download_url': downloadUrl,
        'file_type': fileType,
      };

  factory EclassPrivateFile.fromMap(Map<String, Object?> m) =>
      EclassPrivateFile(
        id: (m['id'] as String?) ?? '',
        filename: (m['filename'] as String?) ?? '',
        filepath: (m['filepath'] as String?) ?? '/',
        size: (m['size'] as int?) ?? 0,
        sizeText: (m['size_text'] as String?) ?? '',
        modifiedAt: (m['modified_at'] as int?) ?? 0,
        modifiedText: (m['modified_text'] as String?) ?? '',
        downloadUrl: (m['download_url'] as String?) ?? '',
        fileType: (m['file_type'] as String?) ?? '',
      );
}

enum AiCheckMode { requirements, bugsAndEdgeCases, strictGrader }

class AiRequirementItem {
  final String requirement;

  /// One of `'met'`, `'partial'`, or `'missing'`.
  final String status;
  final String note;

  const AiRequirementItem({
    required this.requirement,
    required this.status,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
        'requirement': requirement,
        'status': status,
        'note': note,
      };

  factory AiRequirementItem.fromJson(Map<String, dynamic> json) {
    final rawStatus =
        (json['status'] ?? 'partial').toString().trim().toLowerCase();
    final normalizedStatus = switch (rawStatus) {
      'met' || 'done' || 'ok' || 'pass' || 'passed' => 'met',
      'missing' || 'fail' || 'failed' || 'not_met' => 'missing',
      _ => 'partial',
    };
    return AiRequirementItem(
      requirement: (json['requirement'] ?? '').toString().trim(),
      status: normalizedStatus,
      note: (json['note'] ?? '').toString().trim(),
    );
  }
}

class AiReviewResult {
  final String assignmentId;
  final AiCheckMode mode;
  final String provider;
  final String model;
  final String summary;
  final String? estimatedScore;
  final List<AiRequirementItem> checklist;
  final List<String> issues;
  final List<String> suggestions;
  final String rawMarkdown;
  final int createdAt;

  const AiReviewResult({
    required this.assignmentId,
    required this.mode,
    required this.provider,
    required this.model,
    this.summary = '',
    this.estimatedScore,
    this.checklist = const [],
    this.issues = const [],
    this.suggestions = const [],
    this.rawMarkdown = '',
    this.createdAt = 0,
  });

  bool get hasStructuredContent =>
      summary.isNotEmpty ||
      checklist.isNotEmpty ||
      issues.isNotEmpty ||
      suggestions.isNotEmpty;

  Map<String, Object?> toMap() => {
        'assignment_id': assignmentId,
        'mode': mode.name,
        'provider': provider,
        'model': model,
        'summary': summary,
        'estimated_score': estimatedScore,
        'checklist_json': jsonEncode(checklist.map((e) => e.toJson()).toList()),
        'issues_json': jsonEncode(issues),
        'suggestions_json': jsonEncode(suggestions),
        'raw_markdown': rawMarkdown,
        'created_at': createdAt,
      };

  factory AiReviewResult.fromMap(Map<String, Object?> m) {
    List<AiRequirementItem> parseChecklist(String? raw) {
      if (raw == null || raw.isEmpty) return const [];
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded
            .whereType<Map>()
            .map((e) => AiRequirementItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        return const [];
      }
    }

    List<String> parseStrings(String? raw) {
      if (raw == null || raw.isEmpty) return const [];
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        return decoded.map((e) => e.toString()).toList();
      } catch (_) {
        return const [];
      }
    }

    final modeName = (m['mode'] as String?) ?? AiCheckMode.requirements.name;
    final parsedMode = AiCheckMode.values.firstWhere(
      (v) => v.name == modeName,
      orElse: () => AiCheckMode.requirements,
    );

    return AiReviewResult(
      assignmentId: (m['assignment_id'] as String?) ?? '',
      mode: parsedMode,
      provider: (m['provider'] as String?) ?? '',
      model: (m['model'] as String?) ?? '',
      summary: (m['summary'] as String?) ?? '',
      estimatedScore: m['estimated_score'] as String?,
      checklist: parseChecklist(m['checklist_json'] as String?),
      issues: parseStrings(m['issues_json'] as String?),
      suggestions: parseStrings(m['suggestions_json'] as String?),
      rawMarkdown: (m['raw_markdown'] as String?) ?? '',
      createdAt: (m['created_at'] as int?) ?? 0,
    );
  }

  String toShareableText() {
    final buf = StringBuffer();
    buf.writeln('AI Homework Check ($provider / $model)');
    if (estimatedScore != null && estimatedScore!.trim().isNotEmpty) {
      buf.writeln('Estimated score: ${estimatedScore!.trim()}');
    }
    if (summary.trim().isNotEmpty) {
      buf.writeln('\nSummary:\n${summary.trim()}');
    }
    if (checklist.isNotEmpty) {
      buf.writeln('\nRequirements Checklist:');
      for (final item in checklist) {
        final tag = item.status.toUpperCase();
        buf.write('- [$tag] ${item.requirement}');
        if (item.note.isNotEmpty) buf.write(' — ${item.note}');
        buf.writeln();
      }
    }
    if (issues.isNotEmpty) {
      buf.writeln('\nIssues / Gaps:');
      for (final issue in issues) {
        buf.writeln('- $issue');
      }
    }
    if (suggestions.isNotEmpty) {
      buf.writeln('\nSuggestions:');
      for (final sug in suggestions) {
        buf.writeln('- $sug');
      }
    }
    if (!hasStructuredContent && rawMarkdown.trim().isNotEmpty) {
      buf.writeln('\n${rawMarkdown.trim()}');
    }
    return buf.toString().trim();
  }
}
