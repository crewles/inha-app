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
  final TextEditingController _fileSearchCtrl = TextEditingController();
  bool _loading = false;
  bool _bulkDownloading = false;
  int _bulkDone = 0;
  int _bulkTotal = 0;
  String _assignFilter = 'all';
  String _fileFilter = 'all';
  String _fileQuery = '';
  final Set<String> _downloadingUrls = {};
  final Set<int> _uploadingAssignIds = {};

  void _onTabChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      await app.loadCourseDetailsFromCache(widget.course.id);
      _refresh();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _fileSearchCtrl.dispose();
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

  Future<void> _downloadAllFiles(List<CourseFile> targets) async {
    if (_bulkDownloading || targets.isEmpty) return;
    final app = context.read<AppState>();
    setState(() {
      _bulkDownloading = true;
      _bulkDone = 0;
      _bulkTotal = targets.length;
    });
    String? firstError;
    try {
      for (final file in targets) {
        if (!mounted) break;
        setState(() => _downloadingUrls.add(file.url));
        try {
          await app.downloadCourseFile(file);
        } catch (e) {
          firstError ??= e.toString();
        } finally {
          if (mounted) {
            setState(() {
              _downloadingUrls.remove(file.url);
              _bulkDone++;
            });
          }
        }
      }
      if (mounted && firstError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(firstError)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _bulkDownloading = false;
          _bulkDone = 0;
          _bulkTotal = 0;
        });
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

    final schedule = app.courseScheduleFor(widget.course);
    final professor = (schedule?.teacher.isNotEmpty == true)
        ? schedule!.teacher
        : widget.course.professor.trim();
    final classroom = schedule?.classroomSummary ?? '';
    final slots = schedule?.scheduleSummary ?? '';
    final scheduleParts = [
      if (slots.isNotEmpty) slots,
      if (classroom.isNotEmpty) classroom,
    ];

    final tabs = [
      (Icons.assignment_rounded, s.tabAssignments),
      (Icons.analytics_rounded, s.tabGrades),
      (Icons.how_to_reg_rounded, s.tabAttendance),
      (Icons.folder_rounded, s.tabFiles),
    ];

    final undownloadedFiles = files
        .where((f) => f.localPath == null || f.localPath!.isEmpty)
        .toList();

    Widget? fab;
    if (_tabController.index == 0) {
      fab = FloatingActionButton.extended(
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
      );
    } else if (_tabController.index == 3 && undownloadedFiles.isNotEmpty) {
      fab = FloatingActionButton.extended(
        onPressed: _bulkDownloading
            ? null
            : () => _downloadAllFiles(undownloadedFiles),
        shape: const StadiumBorder(),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        icon: _bulkDownloading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cs.onPrimary,
                ),
              )
            : const Icon(Icons.cloud_download_rounded),
        label: Text(
          _bulkDownloading
              ? s.downloadingAllProgress(_bulkDone, _bulkTotal)
              : s.downloadAllCount(undownloadedFiles.length),
          style: tt.labelLarge?.copyWith(
            color: cs.onPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.courseDetailTitle,
        overline: s.portalHeader,
        showBack: true,
      ),
      floatingActionButton: fab,
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
                          if (!widget.course.isCurrent ||
                              (widget.course.overviewGrade != null &&
                                  widget.course.overviewGrade!.isNotEmpty)) ...[
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
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
                                    backgroundColor: cs.primaryFixed,
                                    foregroundColor: cs.onPrimaryFixed,
                                    fontWeight: FontWeight.w700,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
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
                if (professor.isNotEmpty || scheduleParts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (professor.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InitialsAvatar(name: professor, size: 22),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  professor,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelMedium?.copyWith(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (scheduleParts.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.schedule_rounded,
                                  size: 15, color: cs.primary),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  scheduleParts.join(' • '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
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
                                  final (tabIcon, tabLabel) = tabs[i];
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
                                            horizontal: 12, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? cs.primary
                                              : Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              tabIcon,
                                              size: 16,
                                              color: selected
                                                  ? cs.onPrimary
                                                  : cs.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              tabLabel,
                                              style: tt.labelMedium?.copyWith(
                                                color: selected
                                                    ? cs.onPrimary
                                                    : cs.onSurfaceVariant,
                                                fontWeight: selected
                                                    ? FontWeight.w700
                                                    : FontWeight.w600,
                                              ),
                                            ),
                                          ],
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

    final totalCount = items.length;
    final gradedCount = items.where((a) => a.gradeDisplay != null).length;
    final submittedOnlyCount =
        items.where((a) => a.isSubmitted && a.gradeDisplay == null).length;
    final doneCount = gradedCount + submittedOnlyCount;
    final pendingCount = totalCount - doneCount;
    final pct = totalCount == 0 ? 0 : ((doneCount * 100) / totalCount).round();
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;

    final filtered = items.where((a) {
      switch (_assignFilter) {
        case 'pending':
          return !a.isSubmitted;
        case 'submitted':
          return a.isSubmitted && a.gradeDisplay == null;
        case 'graded':
          return a.gradeDisplay != null;
        default:
          return true;
      }
    }).toList();

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          // Top Stitch Progress Bento Card
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  s.assignmentsProgressTitle.toUpperCase(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.secondary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.completedOfTotal(doneCount, totalCount),
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            pendingCount > 0
                                ? s.tasksDueCount(pendingCount)
                                : s.allCaughtUp,
                            style: tt.bodySmall?.copyWith(
                              color: pendingCount > 0
                                  ? cs.tertiary
                                  : cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 62,
                            height: 62,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 6,
                              strokeCap: StrokeCap.round,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(cs.primary),
                            ),
                          ),
                          Text(
                            '$pct%',
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 8,
                    color: cs.surfaceContainerHighest,
                    child: Row(
                      children: [
                        if (gradedCount > 0)
                          Expanded(
                            flex: gradedCount,
                            child: Container(color: cs.primary),
                          ),
                        if (submittedOnlyCount > 0)
                          Expanded(
                            flex: submittedOnlyCount,
                            child: Container(color: cs.secondary),
                          ),
                        if (pendingCount > 0)
                          Expanded(
                            flex: pendingCount,
                            child:
                                Container(color: cs.surfaceContainerHighest),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips Track
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAssignFilterChip(
                  chipKey: const ValueKey('cd_assign_filter_all'),
                  label: s.filterAll,
                  count: totalCount,
                  selected: _assignFilter == 'all',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _assignFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _buildAssignFilterChip(
                  chipKey: const ValueKey('cd_assign_filter_pending'),
                  label: s.filterPending,
                  count: pendingCount,
                  dotColor: cs.tertiary,
                  selected: _assignFilter == 'pending',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _assignFilter = 'pending'),
                ),
                const SizedBox(width: 8),
                _buildAssignFilterChip(
                  chipKey: const ValueKey('cd_assign_filter_submitted'),
                  label: s.filterSubmitted,
                  count: submittedOnlyCount,
                  dotColor: cs.secondary,
                  selected: _assignFilter == 'submitted',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _assignFilter = 'submitted'),
                ),
                const SizedBox(width: 8),
                _buildAssignFilterChip(
                  chipKey: const ValueKey('cd_assign_filter_graded'),
                  label: s.filterGraded,
                  count: gradedCount,
                  dotColor: cs.primary,
                  selected: _assignFilter == 'graded',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _assignFilter = 'graded'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (filtered.isEmpty)
            ExpressiveCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: Text(
                s.allCaughtUpBody,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else
            for (int i = 0; i < filtered.length; i++) ...[
              _buildAssignmentCard(filtered[i], nowSec, cs, tt, s),
              if (i != filtered.length - 1) const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }

  Widget _buildAssignFilterChip({
    required Key chipKey,
    required String label,
    required int count,
    Color? dotColor,
    required bool selected,
    required ColorScheme cs,
    required TextTheme tt,
    required VoidCallback onTap,
  }) {
    return Material(
      key: chipKey,
      color: selected ? cs.primaryFixed : cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dotColor != null) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: selected ? cs.onPrimaryFixed : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  style: tt.labelSmall?.copyWith(
                    fontSize: 10,
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(
    Assignment a,
    int nowSec,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final uploading =
        a.assignId != null && _uploadingAssignIds.contains(a.assignId);
    final isOverdue =
        !a.isSubmitted && a.dueTimestamp > 0 && a.dueTimestamp < nowSec;
    final isUrgent = !a.isSubmitted &&
        a.dueTimestamp > 0 &&
        a.dueTimestamp >= nowSec &&
        (a.dueTimestamp - nowSec) <= 48 * 3600;

    final Color pillBg;
    final Color pillFg;
    final String pillLabel;
    final IconData pillIcon;
    if (a.gradeDisplay != null) {
      pillBg = cs.primaryFixed;
      pillFg = cs.onPrimaryFixed;
      pillLabel = s.submitted;
      pillIcon = Icons.verified_rounded;
    } else if (a.isSubmitted) {
      pillBg = cs.secondaryFixed;
      pillFg = cs.onSecondaryFixed;
      pillLabel = s.submitted;
      pillIcon = Icons.check_circle_rounded;
    } else if (isOverdue) {
      pillBg = cs.errorContainer;
      pillFg = cs.onErrorContainer;
      pillLabel = s.overdueLabel;
      pillIcon = Icons.error_outline_rounded;
    } else if (isUrgent) {
      pillBg = cs.tertiaryFixed;
      pillFg = cs.onTertiaryFixed;
      pillLabel = s.dueSoonLabel;
      pillIcon = Icons.alarm_rounded;
    } else {
      pillBg = cs.surfaceContainerHigh;
      pillFg = cs.onSurfaceVariant;
      pillLabel = s.notSubmitted;
      pillIcon = Icons.calendar_today_rounded;
    }

    return ExpressiveCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExpressivePill(
                icon: pillIcon,
                label: pillLabel,
                backgroundColor: pillBg,
                foregroundColor: pillFg,
                fontWeight: FontWeight.w700,
              ),
              const Spacer(),
              if (a.gradeDisplay != null)
                ExpressivePill(
                  label: a.gradeDisplay!,
                  backgroundColor: cs.secondaryFixed,
                  foregroundColor: cs.onSecondaryFixed,
                  fontWeight: FontWeight.w800,
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SquircleIcon(
                size: 44,
                radius: 14,
                iconSize: 22,
                icon: a.isSubmitted
                    ? Icons.assignment_turned_in_rounded
                    : Icons.assignment_outlined,
                backgroundColor:
                    a.isSubmitted ? cs.secondaryFixed : cs.tertiaryFixed,
                iconColor:
                    a.isSubmitted ? cs.onSecondaryFixed : cs.onTertiaryFixed,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name,
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (a.due.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${s.dueLabel}: ${a.due}',
                        style: tt.bodySmall?.copyWith(
                          color: (isOverdue || isUrgent)
                              ? cs.error
                              : cs.onSurfaceVariant,
                          fontWeight: (isOverdue || isUrgent)
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (a.files.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final f in a.files)
                  Material(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(999),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: _downloadingUrls.contains(f.link)
                          ? null
                          : () => _downloadAttachment(f),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _downloadingUrls.contains(f.link)
                                ? SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.primary,
                                    ),
                                  )
                                : Icon(
                                    iconForFileName(f.name),
                                    size: 16,
                                    color: colorForFileName(f.name, cs),
                                  ),
                            const SizedBox(width: 6),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 160),
                              child: Text(
                                f.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (f.size > 0) ...[
                              const SizedBox(width: 6),
                              Text(
                                formatFileSize(f.size),
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          if (!a.isSubmitted && a.assignId != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: uploading ? null : () => _submitSingleAssignment(a),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                icon: Icon(
                  uploading
                      ? Icons.hourglass_top_rounded
                      : Icons.cloud_upload_outlined,
                  size: 18,
                ),
                label: Text(
                  uploading ? s.uploading : s.submitSolution,
                  style: tt.labelLarge?.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  double? _parsePercent(String raw) {
    final m = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(raw);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  IconData _categoryIcon(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('midterm') ||
        lower.contains('final') ||
        lower.contains('exam') ||
        lower.contains('quiz')) {
      return Icons.quiz_rounded;
    }
    if (lower.contains('attend')) return Icons.how_to_reg_rounded;
    if (lower.contains('project') ||
        lower.contains('assign') ||
        lower.contains('lab') ||
        lower.contains('hw')) {
      return Icons.terminal_rounded;
    }
    return Icons.analytics_rounded;
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

    GradeItem? totalItem;
    final groupMap = <String, _GradeCategoryGroup>{};

    for (final g in grades) {
      if (g.isTotal) {
        totalItem ??= g;
        continue;
      }
      final key = g.category.trim().isNotEmpty
          ? g.category.trim()
          : (g.isSum
              ? g.name
                  .replaceAll(RegExp(r'\s*\bSUM$', caseSensitive: false), '')
                  .trim()
              : g.name);
      final group = groupMap.putIfAbsent(key, () => _GradeCategoryGroup(key));
      if (g.isSum) {
        group.sumItem = g;
      } else {
        group.items.add(g);
      }
    }

    final groups = groupMap.values.toList();
    final palette = [
      cs.primary,
      cs.secondary,
      cs.tertiary,
      cs.primaryFixedDim,
      cs.secondaryFixedDim,
      cs.outline,
    ];

    final weightedGroups = <({String title, double pct, Color color})>[];
    for (int i = 0; i < groups.length; i++) {
      final wRaw = groups[i].sumItem?.weight ?? '';
      final pct = _parsePercent(wRaw);
      if (pct != null && pct > 0) {
        weightedGroups.add((
          title: groups[i].title,
          pct: pct,
          color: palette[i % palette.length],
        ));
      }
    }
    final weightSum =
        weightedGroups.fold<double>(0, (acc, item) => acc + item.pct);

    final heroPrimaryText = (totalItem?.percentage.isNotEmpty == true &&
            totalItem!.percentage != '-')
        ? totalItem.percentage
        : (totalItem?.value ?? widget.course.overviewGrade ?? '-');
    final heroSubScore = totalItem != null && totalItem.value != heroPrimaryText
        ? (totalItem.range.isNotEmpty
            ? '${totalItem.value} / ${totalItem.range}'
            : totalItem.value)
        : '';

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          // Hero Grade Standing Card
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.currentStandingLabel,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      heroPrimaryText,
                      style: tt.displaySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (heroSubScore.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      ExpressivePill(
                        label: heroSubScore,
                        backgroundColor: cs.primaryFixed,
                        foregroundColor: cs.onPrimaryFixed,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ],
                ),
                if (weightedGroups.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.syllabusWeightsTitle,
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        '${weightSum.round()}%',
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          for (final wg in weightedGroups)
                            Expanded(
                              flex: (wg.pct * 10).round().clamp(1, 1000),
                              child: Container(color: wg.color),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      for (final wg in weightedGroups)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: wg.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '${wg.pct.toStringAsFixed(wg.pct == wg.pct.roundToDouble() ? 0 : 1)}% ${wg.title}',
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          for (int i = 0; i < groups.length; i++) ...[
            _buildGradeCategoryCard(
              groups[i],
              palette[i % palette.length],
              cs,
              tt,
              s,
            ),
            if (i != groups.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildGradeCategoryCard(
    _GradeCategoryGroup group,
    Color accent,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final sum = group.sumItem;
    final subParts = <String>[
      if (sum != null && sum.weight.isNotEmpty) '${s.weightCol}: ${sum.weight}',
      if (group.items.isNotEmpty) s.categoryItemsCount(group.items.length),
    ];
    final hasSumValue = sum != null && sum.value.isNotEmpty && sum.value != '-';
    final rightValue = sum?.value ??
        (group.items.length == 1 ? group.items.first.value : '-');
    final hasRightPct =
        sum != null && sum.percentage.isNotEmpty && sum.percentage != '-';

    return ExpressiveCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SquircleIcon(
                size: 44,
                radius: 14,
                iconSize: 22,
                icon: _categoryIcon(group.title),
                backgroundColor: accent.withValues(alpha: 0.14),
                iconColor: accent,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.title,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subParts.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subParts.join(' • '),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasSumValue ||
                      (sum == null && group.items.length == 1)) ...[
                    Text(
                      sum != null &&
                              sum.range.isNotEmpty &&
                              sum.range != '0-0'
                          ? '$rightValue (${sum.range})'
                          : rightValue,
                      style: tt.titleSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasRightPct)
                      Text(
                        sum.percentage,
                        style: tt.labelSmall?.copyWith(
                          color: cs.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ] else
                    ExpressivePill(
                      label: '-',
                      backgroundColor: cs.surfaceContainerHigh,
                      foregroundColor: cs.onSurfaceVariant,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                ],
              ),
            ],
          ),
          if (group.items.isNotEmpty) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth >= 280
                    ? (constraints.maxWidth - 8) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in group.items)
                      Container(
                        width: tileWidth,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.range.isNotEmpty && item.range != '0-0'
                                  ? '${item.value} (${item.range})'
                                  : item.value,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (item.percentage.isNotEmpty ||
                                item.weight.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (item.percentage.isNotEmpty &&
                                      item.percentage != '-')
                                    item.percentage,
                                  if (item.weight.isNotEmpty)
                                    '${s.weightCol} ${item.weight}',
                                ].join(' • '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                s.itemsPending,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
        ],
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

  String _classifyFile(CourseFile f) {
    final lower = f.name.toLowerCase();
    final dot = lower.lastIndexOf('.');
    final ext = dot >= 0 ? lower.substring(dot + 1) : '';
    if (ext == 'ppt' || ext == 'pptx' || ext == 'key') {
      return 'slides';
    }
    if (ext == 'c' ||
        ext == 'cpp' ||
        ext == 'cc' ||
        ext == 'h' ||
        ext == 'hpp' ||
        ext == 'py' ||
        ext == 'java' ||
        ext == 'js' ||
        ext == 'ts' ||
        ext == 'dart' ||
        ext == 'zip' ||
        ext == 'rar' ||
        ext == '7z' ||
        ext == 'tar' ||
        ext == 'gz' ||
        ext == 'ipynb' ||
        lower.contains('lab') ||
        lower.contains('starter') ||
        lower.contains('assign') ||
        lower.contains('code')) {
      return 'labs';
    }
    if (ext == 'pdf' &&
        (lower.contains('lec') ||
            lower.contains('slide') ||
            lower.contains('week') ||
            lower.contains('chap') ||
            lower.contains('unit'))) {
      return 'slides';
    }
    return 'docs';
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

    final downloadedCount =
        files.where((f) => f.localPath != null && f.localPath!.isNotEmpty).length;
    final slidesFiles = <CourseFile>[];
    final labsFiles = <CourseFile>[];
    final docsFiles = <CourseFile>[];
    for (final f in files) {
      switch (_classifyFile(f)) {
        case 'slides':
          slidesFiles.add(f);
          break;
        case 'labs':
          labsFiles.add(f);
          break;
        default:
          docsFiles.add(f);
      }
    }

    final query = _fileQuery.trim().toLowerCase();
    final visible = files.where((f) {
      if (query.isNotEmpty && !f.name.toLowerCase().contains(query)) {
        return false;
      }
      switch (_fileFilter) {
        case 'slides':
          return _classifyFile(f) == 'slides';
        case 'labs':
          return _classifyFile(f) == 'labs';
        case 'docs':
          return _classifyFile(f) == 'docs';
        case 'offline':
          return f.localPath != null && f.localPath!.isNotEmpty;
        default:
          return true;
      }
    }).toList();

    final showGrouped = _fileFilter == 'all' && query.isEmpty;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
        children: [
          // Offline Storage & Search Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.offline_pin_rounded,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.offlineStorageTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            s.offlineFilesCount(downloadedCount, files.length),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _fileSearchCtrl,
                  onChanged: (v) => setState(() => _fileQuery = v),
                  decoration: InputDecoration(
                    hintText: s.searchMaterialsHint,
                    isDense: true,
                    filled: true,
                    fillColor: cs.surfaceContainerLowest,
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: cs.onSurfaceVariant,
                    ),
                    suffixIcon: _fileQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: () {
                              _fileSearchCtrl.clear();
                              setState(() => _fileQuery = '');
                            },
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(999),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Category Filter Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFileFilterChip(
                  chipKey: const ValueKey('cd_file_filter_all'),
                  label: '${s.filterAll} (${files.length})',
                  selected: _fileFilter == 'all',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _fileFilter = 'all'),
                ),
                const SizedBox(width: 8),
                _buildFileFilterChip(
                  chipKey: const ValueKey('cd_file_filter_slides'),
                  label: '${s.filterLectures} (${slidesFiles.length})',
                  selected: _fileFilter == 'slides',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _fileFilter = 'slides'),
                ),
                const SizedBox(width: 8),
                _buildFileFilterChip(
                  chipKey: const ValueKey('cd_file_filter_labs'),
                  label: '${s.filterLabs} (${labsFiles.length})',
                  selected: _fileFilter == 'labs',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _fileFilter = 'labs'),
                ),
                const SizedBox(width: 8),
                _buildFileFilterChip(
                  chipKey: const ValueKey('cd_file_filter_docs'),
                  label: '${s.filterDocuments} (${docsFiles.length})',
                  selected: _fileFilter == 'docs',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _fileFilter = 'docs'),
                ),
                const SizedBox(width: 8),
                _buildFileFilterChip(
                  chipKey: const ValueKey('cd_file_filter_offline'),
                  label: '${s.filterOffline} ($downloadedCount)',
                  selected: _fileFilter == 'offline',
                  cs: cs,
                  tt: tt,
                  onTap: () => setState(() => _fileFilter = 'offline'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (visible.isEmpty)
            ExpressiveCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(24),
              child: Text(
                s.noFiles,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            )
          else if (showGrouped) ...[
            if (slidesFiles.isNotEmpty) ...[
              _buildFileSectionHeader(
                Icons.co_present_rounded,
                cs.primary,
                s.filterLectures,
                slidesFiles.length,
                tt,
                cs,
              ),
              const SizedBox(height: 8),
              for (final f in slidesFiles) ...[
                _buildFileRow(f, cs, tt, s),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
            ],
            if (labsFiles.isNotEmpty) ...[
              _buildFileSectionHeader(
                Icons.terminal_rounded,
                cs.secondary,
                s.filterLabs,
                labsFiles.length,
                tt,
                cs,
              ),
              const SizedBox(height: 8),
              for (final f in labsFiles) ...[
                _buildFileRow(f, cs, tt, s),
                const SizedBox(height: 10),
              ],
              const SizedBox(height: 6),
            ],
            if (docsFiles.isNotEmpty) ...[
              _buildFileSectionHeader(
                Icons.description_outlined,
                cs.onSurfaceVariant,
                s.filterDocuments,
                docsFiles.length,
                tt,
                cs,
              ),
              const SizedBox(height: 8),
              for (final f in docsFiles) ...[
                _buildFileRow(f, cs, tt, s),
                const SizedBox(height: 10),
              ],
            ],
          ] else
            for (int i = 0; i < visible.length; i++) ...[
              _buildFileRow(visible[i], cs, tt, s),
              if (i != visible.length - 1) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  Widget _buildFileFilterChip({
    required Key chipKey,
    required String label,
    required bool selected,
    required ColorScheme cs,
    required TextTheme tt,
    required VoidCallback onTap,
  }) {
    return Material(
      key: chipKey,
      color: selected ? cs.primary : cs.surfaceContainer,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileSectionHeader(
    IconData icon,
    Color iconColor,
    String title,
    int count,
    TextTheme tt,
    ColorScheme cs,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 6),
          Text(
            title,
            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Spacer(),
          Text(
            '$count',
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
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
    final isCached = f.localPath != null && f.localPath!.isNotEmpty;

    return ExpressiveCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(12),
      onTap: busy ? null : () => _downloadAndOpen(f),
      child: Row(
        children: [
          SquircleIcon(
            size: 44,
            radius: 14,
            iconSize: 22,
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
          if (isCached && !busy) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: cs.secondaryFixed,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: cs.onSecondaryFixed,
              ),
            ),
            const SizedBox(width: 6),
          ],
          CircleActionButton(
            icon: isCached
                ? Icons.open_in_new_rounded
                : Icons.cloud_download_outlined,
            loading: busy,
            backgroundColor: isCached ? cs.surfaceContainer : cs.primaryFixed,
            iconColor: isCached ? cs.onSurfaceVariant : cs.onPrimaryFixed,
            onPressed: () => _downloadAndOpen(f),
          ),
        ],
      ),
    );
  }
}

class _GradeCategoryGroup {
  final String title;
  final List<GradeItem> items = [];
  GradeItem? sumItem;

  _GradeCategoryGroup(this.title);
}
