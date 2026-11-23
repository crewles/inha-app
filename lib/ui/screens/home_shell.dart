import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_logger.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import 'assignments_screen.dart';
import 'courses_screen.dart';
import 'ins_screen.dart';
import 'logs_screen.dart';
import 'settings_screen.dart';
import 'timetable_screen.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  static const _pages = <Widget>[
    CoursesScreen(),
    AssignmentsScreen(),
    TimetableScreen(),
    InsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final index = app.activeTabIndex.clamp(0, _pages.length - 1);

    return Scaffold(
      body: AnimatedBuilder(
        animation: AppLogger.instance,
        builder: (context, _) {
          final showCrashBanner = AppLogger.instance.hasPendingCrashPrompt;
          return Column(
            children: [
              if (showCrashBanner)
                SafeArea(
                  bottom: false,
                  child: Container(
                    key: const ValueKey('crash_prompt_banner'),
                    margin: const EdgeInsets.fromLTRB(12, 8, 12, 6),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.report_problem_rounded,
                              color: cs.onErrorContainer,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.crashBannerTitle,
                                    style: tt.titleSmall?.copyWith(
                                      color: cs.onErrorContainer,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    s.crashBannerDesc,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onErrorContainer
                                          .withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            FilledButton.icon(
                              key: const ValueKey('crash_report_github_btn'),
                              onPressed: () async {
                                AppHaptics.medium();
                                await LogsScreen.openGithubIssue(
                                  context,
                                  fallbackToast: s.logsReportOpenFailedToast,
                                );
                                await AppLogger.instance.dismissCrashPrompt();
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.error,
                                foregroundColor: cs.onError,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: const Size(0, 36),
                              ),
                              icon: const Icon(Icons.open_in_new_rounded,
                                  size: 16),
                              label: Text(
                                s.crashBannerReportBtn,
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onError,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            FilledButton.tonalIcon(
                              key: const ValueKey('crash_enable_logs_btn'),
                              onPressed: () async {
                                AppHaptics.medium();
                                await app.updateSettings(
                                  app.settings
                                      .copyWith(diagnosticsEnabled: true),
                                );
                                await AppLogger.instance.dismissCrashPrompt();
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const LogsScreen(),
                                    ),
                                  );
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: cs.onErrorContainer
                                    .withValues(alpha: 0.14),
                                foregroundColor: cs.onErrorContainer,
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: const Size(0, 36),
                              ),
                              icon: const Icon(Icons.bug_report_rounded,
                                  size: 16),
                              label: Text(
                                s.crashBannerEnableBtn,
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                AppHaptics.selection();
                                await AppLogger.instance.dismissCrashPrompt();
                                if (context.mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const LogsScreen(),
                                    ),
                                  );
                                }
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cs.onErrorContainer,
                                side: BorderSide(
                                  color: cs.onErrorContainer
                                      .withValues(alpha: 0.4),
                                ),
                                shape: const StadiumBorder(),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: const Size(0, 36),
                              ),
                              child: Text(
                                s.crashBannerViewOnlyBtn,
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onErrorContainer,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            TextButton(
                              key: const ValueKey('crash_dismiss_btn'),
                              onPressed: () {
                                AppHaptics.light();
                                AppLogger.instance.dismissCrashPrompt();
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: cs.onErrorContainer,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 8),
                                minimumSize: const Size(0, 36),
                              ),
                              child: Text(
                                s.crashBannerDismissBtn,
                                style: tt.labelMedium?.copyWith(
                                  color: cs.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: IndexedStack(index: index, children: _pages),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: cs.outlineVariant.withValues(alpha: 0.35),
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) {
            AppHaptics.selection();
            ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
            app.openTab(i);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.school_outlined),
              selectedIcon: const Icon(Icons.school_rounded),
              label: s.navCourses,
            ),
            NavigationDestination(
              icon: const Icon(Icons.assignment_outlined),
              selectedIcon: const Icon(Icons.assignment_rounded),
              label: s.navAssignments,
            ),
            NavigationDestination(
              icon: const Icon(Icons.calendar_today_outlined),
              selectedIcon: const Icon(Icons.calendar_today_rounded),
              label: s.navTimetable,
            ),
            NavigationDestination(
              icon: const Icon(Icons.analytics_outlined),
              selectedIcon: const Icon(Icons.analytics_rounded),
              label: s.navIns,
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded),
              label: s.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
