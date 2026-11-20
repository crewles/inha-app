import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';

class InsScreen extends StatefulWidget {
  const InsScreen({super.key});

  @override
  State<InsScreen> createState() => _InsScreenState();
}

class _InsScreenState extends State<InsScreen> {
  final _pwCtrl = TextEditingController();
  String _selectedSemester = '__ALL__';

  @override
  void dispose() {
    _pwCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveAndLoad() async {
    if (_pwCtrl.text.trim().isEmpty) return;
    final app = context.read<AppState>();
    await app.saveInsPassword(_pwCtrl.text.trim());
    _pwCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final hasPassword = (app.credentials?.insPassword ?? '').isNotEmpty;
    final data = app.insData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('INS'),
        actions: [
          if (hasPassword)
            app.isInsLoading
                ? const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: s.refresh,
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: () async {
                      final ok = await app.syncIns();
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.insLoadError)),
                        );
                      }
                    },
                  ),
        ],
      ),
      body: !hasPassword
          ? _buildPasswordPrompt(context, cs, s)
          : data == null
              ? Center(
                  child: app.isInsLoading
                      ? const CircularProgressIndicator()
                      : Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.workspace_premium_outlined,
                                  size: 64, color: cs.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(s.insLoadError,
                                  textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton.icon(
                                onPressed: () => app.syncIns(),
                                icon: const Icon(Icons.refresh_rounded),
                                label: Text(s.refresh),
                              ),
                            ],
                          ),
                        ),
                )
              : _buildGradesView(context, data, cs, s, app),
    );
  }

  Widget _buildPasswordPrompt(
      BuildContext context, ColorScheme cs, dynamic s) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Card.filled(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.workspace_premium_rounded,
                    size: 48, color: cs.primary),
                const SizedBox(height: 14),
                Text(
                  s.insNotConfigured,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _pwCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: s.insPasswordOptional,
                    prefixIcon: const Icon(Icons.key_outlined),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _saveAndLoad,
                  child: Text(s.saveInsPassword),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradesView(
    BuildContext context,
    InsGradeData data,
    ColorScheme cs,
    dynamic s,
    AppState app,
  ) {
    final semesters = <String>[];
    for (final c in data.courses) {
      if (c.semester.isNotEmpty && !semesters.contains(c.semester)) {
        semesters.add(c.semester);
      }
    }

    final visible = _selectedSemester == '__ALL__'
        ? data.courses
        : data.courses.where((c) => c.semester == _selectedSemester).toList();

    final gpa = data.gpaInfo['gpa'] ?? '—';
    final credits =
        '${data.gpaInfo['credits_acquired'] ?? '—'} / ${data.gpaInfo['credits_attempted'] ?? '—'}';
    final rank = data.studentInfo['rank'];

    return RefreshIndicator(
      onRefresh: () => app.syncIns(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: cs.primaryContainer,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((data.studentInfo['name'] ?? '').isNotEmpty)
                    Text(
                      '${data.studentInfo['name']} • ${data.studentInfo['dept'] ?? ''}',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _metric(context, s.gpaLabel, gpa, cs.onPrimaryContainer),
                      _metric(context, s.creditsLabel, credits,
                          cs.onPrimaryContainer),
                      if (rank != null && rank.isNotEmpty)
                        _metric(
                            context, s.rankLabel, rank, cs.onPrimaryContainer),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (semesters.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  FilterChip(
                    label: Text(s.allSemesters),
                    selected: _selectedSemester == '__ALL__',
                    onSelected: (_) =>
                        setState(() => _selectedSemester = '__ALL__'),
                  ),
                  const SizedBox(width: 8),
                  ...semesters.map((sem) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(sem),
                          selected: _selectedSemester == sem,
                          onSelected: (_) =>
                              setState(() => _selectedSemester = sem),
                        ),
                      )),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ...visible.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card.filled(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    title: Text(
                      c.title.isNotEmpty ? c.title : c.courseNumber,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      [
                        if (c.courseNumber.isNotEmpty) c.courseNumber,
                        if (c.credit.isNotEmpty) '${c.credit} cr',
                        if (c.semester.isNotEmpty) c.semester,
                      ].join(' • '),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _gradeColor(c.grade, cs),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        c.grade,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String val, Color fg) {
    return Column(
      children: [
        Text(
          val,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold, color: fg),
        ),
        Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg)),
      ],
    );
  }

  Color _gradeColor(String grade, ColorScheme cs) {
    final g = grade.toUpperCase();
    if (g.startsWith('A')) return Colors.green.shade700;
    if (g.startsWith('B')) return Colors.blue.shade700;
    if (g.startsWith('C')) return Colors.orange.shade700;
    if (g.startsWith('D') || g == 'F') return cs.error;
    return cs.secondary;
  }
}
