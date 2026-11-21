import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/gpa_calculator.dart';
import '../../services/timetable_service.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_widgets.dart';

class GpaCalculatorScreen extends StatefulWidget {
  final Course? focusedCourse;
  final List<SyllabusWeight> focusedWeights;
  final List<GradeItem> focusedGrades;

  const GpaCalculatorScreen({
    super.key,
    this.focusedCourse,
    this.focusedWeights = const [],
    this.focusedGrades = const [],
  });

  @override
  State<GpaCalculatorScreen> createState() => _GpaCalculatorScreenState();
}

class _GpaCalculatorScreenState extends State<GpaCalculatorScreen> {
  late final TextEditingController _priorGpaCtrl;
  late final TextEditingController _priorCreditsCtrl;

  double _priorGpa = 0.0;
  double _priorCredits = 0.0;
  List<GpaCourseEntry> _courses = [];

  bool _hasCourseSimulator = false;
  List<GpaCategorySlider> _simCategories = [];
  int _simGradeIndex = 7; // index into GpaCalculator.gradedLettersAscending ('A0')
  bool _manualGradeOverride = false;

  @override
  void initState() {
    super.initState();
    _priorGpaCtrl = TextEditingController();
    _priorCreditsCtrl = TextEditingController();
    _initDefaults();
  }

  @override
  void dispose() {
    _priorGpaCtrl.dispose();
    _priorCreditsCtrl.dispose();
    super.dispose();
  }

  double? _parseNum(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'([0-9]+(?:[.,][0-9]+)?)').firstMatch(raw);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }

  String _guessInitialLetter(Course c, AppState app) {
    final grades = app.gradesByCourse[c.id] ?? const [];
    for (final g in grades) {
      if (g.isTotal &&
          !RegExp(r'\bSUM$', caseSensitive: false).hasMatch(g.name)) {
        final pct = _parseNum(g.percentage) ?? _parseNum(g.value);
        if (pct != null && pct > 0 && pct <= 100) {
          return GpaCalculator.percentToEstimatedLetter(pct);
        }
      }
    }
    final ov = _parseNum(c.overviewGrade);
    if (ov != null && ov > 0 && ov <= 100) {
      return GpaCalculator.percentToEstimatedLetter(ov);
    }
    return 'A0';
  }

  int _guessCredits(Course c, AppState app) {
    final transcript = app.insData?.courses ?? const <InsCourseGrade>[];
    final matched = TimetableService.matchSubjectToCourse(
      c.name,
      [Course(id: c.id, name: c.name)],
    );
    if (matched != null) {
      for (final t in transcript) {
        if (t.title.toLowerCase().contains(c.name.toLowerCase()) ||
            c.name.toLowerCase().contains(t.title.toLowerCase())) {
          final cr = _parseNum(t.credit)?.round();
          if (cr != null && cr >= 1 && cr <= 6) return cr;
        }
      }
    }
    return 3;
  }

  String _canonicalCategoryKey(String raw) {
    final norm = raw.toLowerCase().replaceAll(RegExp(r'[\s\-_]+'), '');
    if (norm.contains('mid')) return 'midterm';
    if (norm.contains('final')) return 'final';
    if (norm.contains('attend')) return 'attendance';
    if (norm.contains('assign') || norm.contains('hw') || norm.contains('home')) {
      return 'assignments';
    }
    if (norm.contains('quiz')) return 'quiz';
    if (norm.contains('discuss') || norm.contains('project')) return 'project';
    if (norm.contains('lab') || norm.contains('pract')) return 'lab';
    if (norm.contains('etc') || norm.contains('other')) return 'other';
    return norm;
  }

  void _initSimulator(AppState app) {
    final fc = widget.focusedCourse;
    if (fc == null) {
      _hasCourseSimulator = false;
      _simCategories = [];
      return;
    }

    final attData = app.attendanceByCourse[fc.id];
    final attPct = (attData != null && attData.total > 0)
        ? attData.percentage.clamp(0.0, 100.0)
        : null;

    // Gather sum-level categories from Moodle grade report
    final sumCats = <GpaCategorySlider>[];
    final realScoreByKey = <String, double>{};
    if (attPct != null) {
      realScoreByKey['attendance'] = attPct;
    }

    for (final g in widget.focusedGrades) {
      final isCatSum = g.isSum ||
          (g.isTotal && RegExp(r'\bSUM$', caseSensitive: false).hasMatch(g.name));
      if (!isCatSum) continue;
      final label = (g.category.trim().isNotEmpty
              ? g.category.trim()
              : g.name.replaceAll(RegExp(r'\s*\bSUM$', caseSensitive: false), ''))
          .trim();
      final weight = _parseNum(g.weight) ?? 0.0;
      double? scorePct = g.value.trim() == '-' ? null : _parseNum(g.percentage);
      final key = _canonicalCategoryKey(label);
      if (scorePct == null && key == 'attendance' && attPct != null) {
        scorePct = attPct;
      }
      if (scorePct != null) {
        realScoreByKey[key] = scorePct.clamp(0.0, 100.0);
      }
      if (weight > 0) {
        sumCats.add(GpaCategorySlider(
          label: label,
          weightPct: weight,
          scorePct: (scorePct ?? 85.0).clamp(0.0, 100.0),
          hasRealScore: scorePct != null,
        ));
      }
    }

    final sumWeightTotal =
        sumCats.fold<double>(0.0, (acc, e) => acc + e.weightPct);

    if (sumCats.length >= 2 && sumWeightTotal >= 50) {
      _simCategories = sumCats;
    } else if (widget.focusedWeights.isNotEmpty) {
      _simCategories = widget.focusedWeights.map((sw) {
        final key = _canonicalCategoryKey(sw.label);
        final realScore = realScoreByKey[key];
        return GpaCategorySlider(
          label: sw.label,
          weightPct: sw.percentage,
          scorePct: realScore ?? 85.0,
          hasRealScore: realScore != null,
        );
      }).toList();
    } else if (sumCats.isNotEmpty) {
      _simCategories = sumCats;
    } else {
      _simCategories = const [
        GpaCategorySlider(label: 'Midterm', weightPct: 35, scorePct: 85),
        GpaCategorySlider(label: 'Final', weightPct: 45, scorePct: 85),
        GpaCategorySlider(label: 'Assignments', weightPct: 20, scorePct: 85),
      ];
    }

    final overallPct =
        GpaCalculator.calculateWeightedCoursePercent(_simCategories);
    final letter = GpaCalculator.percentToEstimatedLetter(overallPct);
    _simGradeIndex = GpaCalculator.gradedLettersAscending
        .indexOf(letter)
        .clamp(0, GpaCalculator.gradedLettersAscending.length - 1);
    _manualGradeOverride = false;
    _hasCourseSimulator = true;
  }

  void _initDefaults() {
    final app = context.read<AppState>();
    final rawGpa = (app.insData?.gpaInfo['gpa'] ?? '').replaceAll(',', '.');
    final rawCredits =
        (app.insData?.gpaInfo['credits_acquired'] ?? '').replaceAll(',', '.');

    _priorGpa = (double.tryParse(rawGpa) ?? 0.0).clamp(0.0, 4.5);
    _priorCredits = double.tryParse(rawCredits) ?? 0.0;
    if (_priorCredits < 0) _priorCredits = 0.0;

    _priorGpaCtrl.text = _priorGpa > 0 ? _priorGpa.toStringAsFixed(2) : '0.00';
    _priorCreditsCtrl.text = _priorCredits == _priorCredits.roundToDouble()
        ? _priorCredits.round().toString()
        : _priorCredits.toStringAsFixed(1);

    _initSimulator(app);

    final current = app.courses.where((c) => c.isCurrent).toList();
    final fc = widget.focusedCourse;
    if (fc != null && !current.any((c) => c.id == fc.id)) {
      current.insert(0, fc);
    }

    final initialSimLetter = _hasCourseSimulator
        ? GpaCalculator.gradedLettersAscending[_simGradeIndex]
        : null;

    if (current.isEmpty) {
      _courses = [
        GpaCourseEntry(
          name: app.s.customCourseHint,
          credits: 3,
          letter: 'A0',
        ),
      ];
    } else {
      _courses = current.map((c) {
        final isFocused = fc != null && c.id == fc.id;
        return GpaCourseEntry(
          courseId: c.id,
          name: c.name,
          credits: _guessCredits(c, app),
          letter: isFocused && initialSimLetter != null
              ? initialSimLetter
              : _guessInitialLetter(c, app),
        );
      }).toList();
    }
  }

  void _resetAll() {
    AppHaptics.medium();
    setState(() {
      _initDefaults();
    });
  }

  void _syncFocusedCourseLetter(String letter) {
    final fc = widget.focusedCourse;
    if (fc == null) return;
    _courses = _courses
        .map((e) => e.courseId == fc.id ? e.copyWith(letter: letter) : e)
        .toList();
  }

  void _onCategoryScoreChanged(int idx, double val) {
    setState(() {
      _simCategories[idx] = _simCategories[idx].copyWith(scorePct: val);
      final overallPct =
          GpaCalculator.calculateWeightedCoursePercent(_simCategories);
      final autoLetter = GpaCalculator.percentToEstimatedLetter(overallPct);
      _simGradeIndex = GpaCalculator.gradedLettersAscending
          .indexOf(autoLetter)
          .clamp(0, GpaCalculator.gradedLettersAscending.length - 1);
      _manualGradeOverride = false;
      _syncFocusedCourseLetter(autoLetter);
    });
  }

  void _onGradeSliderChanged(double rawIndex) {
    final idx = rawIndex
        .round()
        .clamp(0, GpaCalculator.gradedLettersAscending.length - 1);
    final letter = GpaCalculator.gradedLettersAscending[idx];
    setState(() {
      _simGradeIndex = idx;
      _manualGradeOverride = true;
      _syncFocusedCourseLetter(letter);
    });
  }

  void _resetGradeToAuto() {
    AppHaptics.selection();
    final overallPct =
        GpaCalculator.calculateWeightedCoursePercent(_simCategories);
    final autoLetter = GpaCalculator.percentToEstimatedLetter(overallPct);
    setState(() {
      _simGradeIndex = GpaCalculator.gradedLettersAscending
          .indexOf(autoLetter)
          .clamp(0, GpaCalculator.gradedLettersAscending.length - 1);
      _manualGradeOverride = false;
      _syncFocusedCourseLetter(autoLetter);
    });
  }

  void _addCourse(dynamic s) {
    AppHaptics.light();
    setState(() {
      _courses.add(
        GpaCourseEntry(
          name: '${s.customCourseHint} ${_courses.length + 1}',
          credits: 3,
          letter: 'A0',
        ),
      );
    });
  }

  String _fmtPct(double v) =>
      v == v.roundToDouble() ? '${v.round()}%' : '${v.toStringAsFixed(1)}%';

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final sim = GpaCalculator.calculate(
      currentGpa: _priorGpa,
      completedCredits: _priorCredits,
      courses: _courses,
    );

    final delta = sim.gpaDelta;
    final deltaPrefix = delta >= 0 ? '+' : '';
    final deltaText = '$deltaPrefix${delta.toStringAsFixed(2)}';

    final totalCrStr = sim.totalCredits == sim.totalCredits.roundToDouble()
        ? sim.totalCredits.round().toString()
        : sim.totalCredits.toStringAsFixed(1);

    final overallPct = _hasCourseSimulator
        ? GpaCalculator.calculateWeightedCoursePercent(_simCategories)
        : 0.0;
    final simLetter = GpaCalculator.gradedLettersAscending[_simGradeIndex];
    final simLetterPts = GpaCalculator.letterToPoints(simLetter) ?? 0.0;

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.gpaCalculatorTitle,
        overline: s.portalHeader,
        showBack: true,
        actions: [
          ExpressivePill(
            icon: Icons.restart_alt_rounded,
            label: s.resetBtn,
            backgroundColor: cs.primaryFixed,
            foregroundColor: cs.onPrimaryFixed,
            fontWeight: FontWeight.w700,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onTap: _resetAll,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          // 1. Vibrant Cobalt-Blue Gradient Hero Card (Stitch #14)
          HeroGradientCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.projectedGpaLabel,
                        style: tt.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            delta >= 0
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            size: 15,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            deltaText,
                            style: tt.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
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
                      sim.projectedCumulativeGpa.toStringAsFixed(2),
                      key: const ValueKey('gpa_calc_projected_value'),
                      style: tt.displayMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '/ 4.5',
                      style: tt.titleLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.semesterGpaLabel,
                              style: tt.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${sim.semesterGpa.toStringAsFixed(2)} / 4.5',
                              key: const ValueKey('gpa_calc_semester_value'),
                              style: tt.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.totalCreditsLabel,
                              style: tt.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              s.isRu ? '$totalCrStr кр.' : '$totalCrStr cr',
                              style: tt.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Course Score Simulator Card (per-category sliders + overall % + course grade slider)
          if (_hasCourseSimulator && widget.focusedCourse != null) ...[
            const SizedBox(height: 16),
            ExpressiveCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SquircleIcon(
                        size: 42,
                        radius: 14,
                        iconSize: 21,
                        icon: Icons.science_rounded,
                        backgroundColor: cs.primaryFixed,
                        iconColor: cs.onPrimaryFixed,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.courseScoreSimTitle.toUpperCase(),
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.6,
                              ),
                            ),
                            Text(
                              widget.focusedCourse!.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${overallPct.toStringAsFixed(1)}%',
                        key: const ValueKey('gpa_sim_overall_pct'),
                        style: tt.titleLarge?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Per-category percentage sliders
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _simCategories.length; i++) ...[
                          Row(
                            children: [
                              Expanded(
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    Text(
                                      '${_simCategories[i].label} • ${_simCategories[i].weightPct.round()}%',
                                      style: tt.labelMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_simCategories[i].hasRealScore)
                                      ExpressivePill(
                                        label: s.fromEclassBadge,
                                        backgroundColor:
                                            cs.surfaceContainerHigh,
                                        foregroundColor: cs.onSurfaceVariant,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 7, vertical: 2),
                                        fontSize: 10,
                                      ),
                                  ],
                                ),
                              ),
                              ExpressivePill(
                                label: _fmtPct(_simCategories[i].scorePct),
                                backgroundColor: cs.primaryFixed,
                                foregroundColor: cs.onPrimaryFixed,
                                fontWeight: FontWeight.w800,
                              ),
                            ],
                          ),
                          Slider(
                            key: ValueKey('gpa_cat_slider_$i'),
                            value: _simCategories[i].scorePct,
                            min: 0,
                            max: 100,
                            divisions: 100,
                            onChanged: (v) => _onCategoryScoreChanged(i, v),
                          ),
                          if (i != _simCategories.length - 1)
                            Divider(
                              height: 10,
                              thickness: 1,
                              color: cs.outlineVariant.withValues(alpha: 0.28),
                            ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Separate Course Grade slider (Auto from overall % OR manual override)
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    s.courseGradeSliderLabel,
                                    style: tt.labelMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  ExpressivePill(
                                    label: _manualGradeOverride
                                        ? s.manualModeBadge
                                        : s.autoModeBadge,
                                    backgroundColor: _manualGradeOverride
                                        ? cs.surfaceContainerHigh
                                        : cs.secondaryFixed,
                                    foregroundColor: _manualGradeOverride
                                        ? cs.primary
                                        : cs.onSecondaryFixed,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    fontSize: 10,
                                    onTap: _manualGradeOverride
                                        ? _resetGradeToAuto
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            ExpressivePill(
                              key: const ValueKey('gpa_sim_grade_pill'),
                              label:
                                  '$simLetter (${simLetterPts.toStringAsFixed(1)})',
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ],
                        ),
                        Slider(
                          key: const ValueKey('gpa_sim_grade_slider'),
                          value: _simGradeIndex.toDouble(),
                          min: 0,
                          max: (GpaCalculator.gradedLettersAscending.length - 1)
                              .toDouble(),
                          divisions:
                              GpaCalculator.gradedLettersAscending.length - 1,
                          onChanged: _onGradeSliderChanged,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            for (final mark in const [
                              'F',
                              'D0',
                              'C0',
                              'B0',
                              'A0',
                              'A+'
                            ])
                              Text(
                                mark,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontWeight: simLetter == mark
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Current Standing (INS) Editable Card
          const SizedBox(height: 16),
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 13,
                      iconSize: 20,
                      icon: Icons.account_balance_rounded,
                      backgroundColor: cs.secondaryFixed,
                      iconColor: cs.onSecondaryFixed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.currentStandingTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            s.currentStandingSub,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.priorCumGpaLabel,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            TextField(
                              controller: _priorGpaCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(top: 4),
                              ),
                              onChanged: (v) {
                                final val =
                                    double.tryParse(v.replaceAll(',', '.')) ??
                                        0.0;
                                setState(
                                    () => _priorGpa = val.clamp(0.0, 4.5));
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.completedCreditsLabel,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            TextField(
                              controller: _priorCreditsCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              style: tt.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                              decoration: const InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.only(top: 4),
                              ),
                              onChanged: (v) {
                                final val =
                                    double.tryParse(v.replaceAll(',', '.')) ??
                                        0.0;
                                setState(() =>
                                    _priorCredits = val < 0 ? 0.0 : val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Current Semester Courses
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                s.semesterCoursesTitle,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              ExpressivePill(
                label: s.coursesCountBadge(_courses.length),
                backgroundColor: cs.surfaceContainer,
                foregroundColor: cs.onSurfaceVariant,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _courses.length; i++) ...[
            _buildCourseCard(i, _courses[i], cs, tt, s),
            const SizedBox(height: 12),
          ],
          SizedBox(
            height: 48,
            child: FilledButton.tonalIcon(
              key: const ValueKey('gpa_calc_add_course_btn'),
              onPressed: () => _addCourse(s),
              style: FilledButton.styleFrom(
                backgroundColor: cs.primaryFixed,
                foregroundColor: cs.onPrimaryFixed,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add_rounded, size: 20),
              label: Text(
                s.addCourseBtn,
                style: tt.titleSmall?.copyWith(
                  color: cs.onPrimaryFixed,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(
    int idx,
    GpaCourseEntry entry,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    return ExpressiveCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: entry.courseId == null
                    ? TextFormField(
                        initialValue: entry.name,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: s.customCourseHint,
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (v) {
                          _courses[idx] = entry.copyWith(name: v);
                        },
                      )
                    : Text(
                        entry.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stepperBtn(
                      icon: Icons.remove_rounded,
                      cs: cs,
                      onTap: entry.credits > 1
                          ? () {
                              AppHaptics.selection();
                              setState(() {
                                _courses[idx] =
                                    entry.copyWith(credits: entry.credits - 1);
                              });
                            }
                          : null,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        s.crShort(entry.credits),
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    _stepperBtn(
                      icon: Icons.add_rounded,
                      cs: cs,
                      onTap: entry.credits < 6
                          ? () {
                              AppHaptics.selection();
                              setState(() {
                                _courses[idx] =
                                    entry.copyWith(credits: entry.credits + 1);
                              });
                            }
                          : null,
                    ),
                  ],
                ),
              ),
              if (_courses.length > 1)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded,
                      size: 18, color: cs.onSurfaceVariant),
                  onPressed: () {
                    AppHaptics.selection();
                    setState(() => _courses.removeAt(idx));
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final item in GpaCalculator.gradeScale) ...[
                  _gradePill(
                    key: ValueKey('gpa_grade_${idx}_${item.letter}'),
                    letter: item.letter,
                    selected: entry.letter == item.letter,
                    cs: cs,
                    tt: tt,
                    onTap: () {
                      AppHaptics.selection();
                      setState(() {
                        _courses[idx] = entry.copyWith(letter: item.letter);
                        if (_hasCourseSimulator &&
                            widget.focusedCourse != null &&
                            entry.courseId == widget.focusedCourse!.id) {
                          final gi = GpaCalculator.gradedLettersAscending
                              .indexOf(item.letter);
                          if (gi >= 0) {
                            _simGradeIndex = gi;
                            _manualGradeOverride = true;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn({
    required IconData icon,
    required ColorScheme cs,
    VoidCallback? onTap,
  }) {
    return Material(
      color: cs.surfaceContainerLowest,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            icon,
            size: 16,
            color: onTap != null ? cs.onSurface : cs.outlineVariant,
          ),
        ),
      ),
    );
  }

  Widget _gradePill({
    Key? key,
    required String letter,
    required bool selected,
    required ColorScheme cs,
    required TextTheme tt,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: selected ? cs.primary : cs.surfaceContainerLow,
      shape: const StadiumBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 42),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: tt.labelMedium?.copyWith(
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
