import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/eclass_service.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_sheets.dart';
import '../widgets/expressive_widgets.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  String _courseBadgeCode(Course course) {
    final codeMatch =
        RegExp(r'\b([A-Z]{2,4}\s?\d{3,4}[A-Z]?)\b').firstMatch(course.name);
    if (codeMatch != null) {
      return codeMatch.group(1)!.replaceAll(' ', '');
    }
    const stopWords = {'and', 'of', 'the', 'in', 'to', 'for', 'with'};
    final tokens = course.name
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !stopWords.contains(w.toLowerCase()))
        .toList();
    if (tokens.isEmpty) return 'IUT';
    final letters = StringBuffer();
    String trailingNum = '';
    for (final t in tokens) {
      if (RegExp(r'^\d+$').hasMatch(t)) {
        trailingNum = t;
      } else if (letters.length < 4) {
        letters.write(t[0].toUpperCase());
      }
    }
    final base = letters.isEmpty ? 'IUT' : letters.toString();
    return trailingNum.isEmpty ? base : '$base $trailingNum';
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
    final activeAssigns = app.activeAssignments;
    final totalPending = activeAssigns
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
            if (app.availableUpdate != null && !app.updateBannerDismissed) ...[
              ExpressiveCard(
                borderRadius: 20,
                color: cs.primaryFixed,
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                onTap: () {
                  AppHaptics.light();
                  showUpdateAvailableSheet(context, app.availableUpdate!);
                },
                child: Row(
                  children: [
                    Icon(Icons.system_update_rounded,
                        color: cs.onPrimaryFixed, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.updateAvailableBadge(
                                app.availableUpdate!.version),
                            style: tt.labelLarge?.copyWith(
                              color: cs.onPrimaryFixed,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            s.updateAvailableTitle,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onPrimaryFixedVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.close_rounded,
                          size: 18, color: cs.onPrimaryFixed),
                      onPressed: () {
                        AppHaptics.selection();
                        app.dismissUpdateBanner();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                app: app,
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
                  app: app,
                  course: visible[i],
                  schedule: app.courseScheduleFor(visible[i]),
                  pendingCount: activeAssigns
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
    required AppState app,
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
      key: const ValueKey('courses_glance_card'),
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      onTap: () {
        AppHaptics.light();
        app.openTab(hasGpa ? 3 : 1);
      },
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
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard({
    required BuildContext context,
    required AppState app,
    required Course course,
    required CourseScheduleInfo? schedule,
    required int pendingCount,
    required ColorScheme cs,
    required TextTheme tt,
    required dynamic s,
  }) {
    final badgeCode = _courseBadgeCode(course);
    final professor = (schedule?.teacher.isNotEmpty == true)
        ? schedule!.teacher
        : course.professor.trim();
    final classroom = schedule?.classroomSummary ?? '';
    final slots = schedule?.scheduleSummary ?? '';
    final firstSlot =
        slots.isNotEmpty ? slots.split(',').first.trim() : '';
    final hasGrade =
        course.overviewGrade != null && course.overviewGrade!.trim().isNotEmpty;

    final statusIcon = pendingCount > 0
        ? Icons.assignment_outlined
        : Icons.check_circle_outline_rounded;
    final statusBase =
        pendingCount > 0 ? s.tasksDueCount(pendingCount) : s.allCaughtUp;
    final statusText =
        firstSlot.isNotEmpty ? '$statusBase • $firstSlot' : statusBase;

    void openCourse({int tab = 0}) {
      AppHaptics.light();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(course: course, initialTab: tab),
        ),
      );
    }

    void openSyllabusUrl() {
      AppHaptics.light();
      launchUrl(
        Uri.parse(EclassService.syllabusUrl(course.id)),
        mode: LaunchMode.externalApplication,
      );
    }

    return ExpressiveCard(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      onTap: () => openCourse(tab: 0),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 14,
            bottom: 14,
            child: Container(
              width: 5,
              decoration: BoxDecoration(
                color: course.isCurrent ? cs.primary : cs.outlineVariant,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(6),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Top Metadata Row
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ExpressivePill(
                            label: badgeCode,
                            backgroundColor: course.isCurrent
                                ? cs.primaryFixed
                                : cs.surfaceContainerHigh,
                            foregroundColor: course.isCurrent
                                ? cs.onPrimaryFixed
                                : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 11, vertical: 4),
                          ),
                          if (hasGrade)
                            ExpressivePill(
                              label: course.overviewGrade!,
                              backgroundColor: cs.surfaceContainerLow,
                              foregroundColor: cs.primary,
                              fontWeight: FontWeight.w700,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              onTap: () => openCourse(tab: 1),
                            )
                          else
                            ExpressivePill(
                              label: course.isCurrent
                                  ? s.currentCourseTag
                                  : s.archiveTag,
                              backgroundColor: cs.surfaceContainerLow,
                              foregroundColor: cs.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                            ),
                          if (hasGrade && !course.isCurrent)
                            ExpressivePill(
                              label: s.archiveTag,
                              backgroundColor: cs.surfaceContainerLow,
                              foregroundColor: cs.onSurfaceVariant,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 4),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<int>(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        icon: Icon(
                          Icons.more_vert_rounded,
                          size: 20,
                          color: cs.onSurfaceVariant,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        onSelected: (val) {
                          if (val == 4) {
                            openSyllabusUrl();
                          } else {
                            openCourse(tab: val);
                          }
                        },
                        itemBuilder: (ctx) => [
                          PopupMenuItem<int>(
                            value: 0,
                            child: Row(
                              children: [
                                Icon(Icons.assignment_outlined,
                                    size: 18, color: cs.onSurface),
                                const SizedBox(width: 10),
                                Text(s.tabAssignments),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 1,
                            child: Row(
                              children: [
                                Icon(Icons.grade_outlined,
                                    size: 18, color: cs.onSurface),
                                const SizedBox(width: 10),
                                Text(s.tabGrades),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 2,
                            child: Row(
                              children: [
                                Icon(Icons.fact_check_outlined,
                                    size: 18, color: cs.onSurface),
                                const SizedBox(width: 10),
                                Text(s.tabAttendance),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 3,
                            child: Row(
                              children: [
                                Icon(Icons.folder_outlined,
                                    size: 18, color: cs.onSurface),
                                const SizedBox(width: 10),
                                Text(s.tabFiles),
                              ],
                            ),
                          ),
                          PopupMenuItem<int>(
                            value: 4,
                            child: Row(
                              children: [
                                Icon(Icons.description_outlined,
                                    size: 18, color: cs.primary),
                                const SizedBox(width: 10),
                                Text(s.syllabus),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 2. Course Title
                Text(
                  course.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),

                // 3. Schedule & Instructor Row
                if (professor.isNotEmpty ||
                    classroom.isNotEmpty ||
                    slots.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (professor.isNotEmpty)
                        GestureDetector(
                          onLongPress: () async {
                            AppHaptics.medium();
                            await Clipboard.setData(
                                ClipboardData(text: professor));
                            if (context.mounted) {
                              showQuickToast(context, s.copiedToast(professor));
                            }
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  professor,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (classroom.isNotEmpty || slots.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 1),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.meeting_room_outlined,
                                size: 15,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
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
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 10),

                // 4. Status Info Pill
                Material(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => openCourse(tab: 0),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            statusIcon,
                            size: 15,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              statusText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelMedium?.copyWith(
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
                const SizedBox(height: 12),

                // 5. Bottom Action Row
                Container(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.25),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: openSyllabusUrl,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 16,
                                color: cs.onSurfaceVariant,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                s.syllabus,
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Material(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(999),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => openCourse(tab: 0),
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                s.openCourseBtn,
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 15,
                                color: cs.onPrimary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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
