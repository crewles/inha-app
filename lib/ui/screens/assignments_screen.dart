import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/expressive_widgets.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  String _filter = 'pending'; // pending | submitted | graded | all
  final Set<String> _downloading = {};
  final Set<int> _uploadingAssignIds = {};

  Future<void> _downloadAttachment(AssignmentFile att) async {
    setState(() => _downloading.add(att.link));
    try {
      final path = await context
          .read<AppState>()
          .eclass
          .downloadFile(att.link, att.name);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.uploading)),
      );

      await app.eclass.uploadSubmission(
        assignId,
        picked.files.single.path!,
        picked.files.single.name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.uploadSuccess)),
      );
      await app.syncAllAssignments();
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

  (Color bg, Color fg) _courseTagColors(String courseId, ColorScheme cs) {
    final idx = courseId.hashCode.abs() % 4;
    switch (idx) {
      case 0:
        return (cs.primaryFixed, cs.onPrimaryFixed);
      case 1:
        return (cs.secondaryFixed, cs.onSecondaryFixed);
      case 2:
        return (cs.surfaceContainerHighest, cs.onSurfaceVariant);
      default:
        return (cs.tertiaryFixed, cs.onTertiaryFixed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final all = app.allAssignments;
    final totalCount = all.length;
    final submittedCount = all.where((a) => a.isSubmitted).length;
    final pendingCount = totalCount - submittedCount;
    final gradedCount = all.where((a) => a.gradeDisplay != null).length;

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final dueSoonCount = all
        .where((a) =>
            !a.isSubmitted &&
            a.dueTimestamp > nowSec &&
            a.dueTimestamp - nowSec <= 7 * 86400)
        .length;

    final filtered = all.where((a) {
      switch (_filter) {
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

    final pct = totalCount > 0 ? ((submittedCount / totalCount) * 100).round() : 0;

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.navAssignments,
        overline: s.portalHeader,
        actions: [
          CircleActionButton(
            icon: Icons.refresh_rounded,
            tooltip: s.refresh,
            loading: app.isSyncing,
            onPressed: () => app.syncAllAssignments(),
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
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
            if (totalCount > 0) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                ),
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
                        Text(
                          s.percentFinished(pct),
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: (submittedCount / totalCount).clamp(0.0, 1.0),
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
            ],
            const SizedBox(height: 14),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                    key: const ValueKey('filter_pending'),
                    id: 'pending',
                    label: '${s.filterPending} ($pendingCount)',
                    icon: Icons.hourglass_top_rounded,
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    key: const ValueKey('filter_submitted'),
                    id: 'submitted',
                    label: '${s.filterSubmitted} ($submittedCount)',
                    icon: Icons.check_circle_outline_rounded,
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    key: const ValueKey('filter_graded'),
                    id: 'graded',
                    label: '${s.filterGraded} ($gradedCount)',
                    icon: Icons.grade_outlined,
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    key: const ValueKey('filter_all'),
                    id: 'all',
                    label: '${s.filterAll} ($totalCount)',
                    cs: cs,
                    tt: tt,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
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
                _buildAssignmentCard(
                  context: context,
                  a: filtered[i],
                  nowSec: nowSec,
                  cs: cs,
                  tt: tt,
                  s: s,
                ),
                if (i != filtered.length - 1) const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    Key? key,
    required String id,
    required String label,
    IconData? icon,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    final selected = _filter == id;
    return Material(
      key: key,
      color: selected ? cs.primary : cs.surfaceContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _filter = id),
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

  Widget _buildAssignmentCard({
    required BuildContext context,
    required Assignment a,
    required int nowSec,
    required ColorScheme cs,
    required TextTheme tt,
    required dynamic s,
  }) {
    final isUrgent = !a.isSubmitted &&
        a.dueTimestamp > 0 &&
        (a.dueTimestamp - nowSec <= 48 * 3600);
    final isSoon = !a.isSubmitted &&
        !isUrgent &&
        a.dueTimestamp > 0 &&
        (a.dueTimestamp - nowSec <= 7 * 86400);
    final isOverdue =
        !a.isSubmitted && a.dueTimestamp > 0 && a.dueTimestamp < nowSec;

    Color? barColor;
    Color dueBg;
    Color dueFg;
    IconData dueIcon;

    if (isUrgent) {
      barColor = cs.error;
      dueBg = cs.errorContainer;
      dueFg = cs.onErrorContainer;
      dueIcon = Icons.schedule_rounded;
    } else if (isSoon) {
      barColor = cs.tertiary;
      dueBg = cs.tertiaryFixed;
      dueFg = cs.onTertiaryFixed;
      dueIcon = Icons.event_rounded;
    } else if (a.isSubmitted) {
      dueBg = cs.surfaceContainerLow;
      dueFg = cs.onSurfaceVariant;
      dueIcon = Icons.done_all_rounded;
    } else {
      dueBg = cs.surfaceContainer;
      dueFg = cs.onSurfaceVariant;
      dueIcon = Icons.calendar_today_rounded;
    }

    String dueText = a.due;
    if (isOverdue) {
      dueText = '${a.due} • ${s.overdueLabel}';
    } else if (isUrgent) {
      dueText = '${a.due} • ${s.dueSoonLabel}';
    }

    final (courseBg, courseFg) = _courseTagColors(a.courseId, cs);
    final isUploading =
        a.assignId != null && _uploadingAssignIds.contains(a.assignId);

    return ExpressiveCard(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          if (barColor != null)
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 5,
              child: ColoredBox(color: barColor),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              barColor != null ? 19 : 16,
              16,
              16,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (a.courseName.isNotEmpty)
                            ExpressivePill(
                              label: a.courseName,
                              backgroundColor: courseBg,
                              foregroundColor: courseFg,
                            ),
                          if (a.gradeDisplay != null)
                            ExpressivePill(
                              label: a.gradeDisplay!,
                              backgroundColor: cs.surfaceContainerHigh,
                              foregroundColor: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                        ],
                      ),
                    ),
                    if (a.url != null && a.url!.isNotEmpty)
                      IconButton(
                        tooltip: s.openInEclass,
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          Icons.open_in_new_rounded,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        onPressed: () => launchUrl(
                          Uri.parse(a.url!),
                          mode: LaunchMode.externalApplication,
                        ),
                      )
                    else if (a.isSubmitted)
                      Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  a.name,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (a.due.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ExpressivePill(
                    icon: dueIcon,
                    label: dueText,
                    backgroundColor: dueBg,
                    foregroundColor: dueFg,
                  ),
                ],
                if (a.files.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: a.files.map((f) {
                      final busy = _downloading.contains(f.link);
                      final sizeText =
                          f.size > 0 ? ' (${formatFileSize(f.size)})' : '';
                      return Material(
                        color: cs.surfaceContainer,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: busy ? null : () => _downloadAttachment(f),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (busy)
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: cs.primary,
                                    ),
                                  )
                                else
                                  Icon(
                                    iconForFileName(f.name),
                                    size: 15,
                                    color: colorForFileName(f.name, cs),
                                  ),
                                const SizedBox(width: 6),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 180),
                                  child: Text(
                                    '${f.name}$sizeText',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            a.isSubmitted
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_upload_outlined,
                            size: 15,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              a.isSubmitted
                                  ? s.submitted
                                  : (a.status.isNotEmpty
                                      ? a.status
                                      : s.noSubmissionYet),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!a.isSubmitted && a.assignId != null) ...[
                      const SizedBox(width: 10),
                      Material(
                        color: isUrgent ? cs.primary : cs.surfaceContainerHigh,
                        shape: const StadiumBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap:
                              isUploading ? null : () => _submitAssignment(a),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isUploading)
                                  SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color:
                                          isUrgent ? cs.onPrimary : cs.primary,
                                    ),
                                  )
                                else
                                  Icon(
                                    Icons.upload_file_rounded,
                                    size: 16,
                                    color:
                                        isUrgent ? cs.onPrimary : cs.primary,
                                  ),
                                const SizedBox(width: 6),
                                Text(
                                  s.submitSolution,
                                  style: tt.labelMedium?.copyWith(
                                    color:
                                        isUrgent ? cs.onPrimary : cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
