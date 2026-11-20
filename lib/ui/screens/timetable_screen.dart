import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/timetable_service.dart';
import '../../state/app_state.dart';

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
      builder: (ctx) => StatefulBuilder(
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
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => ListTile(
                      title: Text(filtered[i]),
                      trailing: filtered[i] == app.settings.timetableGroup
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(ctx, filtered[i]),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (chosen != null) {
      await app.updateSettings(
        app.settings.copyWith(timetableGroup: chosen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;

    final group = app.settings.timetableGroup;
    final groupEntries = group.isEmpty
        ? <ScheduleEntry>[]
        : TimetableService.filterByClass(app.timetableEntries, group);
    final dayCode = TimetableService.dayNames[_selectedDayIdx];
    final dayEntries = TimetableService.filterByDay(groupEntries, dayCode);
    final next = TimetableService.findNextLesson(groupEntries);

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navTimetable),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ActionChip(
              avatar: const Icon(Icons.groups_rounded, size: 18),
              label: Text(group.isEmpty ? s.selectGroup : group),
              onPressed: () => _pickGroup(context, app),
            ),
          ),
          if (app.isTimetableLoading)
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
              onPressed: () => app.syncTimetable(),
            ),
        ],
      ),
      body: group.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 64, color: cs.onSurfaceVariant),
                    const SizedBox(height: 16),
                    Text(
                      s.noGroupSelected,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _pickGroup(context, app),
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
                padding: const EdgeInsets.all(16),
                children: [
                  if (next != null) _buildNextLessonCard(context, next, cs, s),
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: List.generate(
                      5,
                      (i) => ButtonSegment(
                        value: i,
                        label: Text(s.dayLabels[i]),
                      ),
                    ),
                    selected: {_selectedDayIdx},
                    onSelectionChanged: (sel) =>
                        setState(() => _selectedDayIdx = sel.first),
                  ),
                  const SizedBox(height: 16),
                  if (dayEntries.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: Text(
                          s.noLessonsToday,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                    )
                  else
                    ...dayEntries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _buildLessonCard(context, e, cs),
                        )),
                ],
              ),
            ),
    );
  }

  Widget _buildNextLessonCard(
    BuildContext context,
    (ScheduleEntry, String, int?) next,
    ColorScheme cs,
    dynamic s,
  ) {
    final (entry, dayCode, minsUntil) = next;
    String badge;
    if (minsUntil != null) {
      final h = minsUntil ~/ 60;
      final m = minsUntil % 60;
      badge = h > 0 ? '${h}h ${m}m' : '${m}m';
    } else {
      final idx = TimetableService.dayNames.indexOf(dayCode);
      badge = idx >= 0 ? s.dayLabels[idx] : dayCode;
    }

    return Card(
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bolt_rounded, color: cs.onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  s.nextLesson,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              entry.subject,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: cs.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${entry.periodStart} – ${entry.periodEnd}  •  ${entry.classrooms.isEmpty ? "—" : entry.classrooms.join(", ")}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onPrimaryContainer),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(
      BuildContext context, ScheduleEntry e, ColorScheme cs) {
    return Card.filled(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    e.periodStart,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                  Text(
                    e.periodEnd,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.subject,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (e.teachers.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person_outline_rounded,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            e.teachers.join(', '),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (e.classrooms.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.meeting_room_outlined,
                            size: 16, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          e.classrooms.join(', '),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
