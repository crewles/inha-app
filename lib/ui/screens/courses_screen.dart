import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import 'course_detail_screen.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final visible = app.visibleCourses;
    final hasPastCourses = app.courses.any((c) => !c.isCurrent);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navCourses),
        actions: [
          if (app.isSyncing)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: s.refresh,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () => app.syncCourses(),
            ),
        ],
      ),
      body: Column(
        children: [
          if (hasPastCourses)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  segments: [
                    ButtonSegment(value: false, label: Text(s.currentSemester)),
                    ButtonSegment(value: true, label: Text(s.allCourses)),
                  ],
                  selected: {app.settings.showAllCourses},
                  onSelectionChanged: (sel) => app.updateSettings(
                    app.settings.copyWith(showAllCourses: sel.first),
                  ),
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => app.syncCourses(),
              child: visible.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.25),
                        Icon(Icons.menu_book_outlined,
                            size: 64, color: cs.onSurfaceVariant),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            s.coursesEmpty,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: visible.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final Course course = visible[index];
                        final pendingCount = app.allAssignments
                            .where(
                                (a) => a.courseId == course.id && !a.isSubmitted)
                            .length;

                        return Card.filled(
                          clipBehavior: Clip.antiAlias,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    CourseDetailScreen(course: course),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: course.isCurrent
                                          ? cs.primaryContainer
                                          : cs.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      Icons.book_rounded,
                                      color: course.isCurrent
                                          ? cs.onPrimaryContainer
                                          : cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          course.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w600),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          course.overviewGrade != null
                                              ? 'ID: ${course.id} • ${course.overviewGrade}'
                                              : 'ID: ${course.id}',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: cs.onSurfaceVariant),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (pendingCount > 0)
                                    Badge.count(
                                      count: pendingCount,
                                      backgroundColor: cs.error,
                                      textColor: cs.onError,
                                    ),
                                  const SizedBox(width: 8),
                                  Icon(Icons.chevron_right_rounded,
                                      color: cs.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
