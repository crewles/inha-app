import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/timetable_service.dart';
import '../../services/update_service.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_widgets.dart';

class WidgetGalleryScreen extends StatelessWidget {
  const WidgetGalleryScreen({super.key});

  Future<void> _pinWidget(
    BuildContext context,
    String key,
    dynamic s,
  ) async {
    AppHaptics.medium();
    final sent = await UpdateService.requestPinWidget(key);
    if (!context.mounted) return;
    showQuickToast(
      context,
      sent ? s.widgetPinSentToast : s.widgetPinFallbackToast,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final group = app.settings.timetableGroup;
    final groupEntries = group.isEmpty
        ? <ScheduleEntry>[]
        : TimetableService.filterByClass(app.timetableEntries, group);
    final next = TimetableService.findNextLesson(groupEntries);

    final now = TimetableService.nowTashkent();
    final todayIdx = now.weekday <= 5 ? now.weekday - 1 : 0;
    final todayCode = TimetableService.dayNames[todayIdx];
    final todayLessons = TimetableService.filterByDay(groupEntries, todayCode);

    final gpa = formatGpa(app.insData?.gpaInfo['gpa'] ?? '');
    final acq = formatCredits(app.insData?.gpaInfo['credits_acquired'] ?? '');
    final att = formatCredits(app.insData?.gpaInfo['credits_attempted'] ?? '');

    final pending = Assignment.sortForDisplay(
      app.activeAssignments.where((a) => !a.isSubmitted).toList(),
      pendingMode: true,
    );

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.widgetGalleryTitle,
        overline: s.portalHeader,
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        children: [
          Text(
            s.widgetGallerySubtitle,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 18),

          // 1. Next Lecture Glance (4x2) — Stitch #11
          _widgetSection(
            context: context,
            title: s.widgetNextLectureTitle,
            subtitle: s.widgetNextLectureDesc,
            sizeLabel: '4×2',
            widgetKey: 'next_lecture',
            preview: HeroGradientCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(16),
              child: next == null
                  ? Row(
                      children: [
                        const Icon(Icons.event_available_rounded,
                            color: Colors.white),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            group.isEmpty
                                ? s.noGroupSelected
                                : s.noLessonsToday,
                            style: tt.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                next.$3 != null
                                    ? s.formatCountdown(next.$3!)
                                    : next.$2,
                                style: tt.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${next.$1.periodStart}–${next.$1.periodEnd}',
                              style: tt.labelMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          next.$1.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (next.$1.classrooms.isNotEmpty)
                              next.$1.classrooms
                                  .map(TimetableService.cleanClassroomName)
                                  .join(', '),
                            if (next.$1.teachers.isNotEmpty)
                              next.$1.teachers.first,
                          ].join(' • '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
            ),
            s: s,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 18),

          // 2. Today's Schedule Timeline (4x3) — Stitch #11
          _widgetSection(
            context: context,
            title: s.widgetTodayScheduleTitle,
            subtitle: s.widgetTodayScheduleDesc,
            sizeLabel: '4×3',
            widgetKey: 'today_schedule',
            preview: ExpressiveCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.dayFullNames[todayIdx],
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      ExpressivePill(
                        label: s.classesCount(todayLessons.length),
                        backgroundColor: cs.primaryFixed,
                        foregroundColor: cs.onPrimaryFixed,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (todayLessons.isEmpty)
                    Text(
                      s.noLessonsToday,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    )
                  else
                    for (final lesson in todayLessons.take(3)) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Text(
                              lesson.periodStart,
                              style: tt.labelMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                lesson.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (lesson.classrooms.isNotEmpty)
                              Text(
                                TimetableService.cleanClassroomName(
                                    lesson.classrooms.first),
                                style: tt.labelSmall?.copyWith(
                                  color: cs.secondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                ],
              ),
            ),
            s: s,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 18),

          // 3. INS Academic Dial (2x2) — Stitch #11
          _widgetSection(
            context: context,
            title: s.widgetInsAcademicTitle,
            subtitle: s.widgetInsAcademicDesc,
            sizeLabel: '2×2',
            widgetKey: 'ins_academic',
            preview: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 196,
                child: ExpressiveCard(
                  borderRadius: 22,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.analytics_rounded,
                              size: 16, color: cs.primary),
                          const SizedBox(width: 6),
                          Text(
                            'INS GPA',
                            style: tt.labelSmall?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            gpa.isEmpty ? '—' : gpa,
                            style: tt.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '/ 4.5',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        acq.isNotEmpty
                            ? '${s.creditsLabel}: $acq${att.isNotEmpty ? '/$att' : ''}'
                            : s.activeCoursesCount(app.visibleCourses.length),
                        style: tt.labelSmall?.copyWith(
                          color: cs.secondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            s: s,
            cs: cs,
            tt: tt,
          ),
          const SizedBox(height: 18),

          // 4. Deadlines & Assignments (4x2) — Stitch #11
          _widgetSection(
            context: context,
            title: s.widgetDeadlinesTitle,
            subtitle: s.widgetDeadlinesDesc,
            sizeLabel: '4×2',
            widgetKey: 'deadlines',
            preview: ExpressiveCard(
              borderRadius: 22,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.navAssignments,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      ExpressivePill(
                        label: s.tasksDueCount(pending.length),
                        backgroundColor: pending.isEmpty
                            ? cs.secondaryFixed
                            : cs.tertiaryFixed,
                        foregroundColor: pending.isEmpty
                            ? cs.onSecondaryFixed
                            : cs.onTertiaryFixed,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (pending.isEmpty)
                    Text(
                      s.allCaughtUp,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    )
                  else
                    for (final a in pending.take(2))
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: cs.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              a.due,
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
            s: s,
            cs: cs,
            tt: tt,
          ),
        ],
      ),
    );
  }

  Widget _widgetSection({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String sizeLabel,
    required String widgetKey,
    required Widget preview,
    required dynamic s,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Column(
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
                      Flexible(
                        child: Text(
                          title,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ExpressivePill(
                        label: sizeLabel,
                        backgroundColor: cs.surfaceContainerHigh,
                        foregroundColor: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ],
                  ),
                  Text(
                    subtitle,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: ValueKey('pin_widget_$widgetKey'),
              onPressed: () => _pinWidget(context, widgetKey, s),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primaryFixed,
                foregroundColor: cs.onPrimaryFixed,
                shape: const StadiumBorder(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: const Icon(Icons.add_to_home_screen_rounded, size: 16),
              label: Text(
                s.addToHomeBtn,
                style: tt.labelMedium?.copyWith(
                  color: cs.onPrimaryFixed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        preview,
      ],
    );
  }
}
