import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import 'app_haptics.dart';
import 'expressive_widgets.dart';

class AssignmentCard extends StatelessWidget {
  final Assignment assignment;
  final bool isHidden;
  final int nowSec;
  final bool showCoursePill;
  final Set<String> downloadingLinks;
  final bool isUploading;
  final VoidCallback onTap;
  final VoidCallback? onOpenCourse;
  final ValueChanged<AssignmentFile> onDownloadAttachment;
  final VoidCallback? onSubmit;

  const AssignmentCard({
    super.key,
    required this.assignment,
    required this.isHidden,
    required this.nowSec,
    this.showCoursePill = true,
    this.downloadingLinks = const {},
    this.isUploading = false,
    required this.onTap,
    this.onOpenCourse,
    required this.onDownloadAttachment,
    this.onSubmit,
  });

  String _localizedStatus(Assignment a, dynamic s) {
    final lower = a.status.trim().toLowerCase();
    if (lower.isEmpty ||
        lower == 'no submission' ||
        lower == 'нет ответа' ||
        lower == 'нет отправки') {
      return s.noSubmissionYet;
    }
    if (lower.contains('draft') || lower.contains('черновик')) {
      return s.draftStatus;
    }
    if (a.isGradedOnly) return s.gradedLabel;
    if (a.isSubmitted) return s.submitted;
    return a.status;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final a = assignment;

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
      dueBg = cs.errorContainer.withValues(alpha: 0.7);
      dueFg = cs.onErrorContainer;
      dueIcon = Icons.schedule_rounded;
    } else if (isSoon) {
      barColor = cs.tertiary;
      dueBg = cs.tertiaryFixed.withValues(alpha: 0.7);
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

    return ExpressiveCard(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      onTap: onTap,
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
              14,
              10,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top metadata row (Stitch #1): pill + points/grade pill + 3-dot menu
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (showCoursePill && a.courseName.isNotEmpty)
                            ExpressivePill(
                              label: a.courseName,
                              backgroundColor: cs.primaryFixed,
                              foregroundColor: cs.onPrimaryFixed,
                              fontWeight: FontWeight.w700,
                              onTap: onOpenCourse,
                            )
                          else
                            ExpressivePill(
                              icon: a.isSubmitted
                                  ? Icons.check_circle_rounded
                                  : (isUrgent
                                      ? Icons.alarm_rounded
                                      : Icons.hourglass_top_rounded),
                              label: a.isGradedOnly
                                  ? s.gradedLabel
                                  : (a.isSubmitted
                                      ? s.submitted
                                      : (isOverdue
                                          ? s.overdueLabel
                                          : s.notSubmitted)),
                              backgroundColor: a.isSubmitted
                                  ? cs.primaryFixed
                                  : (isUrgent
                                      ? cs.errorContainer
                                      : cs.surfaceContainerHigh),
                              foregroundColor: a.isSubmitted
                                  ? cs.onPrimaryFixed
                                  : (isUrgent
                                      ? cs.onErrorContainer
                                      : cs.onSurfaceVariant),
                              fontWeight: FontWeight.w700,
                            ),
                          if (a.gradeDisplay != null)
                            ExpressivePill(
                              label: '${s.gradedLabel}: ${a.gradeDisplay!}',
                              backgroundColor: cs.primaryFixed,
                              foregroundColor: cs.onPrimaryFixed,
                              fontWeight: FontWeight.w700,
                            )
                          else if (a.effectiveMaxPoints != null)
                            ExpressivePill(
                              label: s.maxPointsLabel(a.effectiveMaxPoints!),
                              backgroundColor: cs.surfaceContainerLow,
                              foregroundColor: cs.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      key: ValueKey('assign_menu_${a.id}'),
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20,
                        color: cs.onSurfaceVariant,
                      ),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      onSelected: (action) async {
                        if (action == 'toggle_hide') {
                          AppHaptics.medium();
                          final nextHidden = !isHidden;
                          await app.setAssignmentHidden(a.id, nextHidden);
                          if (!context.mounted) return;
                          showQuickToast(
                            context,
                            nextHidden
                                ? s.deadlineHiddenToast
                                : s.deadlineRestoredToast,
                            actionLabel: s.undoLabel,
                            onAction: () =>
                                app.setAssignmentHidden(a.id, !nextHidden),
                          );
                        } else if (action == 'open_eclass' &&
                            a.url != null &&
                            a.url!.isNotEmpty) {
                          AppHaptics.selection();
                          launchUrl(
                            Uri.parse(a.url!),
                            mode: LaunchMode.externalApplication,
                          );
                        } else if (action == 'open_course' &&
                            onOpenCourse != null) {
                          onOpenCourse!();
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem<String>(
                          key: ValueKey('toggle_hide_${a.id}'),
                          value: 'toggle_hide',
                          child: Row(
                            children: [
                              Icon(
                                isHidden
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 19,
                                color: cs.onSurface,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isHidden
                                    ? s.restoreDeadline
                                    : s.hideAssignment,
                              ),
                            ],
                          ),
                        ),
                        if (a.url != null && a.url!.isNotEmpty)
                          PopupMenuItem<String>(
                            value: 'open_eclass',
                            child: Row(
                              children: [
                                Icon(Icons.open_in_new_rounded,
                                    size: 19, color: cs.onSurface),
                                const SizedBox(width: 10),
                                Text(s.openInEclass),
                              ],
                            ),
                          ),
                        if (showCoursePill && onOpenCourse != null)
                          PopupMenuItem<String>(
                            value: 'open_course',
                            child: Row(
                              children: [
                                Icon(Icons.school_outlined,
                                    size: 19, color: cs.onSurface),
                                const SizedBox(width: 10),
                                Text(s.openCourseBtn),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Text(
                        a.name,
                        style:
                            tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (a.due.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ExpressivePill(
                          icon: dueIcon,
                          label: dueText,
                          backgroundColor: dueBg,
                          foregroundColor: dueFg,
                          fontWeight: isUrgent || isOverdue
                              ? FontWeight.w700
                              : FontWeight.w600,
                        ),
                      ],
                      if (a.intro.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          a.intro,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (a.files.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: a.files.map((f) {
                            final busy = downloadingLinks.contains(f.link);
                            final sizeText =
                                f.size > 0 ? ' (${formatFileSize(f.size)})' : '';
                            return Material(
                              color: cs.surfaceContainer,
                              shape: const StadiumBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap:
                                    busy ? null : () => onDownloadAttachment(f),
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
                      if (a.feedbackComment.isNotEmpty ||
                          a.gradeDisplay != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.rate_review_outlined,
                                size: 17,
                                color: cs.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.professorFeedback,
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      a.feedbackComment.isNotEmpty
                                          ? a.feedbackComment
                                          : s.noInstructorComment,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant,
                                        fontStyle: a.feedbackComment.isEmpty
                                            ? FontStyle.italic
                                            : FontStyle.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (!a.isSubmitted)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 15,
                                    color: cs.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      _localizedStatus(a, s),
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
                            if (a.assignId != null && onSubmit != null) ...[
                              const SizedBox(width: 10),
                              Material(
                                color: isUrgent
                                    ? cs.primary
                                    : cs.surfaceContainerHigh,
                                shape: const StadiumBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: isUploading ? null : onSubmit,
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
                                              color: isUrgent
                                                  ? cs.onPrimary
                                                  : cs.primary,
                                            ),
                                          )
                                        else
                                          Icon(
                                            Icons.upload_file_rounded,
                                            size: 16,
                                            color: isUrgent
                                                ? cs.onPrimary
                                                : cs.primary,
                                          ),
                                        const SizedBox(width: 6),
                                        Text(
                                          s.submitSolution,
                                          style: tt.labelMedium?.copyWith(
                                            color: isUrgent
                                                ? cs.onPrimary
                                                : cs.primary,
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
                        )
                      else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: onTap,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.visibility_outlined,
                                        size: 15, color: cs.primary),
                                    const SizedBox(width: 5),
                                    Text(
                                      s.viewDetailsLabel,
                                      style: tt.labelSmall?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (a.submittedFiles.isNotEmpty)
                              Flexible(
                                child: Material(
                                  color: cs.surfaceContainer,
                                  shape: const StadiumBorder(),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: downloadingLinks
                                            .contains(a.submittedFiles.first.link)
                                        ? null
                                        : () => onDownloadAttachment(
                                            a.submittedFiles.first),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 11, vertical: 6),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.download_rounded,
                                              size: 14,
                                              color: cs.onSurfaceVariant),
                                          const SizedBox(width: 5),
                                          Flexible(
                                            child: Text(
                                              a.submittedFiles.first.name,
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
                                  ),
                                ),
                              )
                            else
                              Icon(
                                Icons.check_circle_rounded,
                                size: 18,
                                color: cs.primary,
                              ),
                          ],
                        ),
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
}
