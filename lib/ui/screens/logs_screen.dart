import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../services/app_logger.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_widgets.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  String _filter = 'all'; // all | error | crash

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(dt.hour)}:${two(dt.minute)}:${two(dt.second)}';
  }

  Color _levelBg(LogLevel level, ColorScheme cs) {
    switch (level) {
      case LogLevel.crash:
      case LogLevel.error:
        return cs.errorContainer;
      case LogLevel.warning:
        return cs.tertiaryFixed;
      case LogLevel.info:
        return cs.primaryFixed;
    }
  }

  Color _levelFg(LogLevel level, ColorScheme cs) {
    switch (level) {
      case LogLevel.crash:
      case LogLevel.error:
        return cs.onErrorContainer;
      case LogLevel.warning:
        return cs.onTertiaryFixed;
      case LogLevel.info:
        return cs.onPrimaryFixed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.logsTitle,
        overline: s.portalHeader,
        showBack: true,
      ),
      body: AnimatedBuilder(
        animation: AppLogger.instance,
        builder: (context, _) {
          final allEntries = AppLogger.instance.entries;
          final filtered = allEntries.where((e) {
            if (_filter == 'error') {
              return e.level == LogLevel.error || e.level == LogLevel.crash;
            }
            if (_filter == 'crash') {
              return e.level == LogLevel.crash;
            }
            return true;
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
            children: [
              // Opt-In Control + Privacy Guarantee Card
              ExpressiveCard(
                borderRadius: 24,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile.adaptive(
                      key: const ValueKey('logs_opt_in_switch'),
                      contentPadding: EdgeInsets.zero,
                      value: app.settings.diagnosticsEnabled,
                      onChanged: (v) async {
                        AppHaptics.selection();
                        await app.updateSettings(
                          app.settings.copyWith(diagnosticsEnabled: v),
                        );
                      },
                      secondary: SquircleIcon(
                        size: 42,
                        radius: 14,
                        iconSize: 21,
                        icon: Icons.bug_report_outlined,
                        backgroundColor: app.settings.diagnosticsEnabled
                            ? cs.primaryFixed
                            : cs.surfaceContainerHigh,
                        iconColor: app.settings.diagnosticsEnabled
                            ? cs.onPrimaryFixed
                            : cs.onSurfaceVariant,
                      ),
                      title: Text(
                        s.logsOptInTitle,
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        s.logsOptInSub,
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 18,
                            color: cs.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.logsPrivacyNotice,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            key: const ValueKey('logs_copy_btn'),
                            onPressed: allEntries.isEmpty
                                ? null
                                : () async {
                                    AppHaptics.medium();
                                    await Clipboard.setData(
                                      ClipboardData(
                                        text: AppLogger.instance.exportText(),
                                      ),
                                    );
                                    if (context.mounted) {
                                      showQuickToast(
                                          context, s.logsCopiedToast);
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              disabledBackgroundColor:
                                  cs.surfaceContainerHighest,
                              disabledForegroundColor:
                                  cs.onSurface.withValues(alpha: 0.55),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.copy_rounded, size: 17),
                            label: Text(
                              s.logsCopyBtn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.labelLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          key: const ValueKey('logs_clear_btn'),
                          onPressed: allEntries.isEmpty
                              ? null
                              : () async {
                                  AppHaptics.medium();
                                  await AppLogger.instance.clear();
                                  if (context.mounted) {
                                    showQuickToast(context, s.logsClearedToast);
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            disabledForegroundColor:
                                cs.onSurface.withValues(alpha: 0.55),
                            shape: const StadiumBorder(),
                            side: BorderSide(color: cs.outlineVariant),
                          ),
                          icon: const Icon(Icons.delete_outline_rounded,
                              size: 18),
                          label: Text(
                            s.logsClearBtn,
                            style: tt.labelLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Filter Row
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip(
                      cs: cs,
                      tt: tt,
                      label: '${s.logsFilterAll} (${allEntries.length})',
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      cs: cs,
                      tt: tt,
                      label: s.logsFilterErrors,
                      selected: _filter == 'error',
                      onTap: () => setState(() => _filter = 'error'),
                    ),
                    const SizedBox(width: 8),
                    _filterChip(
                      cs: cs,
                      tt: tt,
                      label: s.logsFilterCrashes,
                      selected: _filter == 'crash',
                      onTap: () => setState(() => _filter = 'crash'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (filtered.isEmpty)
                ExpressiveCard(
                  borderRadius: 24,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      SquircleIcon(
                        size: 52,
                        radius: 16,
                        iconSize: 26,
                        icon: Icons.article_outlined,
                        backgroundColor: cs.primaryFixed,
                        iconColor: cs.onPrimaryFixed,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        s.logsEmptyTitle,
                        style: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.logsEmptySub,
                        textAlign: TextAlign.center,
                        style:
                            tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              else
                for (final entry in filtered) ...[
                  ExpressiveCard(
                    borderRadius: 18,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ExpressivePill(
                              label: entry.level.name.toUpperCase(),
                              backgroundColor: _levelBg(entry.level, cs),
                              foregroundColor: _levelFg(entry.level, cs),
                              fontWeight: FontWeight.w800,
                            ),
                            const SizedBox(width: 8),
                            ExpressivePill(
                              label: entry.tag,
                              backgroundColor: cs.surfaceContainerHigh,
                              foregroundColor: cs.onSurfaceVariant,
                            ),
                            const Spacer(),
                            Text(
                              _formatTime(entry.timestamp),
                              style: tt.labelSmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          entry.message,
                          style: tt.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (entry.details != null &&
                            entry.details!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              entry.details!,
                              maxLines: 6,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
            ],
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required ColorScheme cs,
    required TextTheme tt,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
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
          child: Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: selected ? cs.onPrimary : cs.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
