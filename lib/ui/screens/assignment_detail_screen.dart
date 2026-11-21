import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_widgets.dart';
import 'course_detail_screen.dart';

class AssignmentDetailScreen extends StatefulWidget {
  final Assignment assignment;

  const AssignmentDetailScreen({super.key, required this.assignment});

  @override
  State<AssignmentDetailScreen> createState() => _AssignmentDetailScreenState();
}

class _AssignmentDetailScreenState extends State<AssignmentDetailScreen> {
  final Set<String> _downloadingLinks = {};
  PlatformFile? _pickedFile;
  bool _honorCodeChecked = false;
  bool _submitting = false;

  Future<void> _downloadAndOpen(AssignmentFile f) async {
    AppHaptics.selection();
    setState(() => _downloadingLinks.add(f.link));
    try {
      final path = await context
          .read<AppState>()
          .eclass
          .downloadFile(f.link, f.name);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        showQuickToast(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _downloadingLinks.remove(f.link));
    }
  }

  Future<void> _pickFile() async {
    AppHaptics.selection();
    final res = await FilePicker.platform.pickFiles();
    if (res != null && res.files.single.path != null && mounted) {
      setState(() => _pickedFile = res.files.single);
    }
  }

  Future<void> _submit(Assignment a) async {
    final assignId = a.assignId;
    if (assignId == null) return;
    final app = context.read<AppState>();
    final s = app.s;

    if (_pickedFile == null || _pickedFile!.path == null) {
      await _pickFile();
      if (_pickedFile == null || _pickedFile!.path == null || !mounted) return;
    }

    AppHaptics.medium();
    setState(() => _submitting = true);
    try {
      await app.eclass.uploadSubmission(
        assignId,
        _pickedFile!.path!,
        _pickedFile!.name,
        submitForGrading: _honorCodeChecked,
      );
      if (!mounted) return;
      AppHaptics.heavy();
      setState(() => _pickedFile = null);
      showQuickToast(context, s.uploadSuccess);
      await app.syncAllAssignments();
    } catch (e) {
      if (mounted) {
        showQuickToast(context, e.toString());
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _countdownText(Assignment a, dynamic s) {
    if (a.dueTimestamp <= 0) return s.noDeadlineSet;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final diff = a.dueTimestamp - nowSec;
    if (diff <= 0) return s.overdueLabel;
    final days = diff ~/ 86400;
    final hours = (diff % 86400) ~/ 3600;
    final mins = (diff % 3600) ~/ 60;
    return s.dueInCountdown(days, hours, mins);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Resolve live state if assignment updated or hidden while on screen
    final a = app.allAssignments.firstWhere(
      (item) => item.id == widget.assignment.id,
      orElse: () => widget.assignment,
    );
    final isHidden = app.isAssignmentHidden(a.id);
    final matchedCourse = app.courses.cast<Course?>().firstWhere(
          (c) => c?.id == a.courseId,
          orElse: () => null,
        );

    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final isOverdue =
        !a.isSubmitted && a.dueTimestamp > 0 && a.dueTimestamp < nowSec;
    final isUrgent = !a.isSubmitted &&
        a.dueTimestamp > 0 &&
        a.dueTimestamp >= nowSec &&
        (a.dueTimestamp - nowSec <= 48 * 3600);

    final Color dueBg;
    final Color dueFg;
    if (a.isSubmitted) {
      dueBg = cs.secondaryFixed;
      dueFg = cs.onSecondaryFixed;
    } else if (isOverdue || isUrgent) {
      dueBg = cs.errorContainer;
      dueFg = cs.onErrorContainer;
    } else {
      dueBg = cs.primaryFixed;
      dueFg = cs.onPrimaryFixed;
    }

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.assignmentDetailTitle,
        overline: s.portalHeader,
        showBack: true,
        actions: [
          CircleActionButton(
            key: const ValueKey('ad_toggle_hide_btn'),
            icon: isHidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            tooltip: isHidden ? s.restoreDeadline : s.hideDeadline,
            backgroundColor: isHidden ? cs.tertiaryFixed : cs.surfaceContainer,
            iconColor: isHidden ? cs.onTertiaryFixed : cs.onSurfaceVariant,
            onPressed: () async {
              AppHaptics.medium();
              await app.setAssignmentHidden(a.id, !isHidden);
              if (context.mounted) {
                showQuickToast(
                  context,
                  !isHidden
                      ? s.deadlineHiddenToast
                      : s.deadlineRestoredToast,
                );
              }
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildStickyDock(context, a, cs, tt, s),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          // Course Breadcrumb Chip + Hidden Pill
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              if (a.courseName.isNotEmpty)
                ExpressivePill(
                  icon: Icons.school_outlined,
                  label: a.courseName,
                  backgroundColor: cs.primaryFixed,
                  foregroundColor: cs.onPrimaryFixed,
                  fontWeight: FontWeight.w700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  onTap: matchedCourse == null
                      ? null
                      : () {
                          AppHaptics.light();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  CourseDetailScreen(course: matchedCourse),
                            ),
                          );
                        },
                ),
              if (isHidden)
                ExpressivePill(
                  icon: Icons.visibility_off_outlined,
                  label: s.hiddenBadge,
                  backgroundColor: cs.tertiaryFixed,
                  foregroundColor: cs.onTertiaryFixed,
                  fontWeight: FontWeight.w700,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a.name,
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),

          // Deadline & Points Bento Card (Stitch #12)
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                SquircleIcon(
                  size: 46,
                  radius: 15,
                  iconSize: 23,
                  icon: a.isSubmitted
                      ? Icons.task_alt_rounded
                      : Icons.alarm_rounded,
                  backgroundColor: dueBg,
                  iconColor: dueFg,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.due.isNotEmpty ? a.due : s.deadlineSectionLabel,
                        style: tt.labelSmall?.copyWith(
                          color: isOverdue || isUrgent
                              ? cs.error
                              : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.isGradedOnly
                            ? s.gradedLabel
                            : (a.isSubmitted
                                ? s.submitted
                                : _countdownText(a, s)),
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                if (a.gradeDisplay != null)
                  ExpressivePill(
                    icon: Icons.grade_rounded,
                    label: a.gradeDisplay!,
                    backgroundColor: cs.secondaryFixed,
                    foregroundColor: cs.onSecondaryFixed,
                    fontWeight: FontWeight.w800,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                  )
                else if (a.effectiveMaxPoints != null)
                  ExpressivePill(
                    icon: Icons.star_outline_rounded,
                    label: s.maxPointsLabel(a.effectiveMaxPoints!),
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    fontWeight: FontWeight.w700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Problem Statement & Starter Files Card
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SquircleIcon(
                      size: 38,
                      radius: 12,
                      iconSize: 20,
                      icon: Icons.description_outlined,
                      backgroundColor: cs.secondaryFixed,
                      iconColor: cs.onSecondaryFixed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.problemStatement,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (a.intro.isNotEmpty)
                  SelectableText(
                    a.intro,
                    style: tt.bodyMedium?.copyWith(
                      color: cs.onSurface,
                      height: 1.5,
                    ),
                  )
                else
                  Text(
                    s.noDescriptionProvided,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                if (a.files.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(
                    s.attachedFiles.toUpperCase(),
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final f in a.files) _buildFileTile(f, cs, tt),
                ],
              ],
            ),
          ),

          // Instructor Feedback Card
          if (a.feedbackComment.isNotEmpty ||
              a.gradeDisplay != null ||
              a.isSubmitted) ...[
            const SizedBox(height: 14),
            ExpressiveCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SquircleIcon(
                        size: 38,
                        radius: 12,
                        iconSize: 20,
                        icon: Icons.rate_review_outlined,
                        backgroundColor: cs.primaryFixed,
                        iconColor: cs.onPrimaryFixed,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.professorFeedback,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (a.gradeDisplay != null)
                        ExpressivePill(
                          label: a.gradeDisplay!,
                          backgroundColor: cs.primaryFixed,
                          foregroundColor: cs.onPrimaryFixed,
                          fontWeight: FontWeight.w800,
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (a.feedbackComment.isNotEmpty)
                    SelectableText(
                      a.feedbackComment,
                      style: tt.bodyMedium?.copyWith(height: 1.45),
                    )
                  else
                    Text(
                      s.noInstructorComment,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Submission Portal Card (Stitch #12)
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SquircleIcon(
                      size: 38,
                      radius: 12,
                      iconSize: 20,
                      icon: Icons.cloud_upload_outlined,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.submissionPortal,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    ExpressivePill(
                      label: a.isGradedOnly
                          ? s.gradedLabel
                          : (a.isSubmitted ? s.submitted : s.notSubmitted),
                      backgroundColor: a.isSubmitted
                          ? cs.secondaryFixed
                          : cs.errorContainer,
                      foregroundColor: a.isSubmitted
                          ? cs.onSecondaryFixed
                          : cs.onErrorContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ],
                ),
                if (a.submittedFiles.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    s.submittedFilesLabel.toUpperCase(),
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final sf in a.submittedFiles) _buildFileTile(sf, cs, tt),
                ],
                if (!a.isGradedOnly) ...[
                  const SizedBox(height: 14),
                  if (a.assignId == null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        s.uploadOnlyInWebHint,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    )
                  else ...[
                    Material(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: _submitting ? null : _pickFile,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 18),
                          child: Column(
                            children: [
                              SquircleIcon(
                                size: 44,
                                radius: 14,
                                iconSize: 22,
                                icon: Icons.upload_file_rounded,
                                backgroundColor: cs.primaryFixed,
                                iconColor: cs.onPrimaryFixed,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _pickedFile == null
                                    ? s.pickFileToUpload
                                    : s.changeFile,
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_pickedFile != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHighest,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        iconForFileName(_pickedFile!.name),
                                        size: 16,
                                        color: cs.primary,
                                      ),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          '${_pickedFile!.name} (${formatFileSize(_pickedFile!.size)})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: tt.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () =>
                                            setState(() => _pickedFile = null),
                                        child: Icon(Icons.close_rounded,
                                            size: 16,
                                            color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      key: const ValueKey('ad_honor_checkbox'),
                      value: _honorCodeChecked,
                      onChanged: _submitting
                          ? null
                          : (v) {
                              AppHaptics.selection();
                              setState(() => _honorCodeChecked = v ?? false);
                            },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        s.honorCodeLabel,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        s.honorCodeSub,
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileTile(AssignmentFile f, ColorScheme cs, TextTheme tt) {
    final busy = _downloadingLinks.contains(f.link);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: busy ? null : () => _downloadAndOpen(f),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                        style: tt.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (f.size > 0)
                        Text(
                          formatFileSize(f.size),
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cs.primary,
                        ),
                      )
                    : Icon(Icons.download_rounded,
                        size: 20, color: cs.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickyDock(
    BuildContext context,
    Assignment a,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final hasUrl = a.url != null && a.url!.isNotEmpty;
    final canUpload = a.assignId != null && !a.isGradedOnly;
    if (!hasUrl && !canUpload) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.35)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              if (hasUrl)
                Expanded(
                  flex: canUpload ? 2 : 1,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        AppHaptics.selection();
                        launchUrl(
                          Uri.parse(a.url!),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: const StadiumBorder(),
                        side: BorderSide(color: cs.outlineVariant),
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(
                        canUpload ? s.openInEclassShort : s.openInEclass,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              if (hasUrl && canUpload) const SizedBox(width: 10),
              if (canUpload)
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _submitting ? null : () => _submit(a),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: const StadiumBorder(),
                      ),
                      icon: _submitting
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimary,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        _submitting ? s.uploading : s.submitSolution,
                        style: tt.titleSmall?.copyWith(
                          color: cs.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
