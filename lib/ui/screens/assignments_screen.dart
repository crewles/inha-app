import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../state/app_state.dart';

class AssignmentsScreen extends StatefulWidget {
  const AssignmentsScreen({super.key});

  @override
  State<AssignmentsScreen> createState() => _AssignmentsScreenState();
}

class _AssignmentsScreenState extends State<AssignmentsScreen> {
  String _filter = 'pending'; // all | pending | submitted
  final Set<String> _downloading = {};

  Future<void> _downloadAttachment(AssignmentFile att) async {
    setState(() => _downloading.add(att.link));
    try {
      final path = await context
          .read<AppState>()
          .eclass
          .downloadFile(att.link, att.name);
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _downloading.remove(att.link));
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;

    final filtered = app.allAssignments.where((a) {
      if (_filter == 'pending') return !a.isSubmitted;
      if (_filter == 'submitted') return a.isSubmitted;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navAssignments),
        actions: [
          if (app.isSyncing)
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
              onPressed: () => app.syncAllAssignments(),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                FilterChip(
                  label: Text(s.filterPending),
                  selected: _filter == 'pending',
                  onSelected: (_) => setState(() => _filter = 'pending'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(s.filterSubmitted),
                  selected: _filter == 'submitted',
                  onSelected: (_) => setState(() => _filter = 'submitted'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: Text(s.filterAll),
                  selected: _filter == 'all',
                  onSelected: (_) => setState(() => _filter = 'all'),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => app.syncAllAssignments(),
              child: filtered.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.22),
                        Icon(Icons.assignment_turned_in_outlined,
                            size: 64, color: cs.onSurfaceVariant),
                        const SizedBox(height: 12),
                        Center(child: Text(s.noAssignments)),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final a = filtered[i];
                        return Card.filled(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  a.courseName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelMedium
                                      ?.copyWith(color: cs.primary),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        a.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    if (a.gradeDisplay != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: cs.primaryContainer,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          a.gradeDisplay!,
                                          style: TextStyle(
                                            color: cs.onPrimaryContainer,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (a.due.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.schedule_rounded,
                                          size: 15,
                                          color: cs.onSurfaceVariant),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          a.due,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                  color: cs.onSurfaceVariant),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                if (a.files.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    children: a.files.map((f) {
                                      final busy =
                                          _downloading.contains(f.link);
                                      return ActionChip(
                                        avatar: busy
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : const Icon(
                                                Icons.download_rounded,
                                                size: 16),
                                        label: Text(f.name),
                                        onPressed: busy
                                            ? null
                                            : () => _downloadAttachment(f),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
