import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/notification_service.dart';
import '../../services/timetable_service.dart';
import '../../services/update_service.dart';
import '../../state/app_state.dart';
import 'app_haptics.dart';
import 'expressive_widgets.dart';

const _sheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
);

Future<void> _copyWithFeedback(
  BuildContext context,
  String value,
  String toastLabel,
) async {
  AppHaptics.medium();
  await Clipboard.setData(ClipboardData(text: value));
  if (!context.mounted) return;
  showQuickToast(context, toastLabel);
}

Future<void> showCompletionBreakdownSheet(
  BuildContext context, {
  required List<Assignment> activeAssignments,
  required int hiddenCount,
  required List<Course> courses,
  required ValueChanged<String> onSelectFilter,
  required ValueChanged<Course> onOpenCourse,
  bool scopedToCourse = false,
}) async {
  final app = context.read<AppState>();
  final s = app.s;
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  final totalCount = activeAssignments.length;
  final submittedAllCount = activeAssignments.where((a) => a.isSubmitted).length;
  final gradedCount =
      activeAssignments.where((a) => a.gradeDisplay != null).length;
  final pendingCount = totalCount - submittedAllCount;
  final pct =
      totalCount > 0 ? ((submittedAllCount / totalCount) * 100).round() : 0;
  final progress =
      totalCount > 0 ? (submittedAllCount / totalCount).clamp(0.0, 1.0) : 0.0;

  final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final dueSoonCount = activeAssignments
      .where((a) =>
          !a.isSubmitted &&
          a.dueTimestamp > nowSec &&
          a.dueTimestamp - nowSec <= 7 * 86400)
      .length;

  final courseById = {for (final c in courses) c.id: c};
  final byCourse = <String, ({String name, int pending, int urgent, int total})>{};
  for (final a in activeAssignments) {
    final prev = byCourse[a.courseId];
    final isPend = !a.isSubmitted;
    final isUrg = isPend &&
        a.dueTimestamp > 0 &&
        (a.dueTimestamp - nowSec <= 48 * 3600);
    byCourse[a.courseId] = (
      name: courseById[a.courseId]?.name ?? a.courseName,
      pending: (prev?.pending ?? 0) + (isPend ? 1 : 0),
      urgent: (prev?.urgent ?? 0) + (isUrg ? 1 : 0),
      total: (prev?.total ?? 0) + 1,
    );
  }
  final courseRows = byCourse.entries.toList()
    ..sort((a, b) {
      final pCmp = b.value.pending.compareTo(a.value.pending);
      return pCmp != 0 ? pCmp : a.value.name.compareTo(b.value.name);
    });

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: _sheetShape,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * 0.82,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SquircleIcon(
                    size: 42,
                    radius: 14,
                    iconSize: 22,
                    icon: Icons.pie_chart_rounded,
                    backgroundColor: cs.primaryFixed,
                    iconColor: cs.onPrimaryFixed,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.progressBreakdownTitle,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          s.tapToFilterHint,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 66,
                      height: 66,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 66,
                            height: 66,
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
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.completedOf(submittedAllCount, totalCount),
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${s.tasksDueCount(pendingCount)} • ${s.dueIn7Days(dueSoonCount)}',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.byStatusLabel,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ExpressivePill(
                    icon: Icons.hourglass_top_rounded,
                    label: '${s.filterPending} ($pendingCount)',
                    backgroundColor: cs.tertiaryFixed,
                    foregroundColor: cs.onTertiaryFixed,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fontWeight: FontWeight.w700,
                    onTap: () {
                      AppHaptics.selection();
                      Navigator.pop(ctx);
                      onSelectFilter('pending');
                    },
                  ),
                  ExpressivePill(
                    icon: Icons.check_circle_outline_rounded,
                    label: '${s.filterSubmitted} ($submittedAllCount)',
                    backgroundColor: cs.secondaryFixed,
                    foregroundColor: cs.onSecondaryFixed,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fontWeight: FontWeight.w700,
                    onTap: () {
                      AppHaptics.selection();
                      Navigator.pop(ctx);
                      onSelectFilter('submitted');
                    },
                  ),
                  ExpressivePill(
                    icon: Icons.grade_outlined,
                    label: '${s.filterGraded} ($gradedCount)',
                    backgroundColor: cs.primaryFixed,
                    foregroundColor: cs.onPrimaryFixed,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    fontWeight: FontWeight.w700,
                    onTap: () {
                      AppHaptics.selection();
                      Navigator.pop(ctx);
                      onSelectFilter('graded');
                    },
                  ),
                  if (hiddenCount > 0)
                    ExpressivePill(
                      icon: Icons.visibility_off_outlined,
                      label: '${s.hiddenFilter} ($hiddenCount)',
                      backgroundColor: cs.surfaceContainerHigh,
                      foregroundColor: cs.onSurfaceVariant,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      fontWeight: FontWeight.w700,
                      onTap: () {
                        AppHaptics.selection();
                        Navigator.pop(ctx);
                        onSelectFilter('hidden');
                      },
                    ),
                ],
              ),
              if (!scopedToCourse && courseRows.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  s.byCourseLabel,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
                const SizedBox(height: 8),
                for (final entry in courseRows) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ExpressiveCard(
                      borderRadius: 18,
                      color: cs.surfaceContainerLow,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      onTap: courseById[entry.key] == null
                          ? null
                          : () {
                              AppHaptics.light();
                              Navigator.pop(ctx);
                              onOpenCourse(courseById[entry.key]!);
                            },
                      child: Row(
                        children: [
                          SquircleIcon(
                            size: 38,
                            radius: 12,
                            iconSize: 20,
                            icon: entry.value.pending > 0
                                ? Icons.menu_book_rounded
                                : Icons.task_alt_rounded,
                            backgroundColor: entry.value.urgent > 0
                                ? cs.errorContainer
                                : (entry.value.pending > 0
                                    ? cs.primaryFixed
                                    : cs.secondaryFixed),
                            iconColor: entry.value.urgent > 0
                                ? cs.onErrorContainer
                                : (entry.value.pending > 0
                                    ? cs.onPrimaryFixed
                                    : cs.onSecondaryFixed),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.value.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  entry.value.pending > 0
                                      ? s.tasksDueCount(entry.value.pending)
                                      : s.noPendingInCourse,
                                  style: tt.labelSmall?.copyWith(
                                    color: entry.value.urgent > 0
                                        ? cs.error
                                        : cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (courseById[entry.key] != null)
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> showUpdateAvailableSheet(
  BuildContext context,
  AppReleaseInfo release,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: _sheetShape,
    builder: (ctx) => _UpdateAvailableSheetBody(release: release),
  );
}

class _UpdateAvailableSheetBody extends StatefulWidget {
  final AppReleaseInfo release;
  const _UpdateAvailableSheetBody({required this.release});

  @override
  State<_UpdateAvailableSheetBody> createState() =>
      _UpdateAvailableSheetBodyState();
}

class _UpdateAvailableSheetBodyState extends State<_UpdateAvailableSheetBody> {
  final bool _downloading = false;
  final double _progress = 0;
  String? _error;

  Future<void> _downloadAndInstall() async {
    AppHaptics.medium();
    final url = widget.release.apkUrl ?? widget.release.htmlUrl;
    try {
      await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final rel = widget.release;
    final pct = (_progress * 100).round();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SquircleIcon(
                  size: 46,
                  radius: 15,
                  iconSize: 24,
                  icon: Icons.system_update_rounded,
                  backgroundColor: cs.primaryFixed,
                  iconColor: cs.onPrimaryFixed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.updateAvailableTitle,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ExpressivePill(
                            label: 'v${UpdateService.currentVersion}',
                            backgroundColor: cs.surfaceContainerHigh,
                            foregroundColor: cs.onSurfaceVariant,
                          ),
                          Icon(Icons.arrow_forward_rounded,
                              size: 14, color: cs.onSurfaceVariant),
                          ExpressivePill(
                            label: 'v${rel.version}',
                            backgroundColor: cs.primaryFixed,
                            foregroundColor: cs.onPrimaryFixed,
                            fontWeight: FontWeight.w800,
                          ),
                          if (rel.apkSize > 0)
                            Text(
                              formatFileSize(rel.apkSize),
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
            ),
            const SizedBox(height: 16),
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(18),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.whatsNewLabel.toUpperCase(),
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      rel.notes.isNotEmpty ? rel.notes : rel.title,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurface,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_downloading) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.downloadingUpdatePct(pct),
                    style: tt.labelMedium?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$pct%',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: _progress > 0 ? _progress : null,
                  minHeight: 8,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: cs.primary,
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            const SizedBox(height: 18),
            if (rel.apkUrl != null) ...[
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _downloading ? null : _downloadAndInstall,
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: const StadiumBorder(),
                  ),
                  icon: const Icon(Icons.download_rounded, size: 20),
                  label: Text(
                    s.downloadAndInstallBtn,
                    style: tt.titleSmall?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              height: 46,
              child: FilledButton.tonalIcon(
                onPressed: () {
                  AppHaptics.selection();
                  launchUrl(
                    Uri.parse(rel.htmlUrl),
                    mode: LaunchMode.externalApplication,
                  );
                },
                style: FilledButton.styleFrom(
                  backgroundColor: cs.surfaceContainerHigh,
                  foregroundColor: cs.onSurface,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 18),
                label: Text(s.openOnGithubBtn),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showNotificationDiagnosticsSheet(
  BuildContext context,
  AppState app,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: _sheetShape,
    builder: (_) => const _NotificationDiagnosticsSheetBody(),
  );
}

class _NotificationDiagnosticsSheetBody extends StatefulWidget {
  const _NotificationDiagnosticsSheetBody();

  @override
  State<_NotificationDiagnosticsSheetBody> createState() =>
      _NotificationDiagnosticsSheetBodyState();
}

class _NotificationDiagnosticsSheetBodyState
    extends State<_NotificationDiagnosticsSheetBody> {
  bool? _granted;
  List<PendingNotificationRequest> _pending = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final ok = await NotificationService.instance.areNotificationsEnabled();
      final pending =
          await NotificationService.instance.getPendingNotifications();
      if (mounted) {
        setState(() {
          _granted = ok;
          _pending = pending;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendInstantTest(bool isRu) async {
    final s = context.read<AppState>().s;
    AppHaptics.medium();
    try {
      await NotificationService.instance
          .sendInstantTestNotification(isRu: isRu);
      if (!mounted) return;
      showQuickToast(context, s.instantTestSentToast);
    } catch (e, st) {
      debugPrint('Instant test notification error: $e\n$st');
      if (!mounted) return;
      showQuickToast(context, 'Notification error: $e');
    }
  }

  Future<void> _schedule10sTest(bool isRu) async {
    final s = context.read<AppState>().s;
    AppHaptics.medium();
    try {
      final exact = await NotificationService.instance
          .scheduleDelayedTestNotification(isRu: isRu, delaySeconds: 10);
      await _reload();
      if (!mounted) return;
      showQuickToast(
        context,
        exact ? s.delayedTestScheduledToast : s.delayedTestInexactToast,
        duration: Duration(milliseconds: exact ? 2400 : 3200),
      );
    } catch (e, st) {
      debugPrint('Delayed 10s test notification error: $e\n$st');
      if (!mounted) return;
      showQuickToast(context, 'Notification error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final classCount =
        _pending.where((p) => p.id >= 1000 && p.id < 1200).length;
    final deadlineCount =
        _pending.where((p) => p.id >= 2000 && p.id < 2300).length;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  SquircleIcon(
                    size: 44,
                    radius: 14,
                    iconSize: 22,
                    icon: Icons.notifications_active_rounded,
                    backgroundColor: cs.primaryFixed,
                    iconColor: cs.onPrimaryFixed,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      s.notifDiagnosticsTitle,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_granted != null)
                    ExpressivePill(
                      icon: _granted == true
                          ? Icons.check_circle_rounded
                          : Icons.warning_amber_rounded,
                      label: _granted == true
                          ? s.permissionGranted
                          : s.permissionDenied,
                      backgroundColor: _granted == true
                          ? cs.secondaryFixed
                          : cs.errorContainer,
                      foregroundColor: _granted == true
                          ? cs.onSecondaryFixed
                          : cs.onErrorContainer,
                      fontWeight: FontWeight.w700,
                      onTap: _granted == false
                          ? () async {
                              AppHaptics.selection();
                              await NotificationService.instance
                                  .requestPermission();
                              await _reload();
                            }
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _metricTile(
                      label: s.classesMetricLabel,
                      value: '$classCount',
                      cs: cs,
                      tt: tt,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile(
                      label: s.deadlinesMetricLabel,
                      value: '$deadlineCount',
                      cs: cs,
                      tt: tt,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _metricTile(
                      label: s.scheduledMetricLabel,
                      value: '${_pending.length}',
                      cs: cs,
                      tt: tt,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.whatWeNotifyTitle,
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final item in s.whatWeNotifyItems) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('• ', style: TextStyle(color: cs.primary)),
                          Expanded(
                            child: Text(
                              item,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                s.upcomingScheduledLabel,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 8),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_pending.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    s.noScheduledAlerts,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              else
                for (final req in _pending.take(4))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule_rounded,
                              size: 16, color: cs.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  req.title ?? '#${req.id}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (req.body != null && req.body!.isNotEmpty)
                                  Text(
                                    req.body!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: () => _sendInstantTest(s.isRu),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.send_rounded, size: 17),
                        label: Text(
                          s.sendInstantTestBtn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: FilledButton.tonalIcon(
                        key: const ValueKey('notif_test_10s_btn'),
                        onPressed: () => _schedule10sTest(s.isRu),
                        style: FilledButton.styleFrom(
                          backgroundColor: cs.primaryFixed,
                          foregroundColor: cs.onPrimaryFixed,
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.timer_10_rounded, size: 18),
                        label: Text(
                          s.schedule10sTestBtn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metricTile({
    required String label,
    required String value,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: tt.titleLarge?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

Future<void> showClassInfoSheet(
  BuildContext context,
  ScheduleEntry entry,
) async {
  final s = context.read<AppState>().s;
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;
  final rooms = entry.classrooms.map(TimetableService.cleanClassroomName).join(', ');
  final teachers = entry.teachers.join(', ');
  final groups = entry.classes.join(', ');

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: _sheetShape,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.classDetailsTitle,
              style: tt.labelSmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.7,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              entry.subject,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            ExpressivePill(
              icon: Icons.schedule_rounded,
              label:
                  '${entry.days.join(', ')} • ${entry.periodStart}–${entry.periodEnd}',
              backgroundColor: cs.primaryFixed,
              foregroundColor: cs.onPrimaryFixed,
              fontWeight: FontWeight.w700,
            ),
            if (teachers.isNotEmpty) ...[
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: cs.surfaceContainerLow,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(s.professorLabel),
                subtitle: Text(teachers),
                onLongPress: () =>
                    _copyWithFeedback(context, teachers, s.copiedToast(teachers)),
              ),
            ],
            if (rooms.isNotEmpty) ...[
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: cs.surfaceContainerLow,
                leading: const Icon(Icons.meeting_room_outlined),
                title: Text(s.classroomLabel),
                subtitle: Text(rooms),
                onTap: () =>
                    _copyWithFeedback(context, rooms, s.copiedToast(rooms)),
              ),
            ],
            if (groups.isNotEmpty) ...[
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: cs.surfaceContainerLow,
                leading: const Icon(Icons.groups_outlined),
                title: Text(s.groupsLabel),
                subtitle: Text(groups),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

Future<void> showTranscriptInfoSheet(
  BuildContext context,
  InsCourseGrade course,
) async {
  final s = context.read<AppState>().s;
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    shape: _sheetShape,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.transcriptDetailsTitle,
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        course.title.isNotEmpty
                            ? course.title
                            : course.courseNumber,
                        style: tt.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ExpressivePill(
                  label: course.grade,
                  backgroundColor: cs.primaryFixed,
                  foregroundColor: cs.onPrimaryFixed,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (course.courseNumber.isNotEmpty)
                  ExpressivePill(
                    label: course.courseNumber,
                    backgroundColor: cs.surfaceContainerHigh,
                    foregroundColor: cs.onSurface,
                  ),
                if (course.credit.isNotEmpty)
                  ExpressivePill(
                    label:
                        '${formatCredits(course.credit)} ${s.creditsFullLabel}',
                    backgroundColor: cs.secondaryFixed,
                    foregroundColor: cs.onSecondaryFixed,
                  ),
                if (course.courseType.isNotEmpty)
                  ExpressivePill(
                    label: course.courseType,
                    backgroundColor: cs.surfaceContainerLow,
                    foregroundColor: cs.onSurfaceVariant,
                  ),
                if (course.semester.isNotEmpty)
                  ExpressivePill(
                    label: course.semester,
                    backgroundColor: cs.surfaceContainerLow,
                    foregroundColor: cs.onSurfaceVariant,
                  ),
              ],
            ),
            if (course.professor.isNotEmpty) ...[
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                tileColor: cs.surfaceContainerLow,
                leading: const Icon(Icons.person_outline_rounded),
                title: Text(s.professorLabel),
                subtitle: Text(course.professor),
                onTap: () => _copyWithFeedback(
                  context,
                  course.professor,
                  s.copiedToast(course.professor),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
