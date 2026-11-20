import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/eclass_service.dart';
import '../../state/app_state.dart';

class CourseDetailScreen extends StatefulWidget {
  final Course course;
  const CourseDetailScreen({super.key, required this.course});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _loading = false;
  final Set<String> _downloadingUrls = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      await app.loadCourseDetailsFromCache(widget.course.id);
      _refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await context.read<AppState>().syncCourseDetails(widget.course);
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openSyllabus() async {
    final uri = Uri.parse(EclassService.syllabusUrl(widget.course.id));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _downloadAndOpen(CourseFile file) async {
    final app = context.read<AppState>();
    if (file.localPath != null && await File(file.localPath!).exists()) {
      await OpenFilex.open(file.localPath!);
      return;
    }
    setState(() => _downloadingUrls.add(file.url));
    try {
      final path = await app.downloadCourseFile(file);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingUrls.remove(file.url));
    }
  }

  Future<void> _downloadAttachment(AssignmentFile att) async {
    setState(() => _downloadingUrls.add(att.link));
    try {
      final path = await context
          .read<AppState>()
          .eclass
          .downloadFile(att.link, att.name);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingUrls.remove(att.link));
    }
  }

  Future<void> _uploadToAssignment() async {
    final app = context.read<AppState>();
    final s = app.s;

    try {
      final openList = await app.eclass.getOpenAssignments(widget.course.id);
      if (!mounted) return;
      if (openList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.noAssignments)),
        );
        return;
      }

      final chosen = await showModalBottomSheet<OpenAssignment>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(s.uploadFile,
                style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            ...openList.map((oa) => ListTile(
                  leading: const Icon(Icons.upload_file_rounded),
                  title: Text(oa.name),
                  onTap: () => Navigator.pop(ctx, oa),
                )),
          ],
        ),
      );
      if (chosen == null || !mounted) return;

      final picked = await FilePicker.platform.pickFiles();
      if (picked == null || picked.files.single.path == null) return;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.uploading)),
      );

      await app.eclass.uploadSubmission(
        chosen.id,
        picked.files.single.path!,
        picked.files.single.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.uploadSuccess)),
        );
        _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;

    final assignments = app.allAssignments
        .where((a) => a.courseId == widget.course.id)
        .toList();
    final grades = app.gradesByCourse[widget.course.id] ?? [];
    final attendance = app.attendanceByCourse[widget.course.id];
    final files = app.filesByCourse[widget.course.id] ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.name),
        actions: [
          IconButton(
            tooltip: s.openSyllabus,
            icon: const Icon(Icons.description_outlined),
            onPressed: _openSyllabus,
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: s.refresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _refresh,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: s.tabAssignments, icon: const Icon(Icons.assignment_outlined)),
            Tab(text: s.tabGrades, icon: const Icon(Icons.grade_outlined)),
            Tab(text: s.tabAttendance, icon: const Icon(Icons.event_available_outlined)),
            Tab(text: s.tabFiles, icon: const Icon(Icons.folder_outlined)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadToAssignment,
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(s.uploadFile),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAssignmentsTab(context, assignments, cs, s),
          _buildGradesTab(context, grades, cs, s),
          _buildAttendanceTab(context, attendance, cs, s),
          _buildFilesTab(context, files, cs, s),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab(
    BuildContext context,
    List<Assignment> items,
    ColorScheme cs,
    dynamic s,
  ) {
    if (items.isEmpty) {
      return Center(child: Text(s.noAssignments));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final a = items[i];
          return Card.filled(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          a.name,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: a.isSubmitted
                            ? cs.secondaryContainer
                            : cs.errorContainer,
                        label: Text(
                          a.isSubmitted ? s.submitted : s.notSubmitted,
                          style: TextStyle(
                            color: a.isSubmitted
                                ? cs.onSecondaryContainer
                                : cs.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (a.due.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${s.dueLabel}: ${a.due}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (a.gradeDisplay != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${s.tabGrades}: ${a.gradeDisplay}',
                        style: TextStyle(
                          color: cs.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  if (a.files.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: a.files.map((f) {
                        final busy = _downloadingUrls.contains(f.link);
                        return ActionChip(
                          avatar: busy
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2),
                                )
                              : const Icon(Icons.download_rounded, size: 16),
                          label: Text(f.name, overflow: TextOverflow.ellipsis),
                          onPressed: busy ? null : () => _downloadAttachment(f),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGradesTab(
    BuildContext context,
    List<GradeItem> grades,
    ColorScheme cs,
    dynamic s,
  ) {
    if (grades.isEmpty) {
      return Center(child: Text(s.noGrades));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: grades.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final g = grades[i];
          return Card.outlined(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              title: Text(g.name),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  g.value,
                  style: TextStyle(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttendanceTab(
    BuildContext context,
    AttendanceData? att,
    ColorScheme cs,
    dynamic s,
  ) {
    if (att == null) {
      return Center(child: Text(s.attendanceUnavailable));
    }
    final pct = att.percentage;
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          Card.filled(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    '${pct.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.primary,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: (pct / 100.0).clamp(0.0, 1.0),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _statPill(context, s.present, '${att.attendanceCount}',
                          cs.primaryContainer, cs.onPrimaryContainer),
                      _statPill(context, s.absent, '${att.absenceCount}',
                          cs.errorContainer, cs.onErrorContainer),
                      _statPill(context, s.lateLabel, '${att.lateCount}',
                          cs.tertiaryContainer, cs.onTertiaryContainer),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(s.recentSessions,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...att.records.reversed.map((r) {
            IconData icon;
            Color color;
            switch (r.statusType) {
              case 'present':
                icon = Icons.check_circle_rounded;
                color = Colors.green;
                break;
              case 'absent':
                icon = Icons.cancel_rounded;
                color = cs.error;
                break;
              case 'late':
                icon = Icons.access_time_filled_rounded;
                color = Colors.orange;
                break;
              default:
                icon = Icons.help_outline_rounded;
                color = cs.onSurfaceVariant;
            }
            return ListTile(
              leading: Icon(icon, color: color),
              title: Text(r.date),
              subtitle: r.className.isNotEmpty ? Text(r.className) : null,
            );
          }),
        ],
      ),
    );
  }

  Widget _statPill(BuildContext context, String label, String val, Color bg,
      Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(val,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold, color: fg)),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: fg)),
        ],
      ),
    );
  }

  Widget _buildFilesTab(
    BuildContext context,
    List<CourseFile> files,
    ColorScheme cs,
    dynamic s,
  ) {
    if (files.isEmpty) {
      return Center(child: Text(s.noFiles));
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final f = files[i];
          final busy = _downloadingUrls.contains(f.url);
          final isCached = f.localPath != null;
          return Card.outlined(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: Icon(
                isCached ? Icons.offline_pin_rounded : Icons.insert_drive_file_outlined,
                color: isCached ? cs.primary : cs.onSurfaceVariant,
              ),
              title: Text(f.name),
              subtitle: f.size > 0 ? Text(_formatSize(f.size)) : null,
              trailing: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: Icon(isCached
                          ? Icons.open_in_new_rounded
                          : Icons.download_rounded),
                      onPressed: () => _downloadAndOpen(f),
                    ),
              onTap: busy ? null : () => _downloadAndOpen(f),
            ),
          );
        },
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
