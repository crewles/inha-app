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

  // Matches android/app/src/main/res/values/colors.xml 1:1.
  static const Color _wBg = Color(0xFF171B26);
  static const Color _wRowBg = Color(0xFF222838);
  static const Color _wBorder = Color(0xFF2F374E);
  static const Color _wText = Color(0xFFEEF0FF);
  static const Color _wMuted = Color(0xFF9BA5C0);
  static const Color _wPrimary = Color(0xFFB7C4FF);
  static const Color _wPillPrimaryBg = Color(0xFF28458A);
  static const Color _wPillPrimaryFg = Color(0xFFDCE1FF);
  static const Color _wPillSecondaryBg = Color(0xFF1E4368);
  static const Color _wPillSecondaryFg = Color(0xFFCCE5FF);
  static const Color _wPillErrorBg = Color(0xFF691B22);
  static const Color _wPillErrorFg = Color(0xFFFFDAD6);
  static const Color _wDotUrgent = Color(0xFFF87171);
  static const Color _wDotSoon = Color(0xFFFB923C);
  static const Color _wDotNormal = Color(0xFF4ADE80);
  static const List<Color> _wHeroColors = [
    Color(0xFF202F58),
    Color(0xFF223A66),
    Color(0xFF234D69),
  ];

  static Widget _nativeWidgetCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _wBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _wBorder, width: 1),
      ),
      child: child,
    );
  }

  static Widget _nativePill({
    required String label,
    required Color backgroundColor,
    required Color foregroundColor,
    double fontSize = 11,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foregroundColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _nativeHeroCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _wHeroColors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -28,
              right: -28,
              child: Container(
                width: 136,
                height: 136,
                decoration: const BoxDecoration(
                  color: Color(0x16FFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Positioned(
              left: -24,
              bottom: -34,
              child: Container(
                width: 112,
                height: 112,
                decoration: const BoxDecoration(
                  color: Color(0x16FFFFFF),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

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
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

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

          // 1. Next Lecture Glance (4x2) — matches widget_next_lecture.xml
          _widgetSection(
            context: context,
            title: s.widgetNextLectureTitle,
            subtitle: s.widgetNextLectureDesc,
            sizeLabel: '4×2',
            widgetKey: 'next_lecture',
            preview: _nativeHeroCard(
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
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
                                  horizontal: 11, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                next.$3 != null
                                    ? s.formatCountdown(next.$3!)
                                    : next.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              '${next.$1.periodStart}–${next.$1.periodEnd}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          next.$1.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
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
                          style: const TextStyle(
                            color: Color(0xFFD9E2F5),
                            fontSize: 12,
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

          // 2. Today's Schedule Timeline (4x3) — matches widget_today_schedule.xml
          _widgetSection(
            context: context,
            title: s.widgetTodayScheduleTitle,
            subtitle: s.widgetTodayScheduleDesc,
            sizeLabel: '4×3',
            widgetKey: 'today_schedule',
            preview: _nativeWidgetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          s.dayFullNames[todayIdx],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _wText,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _nativePill(
                        label: s.classesCount(todayLessons.length),
                        backgroundColor: _wPillPrimaryBg,
                        foregroundColor: _wPillPrimaryFg,
                      ),
                    ],
                  ),
                  if (todayLessons.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Text(
                        s.noLessonsToday,
                        style: const TextStyle(
                          color: _wMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 2),
                    for (final lesson in todayLessons.take(4))
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _wRowBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 46,
                              child: Text(
                                lesson.periodStart,
                                style: const TextStyle(
                                  color: _wPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lesson.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _wText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (lesson.classrooms.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                TimetableService.cleanClassroomName(
                                    lesson.classrooms.first),
                                style: const TextStyle(
                                  color: _wMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
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

          // 3. INS Academic Dial (2x2) — matches widget_ins_academic.xml
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
                child: _nativeWidgetCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'INS GPA',
                        style: TextStyle(
                          color: _wPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              gpa.isEmpty ? '—' : gpa,
                              style: const TextStyle(
                                color: _wText,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 3),
                            const Text(
                              '/ 4.5',
                              style: TextStyle(
                                color: _wMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        acq.isNotEmpty
                            ? '${s.creditsLabel}: $acq${att.isNotEmpty ? '/$att' : ''}'
                            : '${s.creditsLabel}: —',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _wMuted,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _nativePill(
                        label: s.activeCoursesCount(app.visibleCourses.length),
                        backgroundColor: _wPillPrimaryBg,
                        foregroundColor: _wPillPrimaryFg,
                        fontSize: 10,
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

          // 4. Deadlines & Assignments (4x2) — matches widget_deadlines.xml
          _widgetSection(
            context: context,
            title: s.widgetDeadlinesTitle,
            subtitle: s.widgetDeadlinesDesc,
            sizeLabel: '4×2',
            widgetKey: 'deadlines',
            preview: _nativeWidgetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.navAssignments,
                        style: const TextStyle(
                          color: _wText,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      _nativePill(
                        label: s.tasksDueCount(pending.length),
                        backgroundColor:
                            pending.isEmpty ? _wPillSecondaryBg : _wPillErrorBg,
                        foregroundColor:
                            pending.isEmpty ? _wPillSecondaryFg : _wPillErrorFg,
                      ),
                    ],
                  ),
                  if (pending.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 14, bottom: 6),
                      child: Text(
                        s.allCaughtUp,
                        style: const TextStyle(
                          color: _wMuted,
                          fontSize: 13,
                        ),
                      ),
                    )
                  else ...[
                    const SizedBox(height: 2),
                    for (final a in pending.take(3))
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: _wRowBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: (a.dueTimestamp > 0 &&
                                        a.dueTimestamp - nowSec <= 48 * 3600)
                                    ? _wDotUrgent
                                    : (a.dueTimestamp > 0 &&
                                            a.dueTimestamp - nowSec <=
                                                7 * 86400)
                                        ? _wDotSoon
                                        : _wDotNormal,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: _wText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (a.due.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Text(
                                a.due,
                                style: const TextStyle(
                                  color: _wMuted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
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
