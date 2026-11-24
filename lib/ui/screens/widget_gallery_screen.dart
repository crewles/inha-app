import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/timetable_service.dart';
import '../../services/update_service.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_widgets.dart';

/// Exact 1:1 mirror of `android/app/src/main/res/values/colors.xml`
/// and `android/app/src/main/res/values-night/colors.xml`.
class _WidgetPalette {
  final Color bg;
  final Color rowBg;
  final Color border;
  final Color text;
  final Color muted;
  final Color primary;
  final Color primaryAccent;
  final Color barInactive;
  final Color iconBg;
  final Color iconFg;
  final Color pillPrimaryBg;
  final Color pillPrimaryFg;
  final Color pillRoomBg;
  final Color pillRoomFg;
  final Color pillErrorBg;
  final Color pillErrorFg;
  final Color pillOkBg;
  final Color pillOkFg;
  final Color barUrgent;
  final Color dueUrgentBg;
  final Color dueUrgentFg;
  final Color barSoon;
  final Color dueSoonBg;
  final Color dueSoonFg;
  final Color barNormal;
  final Color dueNormalBg;
  final Color dueNormalFg;
  final Color progressTrack;
  final Color progressFill;
  final Color heroStart;
  final Color heroCenter;
  final Color heroEnd;
  final List<Color> wallpaperFrame;
  final Color wallpaperBorder;

  const _WidgetPalette({
    required this.bg,
    required this.rowBg,
    required this.border,
    required this.text,
    required this.muted,
    required this.primary,
    required this.primaryAccent,
    required this.barInactive,
    required this.iconBg,
    required this.iconFg,
    required this.pillPrimaryBg,
    required this.pillPrimaryFg,
    required this.pillRoomBg,
    required this.pillRoomFg,
    required this.pillErrorBg,
    required this.pillErrorFg,
    required this.pillOkBg,
    required this.pillOkFg,
    required this.barUrgent,
    required this.dueUrgentBg,
    required this.dueUrgentFg,
    required this.barSoon,
    required this.dueSoonBg,
    required this.dueSoonFg,
    required this.barNormal,
    required this.dueNormalBg,
    required this.dueNormalFg,
    required this.progressTrack,
    required this.progressFill,
    required this.heroStart,
    required this.heroCenter,
    required this.heroEnd,
    required this.wallpaperFrame,
    required this.wallpaperBorder,
  });

  static const light = _WidgetPalette(
    bg: Color(0xFFF3F5FF),
    rowBg: Color(0xFFFFFFFF),
    border: Color(0xFFDCE3FA),
    text: Color(0xFF131B2E),
    muted: Color(0xFF5B6278),
    primary: Color(0xFF0037B0),
    primaryAccent: Color(0xFF1D4ED8),
    barInactive: Color(0xFFC4CCF0),
    iconBg: Color(0xFFDCE4FF),
    iconFg: Color(0xFF0037B0),
    pillPrimaryBg: Color(0xFFDCE4FF),
    pillPrimaryFg: Color(0xFF0037B0),
    pillRoomBg: Color(0xFFEAF0FF),
    pillRoomFg: Color(0xFF163B99),
    pillErrorBg: Color(0xFFFFE4E6),
    pillErrorFg: Color(0xFFBE123C),
    pillOkBg: Color(0xFFDCFCE7),
    pillOkFg: Color(0xFF15803D),
    barUrgent: Color(0xFFDC2626),
    dueUrgentBg: Color(0xFFFEE2E2),
    dueUrgentFg: Color(0xFFB91C1C),
    barSoon: Color(0xFFD97706),
    dueSoonBg: Color(0xFFFEF3C7),
    dueSoonFg: Color(0xFFB45309),
    barNormal: Color(0xFF16A34A),
    dueNormalBg: Color(0xFFDCFCE7),
    dueNormalFg: Color(0xFF15803D),
    progressTrack: Color(0xFFD8E1FB),
    progressFill: Color(0xFF1D4ED8),
    heroStart: Color(0xFF0037B0),
    heroCenter: Color(0xFF1D4ED8),
    heroEnd: Color(0xFF026AA7),
    wallpaperFrame: [Color(0xFFE4EAFA), Color(0xFFD6E0FA)],
    wallpaperBorder: Color(0xFFCAD5F5),
  );

  static const dark = _WidgetPalette(
    bg: Color(0xFF141A29),
    rowBg: Color(0xFF1E263B),
    border: Color(0xFF2C3652),
    text: Color(0xFFEEF1FF),
    muted: Color(0xFF9BA5C0),
    primary: Color(0xFFB7C4FF),
    primaryAccent: Color(0xFF6D94FF),
    barInactive: Color(0xFF384569),
    iconBg: Color(0xFF24345E),
    iconFg: Color(0xFFB7C4FF),
    pillPrimaryBg: Color(0xFF24345E),
    pillPrimaryFg: Color(0xFFDCE4FF),
    pillRoomBg: Color(0xFF253357),
    pillRoomFg: Color(0xFFC7D4FF),
    pillErrorBg: Color(0xFF5E1B26),
    pillErrorFg: Color(0xFFFFD6DC),
    pillOkBg: Color(0xFF153D29),
    pillOkFg: Color(0xFF86EFAC),
    barUrgent: Color(0xFFF87171),
    dueUrgentBg: Color(0xFF4C1D24),
    dueUrgentFg: Color(0xFFFCA5A5),
    barSoon: Color(0xFFFBBF24),
    dueSoonBg: Color(0xFF473215),
    dueSoonFg: Color(0xFFFDE68A),
    barNormal: Color(0xFF4ADE80),
    dueNormalBg: Color(0xFF143A26),
    dueNormalFg: Color(0xFF86EFAC),
    progressTrack: Color(0xFF273250),
    progressFill: Color(0xFF6D94FF),
    heroStart: Color(0xFF17254D),
    heroCenter: Color(0xFF1E3A7A),
    heroEnd: Color(0xFF17537A),
    wallpaperFrame: [Color(0xFF0A0F1C), Color(0xFF121A30)],
    wallpaperBorder: Color(0xFF232C44),
  );
}

class WidgetGalleryScreen extends StatefulWidget {
  const WidgetGalleryScreen({super.key});

  @override
  State<WidgetGalleryScreen> createState() => _WidgetGalleryScreenState();
}

class _WidgetGalleryScreenState extends State<WidgetGalleryScreen> {
  static const List<String> _monthsEn = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  bool? _previewDark;

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

  String _formatShortDue(int dueTs, String fallback, dynamic s) {
    if (dueTs <= 0) return fallback;
    final nowTashkent = TimetableService.nowTashkent();
    final today = DateTime.utc(
      nowTashkent.year,
      nowTashkent.month,
      nowTashkent.day,
    );
    final dueUtc = DateTime.fromMillisecondsSinceEpoch(
      dueTs * 1000,
      isUtc: true,
    ).add(const Duration(hours: 5));
    final dueDay = DateTime.utc(dueUtc.year, dueUtc.month, dueUtc.day);
    final diffDays = dueDay.difference(today).inDays;
    if (diffDays == 0) return s.widgetToday;
    if (diffDays == 1) return s.widgetTomorrow;
    if (diffDays >= 2 && diffDays <= 6) {
      return '$diffDays${s.isRu ? 'д' : 'd'}';
    }
    if (s.isRu) {
      final d = dueUtc.day.toString().padLeft(2, '0');
      final m = dueUtc.month.toString().padLeft(2, '0');
      return '$d.$m';
    }
    return '${_monthsEn[dueUtc.month - 1]} ${dueUtc.day}';
  }

  Widget _wallpaperFrame({
    required _WidgetPalette palette,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette.wallpaperFrame,
        ),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: palette.wallpaperBorder, width: 1),
      ),
      child: child,
    );
  }

  Widget _widgetCardShell({
    required _WidgetPalette palette,
    required Widget child,
    double minHeight = 0,
  }) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.bg,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: palette.border, width: 1),
        ),
        child: child,
      ),
    );
  }

  Widget _squircleBadge({
    required Color bg,
    required Color fg,
    required IconData icon,
    double size = 30,
    double iconSize = 15,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: iconSize, color: fg),
    );
  }

  Widget _pill({
    required String label,
    required Color bg,
    required Color fg,
    double fontSize = 11,
    double radius = 999,
    EdgeInsetsGeometry padding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: fg,
          fontSize: fontSize,
          height: 1.0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final isDarkPreview =
        _previewDark ?? (Theme.of(context).brightness == Brightness.dark);
    final palette = isDarkPreview ? _WidgetPalette.dark : _WidgetPalette.light;

    final group = app.settings.timetableGroup.trim();
    final groupEntries = group.isEmpty
        ? <ScheduleEntry>[]
        : TimetableService.filterByClass(app.timetableEntries, group);
    final next = TimetableService.findNextLesson(groupEntries);

    final now = TimetableService.nowTashkent();
    final todayIdx = now.weekday <= 5 ? now.weekday - 1 : 0;
    final todayCode = TimetableService.dayNames[todayIdx];
    final todayLessons = TimetableService.filterByDay(groupEntries, todayCode);

    final gpa = formatGpa(app.insData?.gpaInfo['gpa'] ?? '');
    final gpaNumeric = double.tryParse(gpa.replaceAll(',', '.')) ?? 0.0;
    final gpaRatio = (gpaNumeric.clamp(0.0, 4.5)) / 4.5;
    final acq = formatCredits(app.insData?.gpaInfo['credits_acquired'] ?? '');
    final att = formatCredits(app.insData?.gpaInfo['credits_attempted'] ?? '');
    final creditsValue = acq.isNotEmpty
        ? (att.isNotEmpty ? '$acq/$att' : acq)
        : '—';

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s.widgetGallerySubtitle,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            ExpressiveSegmentedControl<bool>(
              key: const ValueKey('widget_theme_toggle'),
              selected: isDarkPreview,
              onChanged: (v) {
                AppHaptics.selection();
                setState(() => _previewDark = v);
              },
              segments: [
                ExpressiveSegment(
                  value: false,
                  label: s.widgetPreviewLight,
                  icon: Icons.light_mode_rounded,
                ),
                ExpressiveSegment(
                  value: true,
                  label: s.widgetPreviewDark,
                  icon: Icons.dark_mode_rounded,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 1. Next Lecture Glance (4x2) — matches widget_next_lecture.xml
            _widgetSection(
              context: context,
              title: s.widgetNextLectureTitle,
              subtitle: s.widgetNextLectureDesc,
              sizeLabel: '4×2',
              widgetKey: 'next_lecture',
              preview: _wallpaperFrame(
                palette: palette,
                child: _buildNextLecturePreview(
                  palette: palette,
                  s: s,
                  group: group,
                  next: next,
                ),
              ),
              s: s,
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 20),

            // 2. Today's Schedule (4x3) — matches widget_today_schedule.xml
            _widgetSection(
              context: context,
              title: s.widgetTodayScheduleTitle,
              subtitle: s.widgetTodayScheduleDesc,
              sizeLabel: '4×3',
              widgetKey: 'today_schedule',
              preview: _wallpaperFrame(
                palette: palette,
                child: _buildTodaySchedulePreview(
                  palette: palette,
                  s: s,
                  group: group,
                  todayIdx: todayIdx,
                  todayCode: todayCode,
                  todayLessons: todayLessons,
                  next: next,
                ),
              ),
              s: s,
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 20),

            // 3. INS Academic (2x2) — matches widget_ins_academic.xml
            _widgetSection(
              context: context,
              title: s.widgetInsAcademicTitle,
              subtitle: s.widgetInsAcademicDesc,
              sizeLabel: '2×2',
              widgetKey: 'ins_academic',
              preview: _wallpaperFrame(
                palette: palette,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 184,
                    height: 176,
                    child: _buildInsAcademicPreview(
                      palette: palette,
                      s: s,
                      gpa: gpa,
                      gpaRatio: gpaRatio,
                      creditsValue: creditsValue,
                      courseCount: app.visibleCourses.length,
                    ),
                  ),
                ),
              ),
              s: s,
              cs: cs,
              tt: tt,
            ),
            const SizedBox(height: 20),

            // 4. Deadlines (4x3) — matches widget_deadlines.xml
            _widgetSection(
              context: context,
              title: s.widgetDeadlinesTitle,
              subtitle: s.widgetDeadlinesDesc,
              sizeLabel: '4×3',
              widgetKey: 'deadlines',
              preview: _wallpaperFrame(
                palette: palette,
                child: _buildDeadlinesPreview(
                  palette: palette,
                  s: s,
                  pending: pending,
                  nowSec: nowSec,
                ),
              ),
              s: s,
              cs: cs,
              tt: tt,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNextLecturePreview({
    required _WidgetPalette palette,
    required dynamic s,
    required String group,
    required (ScheduleEntry, String, int?)? next,
  }) {
    final badgeText = next == null
        ? s.widgetTimetableOverline
        : (next.$3 != null
            ? s.formatCountdown(next.$3!)
            : next.$2);
    final subjectText = next == null
        ? (group.isEmpty ? s.widgetSelectGroupApp : s.widgetNoUpcoming)
        : next.$1.subject;
    final roomText = next == null
        ? ''
        : next.$1.classrooms
            .map(TimetableService.cleanClassroomName)
            .where((e) => e.isNotEmpty)
            .join(', ');
    final teacherText = next == null
        ? s.widgetTapToOpen
        : (next.$1.teachers.isNotEmpty ? next.$1.teachers.first : '');

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 152),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                palette.heroStart,
                palette.heroCenter,
                palette.heroEnd,
              ],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0x22FFFFFF), width: 1),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(0.76, -0.72),
                      radius: 0.9,
                      colors: const [Color(0x24FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(10, 4, 11, 4),
                          decoration: BoxDecoration(
                            color: const Color(0x2BFFFFFF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                badgeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  height: 1.0,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (next != null)
                          Text(
                            '${next.$1.periodStart} – ${next.$1.periodEnd}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      s.widgetNextLectureOverline,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xBFE8F0FF),
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subjectText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        if (roomText.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
                            decoration: BoxDecoration(
                              color: const Color(0x2BFFFFFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  roomText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    height: 1.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            teacherText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFDCE6FF),
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                        if (group.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0x2BFFFFFF),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              group,
                              maxLines: 1,
                              style: const TextStyle(
                                color: Color(0xFFEEF4FF),
                                fontSize: 10.5,
                                height: 1.0,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySchedulePreview({
    required _WidgetPalette palette,
    required dynamic s,
    required String group,
    required int todayIdx,
    required String todayCode,
    required List<ScheduleEntry> todayLessons,
    required (ScheduleEntry, String, int?)? next,
  }) {
    return _widgetCardShell(
      palette: palette,
      minHeight: todayLessons.isEmpty ? 164 : 210,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _squircleBadge(
                bg: palette.iconBg,
                fg: palette.iconFg,
                icon: Icons.calendar_today_rounded,
                size: 32,
                iconSize: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.dayFullNames[todayIdx],
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.text,
                        fontSize: 14.5,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (group.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        group,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 11,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _pill(
                label: s.widgetClassesPlural(todayLessons.length),
                bg: palette.pillPrimaryBg,
                fg: palette.pillPrimaryFg,
              ),
            ],
          ),
          if (todayLessons.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 34),
              child: Center(
                child: Text(
                  group.isEmpty ? s.noGroupSelected : s.noLessonsToday,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else ...[
            const SizedBox(height: 3),
            for (final lesson in todayLessons.take(4)) ...[
              Container(
                margin: const EdgeInsets.only(top: 7),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.rowBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 28,
                      decoration: BoxDecoration(
                        color: (next != null &&
                                next.$2 == todayCode &&
                                lesson.periodStart == next.$1.periodStart &&
                                lesson.subject == next.$1.subject)
                            ? palette.primaryAccent
                            : palette.barInactive,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 42,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.periodStart,
                            maxLines: 1,
                            style: TextStyle(
                              color: palette.primary,
                              fontSize: 12,
                              height: 1.0,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lesson.periodEnd,
                            maxLines: 1,
                            style: TextStyle(
                              color: palette.muted,
                              fontSize: 10,
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lesson.subject,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.text,
                              fontSize: 12.5,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (lesson.teachers.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              lesson.teachers.first,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.muted,
                                fontSize: 10.5,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (lesson.classrooms.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _pill(
                        label: TimetableService.cleanClassroomName(
                            lesson.classrooms.first),
                        bg: palette.pillRoomBg,
                        fg: palette.pillRoomFg,
                        fontSize: 10.5,
                        radius: 10,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInsAcademicPreview({
    required _WidgetPalette palette,
    required dynamic s,
    required String gpa,
    required double gpaRatio,
    required String creditsValue,
    required int courseCount,
  }) {
    return _widgetCardShell(
      palette: palette,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _squircleBadge(
                bg: palette.iconBg,
                fg: palette.iconFg,
                icon: Icons.school_rounded,
                size: 26,
                iconSize: 14,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'INS GPA',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _pill(
                label: s.widgetCoursesPlural(courseCount),
                bg: palette.pillPrimaryBg,
                fg: palette.pillPrimaryFg,
                fontSize: 10,
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ],
          ),
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  gpa.isEmpty ? '—' : gpa,
                  style: TextStyle(
                    color: palette.primary,
                    fontSize: 32,
                    height: 1.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '/ 4.5',
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.creditsLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.muted,
                    fontSize: 11,
                  ),
                ),
              ),
              Text(
                creditsValue,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: gpaRatio,
              minHeight: 6,
              backgroundColor: palette.progressTrack,
              valueColor: AlwaysStoppedAnimation<Color>(palette.progressFill),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeadlinesPreview({
    required _WidgetPalette palette,
    required dynamic s,
    required List<Assignment> pending,
    required int nowSec,
  }) {
    final hasDue = pending.isNotEmpty;
    return _widgetCardShell(
      palette: palette,
      minHeight: hasDue ? 190 : 152,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _squircleBadge(
                bg: palette.iconBg,
                fg: palette.iconFg,
                icon: Icons.assignment_outlined,
                size: 30,
                iconSize: 15,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  s.widgetDeadlinesShortTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _pill(
                label: s.widgetDuePlural(pending.length),
                bg: hasDue ? palette.pillErrorBg : palette.pillOkBg,
                fg: hasDue ? palette.pillErrorFg : palette.pillOkFg,
              ),
            ],
          ),
          if (!hasDue)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: palette.pillOkFg,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.allCaughtUp,
                    style: TextStyle(
                      color: palette.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            const SizedBox(height: 3),
            for (final a in pending.take(3)) ...[
              Builder(
                builder: (_) {
                  final diff = a.dueTimestamp - nowSec;
                  final isUrgent = a.dueTimestamp > 0 && diff <= 48 * 3600;
                  final isSoon =
                      !isUrgent && a.dueTimestamp > 0 && diff <= 7 * 86400;
                  final barColor = isUrgent
                      ? palette.barUrgent
                      : (isSoon ? palette.barSoon : palette.barNormal);
                  final dueBg = isUrgent
                      ? palette.dueUrgentBg
                      : (isSoon ? palette.dueSoonBg : palette.dueNormalBg);
                  final dueFg = isUrgent
                      ? palette.dueUrgentFg
                      : (isSoon ? palette.dueSoonFg : palette.dueNormalFg);
                  final dueLabel =
                      _formatShortDue(a.dueTimestamp, a.due, s);

                  return Container(
                    margin: const EdgeInsets.only(top: 7),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.rowBg,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 26,
                          decoration: BoxDecoration(
                            color: barColor,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 12.5,
                                  height: 1.1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (a.courseName.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  a.courseName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: palette.muted,
                                    fontSize: 10.5,
                                    height: 1.0,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (dueLabel.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          _pill(
                            label: dueLabel,
                            bg: dueBg,
                            fg: dueFg,
                            fontSize: 10.5,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
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
                style: const TextStyle(fontWeight: FontWeight.w700),
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
