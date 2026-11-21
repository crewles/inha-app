import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';

/// Local SQLite database storing all user data, credentials, and offline cache
/// strictly on the user's Android device (also read by native EclassSyncWorker).
class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  AppDatabase._internal();

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final fullPath = p.join(dbPath, 'inha_app.db');
    return openDatabase(
      fullPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE credentials (
            id INTEGER PRIMARY KEY CHECK (id = 1),
            student_id TEXT NOT NULL,
            eclass_password TEXT NOT NULL,
            ins_password TEXT,
            eclass_token TEXT,
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE settings (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            category INTEGER NOT NULL DEFAULT 0,
            is_current INTEGER NOT NULL DEFAULT 1,
            overview_grade TEXT,
            professor TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE assignments (
            id TEXT PRIMARY KEY,
            assign_id INTEGER,
            course_id TEXT NOT NULL,
            course_name TEXT NOT NULL,
            name TEXT NOT NULL,
            due TEXT NOT NULL,
            due_timestamp INTEGER NOT NULL DEFAULT 0,
            status TEXT NOT NULL,
            grade TEXT,
            grade_max TEXT,
            url TEXT,
            files_json TEXT NOT NULL,
            intro TEXT NOT NULL DEFAULT '',
            max_points TEXT,
            cutoff_timestamp INTEGER NOT NULL DEFAULT 0,
            submitted_files_json TEXT NOT NULL DEFAULT '[]',
            feedback_comment TEXT NOT NULL DEFAULT '',
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE syllabus_weights (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id TEXT NOT NULL,
            label TEXT NOT NULL,
            percentage REAL NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE hidden_assignments (
            assignment_id TEXT PRIMARY KEY,
            hidden_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE grades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id TEXT NOT NULL,
            name TEXT NOT NULL,
            value TEXT NOT NULL,
            category TEXT NOT NULL DEFAULT '',
            weight TEXT NOT NULL DEFAULT '',
            range_str TEXT NOT NULL DEFAULT '',
            percentage TEXT NOT NULL DEFAULT '',
            item_type TEXT NOT NULL DEFAULT 'item'
          )
        ''');

        await db.execute('''
          CREATE TABLE attendance (
            course_id TEXT PRIMARY KEY,
            attendance_count INTEGER NOT NULL,
            absence_count INTEGER NOT NULL,
            late_count INTEGER NOT NULL,
            others_count INTEGER NOT NULL,
            records_json TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE course_files (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_id TEXT NOT NULL,
            name TEXT NOT NULL,
            url TEXT NOT NULL,
            size INTEGER NOT NULL,
            local_path TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE ins_grades (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            course_number TEXT NOT NULL,
            title TEXT NOT NULL,
            credit TEXT NOT NULL,
            grade TEXT NOT NULL,
            course_type TEXT NOT NULL,
            semester TEXT NOT NULL,
            yearterm TEXT NOT NULL,
            professor TEXT NOT NULL,
            class_number TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE ins_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE timetable_entries (
            card_id TEXT PRIMARY KEY,
            lesson_id TEXT NOT NULL,
            days_json TEXT NOT NULL,
            period_start TEXT NOT NULL,
            period_end TEXT NOT NULL,
            subject TEXT NOT NULL,
            teachers_json TEXT NOT NULL,
            classes_json TEXT NOT NULL,
            classrooms_json TEXT NOT NULL,
            duration_periods INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE timetable_meta (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          const alters = [
            "ALTER TABLE courses ADD COLUMN professor TEXT NOT NULL DEFAULT ''",
            "ALTER TABLE grades ADD COLUMN category TEXT NOT NULL DEFAULT ''",
            "ALTER TABLE grades ADD COLUMN weight TEXT NOT NULL DEFAULT ''",
            "ALTER TABLE grades ADD COLUMN range_str TEXT NOT NULL DEFAULT ''",
            "ALTER TABLE grades ADD COLUMN percentage TEXT NOT NULL DEFAULT ''",
            "ALTER TABLE grades ADD COLUMN item_type TEXT NOT NULL DEFAULT 'item'",
          ];
          for (final sql in alters) {
            try {
              await db.execute(sql);
            } catch (_) {
              // Column already exists on partial/retried upgrades.
            }
          }
        }
        if (oldVersion < 3) {
          const altersV3 = [
            "ALTER TABLE assignments ADD COLUMN intro TEXT NOT NULL DEFAULT ''",
            "ALTER TABLE assignments ADD COLUMN max_points TEXT",
            "ALTER TABLE assignments ADD COLUMN cutoff_timestamp INTEGER NOT NULL DEFAULT 0",
            "ALTER TABLE assignments ADD COLUMN submitted_files_json TEXT NOT NULL DEFAULT '[]'",
            "ALTER TABLE assignments ADD COLUMN feedback_comment TEXT NOT NULL DEFAULT ''",
          ];
          for (final sql in altersV3) {
            try {
              await db.execute(sql);
            } catch (_) {}
          }
          await db.execute('''
            CREATE TABLE IF NOT EXISTS syllabus_weights (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              course_id TEXT NOT NULL,
              label TEXT NOT NULL,
              percentage REAL NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS hidden_assignments (
              assignment_id TEXT PRIMARY KEY,
              hidden_at INTEGER NOT NULL
            )
          ''');
        }
      },
    );
  }

  // ── Credentials ─────────────────────────────────────────────

  Future<UserCredentials?> getCredentials() async {
    final db = await database;
    final rows = await db.query('credentials', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return UserCredentials(
      studentId: r['student_id'] as String,
      eclassPassword: r['eclass_password'] as String,
      insPassword: r['ins_password'] as String?,
      eclassToken: r['eclass_token'] as String?,
    );
  }

  Future<void> saveCredentials(UserCredentials creds) async {
    final db = await database;
    await db.insert(
      'credentials',
      {
        'id': 1,
        'student_id': creds.studentId,
        'eclass_password': creds.eclassPassword,
        'ins_password': creds.insPassword,
        'eclass_token': creds.eclassToken,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('credentials');
      await txn.delete('courses');
      await txn.delete('assignments');
      await txn.delete('grades');
      await txn.delete('attendance');
      await txn.delete('course_files');
      await txn.delete('ins_grades');
      await txn.delete('ins_meta');
      await txn.delete('timetable_entries');
      await txn.delete('timetable_meta');
      await txn.delete('syllabus_weights');
      await txn.delete('hidden_assignments');
    });
  }

  Future<void> clearCacheOnly() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('courses');
      await txn.delete('assignments');
      await txn.delete('grades');
      await txn.delete('attendance');
      await txn.delete('course_files');
      await txn.delete('ins_grades');
      await txn.delete('ins_meta');
      await txn.delete('timetable_entries');
      await txn.delete('timetable_meta');
      await txn.delete('syllabus_weights');
    });
  }

  // ── Settings ────────────────────────────────────────────────

  Future<AppSettings> getSettings() async {
    final db = await database;
    final rows = await db.query('settings');
    final map = {for (final r in rows) r['key'] as String: r['value'] as String};
    return AppSettings(
      themeMode: map['theme_mode'] ?? 'system',
      dynamicColor: (map['dynamic_color'] ?? 'true') == 'true',
      language: map['language'] ?? 'ru',
      hideSubmitted: (map['hide_submitted'] ?? 'false') == 'true',
      showAllCourses: (map['show_all_courses'] ?? 'false') == 'true',
      notifyAssignments: (map['notify_assignments'] ?? 'true') == 'true',
      notifyGrades: (map['notify_grades'] ?? 'true') == 'true',
      notifyTimetable: (map['notify_timetable'] ?? 'true') == 'true',
      reminderOffsetMinutes:
          int.tryParse(map['reminder_offset_minutes'] ?? '15') ?? 15,
      bgSyncEnabled: (map['bg_sync_enabled'] ?? 'false') == 'true',
      bgSyncIntervalHours:
          int.tryParse(map['bg_sync_interval_hours'] ?? '2') ?? 2,
      timetableGroup: map['timetable_group'] ?? '',
      lastSyncAt: int.tryParse(map['last_sync_at'] ?? '0') ?? 0,
      hapticsEnabled: (map['haptics_enabled'] ?? 'true') == 'true',
    );
  }

  Future<void> saveSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ── Courses ─────────────────────────────────────────────────

  Future<List<Course>> getCourses() async {
    final db = await database;
    final rows = await db.query('courses', orderBy: 'is_current DESC, name ASC');
    return rows.map(Course.fromMap).toList();
  }

  Future<void> saveCourses(List<Course> courses) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('courses');
      for (final c in courses) {
        await txn.insert('courses', c.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ── Assignments ─────────────────────────────────────────────

  Future<List<Assignment>> getAssignments({String? courseId}) async {
    final db = await database;
    final rows = courseId == null
        ? await db.query('assignments', orderBy: 'due_timestamp ASC')
        : await db.query('assignments',
            where: 'course_id = ?',
            whereArgs: [courseId],
            orderBy: 'due_timestamp ASC');
    return rows.map(Assignment.fromMap).toList();
  }

  Future<void> saveCourseAssignments(
      String courseId, List<Assignment> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('assignments',
          where: 'course_id = ?', whereArgs: [courseId]);
      for (final item in items) {
        await txn.insert('assignments', item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> saveAllAssignments(List<Assignment> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('assignments');
      for (final item in items) {
        await txn.insert('assignments', item.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  // ── Grades ──────────────────────────────────────────────────

  Future<List<GradeItem>> getGrades(String courseId) async {
    final db = await database;
    final rows = await db.query('grades',
        where: 'course_id = ?', whereArgs: [courseId]);
    return rows.map(GradeItem.fromMap).toList();
  }

  Future<void> saveGrades(String courseId, List<GradeItem> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('grades', where: 'course_id = ?', whereArgs: [courseId]);
      for (final item in items) {
        await txn.insert('grades', item.toMap());
      }
    });
  }

  // ── Attendance ──────────────────────────────────────────────

  Future<AttendanceData?> getAttendance(String courseId) async {
    final db = await database;
    final rows = await db.query('attendance',
        where: 'course_id = ?', whereArgs: [courseId], limit: 1);
    if (rows.isEmpty) return null;
    return AttendanceData.fromMap(rows.first);
  }

  Future<void> saveAttendance(AttendanceData data) async {
    final db = await database;
    await db.insert('attendance', data.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Course Files ────────────────────────────────────────────

  Future<List<CourseFile>> getCourseFiles(String courseId) async {
    final db = await database;
    final rows = await db.query('course_files',
        where: 'course_id = ?', whereArgs: [courseId]);
    return rows.map(CourseFile.fromMap).toList();
  }

  Future<void> saveCourseFiles(String courseId, List<CourseFile> files) async {
    final db = await database;
    final existing = await getCourseFiles(courseId);
    final localMap = {
      for (final f in existing)
        if (f.localPath != null) f.url: f.localPath
    };

    await db.transaction((txn) async {
      await txn.delete('course_files',
          where: 'course_id = ?', whereArgs: [courseId]);
      for (final f in files) {
        final merged = f.localPath != null
            ? f
            : f.copyWith(localPath: localMap[f.url]);
        await txn.insert('course_files', merged.toMap());
      }
    });
  }

  Future<void> updateFileLocalPath(String url, String localPath) async {
    final db = await database;
    await db.update(
      'course_files',
      {'local_path': localPath},
      where: 'url = ?',
      whereArgs: [url],
    );
  }

  // ── INS Grades & Transcript ─────────────────────────────────

  Future<InsGradeData?> getInsData() async {
    final db = await database;
    final courseRows = await db.query('ins_grades');
    final metaRows = await db.query('ins_meta');
    if (courseRows.isEmpty && metaRows.isEmpty) return null;

    final meta = {
      for (final r in metaRows) r['key'] as String: r['value'] as String
    };
    final gpaInfo = Map<String, String>.from(
        jsonDecode(meta['gpa_info'] ?? '{}') as Map<String, dynamic>);
    final studentInfo = Map<String, String>.from(
        jsonDecode(meta['student_info'] ?? '{}') as Map<String, dynamic>);
    final updatedAt = int.tryParse(meta['updated_at'] ?? '0') ?? 0;

    return InsGradeData(
      courses: courseRows.map(InsCourseGrade.fromMap).toList(),
      gpaInfo: gpaInfo,
      studentInfo: studentInfo,
      updatedAt: updatedAt,
    );
  }

  Future<void> saveInsData(InsGradeData data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('ins_grades');
      for (final c in data.courses) {
        await txn.insert('ins_grades', c.toMap());
      }
      await txn.insert(
        'ins_meta',
        {'key': 'gpa_info', 'value': jsonEncode(data.gpaInfo)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'ins_meta',
        {'key': 'student_info', 'value': jsonEncode(data.studentInfo)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'ins_meta',
        {
          'key': 'updated_at',
          'value': DateTime.now().millisecondsSinceEpoch.toString()
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  // ── Timetable ───────────────────────────────────────────────

  Future<List<ScheduleEntry>> getTimetableEntries() async {
    final db = await database;
    final rows = await db.query('timetable_entries');
    return rows.map(ScheduleEntry.fromMap).toList();
  }

  Future<void> saveTimetableEntries(
      List<ScheduleEntry> entries, String ttNum, String label) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('timetable_entries');
      for (final e in entries) {
        await txn.insert('timetable_entries', e.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await txn.insert(
        'timetable_meta',
        {'key': 'tt_num', 'value': ttNum},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'timetable_meta',
        {'key': 'label', 'value': label},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'timetable_meta',
        {
          'key': 'updated_at',
          'value': DateTime.now().millisecondsSinceEpoch.toString()
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<Map<String, String>> getTimetableMeta() async {
    final db = await database;
    final rows = await db.query('timetable_meta');
    return {for (final r in rows) r['key'] as String: r['value'] as String};
  }

  // ── Syllabus Weights ────────────────────────────────────────

  Future<List<SyllabusWeight>> getSyllabusWeights(String courseId) async {
    final db = await database;
    final rows = await db.query('syllabus_weights',
        where: 'course_id = ?', whereArgs: [courseId]);
    return rows.map(SyllabusWeight.fromMap).toList();
  }

  Future<void> saveSyllabusWeights(
      String courseId, List<SyllabusWeight> items) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('syllabus_weights',
          where: 'course_id = ?', whereArgs: [courseId]);
      for (final item in items) {
        await txn.insert('syllabus_weights', item.toMap());
      }
    });
  }

  // ── Hidden Assignments ──────────────────────────────────────

  Future<Set<String>> getHiddenAssignmentIds() async {
    final db = await database;
    final rows = await db.query('hidden_assignments', columns: ['assignment_id']);
    return rows.map((r) => r['assignment_id'] as String).toSet();
  }

  Future<void> setAssignmentHidden(String assignmentId, bool hidden) async {
    final db = await database;
    if (hidden) {
      await db.insert(
        'hidden_assignments',
        {
          'assignment_id': assignmentId,
          'hidden_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      await db.delete(
        'hidden_assignments',
        where: 'assignment_id = ?',
        whereArgs: [assignmentId],
      );
    }
  }
}
