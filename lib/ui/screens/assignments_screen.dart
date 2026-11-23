import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/assignment_card.dart';
import '../widgets/expressive_sheets.dart';
import '../widgets/expressive_widgets.dart';
import 'assignment_detail_screen.dart';
import 'course_detail_screen.dart';
import 'drafts_screen.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  String _filter = 'pending'; // pending | submitted | graded | all | hidden
  final Set<String> _downloading = {};
  final Set<int> _uploadingAssignIds = {};

  Future<void> _downloadAttachment(AssignmentFile att) async {
    AppHaptics.selection();
    setState(() => _downloading.add(att.link));
    try {
      final path = await context
          .read<AppState>()
          .eclass
          .downloadFile(att.link, att.name);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        showQuickToast(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(att.link));
    }
  }

  Future<void> _submitAssignment(Assignment a) async {
    final assignId = a.assignId;
    if (assignId == null) return;
    final app = context.read<AppState>();
    final s = app.s;

    try {
      final picked = await FilePicker.platform.pickFiles();
      if (picked == null || picked.files.single.path == null) return;
      if (!mounted) return;

      setState(() => _uploadingAssignIds.add(assignId));
      showQuickToast(context, s.uploading);

      await app.eclass.uploadSubmission(
        assignId,
        picked.files.single.path!,
        picked.files.single.name,
      );

      if (!mounted) return;
      showQuickToast(context, s.uploadSuccess);
      await app.syncAllAssignments();
    } catch (e) {
      if (mounted) {
        showQuickToast(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _uploadingAssignIds.remove(assignId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final active = app.activeAssignments;
    final hidden = app.hiddenAssignments;
    final effectiveFilter =
        (_filter == 'hidden' && hidden.isEmpty) ? 'pending' : _filter;

    final totalCount = active.length;
    final submittedCount = active.where((a) => a.isSubmitted).length;
    final pendingCount = totalCount - submittedCount;
    final gradedCount = active.where((a) => a.gradeDisplay != null).length;

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final dueSoonCount = active
        .where((a) =>
            !a.isSubmitted &&
            a.dueTimestamp > nowSec &&
            a.dueTimestamp - nowSec <= 7 * 86400)
        .length;

    final rawFiltered = effectiveFilter == 'hidden'
        ? hidden
        : active.where((a) {
            switch (effectiveFilter) {
              case 'pending':
                return !a.isSubmitted;
              case 'submitted':
                return a.isSubmitted;
              case 'graded':
                return a.gradeDisplay != null;
              default:
                return true;
            }
          }).toList();

    final filtered = Assignment.sortForDisplay(
      rawFiltered,
      pendingMode: effectiveFilter == 'pending',
      nowSec: nowSec,
    );

    final pct =
        totalCount > 0 ? ((submittedCount / totalCount) * 100).round() : 0;

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.navAssignments,
        overline: s.portalHeader,
        actions: [
          CircleActionButton(
            key: const ValueKey('open_drafts_btn'),
            icon: Icons.folder_copy_outlined,
            tooltip: s.draftsTitle,
            backgroundColor: app.totalDraftsCount > 0
                ? cs.primaryFixed
                : cs.surfaceContainer,
            iconColor: app.totalDraftsCount > 0
                ? cs.onPrimaryFixed
                : cs.onSurfaceVariant,
            onPressed: () {
              AppHaptics.selection();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DraftsScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          CircleActionButton(
            icon: Icons.refresh_rounded,
            tooltip: s.refresh,
            loading: app.isSyncing,
            onPressed: () {
              AppHaptics.selection();
              app.syncAllAssignments();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => app.syncAllAssignments(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            Row(
              children: [
                Text(
                  s.navAssignments,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$pendingCount',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              s.assignmentsAttention(pendingCount),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            if (totalCount > 0 || hidden.isNotEmpty) ...[
              const SizedBox(height: 14),
              Material(
                key: const ValueKey('completion_pace_card'),
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    AppHaptics.light();
                    showCompletionBreakdownSheet(
                      context,
                      activeAssignments: active,
                      hiddenCount: hidden.length,
                      courses: app.courses,
                      onSelectFilter: (id) => setState(() => _filter = id),
                      onOpenCourse: (c) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              CourseDetailScreen(course: c, initialTab: 0),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.verified_rounded,
                                    size: 18, color: cs.primary),
                                const SizedBox(width: 6),
                                Text(
                                  s.completionPace,
                                  style: tt.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  s.percentFinished(pct),
                                  style: tt.labelMedium?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(Icons.chevron_right_rounded,
                                    size: 16, color: cs.primary),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: totalCount > 0
                                ? (submittedCount / totalCount).clamp(0.0, 1.0)
                                : 0.0,
                            minHeight: 8,
                            backgroundColor: cs.surfaceContainerHighest,
                            color: cs.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.completedOf(submittedCount, totalCount),
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              s.dueIn7Days(dueSoonCount),
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                    key: const ValueKey('filter_pending'),
                    id: 'pending',
                    activeFilter: effectiveFilter,
                    label: '${s.filterPending} ($pendingCount)',
                    icon: Icons.hourglass_top_rounded,
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    key: const ValueKey('filter_submitted'),
                    id: 'submitted',
                    activeFilter: effectiveFilter,
                    label: '${s.filterSubmitted} ($submittedCount)',
                    icon: Icons.check_circle_outline_rounded,
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    key: const ValueKey('filter_graded'),
                    id: 'graded',
                    activeFilter: effectiveFilter,
                    label: '${s.filterGraded} ($gradedCount)',
                    icon: Icons.grade_outlined,
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    key: const ValueKey('filter_all'),
                    id: 'all',
                    activeFilter: effectiveFilter,
                    label: '${s.filterAll} ($totalCount)',
                    cs: cs,
                    tt: tt,
                  ),
                  if (hidden.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _filterChip(
                      key: const ValueKey('filter_hidden'),
                      id: 'hidden',
                      activeFilter: effectiveFilter,
                      label: '${s.hiddenFilter} (${hidden.length})',
                      icon: Icons.visibility_off_outlined,
                      cs: cs,
                      tt: tt,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHigh,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.task_alt_rounded,
                          size: 32, color: cs.primary),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.allCaughtUpTitle,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.allCaughtUpBody,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else
              for (int i = 0; i < filtered.length; i++) ...[
                _buildCard(context, app, filtered[i],
                    effectiveFilter == 'hidden', nowSec),
                if (i != filtered.length - 1) const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    AppState app,
    Assignment a,
    bool isHidden,
    int nowSec,
  ) {
    final matchedCourse = app.courses.cast<Course?>().firstWhere(
          (c) => c?.id == a.courseId,
          orElse: () => null,
        );
    final isUploading =
        a.assignId != null && _uploadingAssignIds.contains(a.assignId);

    return AssignmentCard(
      assignment: a,
      isHidden: isHidden,
      nowSec: nowSec,
      showCoursePill: true,
      downloadingLinks: _downloading,
      isUploading: isUploading,
      onTap: () {
        AppHaptics.light();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AssignmentDetailScreen(assignment: a),
          ),
        );
      },
      onOpenCourse: matchedCourse == null
          ? null
          : () {
              AppHaptics.light();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CourseDetailScreen(course: matchedCourse),
                ),
              );
            },
      onDownloadAttachment: _downloadAttachment,
      onSubmit: a.assignId != null ? () => _submitAssignment(a) : null,
    );
  }

  Widget _filterChip({
    Key? key,
    required String id,
    required String activeFilter,
    required String label,
    IconData? icon,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    final selected = activeFilter == id;
    return Material(
      key: key,
      color: selected ? cs.primary : cs.surfaceContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          setState(() => _filter = id);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
