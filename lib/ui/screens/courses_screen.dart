import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/eclass_service.dart';
import '../../state/app_state.dart';
import '../widgets/expressive_widgets.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  (Color bg, Color fg, IconData icon) _courseAccent(
      Course course, ColorScheme cs) {
    if (!course.isCurrent) {
      return (cs.surfaceContainerHigh, cs.onSurfaceVariant, Icons.book_rounded);
    }
    const icons = [
      Icons.terminal_rounded,
      Icons.memory_rounded,
      Icons.hub_rounded,
      Icons.layers_rounded,
      Icons.menu_book_rounded,
    ];
    final idx = course.id.hashCode.abs() % 4;
    final icon = icons[course.id.hashCode.abs() % icons.length];
    switch (idx) {
      case 0:
        return (cs.primaryFixed, cs.onPrimaryFixed, icon);
      case 1:
        return (cs.secondaryFixed, cs.onSecondaryFixed, icon);
      case 2:
        return (cs.surfaceContainerHigh, cs.primary, icon);
      default:
        return (cs.tertiaryFixed, cs.onTertiaryFixed, icon);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final visible = app.visibleCourses;
    final hasPastCourses = app.courses.any((c) => !c.isCurrent);

    final studentName = (app.insData?.studentInfo['name'] ?? '').trim();
    final firstName = studentName.isEmpty
        ? ''
        : formatPersonName(studentName.split(RegExp(r'\s+')).first);
    final gradeYear = (app.insData?.studentInfo['grade_year'] ?? '').trim();
    final insGpa = formatGpa(app.insData?.gpaInfo['gpa'] ?? '');

    final visibleIds = visible.map((c) => c.id).toSet();
    final totalPending = app.allAssignments
        .where((a) => visibleIds.contains(a.courseId) && !a.isSubmitted)
        .length;

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.navCourses,
        overline: s.portalHeader,
        actions: [
          CircleActionButton(
            icon: Icons.sync_rounded,
            tooltip: s.refresh,
            loading: app.isSyncing,
            onPressed: () => app.syncCourses(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => app.syncCourses(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: [
            if (firstName.isNotEmpty) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.welcomeBack,
                          style: tt.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.helloUser(firstName),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (gradeYear.isNotEmpty)
                    ExpressivePill(
                      icon: Icons.school_outlined,
                      label: s.yearLabel(gradeYear),
                      backgroundColor: cs.primaryFixed,
                      foregroundColor: cs.onPrimaryFixed,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (hasPastCourses) ...[
              ExpressiveSegmentedControl<bool>(
                activeColor: cs.primaryContainer,
                activeForeground: cs.onPrimaryContainer,
                segments: [
                  ExpressiveSegment(value: false, label: s.currentSemester),
                  ExpressiveSegment(value: true, label: s.allCourses),
                ],
                selected: app.settings.showAllCourses,
                onChanged: (val) => app.updateSettings(
                  app.settings.copyWith(showAllCourses: val),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (insGpa.isNotEmpty || visible.isNotEmpty) ...[
              _buildGlanceCard(
                context: context,
                cs: cs,
                tt: tt,
                s: s,
                insGpa: insGpa,
                courseCount: visible.length,
                totalPending: totalPending,
              ),
              const SizedBox(height: 16),
            ],
            if (visible.isEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).size.height * 0.14,
                  left: 16,
                  right: 16,
                ),
                child: Column(
                  children: [
                    SquircleIcon(
                      size: 68,
                      radius: 22,
                      iconSize: 34,
                      icon: Icons.menu_book_outlined,
                      backgroundColor: cs.surfaceContainerHigh,
                      iconColor: cs.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.coursesEmpty,
                      textAlign: TextAlign.center,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              )
            else ...[
              for (int i = 0; i < visible.length; i++) ...[
                _buildCourseCard(
                  context: context,
                  course: visible[i],
                  schedule: app.courseScheduleFor(visible[i]),
                  pendingCount: app.allAssignments
                      .where(
                          (a) => a.courseId == visible[i].id && !a.isSubmitted)
                      .length,
                  cs: cs,
                  tt: tt,
                  s: s,
                ),
                if (i != visible.length - 1) const SizedBox(height: 12),
              ],
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      s.tapCourseHint,
                      textAlign: TextAlign.center,
                      style: tt.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGlanceCard({
    required BuildContext context,
    required ColorScheme cs,
    required TextTheme tt,
    required dynamic s,
    required String insGpa,
    required int courseCount,
    required int totalPending,
  }) {
    final hasGpa = insGpa.isNotEmpty;
    final numericGpa = double.tryParse(insGpa) != null;

    return ExpressiveCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          SquircleIcon(
            size: 44,
            radius: 14,
            iconSize: 22,
            icon: hasGpa ? Icons.auto_graph_rounded : Icons.school_rounded,
            backgroundColor: cs.primaryFixed,
            iconColor: cs.onPrimaryFixed,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasGpa ? s.cumulativeGpaCaps : s.coursesSummaryLabel,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      hasGpa ? insGpa : '$courseCount',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasGpa && numericGpa) ...[
                      const SizedBox(width: 4),
                      Text(
                        '/ 4.50',
                        style: tt.labelMedium?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ExpressivePill(
            label: hasGpa
                ? s.activeCoursesCount(courseCount)
                : (totalPending > 0
                    ? s.tasksDueCount(totalPending)
                    : s.allCaughtUp),
            backgroundColor: (!hasGpa && totalPending > 0)
                ? cs.errorContainer
                : cs.surfaceContainerHigh,
            foregroundColor: (!hasGpa && totalPending > 0)
                ? cs.onErrorContainer
                : cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard({
    required BuildContext context,
    required Course course,
    required CourseScheduleInfo? schedule,
    required int pendingCount,
    required ColorScheme cs,
    required TextTheme tt,
    required dynamic s,
  }) {
    final (iconBg, iconFg, iconData) = _courseAccent(course, cs);
    final professor = (schedule?.teacher.isNotEmpty == true)
        ? schedule!.teacher
        : course.professor.trim();
    final classroom = schedule?.classroomSummary ?? '';
    final slots = schedule?.scheduleSummary ?? '';

    Color statusBg;
    Color statusFg;
    IconData statusIcon;
    String statusText;

    if (pendingCount >= 2) {
      statusBg = cs.errorContainer;
      statusFg = cs.onErrorContainer;
      statusIcon = Icons.schedule_rounded;
      statusText = s.tasksDueCount(pendingCount);
    } else if (pendingCount == 1) {
      statusBg = cs.tertiaryFixed;
      statusFg = cs.onTertiaryFixed;
      statusIcon = Icons.assignment_late_outlined;
      statusText = s.tasksDueCount(1);
    } else {
      statusBg = cs.surfaceContainerHigh;
      statusFg = cs.onSurfaceVariant;
      statusIcon = Icons.check_circle_outline_rounded;
      statusText = s.allCaughtUp;
    }

    return ExpressiveCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(course: course),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SquircleIcon(
                size: 48,
                radius: 16,
                iconSize: 24,
                icon: iconData,
                backgroundColor: iconBg,
                iconColor: iconFg,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            course.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (course.overviewGrade != null &&
                            course.overviewGrade!.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ExpressivePill(
                            label: course.overviewGrade!,
                            backgroundColor: cs.surfaceContainerHigh,
                            foregroundColor: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ],
                      ],
                    ),
                    if (professor.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 14,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              professor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (classroom.isNotEmpty || slots.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            Icons.meeting_room_outlined,
                            size: 14,
                            color: cs.secondary,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              [
                                if (classroom.isNotEmpty) classroom,
                                if (slots.isNotEmpty) slots,
                              ].join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (!course.isCurrent) ...[
                      const SizedBox(height: 6),
                      ExpressivePill(
                        label: s.archiveTag,
                        backgroundColor: cs.surfaceContainerHigh,
                        foregroundColor: cs.onSurfaceVariant,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        fontSize: 11,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: ExpressivePill(
                    icon: statusIcon,
                    label: statusText,
                    backgroundColor: statusBg,
                    foregroundColor: statusFg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => launchUrl(
                      Uri.parse(EclassService.syllabusUrl(course.id)),
                      mode: LaunchMode.externalApplication,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            s.syllabus,
                            style: tt.labelMedium?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
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
