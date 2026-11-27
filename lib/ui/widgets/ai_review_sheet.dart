import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/ai_review_service.dart';
import '../../state/app_state.dart';
import 'ai_config_sheet.dart';
import 'app_haptics.dart';
import 'expressive_widgets.dart';

Future<void> showAiReviewSheet(
  BuildContext context, {
  required Assignment assignment,
  PlatformFile? initialPickedFile,
}) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: cs.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => _AiReviewSheet(
      assignment: assignment,
      initialPickedFile: initialPickedFile,
    ),
  );
}

class _AiReviewSheet extends StatefulWidget {
  final Assignment assignment;
  final PlatformFile? initialPickedFile;

  const _AiReviewSheet({
    required this.assignment,
    this.initialPickedFile,
  });

  @override
  State<_AiReviewSheet> createState() => _AiReviewSheetState();
}

class _AiReviewSheetState extends State<_AiReviewSheet> {
  AiCheckMode _mode = AiCheckMode.requirements;
  final List<({String name, String path, int size})> _localFiles = [];
  final Set<String> _selectedDraftPaths = {};
  final Set<String> _selectedSubmittedLinks = {};
  bool _includeSpecFiles = false;
  late TextEditingController _pasteCtrl;

  bool _running = false;
  bool _showingCached = false;
  String? _error;
  List<AiAttachment> _skippedAttachments = const [];
  AiReviewResult? _result;

  @override
  void initState() {
    super.initState();
    _pasteCtrl = TextEditingController();
    final initial = widget.initialPickedFile;
    if (initial != null && initial.path != null && initial.path!.isNotEmpty) {
      _localFiles.add(
        (name: initial.name, path: initial.path!, size: initial.size),
      );
    }

    final app = context.read<AppState>();
    for (final d in app.localDrafts) {
      if (d.assignmentId == widget.assignment.id &&
          d.filePath.isNotEmpty &&
          File(d.filePath).existsSync()) {
        _selectedDraftPaths.add(d.filePath);
      }
    }
    if (_localFiles.isEmpty &&
        _selectedDraftPaths.isEmpty &&
        widget.assignment.submittedFiles.isNotEmpty) {
      _selectedSubmittedLinks.add(widget.assignment.submittedFiles.first.link);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final cached = await app.loadAiReview(widget.assignment.id);
      if (mounted && cached != null && _result == null) {
        setState(() {
          _result = cached;
          _mode = cached.mode;
          _showingCached = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _pasteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFiles() async {
    AppHaptics.selection();
    final res = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (res == null || !mounted) return;
    setState(() {
      for (final f in res.files) {
        final path = f.path;
        if (path == null || path.isEmpty) continue;
        if (_localFiles.any((e) => e.path == path)) continue;
        _localFiles.add((name: f.name, path: path, size: f.size));
      }
    });
  }

  Future<void> _runCheck() async {
    AppHaptics.medium();
    final app = context.read<AppState>();
    final s = app.s;
    final settings = app.settings;
    final preset = AiReviewService.presetFor(settings.aiProvider);

    setState(() {
      _running = true;
      _error = null;
      _skippedAttachments = const [];
    });

    try {
      final attachments = <AiAttachment>[];
      final seenPaths = <String>{};

      for (final lf in _localFiles) {
        if (!seenPaths.add(lf.path)) continue;
        attachments.add(
          await AiAttachment.fromFile(
            lf.path,
            role: 'submission',
            supportsPdf: preset.supportsPdf,
          ),
        );
      }

      for (final dPath in _selectedDraftPaths) {
        if (!seenPaths.add(dPath)) continue;
        attachments.add(
          await AiAttachment.fromFile(
            dPath,
            role: 'submission',
            supportsPdf: preset.supportsPdf,
          ),
        );
      }

      for (final sf in widget.assignment.submittedFiles) {
        if (!_selectedSubmittedLinks.contains(sf.link)) continue;
        final path = await app.eclass.downloadFile(sf.link, sf.name);
        if (!seenPaths.add(path)) continue;
        attachments.add(
          await AiAttachment.fromFile(
            path,
            role: 'submission',
            supportsPdf: preset.supportsPdf,
          ),
        );
      }

      if (_includeSpecFiles) {
        for (final spec in widget.assignment.files) {
          final path = await app.eclass.downloadFile(spec.link, spec.name);
          if (!seenPaths.add(path)) continue;
          attachments.add(
            await AiAttachment.fromFile(
              path,
              role: 'spec',
              supportsPdf: preset.supportsPdf,
            ),
          );
        }
      }

      final included = attachments.where((a) => a.isIncluded).toList();
      final skipped = attachments.where((a) => !a.isIncluded).toList();
      final pasted = _pasteCtrl.text.trim();

      if (included.isEmpty &&
          pasted.isEmpty &&
          widget.assignment.intro.trim().isEmpty) {
        if (!mounted) return;
        setState(() {
          _skippedAttachments = skipped;
          _error = s.aiNeedContentError;
        });
        return;
      }

      final review = await app.aiReviewer.reviewHomework(
        settings: settings,
        assignment: widget.assignment,
        mode: _mode,
        attachments: included,
        pastedSolution: pasted,
      );
      await app.saveAiReview(review);

      if (!mounted) return;
      AppHaptics.heavy();
      setState(() {
        _result = review;
        _showingCached = false;
        _skippedAttachments = skipped;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      key: const ValueKey('ai_review_sheet'),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.86,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) {
          return SafeArea(
            top: false,
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              children: [
                Row(
                  children: [
                    SquircleIcon(
                      size: 42,
                      radius: 14,
                      iconSize: 22,
                      icon: Icons.auto_awesome_rounded,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.aiReviewTitle,
                            style: tt.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            widget.assignment.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (app.settings.isAiConfigured)
                      IconButton(
                        tooltip: s.aiConfigTitle,
                        onPressed:
                            _running ? null : () => showAiConfigSheet(context),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!app.settings.isAiConfigured)
                  _buildUnconfiguredCard(context, cs, tt, s)
                else ...[
                  _buildControlsCard(context, app, cs, tt, s),
                  if (_skippedAttachments.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildSkippedBanner(cs, tt, s),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.errorContainer,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.error_outline_rounded,
                              size: 18, color: cs.onErrorContainer),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onErrorContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 16),
                    _buildResultSection(context, app, _result!, cs, tt, s),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildUnconfiguredCard(
    BuildContext context,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    return ExpressiveCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          SquircleIcon(
            size: 56,
            radius: 18,
            iconSize: 28,
            icon: Icons.vpn_key_outlined,
            backgroundColor: cs.primaryFixed,
            iconColor: cs.onPrimaryFixed,
          ),
          const SizedBox(height: 12),
          Text(
            s.aiNotConfiguredTitle,
            textAlign: TextAlign.center,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            s.aiNotConfiguredDesc,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              key: const ValueKey('ai_review_open_config_btn'),
              onPressed: () => showAiConfigSheet(context),
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              icon: const Icon(Icons.key_rounded, size: 18),
              label: Text(
                s.aiOpenSettingsBtn,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsCard(
    BuildContext context,
    AppState app,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final matchingDrafts = app.localDrafts
        .where((d) =>
            d.assignmentId == widget.assignment.id &&
            d.filePath.isNotEmpty &&
            File(d.filePath).existsSync())
        .toList();

    return ExpressiveCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.aiModeLabel,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(s.aiModeRequirements),
                selected: _mode == AiCheckMode.requirements,
                showCheckmark: false,
                onSelected: _running
                    ? null
                    : (_) {
                        AppHaptics.selection();
                        setState(() => _mode = AiCheckMode.requirements);
                      },
              ),
              ChoiceChip(
                label: Text(s.aiModeBugs),
                selected: _mode == AiCheckMode.bugsAndEdgeCases,
                showCheckmark: false,
                onSelected: _running
                    ? null
                    : (_) {
                        AppHaptics.selection();
                        setState(() => _mode = AiCheckMode.bugsAndEdgeCases);
                      },
              ),
              ChoiceChip(
                label: Text(s.aiModeStrict),
                selected: _mode == AiCheckMode.strictGrader,
                showCheckmark: false,
                onSelected: _running
                    ? null
                    : (_) {
                        AppHaptics.selection();
                        setState(() => _mode = AiCheckMode.strictGrader);
                      },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            s.aiSourcesLabel,
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (_localFiles.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (int i = 0; i < _localFiles.length; i++)
                  InputChip(
                    avatar: Icon(
                      iconForFileName(_localFiles[i].name),
                      size: 16,
                    ),
                    label: Text(
                      s.aiUsePickedLabel(_localFiles[i].name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onDeleted: _running
                        ? null
                        : () => setState(() => _localFiles.removeAt(i)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (matchingDrafts.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final d in matchingDrafts)
                  FilterChip(
                    label: Text(s.aiUseDraftLabel(d.fileName)),
                    selected: _selectedDraftPaths.contains(d.filePath),
                    onSelected: _running
                        ? null
                        : (v) {
                            setState(() {
                              if (v) {
                                _selectedDraftPaths.add(d.filePath);
                              } else {
                                _selectedDraftPaths.remove(d.filePath);
                              }
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          if (widget.assignment.submittedFiles.isNotEmpty) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final sf in widget.assignment.submittedFiles)
                  FilterChip(
                    label: Text(sf.name),
                    selected: _selectedSubmittedLinks.contains(sf.link),
                    onSelected: _running
                        ? null
                        : (v) {
                            setState(() {
                              if (v) {
                                _selectedSubmittedLinks.add(sf.link);
                              } else {
                                _selectedSubmittedLinks.remove(sf.link);
                              }
                            });
                          },
                  ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          OutlinedButton.icon(
            onPressed: _running ? null : _pickFiles,
            style: OutlinedButton.styleFrom(
              shape: const StadiumBorder(),
            ),
            icon: const Icon(Icons.attach_file_rounded, size: 18),
            label: Text(s.aiPickFileBtn),
          ),
          if (widget.assignment.files.isNotEmpty) ...[
            const SizedBox(height: 4),
            CheckboxListTile(
              value: _includeSpecFiles,
              onChanged: _running
                  ? null
                  : (v) => setState(() => _includeSpecFiles = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                s.aiIncludeSpecFilesLabel,
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                widget.assignment.files.map((f) => f.name).join(', '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('ai_paste_solution_field'),
            controller: _pasteCtrl,
            enabled: !_running,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(
              labelText: s.aiPasteSolutionLabel,
              hintText: s.aiPasteSolutionHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: FilledButton.icon(
              key: const ValueKey('ai_run_check_btn'),
              onPressed: _running ? null : _runCheck,
              style: FilledButton.styleFrom(
                shape: const StadiumBorder(),
              ),
              icon: _running
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.onPrimary,
                      ),
                    )
                  : const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                _running
                    ? s.aiRunningCheck
                    : (_result == null ? s.aiRunCheckBtn : s.aiRerunCheckBtn),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkippedBanner(ColorScheme cs, TextTheme tt, dynamic s) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.aiSkippedFilesTitle,
            style: tt.labelMedium?.copyWith(
              color: cs.onTertiaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          for (final item in _skippedAttachments)
            Text(
              '• ${item.name}: ${s.aiSkipReasonText(item.skippedReason ?? '')}',
              style: tt.bodySmall?.copyWith(color: cs.onTertiaryContainer),
            ),
        ],
      ),
    );
  }

  Widget _buildResultSection(
    BuildContext context,
    AppState app,
    AiReviewResult result,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.aiDisclaimer,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    if (_showingCached) ...[
                      const SizedBox(height: 4),
                      Text(
                        s.aiCachedNotice,
                        style: tt.labelSmall?.copyWith(
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (!result.hasStructuredContent)
          ExpressiveCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              result.rawMarkdown,
              style: tt.bodyMedium?.copyWith(height: 1.45),
            ),
          )
        else ...[
          ExpressiveCard(
            borderRadius: 20,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.aiSummaryTitle,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (result.estimatedScore != null)
                      ExpressivePill(
                        label:
                            '${s.aiEstimatedScoreLabel}: ${result.estimatedScore}',
                        backgroundColor: cs.primaryFixed,
                        foregroundColor: cs.onPrimaryFixed,
                        fontWeight: FontWeight.w800,
                      ),
                  ],
                ),
                if (result.summary.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    result.summary,
                    style: tt.bodyMedium?.copyWith(height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          if (result.checklist.isNotEmpty) ...[
            const SizedBox(height: 12),
            ExpressiveCard(
              borderRadius: 20,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.aiChecklistTitle,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (int i = 0; i < result.checklist.length; i++) ...[
                    _buildChecklistRow(result.checklist[i], cs, tt, s),
                    if (i != result.checklist.length - 1)
                      const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ],
          if (result.issues.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBulletsCard(
              title: s.aiIssuesTitle,
              items: result.issues,
              icon: Icons.warning_amber_rounded,
              iconColor: cs.error,
              tt: tt,
            ),
          ],
          if (result.suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildBulletsCard(
              title: s.aiSuggestionsTitle,
              items: result.suggestions,
              icon: Icons.lightbulb_outline_rounded,
              iconColor: cs.primary,
              tt: tt,
            ),
          ],
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  AppHaptics.selection();
                  await Clipboard.setData(
                    ClipboardData(text: result.toShareableText()),
                  );
                  if (context.mounted) {
                    showQuickToast(context, s.aiReportCopiedToast);
                  }
                },
                style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(s.aiCopyReportBtn),
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () async {
                AppHaptics.selection();
                await app.clearAiReview(widget.assignment.id);
                if (mounted) {
                  setState(() {
                    _result = null;
                    _showingCached = false;
                  });
                }
              },
              icon: const Icon(Icons.clear_rounded, size: 18),
              label: Text(s.aiClearReportBtn),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChecklistRow(
    AiRequirementItem item,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final (Color bg, Color fg, String statusLabel) = switch (item.status) {
      'met' => (cs.secondaryFixed, cs.onSecondaryFixed, s.aiStatusMet),
      'missing' => (cs.errorContainer, cs.onErrorContainer, s.aiStatusMissing),
      _ => (cs.tertiaryContainer, cs.onTertiaryContainer, s.aiStatusPartial),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpressivePill(
          label: statusLabel,
          backgroundColor: bg,
          foregroundColor: fg,
          fontWeight: FontWeight.w700,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.requirement,
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  item.note,
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBulletsCard({
    required String title,
    required List<String> items,
    required IconData icon,
    required Color iconColor,
    required TextTheme tt,
  }) {
    return ExpressiveCard(
      borderRadius: 20,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          for (int i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 17, color: iconColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    items[i],
                    style: tt.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],
            ),
            if (i != items.length - 1) const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
