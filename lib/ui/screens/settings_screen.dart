import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _showInsPasswordDialog(BuildContext context, AppState app) async {
    final ctrl = TextEditingController(text: app.credentials?.insPassword ?? '');
    final saved = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.s.changeInsPassword),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: InputDecoration(
            labelText: app.s.insPasswordOptional,
            border: const OutlineInputBorder(),
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
    if (saved != null) {
      await app.saveInsPassword(saved);
    }
  }

  Future<void> _confirmLogout(BuildContext context, AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(app.s.logout),
        content: Text(app.s.logoutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(app.s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(app.s.confirm),
          ),
        ],
      ),
    );
    if (ok == true) {
      await app.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final settings = app.settings;

    return Scaffold(
      appBar: AppBar(title: Text(s.navSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionHeader(context, s.accountSection),
          Card.filled(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_rounded),
                  title: Text(app.credentials?.studentId ?? ''),
                  subtitle: Text(s.offlineCache),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.key_rounded),
                  title: Text(s.changeInsPassword),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showInsPasswordDialog(context, app),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader(context, s.appearanceSection),
          Card.filled(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(s.themeLabel,
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          segments: [
                            ButtonSegment(
                                value: 'system', label: Text(s.themeSystem)),
                            ButtonSegment(
                                value: 'light', label: Text(s.themeLight)),
                            ButtonSegment(
                                value: 'dark', label: Text(s.themeDark)),
                          ],
                          selected: {settings.themeMode},
                          onSelectionChanged: (sel) => app.updateSettings(
                            settings.copyWith(themeMode: sel.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SwitchListTile(
                    secondary: const Icon(Icons.palette_outlined),
                    title: Text(s.dynamicColorLabel),
                    subtitle: Text(s.dynamicColorSub),
                    value: settings.dynamicColor,
                    onChanged: (v) => app.updateSettings(
                      settings.copyWith(dynamicColor: v),
                    ),
                  ),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.language_rounded),
                        const SizedBox(width: 16),
                        Expanded(child: Text(s.languageLabel)),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'ru', label: Text('RU')),
                            ButtonSegment(value: 'en', label: Text('EN')),
                          ],
                          selected: {settings.language},
                          onSelectionChanged: (sel) => app.updateSettings(
                            settings.copyWith(language: sel.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader(context, s.notificationsSection),
          Card.filled(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active_outlined),
                  title: Text(s.notifyAssignments),
                  value: settings.notifyAssignments,
                  onChanged: (v) => app.updateSettings(
                    settings.copyWith(notifyAssignments: v),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.alarm_rounded),
                  title: Text(s.notifyTimetable),
                  value: settings.notifyTimetable,
                  onChanged: (v) => app.updateSettings(
                    settings.copyWith(notifyTimetable: v),
                  ),
                ),
                if (settings.notifyTimetable)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        Expanded(child: Text(s.reminderOffset)),
                        DropdownButton<int>(
                          value: settings.reminderOffsetMinutes,
                          underline: const SizedBox.shrink(),
                          items: const [5, 10, 15, 30, 60]
                              .map((m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(s.isRu ? '$m мин' : '$m min'),
                                  ))
                              .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              app.updateSettings(
                                settings.copyWith(reminderOffsetMinutes: v),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.cloud_sync_outlined),
                  title: Text(s.bgSyncLabel),
                  subtitle: Text(s.bgSyncSub),
                  value: settings.bgSyncEnabled,
                  onChanged: (v) => app.updateSettings(
                    settings.copyWith(bgSyncEnabled: v),
                  ),
                ),
                if (settings.bgSyncEnabled)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 40),
                        Expanded(child: Text(s.bgSyncInterval)),
                        SegmentedButton<int>(
                          segments: [
                            ButtonSegment(
                                value: 1, label: Text(s.isRu ? '1ч' : '1h')),
                            ButtonSegment(
                                value: 2, label: Text(s.isRu ? '2ч' : '2h')),
                            ButtonSegment(
                                value: 4, label: Text(s.isRu ? '4ч' : '4h')),
                          ],
                          selected: {settings.bgSyncIntervalHours},
                          onSelectionChanged: (sel) => app.updateSettings(
                            settings.copyWith(bgSyncIntervalHours: sel.first),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync_rounded),
                  title: Text(s.syncNow),
                  trailing: app.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: app.isSyncing ? null : () => app.syncEverything(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _sectionHeader(context, s.storageSection),
          Card.filled(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.cleaning_services_outlined),
                  title: Text(s.clearCache),
                  onTap: () async {
                    await app.clearCache();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.cacheCleared)),
                      );
                    }
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: cs.error),
                  title: Text(s.logout, style: TextStyle(color: cs.error)),
                  onTap: () => _confirmLogout(context, app),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}
