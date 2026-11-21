class GpaCourseEntry {
  final String name;
  final int credits;
  final String letter;
  final String? courseId;

  const GpaCourseEntry({
    required this.name,
    this.credits = 3,
    this.letter = 'A0',
    this.courseId,
  });

  GpaCourseEntry copyWith({
    String? name,
    int? credits,
    String? letter,
    String? courseId,
  }) {
    return GpaCourseEntry(
      name: name ?? this.name,
      credits: credits ?? this.credits,
      letter: letter ?? this.letter,
      courseId: courseId ?? this.courseId,
    );
  }
}

class GpaSimulationResult {
  final double semesterGpa;
  final int semesterGradedCredits;
  final int semesterTotalCredits;
  final double projectedCumulativeGpa;
  final double totalCredits;
  final double gpaDelta;

  const GpaSimulationResult({
    required this.semesterGpa,
    required this.semesterGradedCredits,
    required this.semesterTotalCredits,
    required this.projectedCumulativeGpa,
    required this.totalCredits,
    required this.gpaDelta,
  });
}

class GpaCategorySlider {
  final String label;
  final double weightPct;
  final double scorePct;
  final bool hasRealScore;

  const GpaCategorySlider({
    required this.label,
    required this.weightPct,
    required this.scorePct,
    this.hasRealScore = false,
  });

  GpaCategorySlider copyWith({
    String? label,
    double? weightPct,
    double? scorePct,
    bool? hasRealScore,
  }) {
    return GpaCategorySlider(
      label: label ?? this.label,
      weightPct: weightPct ?? this.weightPct,
      scorePct: scorePct ?? this.scorePct,
      hasRealScore: hasRealScore ?? this.hasRealScore,
    );
  }
}

class GpaCalculator {
  static const List<String> gradedLettersAscending = [
    'F',
    'D0',
    'D+',
    'C0',
    'C+',
    'B0',
    'B+',
    'A0',
    'A+',
  ];

  static const List<({String letter, double? points})> gradeScale = [
    (letter: 'A+', points: 4.5),
    (letter: 'A0', points: 4.0),
    (letter: 'B+', points: 3.5),
    (letter: 'B0', points: 3.0),
    (letter: 'C+', points: 2.5),
    (letter: 'C0', points: 2.0),
    (letter: 'D+', points: 1.5),
    (letter: 'D0', points: 1.0),
    (letter: 'F', points: 0.0),
    (letter: 'P', points: null),
  ];

  static double? letterToPoints(String grade) {
    switch (grade.trim().toUpperCase()) {
      case 'A+':
        return 4.5;
      case 'A0':
      case 'A':
        return 4.0;
      case 'B+':
        return 3.5;
      case 'B0':
      case 'B':
        return 3.0;
      case 'C+':
        return 2.5;
      case 'C0':
      case 'C':
        return 2.0;
      case 'D+':
        return 1.5;
      case 'D0':
      case 'D':
        return 1.0;
      case 'F':
        return 0.0;
      default:
        return null;
    }
  }

  static String percentToEstimatedLetter(double pct) {
    if (pct >= 95) return 'A+';
    if (pct >= 90) return 'A0';
    if (pct >= 85) return 'B+';
    if (pct >= 80) return 'B0';
    if (pct >= 75) return 'C+';
    if (pct >= 70) return 'C0';
    if (pct >= 65) return 'D+';
    if (pct >= 60) return 'D0';
    return 'F';
  }

  static GpaSimulationResult calculate({
    required double currentGpa,
    required double completedCredits,
    required List<GpaCourseEntry> courses,
  }) {
    final safePriorGpa = currentGpa.clamp(0.0, 4.5);
    final safePriorCredits = completedCredits < 0 ? 0.0 : completedCredits;

    double semPoints = 0;
    int semGradedCredits = 0;
    int semTotalCredits = 0;

    for (final c in courses) {
      if (c.credits <= 0) continue;
      semTotalCredits += c.credits;
      final pts = letterToPoints(c.letter);
      if (pts != null) {
        semPoints += pts * c.credits;
        semGradedCredits += c.credits;
      }
    }

    final semGpa = semGradedCredits > 0 ? semPoints / semGradedCredits : 0.0;
    final denom = safePriorCredits + semGradedCredits;
    final projectedCum = denom > 0
        ? ((safePriorGpa * safePriorCredits) + semPoints) / denom
        : safePriorGpa;

    return GpaSimulationResult(
      semesterGpa: semGpa,
      semesterGradedCredits: semGradedCredits,
      semesterTotalCredits: semTotalCredits,
      projectedCumulativeGpa: projectedCum,
      totalCredits: safePriorCredits + semTotalCredits,
      gpaDelta: projectedCum - safePriorGpa,
    );
  }

  static double calculateWeightedCoursePercent(
    List<GpaCategorySlider> categories,
  ) {
    double weightedSum = 0;
    double totalWeight = 0;
    for (final cat in categories) {
      if (cat.weightPct <= 0) continue;
      weightedSum += cat.scorePct.clamp(0.0, 100.0) * cat.weightPct;
      totalWeight += cat.weightPct;
    }
    if (totalWeight <= 0) return 0.0;
    return (weightedSum / totalWeight).clamp(0.0, 100.0);
  }

  static double projectCoursePercentage({
    required double earnedWeightedPct,
    required double completedWeight,
    required double remainingWeight,
    required double expectedRemainingScorePct,
  }) {
    final totalW = completedWeight + remainingWeight;
    if (totalW <= 0) return expectedRemainingScorePct.clamp(0.0, 100.0);
    final total = earnedWeightedPct +
        (remainingWeight * expectedRemainingScorePct.clamp(0.0, 100.0) / 100.0);
    return (total * 100.0 / totalW).clamp(0.0, 100.0);
  }
}
