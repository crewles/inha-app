import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/eclass_service.dart';
import '../../state/app_state.dart';
import '../widgets/expressive_widgets.dart';

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
  final Set<int> _uploadingAssignIds = {};

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

  Future<void> _submitSingleAssignment(Assignment a) async {
    final assignId = a.assignId;
    if (assignId == null) return;
    final app = context.read<AppState>();
    final s = app.s;

    try {
      final picked = await FilePicker.platform.pickFiles();
      if (picked == null || picked.files.single.path == null) return;
      if (!mounted) return;

      setState(() => _uploadingAssignIds.add(assignId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.uploading)),
      );

      await app.eclass.uploadSubmission(
        assignId,
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
    } finally {
      if (mounted) setState(() => _uploadingAssignIds.remove(assignId));
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
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            ...openList.map((oa) => ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
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
    final tt = Theme.of(context).textTheme;

    final assignments = app.allAssignments
        .where((a) => a.courseId == widget.course.id)
        .toList();
    final grades = app.gradesByCourse[widget.course.id] ?? [];
    final attendance = app.attendanceByCourse[widget.course.id];
    final files = app.filesByCourse[widget.course.id] ?? [];

    final tabs = [
      s.tabAssignments,
      s.tabGrades,
      s.tabAttendance,
      s.tabFiles,
    ];

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.courseDetailTitle,
        overline: s.portalHeader,
        showBack: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadToAssignment,
        shape: const StadiumBorder(),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        icon: const Icon(Icons.upload_file_rounded),
        label: Text(
          s.submitWork,
          style: tt.labelLarge?.copyWith(
            color: cs.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              ExpressivePill(
                                label: 'ID: ${widget.course.id}',
                                backgroundColor: cs.primaryFixed,
                                foregroundColor: cs.onPrimaryFixed,
                                fontWeight: FontWeight.w700,
                              ),
                              if (!widget.course.isCurrent)
                                ExpressivePill(
                                  label: s.archiveTag,
                                  backgroundColor: cs.surfaceContainerHigh,
                                  foregroundColor: cs.onSurfaceVariant,
                                ),
                              if (widget.course.overviewGrade != null &&
                                  widget.course.overviewGrade!.isNotEmpty)
                                ExpressivePill(
                                  label: widget.course.overviewGrade!,
                                  backgroundColor: cs.surfaceContainerHigh,
                                  foregroundColor: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.course.name,
                            style: tt.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ExpressivePill(
                          icon: Icons.description_outlined,
                          label: s.syllabus,
                          backgroundColor: cs.secondaryFixed,
                          foregroundColor: cs.onSecondaryFixed,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 9),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          onTap: _openSyllabus,
                        ),
                        const SizedBox(width: 6),
                        CircleActionButton(
                          icon: Icons.refresh_rounded,
                          tooltip: s.refresh,
                          loading: _loading,
                          backgroundColor: cs.surfaceContainer,
                          onPressed: _refresh,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AnimatedBuilder(
                  animation: _tabController,
                  builder: (context, _) {
                    return Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                  minWidth: constraints.maxWidth),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: List.generate(tabs.length, (i) {
                                  final selected = _tabController.index == i;
                                  return Material(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(999),
                                    clipBehavior: Clip.antiAlias,
                                    child: InkWell(
                                      onTap: () => _tabController.animateTo(i),
                                      borderRadius: BorderRadius.circular(999),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 180),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? cs.primary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          tabs[i],
                                          style: tt.labelMedium?.copyWith(
                                            color: selected
                                                ? cs.onPrimary
                                                : cs.onSurfaceVariant,
                                            fontWeight: selected
                                                ? FontWeight.w700
                                                : FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAssignmentsTab(context, assignments, cs, tt, s),
                _buildGradesTab(context, grades, cs, tt, s),
                _buildAttendanceTab(context, attendance, cs, tt, s),
                _buildFilesTab(context, files, cs, tt, s),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentsTab(
    BuildContext context,
    List<Assignment> items,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          s.noAssignments,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final a = items[i];
          final uploading =
              a.assignId != null && _uploadingAssignIds.contains(a.assignId);

          return ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ExpressivePill(
                      label: a.isSubmitted ? s.submitted : s.notSubmitted,
                      backgroundColor: a.isSubmitted
                          ? cs.secondaryFixed
                          : cs.tertiaryFixed,
                      foregroundColor: a.isSubmitted
                          ? cs.onSecondaryFixed
                          : cs.onTertiaryFixed,
                      fontWeight: FontWeight.w700,
                    ),
                    const Spacer(),
                    if (a.gradeDisplay != null)
                      ExpressivePill(
                        label: a.gradeDisplay!,
                        backgroundColor: cs.primaryFixed,
                        foregroundColor: cs.onPrimaryFixed,
                        fontWeight: FontWeight.w700,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  a.name,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (a.due.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.alarm_rounded,
                        size: 16,
                        color: a.isSubmitted ? cs.onSurfaceVariant : cs.error,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${s.dueLabel}: ${a.due}',
                          style: tt.labelMedium?.copyWith(
                            color:
                                a.isSubmitted ? cs.onSurfaceVariant : cs.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (a.files.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  for (final f in a.files) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            iconForFileName(f.name),
                            size: 20,
                            color: colorForFileName(f.name, cs),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (f.size > 0)
                                  Text(
                                    formatFileSize(f.size),
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          CircleActionButton(
                            icon: Icons.download_rounded,
                            loading: _downloadingUrls.contains(f.link),
                            backgroundColor: cs.surfaceContainerLowest,
                            iconColor: cs.primary,
                            onPressed: () => _downloadAttachment(f),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                if (!a.isSubmitted && a.assignId != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ExpressivePill(
                      icon: uploading
                          ? Icons.hourglass_top_rounded
                          : Icons.upload_file_rounded,
                      label: uploading ? s.uploading : s.submitSolution,
                      backgroundColor: cs.primaryFixed,
                      foregroundColor: cs.onPrimaryFixed,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      fontWeight: FontWeight.w700,
                      onTap: uploading ? null : () => _submitSingleAssignment(a),
                    ),
                  ),
                ],
              ],
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
    TextTheme tt,
    dynamic s,
  ) {
    if (grades.isEmpty) {
      return Center(
        child: Text(
          s.noGrades,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        itemCount: grades.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final g = grades[i];
          return ExpressiveCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SquircleIcon(
                  size: 44,
                  radius: 14,
                  iconSize: 22,
                  icon: Icons.grade_rounded,
                  backgroundColor: cs.primaryFixed,
                  iconColor: cs.onPrimaryFixed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    g.name,
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                ExpressivePill(
                  label: g.value,
                  backgroundColor: cs.primaryFixed,
                  foregroundColor: cs.onPrimaryFixed,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ],
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
    TextTheme tt,
    dynamic s,
  ) {
    if (att == null) {
      return Center(
        child: Text(
          s.attendanceUnavailable,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }
    final pct = att.percentage;
    final safe = pct >= 80.0;
    final accent = safe ? cs.primary : cs.error;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  bottom: -24,
                  child: Container(
                    width: 130,
                    height: 130,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: cs.primaryFixed.withValues(alpha: 0.35),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.verified_user_outlined,
                                        size: 18, color: cs.primary),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        s.attendanceRecord,
                                        style: tt.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  s.attendanceThreshold,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${pct.toStringAsFixed(0)}%',
                                style: tt.displayMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                  height: 1.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                safe ? s.statusSafe : s.statusAtRisk,
                                style: tt.labelSmall?.copyWith(
                                  color: safe ? cs.secondary : cs.error,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: (pct / 100.0).clamp(0.0, 1.0),
                          minHeight: 11,
                          backgroundColor: cs.surfaceContainerHighest,
                          color: accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _attendanceStatPill(
                              context,
                              s.present,
                              '${att.attendanceCount}',
                              cs.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _attendanceStatPill(
                              context,
                              s.absent,
                              '${att.absenceCount}',
                              cs.error,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _attendanceStatPill(
                              context,
                              s.lateLabel,
                              '${att.lateCount}',
                              cs.tertiary,
                            ),
                          ),
                          if (att.othersCount > 0) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: _attendanceStatPill(
                                context,
                                s.others,
                                '${att.othersCount}',
                                cs.secondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (att.records.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        Text(
                          s.recentSessions.toUpperCase(),
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            letterSpacing: 0.7,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        for (final r in att.records.reversed)
                          _sessionRow(context, r, cs, tt, s),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceStatPill(
      BuildContext context, String label, String value, Color valueColor) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: tt.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionRow(
    BuildContext context,
    AttendanceRecord r,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    IconData leadingIcon;
    Color leadingColor;
    Color pillBg;
    Color pillFg;
    IconData pillIcon;
    String label;

    switch (r.statusType) {
      case 'present':
        leadingIcon = Icons.calendar_today_rounded;
        leadingColor = cs.primary;
        pillBg = cs.primaryFixed;
        pillFg = cs.onPrimaryFixed;
        pillIcon = Icons.check_circle_rounded;
        label = s.present;
        break;
      case 'absent':
        leadingIcon = Icons.event_busy_rounded;
        leadingColor = cs.error;
        pillBg = cs.errorContainer;
        pillFg = cs.onErrorContainer;
        pillIcon = Icons.cancel_rounded;
        label = s.absent;
        break;
      case 'late':
        leadingIcon = Icons.schedule_rounded;
        leadingColor = cs.tertiary;
        pillBg = cs.tertiaryFixed;
        pillFg = cs.onTertiaryFixed;
        pillIcon = Icons.access_time_filled_rounded;
        label = s.lateLabel;
        break;
      default:
        leadingIcon = Icons.help_outline_rounded;
        leadingColor = cs.onSurfaceVariant;
        pillBg = cs.surfaceContainerHigh;
        pillFg = cs.onSurfaceVariant;
        pillIcon = Icons.info_outline_rounded;
        label = s.others;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(leadingIcon, size: 17, color: leadingColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r.date,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (r.className.isNotEmpty)
                  Text(
                    r.className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ExpressivePill(
            icon: pillIcon,
            label: label,
            backgroundColor: pillBg,
            foregroundColor: pillFg,
            fontWeight: FontWeight.w700,
          ),
        ],
      ),
    );
  }

  Widget _buildFilesTab(
    BuildContext context,
    List<CourseFile> files,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    if (files.isEmpty) {
      return Center(
        child: Text(
          s.noFiles,
          style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: cs.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    s.courseMaterials,
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Text(
                s.filesCount(files.length),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < files.length; i++) ...[
            _buildFileRow(files[i], cs, tt, s),
            if (i != files.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildFileRow(
    CourseFile f,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final busy = _downloadingUrls.contains(f.url);
    final isCached = f.localPath != null;

    return ExpressiveCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(12),
      onTap: busy ? null : () => _downloadAndOpen(f),
      child: Row(
        children: [
          SquircleIcon(
            size: 42,
            radius: 14,
            iconSize: 20,
            icon: iconForFileName(f.name),
            backgroundColor:
                isCached ? cs.secondaryFixed : cs.surfaceContainer,
            iconColor:
                isCached ? cs.onSecondaryFixed : colorForFileName(f.name, cs),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (f.size > 0 || isCached) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (f.size > 0)
                        Text(
                          formatFileSize(f.size),
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      if (f.size > 0 && isCached)
                        Text(
                          ' • ',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      if (isCached) ...[
                        Icon(Icons.offline_pin_rounded,
                            size: 13, color: cs.primary),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            s.savedOffline,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          CircleActionButton(
            icon: isCached
                ? Icons.open_in_new_rounded
                : Icons.cloud_download_outlined,
            loading: busy,
            backgroundColor: cs.surfaceContainer,
            onPressed: () => _downloadAndOpen(f),
          ),
        ],
      ),
    );
  }
}
