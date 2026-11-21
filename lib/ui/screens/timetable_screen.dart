import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/timetable_service.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_sheets.dart';
import '../widgets/expressive_widgets.dart';
import 'course_detail_screen.dart';

class TimetableScreen extends StatefulWidget {
  const TimetableScreen({super.key});

  @override
  State<TimetableScreen> createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late int _selectedDayIdx;

  @override
  void initState() {
    super.initState();
    final wd = TimetableService.nowTashkent().weekday;
    _selectedDayIdx = (wd >= 1 && wd <= 5) ? wd - 1 : 0;
  }

  Future<void> _pickGroup(BuildContext context, AppState app) async {
    final classes = TimetableService.getClasses(app.timetableEntries);
    if (classes.isEmpty) {
      await app.syncTimetable();
    }
    if (!context.mounted) return;
    final updatedClasses = TimetableService.getClasses(app.timetableEntries);
    String query = '';

    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final sheetCs = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final filtered = updatedClasses
                .where((c) => c.toLowerCase().contains(query.toLowerCase()))
                .toList();
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.7,
              maxChildSize: 0.9,
              builder: (_, scrollCtrl) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: app.s.searchGroup,
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: sheetCs.surfaceContainerLow,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(999),
                          borderSide:
                              BorderSide(color: sheetCs.primary, width: 2),
                        ),
                      ),
                      onChanged: (v) => setSheetState(() => query = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final isCurrent =
                            filtered[i] == app.settings.timetableGroup;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            filtered[i],
                            style: TextStyle(
                              fontWeight:
                                  isCurrent ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          trailing: isCurrent
                              ? Icon(Icons.check_circle_rounded,
                                  color: sheetCs.primary)
                              : null,
                          onTap: () => Navigator.pop(ctx, filtered[i]),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (chosen != null) {
      await app.updateSettings(
        app.settings.copyWith(timetableGroup: chosen),
      );
    }
  }

  String _formattedSelectedDate(dynamic s) {
    final now = TimetableService.nowTashkent();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final target = monday.add(Duration(days: _selectedDayIdx));
    final monName = s.monthShortNames[target.month - 1];
    return '$monName ${target.day}, ${target.year}';
  }

  void _openEntryTarget(
      BuildContext context, AppState app, ScheduleEntry entry) {
    AppHaptics.light();
    final matched = app.findCourseForSubject(entry.subject);
    if (matched != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CourseDetailScreen(course: matched),
        ),
      );
    } else {
      showClassInfoSheet(context, entry);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.activeTabIndex == 2) {
      final requestedDay = app.consumePendingTimetableDay();
      if (requestedDay != null && requestedDay != _selectedDayIdx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedDayIdx = requestedDay);
        });
      }
    }
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final group = app.settings.timetableGroup;
    final groupEntries = group.isEmpty
        ? <ScheduleEntry>[]
        : TimetableService.filterByClass(app.timetableEntries, group);
    final dayCode = TimetableService.dayNames[_selectedDayIdx];
    final dayEntries = TimetableService.filterByDay(groupEntries, dayCode);
    final next = TimetableService.findNextLesson(groupEntries);

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.navTimetable,
        overline: s.portalHeader,
      ),
      body: group.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SquircleIcon(
                      size: 72,
                      radius: 24,
                      iconSize: 36,
                      icon: Icons.calendar_month_rounded,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      s.noGroupSelected,
                      textAlign: TextAlign.center,
                      style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      onPressed: () => _pickGroup(context, app),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 14),
                      ),
                      icon: const Icon(Icons.groups_rounded),
                      label: Text(s.selectGroup),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: () => app.syncTimetable(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Material(
                          color: cs.surfaceContainerHigh,
                          shape: const StadiumBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _pickGroup(context, app),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 9),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.groups_rounded,
                                      size: 18, color: cs.primary),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      group,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.labelMedium?.copyWith(
                                        color: cs.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Icon(Icons.arrow_drop_down_rounded,
                                      size: 18, color: cs.onSurfaceVariant),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      CircleActionButton(
                        icon: Icons.sync_rounded,
                        tooltip: s.refresh,
                        loading: app.isTimetableLoading,
                        backgroundColor: cs.surfaceContainerHigh,
                        onPressed: () => app.syncTimetable(),
                      ),
                    ],
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 14),
                    _buildNextLessonCard(context, app, next, tt, s),
                  ],
                  const SizedBox(height: 18),
                  ExpressiveSegmentedControl<int>(
                    segments: List.generate(
                      5,
                      (i) => ExpressiveSegment(value: i, label: s.dayLabels[i]),
                    ),
                    selected: _selectedDayIdx,
                    onChanged: (idx) => setState(() => _selectedDayIdx = idx),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          s.dayFullNames[_selectedDayIdx],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ExpressivePill(
                        label: s.classesCount(dayEntries.length),
                        backgroundColor: cs.surfaceContainerHigh,
                        foregroundColor: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                      const Spacer(),
                      Text(
                        _formattedSelectedDate(s),
                        style: tt.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (dayEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          s.noLessonsToday,
                          style: tt.titleMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    for (int i = 0; i < dayEntries.length; i++) ...[
                      _buildLessonRow(context, app, dayEntries[i], i, cs, tt, s),
                      if (i != dayEntries.length - 1)
                        const SizedBox(height: 12),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _buildNextLessonCard(
    BuildContext context,
    AppState app,
    (ScheduleEntry, String, int?) next,
    TextTheme tt,
    dynamic s,
  ) {
    final (entry, dayCode, minsUntil) = next;
    String badge;
    if (minsUntil != null) {
      badge = s.formatCountdown(minsUntil);
    } else {
      final idx = TimetableService.dayNames.indexOf(dayCode);
      badge = idx >= 0 ? s.dayLabels[idx] : dayCode;
    }

    return HeroGradientCard(
      borderRadius: 28,
      padding: const EdgeInsets.all(18),
      onTap: () => _openEntryTarget(context, app, entry),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt_rounded,
                        size: 15, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      badge,
                      style: tt.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                s.nextLesson.toUpperCase(),
                style: tt.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            entry.subject,
            style: tt.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroBadge(
                tt,
                Icons.schedule_rounded,
                '${entry.periodStart} – ${entry.periodEnd}',
              ),
              if (entry.classrooms.isNotEmpty)
                _heroBadge(
                  tt,
                  Icons.location_on_outlined,
                  entry.classrooms.join(', '),
                ),
            ],
          ),
          if (entry.teachers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                InitialsAvatar(
                  name: entry.teachers.first,
                  size: 26,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    entry.teachers.join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _heroBadge(TextTheme tt, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.labelSmall?.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonRow(
    BuildContext context,
    AppState app,
    ScheduleEntry e,
    int index,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final isFirst = index == 0;
    final timeBg = isFirst ? cs.surfaceContainerHigh : cs.surfaceContainer;
    final startColor = isFirst ? cs.primary : cs.onSurface;
    final roomBg =
        isFirst ? cs.surfaceContainer : cs.secondaryFixed;
    final roomFg =
        isFirst ? cs.primary : cs.onSecondaryFixed;
    final roomsText =
        e.classrooms.map(TimetableService.cleanClassroomName).join(', ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: timeBg,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  e.periodStart,
                  style: tt.titleSmall?.copyWith(
                    color: startColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Container(
                  width: 16,
                  height: 2,
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  decoration: BoxDecoration(
                    color: startColor.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Text(
                  e.periodEnd,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ExpressiveCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              onTap: () => _openEntryTarget(context, app, e),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          e.subject,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (e.classrooms.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        ExpressivePill(
                          label: e.classrooms.join(', '),
                          backgroundColor: roomBg,
                          foregroundColor: roomFg,
                          fontWeight: FontWeight.w700,
                          onLongPress: () async {
                            AppHaptics.medium();
                            await Clipboard.setData(
                                ClipboardData(text: roomsText));
                            if (context.mounted) {
                              showQuickToast(context, s.copiedToast(roomsText));
                            }
                          },
                        ),
                      ],
                    ],
                  ),
                  if (e.teachers.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 16,
                          color: isFirst ? cs.primary : cs.secondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e.teachers.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
