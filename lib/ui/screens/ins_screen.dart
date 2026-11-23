import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_sheets.dart';
import '../widgets/expressive_widgets.dart';
import 'course_detail_screen.dart';
import 'gpa_calculator_screen.dart';

class InsScreen extends StatefulWidget {
  const InsScreen({super.key});

  @override
  State<InsScreen> createState() => _InsScreenState();
}

class _InsScreenState extends State<InsScreen> {
  String _selectedSemester = '__ALL__';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppState>();
      if (app.isLoggedIn &&
          app.insData == null &&
          !app.isInsLoading &&
          app.insError == null) {
        app.syncIns();
      }
    });
  }

  Future<void> _showOverridePasswordDialog(
      BuildContext context, AppState app) async {
    final ctrl =
        TextEditingController(text: app.credentials?.insPassword ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.s.changeInsPassword),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: app.s.insPasswordOptional,
            helperText: app.s.insPasswordHintOverride,
            helperMaxLines: 2,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(app.s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(app.s.save),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (saved != null) {
      await app.saveInsPassword(saved);
    }
  }

  (IconData icon, Color bg, Color fg) _subjectStyle(
      InsCourseGrade c, ColorScheme cs) {
    final code = c.courseNumber.toUpperCase();
    IconData icon = Icons.menu_book_rounded;
    if (code.startsWith('CSE') ||
        code.startsWith('SOC') ||
        code.startsWith('ICE') ||
        code.startsWith('CIS')) {
      icon = Icons.terminal_rounded;
    } else if (code.startsWith('MTH') ||
        code.startsWith('MAT') ||
        code.startsWith('STA')) {
      icon = Icons.functions_rounded;
    } else if (code.startsWith('ENG') ||
        code.startsWith('KOR') ||
        code.startsWith('HUM')) {
      icon = Icons.edit_note_rounded;
    } else if (code.startsWith('PHY') ||
        code.startsWith('CHM') ||
        code.startsWith('BIO')) {
      icon = Icons.science_outlined;
    }
    return (icon, cs.primaryFixed, cs.onPrimaryFixed);
  }

  (Color bg, Color fg) _gradeBadgeColors(String grade, ColorScheme cs) {
    final g = grade.trim().toUpperCase();
    if (g.startsWith('A')) return (cs.secondaryFixed, cs.onSecondaryFixed);
    if (g.startsWith('B')) return (cs.primaryFixed, cs.onPrimaryFixed);
    if (g.startsWith('C')) return (cs.tertiaryFixed, cs.onTertiaryFixed);
    if (g.startsWith('D') || g == 'F') {
      return (cs.errorContainer, cs.onErrorContainer);
    }
    return (cs.surfaceContainerHigh, cs.onSurfaceVariant);
  }

  String? _gradePoints45(String grade) {
    switch (grade.trim().toUpperCase()) {
      case 'A+':
        return '4.5';
      case 'A0':
      case 'A':
        return '4.0';
      case 'B+':
        return '3.5';
      case 'B0':
      case 'B':
        return '3.0';
      case 'C+':
        return '2.5';
      case 'C0':
      case 'C':
        return '2.0';
      case 'D+':
        return '1.5';
      case 'D0':
      case 'D':
        return '1.0';
      case 'F':
        return '0.0';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final data = app.insData;

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.insPortalTitle,
        overline: s.portalHeader,
      ),
      body: data == null
          ? Center(
              child: app.isInsLoading
                  ? const CircularProgressIndicator()
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: ExpressiveCard(
                          borderRadius: 28,
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SquircleIcon(
                                size: 64,
                                radius: 20,
                                iconSize: 32,
                                icon: Icons.workspace_premium_outlined,
                                backgroundColor: cs.errorContainer,
                                iconColor: cs.onErrorContainer,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                app.insError ?? s.insLoadError,
                                textAlign: TextAlign.center,
                                style: tt.bodyMedium,
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: () => app.syncIns(),
                                style: FilledButton.styleFrom(
                                  backgroundColor: cs.primary,
                                  foregroundColor: cs.onPrimary,
                                  shape: const StadiumBorder(),
                                ),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(s.retryLabel),
                              ),
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () =>
                                    _showOverridePasswordDialog(context, app),
                                icon: const Icon(Icons.key_outlined, size: 18),
                                label: Text(s.insOverridePasswordBtn),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            )
          : _buildGradesView(context, data, cs, tt, s, app),
    );
  }

  Widget _buildGradesView(
    BuildContext context,
    InsGradeData data,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
    AppState app,
  ) {
    final semesters = <String>[];
    for (final c in data.courses) {
      if (c.semester.isNotEmpty && !semesters.contains(c.semester)) {
        semesters.add(c.semester);
      }
    }

    final effectiveSemester =
        semesters.contains(_selectedSemester) ? _selectedSemester : '__ALL__';

    final visible = effectiveSemester == '__ALL__'
        ? data.courses
        : data.courses.where((c) => c.semester == effectiveSemester).toList();

    final gpa = formatGpa(data.gpaInfo['gpa'] ?? '');
    final gpaDisplay = gpa.isEmpty ? '—' : gpa;
    final hasNumericGpa = double.tryParse(gpa) != null;

    final acq = formatCredits(data.gpaInfo['credits_acquired'] ?? '');
    final att = formatCredits(data.gpaInfo['credits_attempted'] ?? '');
    final rank = (data.studentInfo['rank'] ?? '').trim();

    final rawName = formatPersonName(data.studentInfo['name'] ?? '');
    final studentId = (data.studentInfo['id'] ?? '').trim().isNotEmpty
        ? data.studentInfo['id']!.trim()
        : (app.credentials?.studentId ?? '');
    final displayName = rawName.isNotEmpty ? rawName : studentId;
    final dept = (data.studentInfo['dept'] ?? '').trim();
    final gradeYear = (data.studentInfo['grade_year'] ?? '').trim();
    final subParts = <String>[
      if (studentId.isNotEmpty && studentId != displayName) studentId,
      if (dept.isNotEmpty) dept,
      if (gradeYear.isNotEmpty) s.yearLabel(gradeYear),
    ];

    final relSync = formatRelativeTime(data.updatedAt, s);

    return RefreshIndicator(
      onRefresh: () async {
        final ok = await app.syncIns();
        if (!ok && context.mounted) {
          showQuickToast(context, s.insLoadError);
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.insPortalTitle,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: cs.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            s.insSyncSub,
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
                ),
              ),
              const SizedBox(width: 8),
              if (relSync.isNotEmpty) ...[
                ExpressivePill(
                  label: s.syncUpdatedAgo(relSync),
                  backgroundColor: cs.surfaceContainer,
                  foregroundColor: cs.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              CircleActionButton(
                icon: Icons.sync_rounded,
                tooltip: s.refresh,
                loading: app.isInsLoading,
                backgroundColor: cs.surfaceContainer,
                iconColor: cs.primary,
                onPressed: () async {
                  final ok = await app.syncIns();
                  if (!ok && context.mounted) {
                    showQuickToast(context, s.insLoadError);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          HeroGradientCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    InitialsAvatar(
                      name: displayName,
                      imagePath: app.profileAvatarPath,
                      size: 44,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      foregroundColor: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (subParts.isNotEmpty)
                            Text(
                              subParts.join(' • '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              s.gpaLabel.toUpperCase(),
                              style: tt.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                                letterSpacing: 0.7,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  gpaDisplay,
                                  style: tt.headlineSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                if (hasNumericGpa)
                                  Text(
                                    ' / 4.5',
                                    style: tt.labelSmall?.copyWith(
                                      color:
                                          Colors.white.withValues(alpha: 0.85),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              s.cumulativeLabel,
                              style: tt.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                s.creditsLabel.toUpperCase(),
                                style: tt.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    acq.isEmpty ? '—' : acq,
                                    style: tt.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (att.isNotEmpty)
                                    Text(
                                      ' / $att',
                                      style: tt.labelSmall?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (rank.isNotEmpty)
                        Expanded(
                          child: Column(
                            children: [
                              Text(
                                s.rankLabel.toUpperCase(),
                                style: tt.labelSmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                rank,
                                textAlign: TextAlign.center,
                                style: tt.titleLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ExpressiveCard(
            key: const ValueKey('ins_gpa_calculator_card'),
            borderRadius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () {
              AppHaptics.light();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GpaCalculatorScreen(),
                ),
              );
            },
            child: Row(
              children: [
                SquircleIcon(
                  size: 44,
                  radius: 14,
                  iconSize: 22,
                  icon: Icons.calculate_rounded,
                  backgroundColor: cs.primaryFixed,
                  iconColor: cs.onPrimaryFixed,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.gpaCalculatorTitle,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.gpaCalculatorSub,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
          ),
          if (semesters.isNotEmpty) ...[
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  s.academicSemesters,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  s.termsCount(semesters.length),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _semesterChip(
                    id: '__ALL__',
                    label: s.allSemesters,
                    selected: effectiveSemester == '__ALL__',
                    cs: cs,
                    tt: tt,
                  ),
                  const SizedBox(width: 8),
                  for (final sem in semesters) ...[
                    _semesterChip(
                      id: sem,
                      label: sem,
                      selected: effectiveSemester == sem,
                      cs: cs,
                      tt: tt,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.enrolledCourses(visible.length),
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                s.letterGrading,
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < visible.length; i++) ...[
            _buildCourseGradeCard(
              context: context,
              app: app,
              c: visible[i],
              showSemester: effectiveSemester == '__ALL__',
              cs: cs,
              tt: tt,
              s: s,
            ),
            if (i != visible.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _semesterChip({
    required String id,
    required String label,
    required bool selected,
    required ColorScheme cs,
    required TextTheme tt,
  }) {
    return Material(
      color: selected ? cs.primary : cs.surfaceContainer,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => setState(() => _selectedSemester = id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 15, color: cs.onPrimary),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseGradeCard({
    required BuildContext context,
    required AppState app,
    required InsCourseGrade c,
    required bool showSemester,
    required ColorScheme cs,
    required TextTheme tt,
    required dynamic s,
  }) {
    final (icon, iconBg, iconFg) = _subjectStyle(c, cs);
    final (badgeBg, badgeFg) = _gradeBadgeColors(c.grade, cs);
    final pts = _gradePoints45(c.grade);

    final cleanCredit = formatCredits(c.credit);
    final metaParts = <String>[
      if (c.courseNumber.isNotEmpty) c.courseNumber,
      if (cleanCredit.isNotEmpty) '$cleanCredit cr',
      if (c.courseType.isNotEmpty) c.courseType,
    ];

    return ExpressiveCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      onTap: () {
        AppHaptics.light();
        final matched = app.findCourseForSubject(c.title);
        if (matched != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  CourseDetailScreen(course: matched, initialTab: 1),
            ),
          );
        } else {
          showTranscriptInfoSheet(context, c);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SquircleIcon(
            size: 48,
            radius: 16,
            iconSize: 22,
            icon: icon,
            backgroundColor: iconBg,
            iconColor: iconFg,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.title.isNotEmpty ? c.title : c.courseNumber,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    metaParts.join(' • '),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
                if (c.professor.isNotEmpty ||
                    (showSemester && c.semester.isNotEmpty)) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showSemester && c.semester.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            c.semester,
                            style: tt.labelSmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      if (c.professor.isNotEmpty)
                        Text(
                          c.professor,
                          style: tt.labelSmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ExpressivePill(
                label: c.grade,
                backgroundColor: badgeBg,
                foregroundColor: badgeFg,
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
              if (pts != null) ...[
                const SizedBox(height: 6),
                Text(
                  s.ptsLabel(pts),
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
