import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_widgets.dart';
import 'assignment_detail_screen.dart';

class DraftsScreen extends StatefulWidget {
  const DraftsScreen({super.key});

  @override
  State<DraftsScreen> createState() => _DraftsScreenState();
}

class _DraftsScreenState extends State<DraftsScreen> {
  String _filter = 'all'; // all | eclass | local
  final Set<String> _busyKeys = {};
  final Set<String> _downloadingLinks = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final app = context.read<AppState>();
      app.syncPrivateFiles(silent: app.eclassPrivateFiles.isNotEmpty);
      if (app.allAssignments.isEmpty) {
        app.syncAllAssignments();
      }
    });
  }

  Future<void> _refreshAll(AppState app) async {
    await Future.wait([
      app.syncPrivateFiles(),
      app.syncAllAssignments(),
    ]);
  }

  Future<void> _downloadAndOpen(AppState app, AssignmentFile f) async {
    AppHaptics.selection();
    setState(() => _downloadingLinks.add(f.link));
    try {
      final path = await app.eclass.downloadFile(f.link, f.name);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) showQuickToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _downloadingLinks.remove(f.link));
    }
  }

  Future<void> _downloadAndOpenPrivateFile(
    AppState app,
    EclassPrivateFile file,
  ) async {
    final key = 'priv::${file.id}';
    AppHaptics.selection();
    setState(() => _downloadingLinks.add(key));
    try {
      final path = await app.eclass.downloadPrivateFile(file);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) showQuickToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _downloadingLinks.remove(key));
    }
  }

  Future<void> _replaceEclassDraft(
    BuildContext context,
    AppState app,
    Assignment a,
  ) async {
    final assignId = a.assignId;
    if (assignId == null) return;
    final res = await FilePicker.platform.pickFiles();
    if (res == null || res.files.single.path == null || !mounted) return;

    final key = 'eclass::${a.id}';
    AppHaptics.medium();
    setState(() => _busyKeys.add(key));
    try {
      await app.eclass.uploadSubmission(
        assignId,
        res.files.single.path!,
        res.files.single.name,
        submitForGrading: false,
        assignmentUrl: a.url,
      );
      if (!mounted) return;
      AppHaptics.heavy();
      showQuickToast(this.context, app.s.uploadSuccess);
      if (a.courseId.isNotEmpty) {
        await app.syncCourseAssignments(a.courseId, a.courseName);
      } else {
        await app.syncAllAssignments();
      }
    } catch (e) {
      if (mounted) showQuickToast(this.context, e.toString());
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _submitEclassDraft(
    BuildContext context,
    AppState app,
    Assignment a,
  ) async {
    final assignId = a.assignId;
    if (assignId == null) return;
    final key = 'eclass::${a.id}';
    AppHaptics.medium();
    setState(() => _busyKeys.add(key));
    try {
      await app.eclass.submitExistingDraft(assignId);
      if (!mounted) return;
      AppHaptics.heavy();
      showQuickToast(this.context, app.s.draftSubmittedToast);
      if (a.courseId.isNotEmpty) {
        await app.syncCourseAssignments(a.courseId, a.courseName);
      } else {
        await app.syncAllAssignments();
      }
    } catch (e) {
      if (mounted) showQuickToast(this.context, e.toString());
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _uploadLocalDraft(
    BuildContext context,
    AppState app,
    LocalDraft draft, {
    required bool submitForGrading,
  }) async {
    final key = 'local::${draft.id ?? draft.filePath}';
    AppHaptics.medium();
    setState(() => _busyKeys.add(key));
    try {
      await app.uploadLocalDraft(draft, submitForGrading: submitForGrading);
      if (!mounted) return;
      AppHaptics.heavy();
      showQuickToast(
        this.context,
        submitForGrading ? app.s.draftSubmittedToast : app.s.uploadSuccess,
      );
    } catch (e) {
      if (mounted) showQuickToast(this.context, e.toString());
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<Assignment?> _pickCandidateAssignment(
    BuildContext context,
    AppState app,
  ) async {
    final candidates = app.activeAssignments
        .where((a) => !a.isSubmitted && !a.isGradedOnly && a.assignId != null)
        .toList();
    if (candidates.isEmpty) {
      showQuickToast(context, app.s.noAssignments);
      return null;
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final s = app.s;

    return showModalBottomSheet<Assignment>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.35,
          builder: (_, scrollCtrl) => ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              Text(
                s.draftsPickAssignmentTitle,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final a in candidates)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    tileColor: cs.surfaceContainerLow,
                    leading: SquircleIcon(
                      size: 40,
                      radius: 12,
                      iconSize: 20,
                      icon: Icons.assignment_outlined,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    title: Text(
                      a.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style:
                          tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      [
                        if (a.courseName.isNotEmpty) a.courseName,
                        if (a.due.isNotEmpty) a.due,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    onTap: () => Navigator.pop(ctx, a),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _attachPrivateFileToAssignment(
    BuildContext context,
    AppState app,
    EclassPrivateFile file,
  ) async {
    AppHaptics.selection();
    final chosen = await _pickCandidateAssignment(context, app);
    if (chosen == null || !mounted) return;

    final cs = Theme.of(this.context).colorScheme;
    final tt = Theme.of(this.context).textTheme;
    final s = app.s;

    final submitMode = await showModalBottomSheet<bool>(
      context: this.context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.draftsChooseActionTitle,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${file.filename} -> ${chosen.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 14),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: cs.surfaceContainerLow,
                leading: SquircleIcon(
                  size: 40,
                  radius: 12,
                  iconSize: 20,
                  icon: Icons.cloud_upload_outlined,
                  backgroundColor: cs.primaryFixed,
                  iconColor: cs.onPrimaryFixed,
                ),
                title: Text(
                  s.draftsUploadAsDraftBtn,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                onTap: () => Navigator.pop(ctx, false),
              ),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                tileColor: cs.primaryContainer,
                leading: SquircleIcon(
                  size: 40,
                  radius: 12,
                  iconSize: 20,
                  icon: Icons.send_rounded,
                  backgroundColor: cs.primary,
                  iconColor: cs.onPrimary,
                ),
                title: Text(
                  s.draftsSubmitNowBtn,
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                onTap: () => Navigator.pop(ctx, true),
              ),
            ],
          ),
        ),
      ),
    );
    if (submitMode == null || !mounted) return;

    final key = 'priv::${file.id}';
    AppHaptics.medium();
    setState(() => _busyKeys.add(key));
    try {
      await app.submitPrivateFileToAssignment(
        file: file,
        assignment: chosen,
        submitForGrading: submitMode,
      );
      if (!mounted) return;
      AppHaptics.heavy();
      showQuickToast(
        this.context,
        submitMode ? s.draftSubmittedToast : s.uploadSuccess,
      );
    } catch (e) {
      if (mounted) showQuickToast(this.context, e.toString());
    } finally {
      if (mounted) setState(() => _busyKeys.remove(key));
    }
  }

  Future<void> _pickAndStageNewDraft(
    BuildContext context,
    AppState app,
  ) async {
    AppHaptics.selection();
    final chosen = await _pickCandidateAssignment(context, app);
    if (chosen == null || !mounted) return;

    final s = app.s;
    final picked = await FilePicker.platform.pickFiles();
    if (picked == null || picked.files.single.path == null || !mounted) return;

    await app.stageLocalDraft(
      assignment: chosen,
      sourcePath: picked.files.single.path!,
      fileName: picked.files.single.name,
    );
    if (mounted) {
      AppHaptics.medium();
      showQuickToast(this.context, s.draftStagedToast);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final eclassDrafts = app.eclassDraftAssignments;
    final privateFiles = app.eclassPrivateFiles;
    final eclassTotal = eclassDrafts.length + privateFiles.length;
    final localDrafts = app.localDrafts;
    final total = eclassTotal + localDrafts.length;

    final showEclass =
        (_filter == 'all' || _filter == 'eclass') && eclassDrafts.isNotEmpty;
    final showPrivateFiles =
        (_filter == 'all' || _filter == 'eclass') && privateFiles.isNotEmpty;
    final showLocal =
        (_filter == 'all' || _filter == 'local') && localDrafts.isNotEmpty;
    final visibleEmpty = !showEclass && !showPrivateFiles && !showLocal;

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.draftsTitle,
        overline: s.portalHeader,
        showBack: true,
        actions: [
          CircleActionButton(
            key: const ValueKey('stage_draft_top_btn'),
            icon: Icons.add_rounded,
            tooltip: s.draftsStageNewBtn,
            backgroundColor: cs.primary,
            iconColor: cs.onPrimary,
            onPressed: () => _pickAndStageNewDraft(context, app),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshAll(app),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
          children: [
            // Overview Bento Card
            ExpressiveCard(
              borderRadius: 24,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SquircleIcon(
                        size: 46,
                        radius: 15,
                        iconSize: 23,
                        icon: Icons.folder_special_rounded,
                        backgroundColor: cs.primaryFixed,
                        iconColor: cs.onPrimaryFixed,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.draftsWorkspaceOverline,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.7,
                              ),
                            ),
                            Text(
                              s.draftsOverviewTitle,
                              style: tt.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleActionButton(
                        icon: Icons.refresh_rounded,
                        tooltip: s.refresh,
                        loading: app.isSyncing || app.isSyncingPrivateFiles,
                        onPressed: () {
                          AppHaptics.selection();
                          _refreshAll(app);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _statBox(
                          cs: cs,
                          tt: tt,
                          icon: Icons.cloud_outlined,
                          label: s.draftsOnEclassLabel,
                          count: eclassTotal,
                          sublabel: s.draftsSavedCountLabel,
                          accentColor: cs.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _statBox(
                          cs: cs,
                          tt: tt,
                          icon: Icons.smartphone_rounded,
                          label: s.draftsOnPhoneLabel,
                          count: localDrafts.length,
                          sublabel: s.draftsLocalCountLabel,
                          accentColor: cs.tertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    s.draftsOverviewDesc,
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _filterPill(
                        key: const ValueKey('drafts_filter_all'),
                        cs: cs,
                        tt: tt,
                        icon: Icons.layers_rounded,
                        label: s.draftsFilterAll(total),
                        selected: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      _filterPill(
                        key: const ValueKey('drafts_filter_eclass'),
                        cs: cs,
                        tt: tt,
                        icon: Icons.cloud_queue_rounded,
                        label: s.draftsFilterEclass(eclassTotal),
                        selected: _filter == 'eclass',
                        onTap: () => setState(() => _filter = 'eclass'),
                      ),
                      _filterPill(
                        key: const ValueKey('drafts_filter_local'),
                        cs: cs,
                        tt: tt,
                        icon: Icons.smartphone_rounded,
                        label: s.draftsFilterLocal(localDrafts.length),
                        selected: _filter == 'local',
                        onTap: () => setState(() => _filter = 'local'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (showEclass) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  Icon(Icons.cloud_sync_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.draftsEclassSectionTitle(eclassDrafts.length),
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              for (final a in eclassDrafts) ...[
                _buildEclassDraftCard(context, app, a, cs, tt, s),
                const SizedBox(height: 12),
              ],
            ],

            if (showPrivateFiles) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Icon(Icons.cloud_done_outlined, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.draftsPrivateFilesSectionTitle(privateFiles.length),
                      style: tt.labelMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.draftsPrivateFilesSectionSub,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              for (final f in privateFiles) ...[
                _buildPrivateFileCard(context, app, f, cs, tt, s),
                const SizedBox(height: 10),
              ],
            ],

            if (showLocal) ...[
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.smartphone_rounded, size: 18, color: cs.tertiary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.draftsLocalSectionTitle(localDrafts.length),
                      style: tt.labelMedium?.copyWith(
                        color: cs.tertiary,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                s.draftsLocalSectionSub,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 10),
              for (final d in localDrafts) ...[
                _buildLocalDraftCard(context, app, d, cs, tt, s),
                const SizedBox(height: 12),
              ],
            ],

            if (visibleEmpty) ...[
              const SizedBox(height: 18),
              ExpressiveCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    SquircleIcon(
                      size: 56,
                      radius: 18,
                      iconSize: 28,
                      icon: Icons.folder_open_rounded,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      s.draftsEmptyTitle,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.draftsEmptySub,
                      textAlign: TextAlign.center,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 14),
            SizedBox(
              height: 50,
              child: FilledButton.tonalIcon(
                key: const ValueKey('stage_draft_bottom_btn'),
                onPressed: () => _pickAndStageNewDraft(context, app),
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primaryFixed,
                  foregroundColor: cs.onPrimaryFixed,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: Text(
                  s.draftsStageNewBtn,
                  style: tt.titleSmall?.copyWith(
                    color: cs.onPrimaryFixed,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox({
    required ColorScheme cs,
    required TextTheme tt,
    required IconData icon,
    required String label,
    required int count,
    required String sublabel,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: accentColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.labelSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$count',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  sublabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _filterPill({
    Key? key,
    required ColorScheme cs,
    required TextTheme tt,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      key: key,
      color: selected ? cs.primary : cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          AppHaptics.selection();
          onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: tt.labelMedium?.copyWith(
                  color: selected ? cs.onPrimary : cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrivateFileCard(
    BuildContext context,
    AppState app,
    EclassPrivateFile file,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final dlKey = 'priv::${file.id}';
    final downloading = _downloadingLinks.contains(dlKey);
    final attaching = _busyKeys.contains(dlKey);
    final folderClean =
        file.filepath.replaceAll(RegExp(r'^/+|/+$'), '').trim();
    final folderLabel =
        folderClean.isEmpty ? s.draftsRootFolderLabel : folderClean;
    final sizeLabel = file.sizeText.isNotEmpty
        ? file.sizeText
        : (file.size > 0 ? formatFileSize(file.size) : '');
    final subtitleParts = <String>[
      if (sizeLabel.isNotEmpty) sizeLabel,
      if (file.modifiedText.isNotEmpty) file.modifiedText,
      if (file.fileType.isNotEmpty && !file.fileType.contains('/'))
        file.fileType,
    ];

    return ExpressiveCard(
      borderRadius: 22,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ExpressivePill(
                icon: folderClean.isEmpty
                    ? Icons.cloud_done_outlined
                    : Icons.folder_outlined,
                label: folderLabel,
                backgroundColor: cs.primaryFixed,
                foregroundColor: cs.onPrimaryFixed,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SquircleIcon(
                size: 40,
                radius: 12,
                iconSize: 20,
                icon: iconForFileName(file.filename),
                backgroundColor: cs.surfaceContainerHigh,
                iconColor: cs.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.filename,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (subtitleParts.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitleParts.join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (downloading || attaching)
                      ? null
                      : () => _downloadAndOpenPrivateFile(app, file),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  icon: downloading
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.primary,
                          ),
                        )
                      : const Icon(Icons.visibility_outlined, size: 17),
                  label: Text(
                    s.draftsOpenFileBtn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: (downloading || attaching)
                      ? null
                      : () => _attachPrivateFileToAssignment(context, app, file),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  icon: attaching
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.attach_file_rounded, size: 17),
                  label: Text(
                    s.draftsAttachToAssignmentBtn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEclassDraftCard(
    BuildContext context,
    AppState app,
    Assignment a,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final busy = _busyKeys.contains('eclass::${a.id}');
    return ExpressiveCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AssignmentDetailScreen(assignment: a),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (a.courseName.isNotEmpty)
                ExpressivePill(
                  icon: Icons.school_outlined,
                  label: a.courseName,
                  backgroundColor: cs.primaryFixed,
                  foregroundColor: cs.onPrimaryFixed,
                  fontWeight: FontWeight.w700,
                ),
              ExpressivePill(
                icon: Icons.edit_note_rounded,
                label: s.draftStatus,
                backgroundColor: cs.tertiaryFixed,
                foregroundColor: cs.onTertiaryFixed,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            a.name,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (a.due.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(
                  a.due,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          if (a.submittedFiles.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final sf in a.submittedFiles) ...[
              Material(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _downloadingLinks.contains(sf.link)
                      ? null
                      : () => _downloadAndOpen(app, sf),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        SquircleIcon(
                          size: 34,
                          radius: 10,
                          iconSize: 18,
                          icon: iconForFileName(sf.name),
                          backgroundColor: cs.primaryFixed,
                          iconColor: cs.onPrimaryFixed,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                sf.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.labelLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (sf.size > 0)
                                Text(
                                  formatFileSize(sf.size),
                                  style: tt.labelSmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _downloadingLinks.contains(sf.link)
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: cs.primary,
                                ),
                              )
                            : Icon(Icons.visibility_outlined,
                                size: 18, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
            ],
          ],
          if (a.assignId != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => _replaceEclassDraft(context, app, a),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 11),
                      side: BorderSide(color: cs.outlineVariant),
                    ),
                    icon: const Icon(Icons.upload_rounded, size: 17),
                    label: Text(
                      s.draftsReplaceFileBtn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed:
                        busy ? null : () => _submitEclassDraft(context, app, a),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 11),
                    ),
                    icon: busy
                        ? SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(
                      s.draftsSubmitForGradingBtn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tt.labelMedium?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
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

  Widget _buildLocalDraftCard(
    BuildContext context,
    AppState app,
    LocalDraft d,
    ColorScheme cs,
    TextTheme tt,
    dynamic s,
  ) {
    final key = 'local::${d.id ?? d.filePath}';
    final busy = _busyKeys.contains(key);
    final matchedAssignment = app.allAssignments.cast<Assignment?>().firstWhere(
          (a) => a?.id == d.assignmentId,
          orElse: () => null,
        );

    return ExpressiveCard(
      borderRadius: 24,
      padding: const EdgeInsets.all(16),
      onTap: matchedAssignment == null
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      AssignmentDetailScreen(assignment: matchedAssignment),
                ),
              ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (d.courseName.isNotEmpty)
                ExpressivePill(
                  icon: Icons.school_outlined,
                  label: d.courseName,
                  backgroundColor: cs.primaryFixed,
                  foregroundColor: cs.onPrimaryFixed,
                  fontWeight: FontWeight.w700,
                ),
              ExpressivePill(
                icon: Icons.smartphone_rounded,
                label: s.draftsOnDeviceBadge,
                backgroundColor: cs.secondaryFixed,
                foregroundColor: cs.onSecondaryFixed,
                fontWeight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            d.assignmentName,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (d.due.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 15, color: cs.onSurfaceVariant),
                const SizedBox(width: 5),
                Text(
                  d.due,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Material(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => OpenFilex.open(d.filePath),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    SquircleIcon(
                      size: 34,
                      radius: 10,
                      iconSize: 18,
                      icon: iconForFileName(d.fileName),
                      backgroundColor: cs.tertiaryFixed,
                      iconColor: cs.onTertiaryFixed,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (d.fileSize > 0)
                            Text(
                              formatFileSize(d.fileSize),
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.open_in_new_rounded,
                        size: 17, color: cs.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy || d.assignId == null
                      ? null
                      : () => _uploadLocalDraft(context, app, d,
                          submitForGrading: false),
                  style: OutlinedButton.styleFrom(
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 11),
                    side: BorderSide(color: cs.outlineVariant),
                  ),
                  icon: const Icon(Icons.cloud_upload_outlined, size: 17),
                  label: Text(
                    s.draftsUploadAsDraftBtn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        tt.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy || d.assignId == null
                      ? null
                      : () => _uploadLocalDraft(context, app, d,
                          submitForGrading: true),
                  style: FilledButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 11),
                  ),
                  icon: busy
                      ? SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.check_circle_outline_rounded,
                          size: 17),
                  label: Text(
                    s.draftsSubmitNowBtn,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: busy
                    ? null
                    : () async {
                        AppHaptics.medium();
                        await app.removeLocalDraft(d);
                        if (context.mounted) {
                          showQuickToast(context, s.draftRemovedToast);
                        }
                      },
                style: IconButton.styleFrom(
                  backgroundColor: cs.errorContainer,
                  foregroundColor: cs.onErrorContainer,
                ),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
