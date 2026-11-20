import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/expressive_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _cacheBytes = 0;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final bytes = await context.read<AppState>().getDownloadsCacheBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  Future<void> _showInsPasswordDialog(
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

  Future<void> _pickReminderOffset(
      BuildContext context, AppState app) async {
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final chosen = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(
            s.reminderOffset,
            style: Theme.of(ctx)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final m in const [5, 10, 15, 30, 60])
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(s.isRu ? '$m мин' : '$m min'),
              trailing: app.settings.reminderOffsetMinutes == m
                  ? Icon(Icons.check_circle_rounded, color: cs.primary)
                  : null,
              onTap: () => Navigator.pop(ctx, m),
            ),
        ],
      ),
    );
    if (chosen != null) {
      await app.updateSettings(
        app.settings.copyWith(reminderOffsetMinutes: chosen),
      );
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
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
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
    final tt = Theme.of(context).textTheme;
    final settings = app.settings;

    final studentId = app.credentials?.studentId ?? '';
    final studentName = (app.insData?.studentInfo['name'] ?? '').trim();
    final gradeYear = (app.insData?.studentInfo['grade_year'] ?? '').trim();
    final displayName = studentName.isNotEmpty ? studentName : studentId;
    final hasCustomIns =
        (app.credentials?.insPassword ?? '').trim().isNotEmpty;
    final offsetLabel =
        '${settings.reminderOffsetMinutes} ${s.isRu ? "мин" : "min"}';

    return Scaffold(
      appBar: ExpressiveAppBar(
        title: s.navSettings,
        overline: s.portalHeader,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Text(
            s.preferencesOverline,
            style: tt.labelSmall?.copyWith(
              color: cs.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.9,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.navSettings,
            style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            s.settingsSubtitle,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // ── ACCOUNT ──────────────────────────────────────────
          _sectionLabel(tt, cs, s.accountSection),
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    InitialsAvatar(
                      name: displayName,
                      size: 48,
                      showVerifiedBadge: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            gradeYear.isNotEmpty
                                ? 'Student ID: $studentId • ${s.yearLabel(gradeYear)}'
                                : 'Student ID: $studentId',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                _divider(cs),
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _showInsPasswordDialog(context, app),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SquircleIcon(
                          size: 40,
                          radius: 14,
                          iconSize: 20,
                          icon: Icons.key_rounded,
                          backgroundColor: cs.primaryFixed,
                          iconColor: cs.onPrimaryFixed,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.changeInsPassword,
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                s.updateInsSub,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        ExpressivePill(
                          icon: hasCustomIns
                              ? Icons.check_circle_rounded
                              : Icons.sync_rounded,
                          label: hasCustomIns
                              ? s.insOverrideBadge
                              : s.insAutoPasswordBadge,
                          backgroundColor: hasCustomIns
                              ? cs.primaryFixed
                              : cs.secondaryFixed,
                          foregroundColor: hasCustomIns
                              ? cs.onPrimaryFixed
                              : cs.onSecondaryFixed,
                          fontWeight: FontWeight.w700,
                        ),
                        const SizedBox(width: 6),
                        Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── APPEARANCE ───────────────────────────────────────
          _sectionLabel(tt, cs, s.appearanceSection),
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 20, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      s.themeModeTitle,
                      style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ExpressiveSegmentedControl<String>(
                  segments: [
                    ExpressiveSegment(
                      value: 'system',
                      label: s.themeSystem,
                      icon: Icons.settings_brightness_rounded,
                    ),
                    ExpressiveSegment(
                      value: 'light',
                      label: s.themeLight,
                      icon: Icons.light_mode_rounded,
                    ),
                    ExpressiveSegment(
                      value: 'dark',
                      label: s.themeDark,
                      icon: Icons.dark_mode_rounded,
                    ),
                  ],
                  selected: settings.themeMode,
                  onChanged: (mode) => app.updateSettings(
                    settings.copyWith(themeMode: mode),
                  ),
                ),
                _divider(cs),
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.wallpaper_rounded,
                      backgroundColor: cs.secondaryFixed,
                      iconColor: cs.onSecondaryFixed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.matchWallpaperTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            s.matchWallpaperSub,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: settings.dynamicColor,
                      onChanged: (v) => app.updateSettings(
                        settings.copyWith(dynamicColor: v),
                      ),
                    ),
                  ],
                ),
                _divider(cs),
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.language_rounded,
                      backgroundColor: cs.surfaceContainerHigh,
                      iconColor: cs.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.displayLanguageTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            s.displayLanguageSub,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    ExpressiveSegmentedControl<String>(
                      expand: false,
                      itemPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 7),
                      segments: const [
                        ExpressiveSegment(value: 'ru', label: 'RU'),
                        ExpressiveSegment(value: 'en', label: 'EN'),
                      ],
                      selected: settings.language,
                      onChanged: (lang) => app.updateSettings(
                        settings.copyWith(language: lang),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── NOTIFICATIONS & SYNC ─────────────────────────────
          _sectionLabel(tt, cs, s.notificationsSection),
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.timer_outlined,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.deadlineRemindersTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            s.deadlineRemindersSub,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: settings.notifyAssignments,
                      onChanged: (v) => app.updateSettings(
                        settings.copyWith(notifyAssignments: v),
                      ),
                    ),
                  ],
                ),
                _divider(cs),
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.notifications_active_outlined,
                      backgroundColor: cs.secondaryFixed,
                      iconColor: cs.onSecondaryFixed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  s.classRemindersTitle,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ExpressivePill(
                                label: offsetLabel,
                                backgroundColor: cs.surfaceContainerHigh,
                                foregroundColor: cs.primary,
                                fontWeight: FontWeight.w700,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 3),
                                onTap: () => _pickReminderOffset(context, app),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.classRemindersBefore(
                                settings.reminderOffsetMinutes),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: settings.notifyTimetable,
                      onChanged: (v) => app.updateSettings(
                        settings.copyWith(notifyTimetable: v),
                      ),
                    ),
                  ],
                ),
                _divider(cs),
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.sync_rounded,
                      backgroundColor: cs.surfaceContainerHigh,
                      iconColor: cs.onSurface,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.autoCheckTasksTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            s.autoCheckTasksSub,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: settings.bgSyncEnabled,
                      onChanged: (v) => app.updateSettings(
                        settings.copyWith(bgSyncEnabled: v),
                      ),
                    ),
                  ],
                ),
                if (settings.bgSyncEnabled) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ExpressiveSegmentedControl<int>(
                      expand: false,
                      itemPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      segments: [
                        ExpressiveSegment(
                            value: 1, label: s.isRu ? '1ч' : '1h'),
                        ExpressiveSegment(
                            value: 2, label: s.isRu ? '2ч' : '2h'),
                        ExpressiveSegment(
                            value: 4, label: s.isRu ? '4ч' : '4h'),
                      ],
                      selected: settings.bgSyncIntervalHours,
                      onChanged: (h) => app.updateSettings(
                        settings.copyWith(bgSyncIntervalHours: h),
                      ),
                    ),
                  ),
                ],
                _divider(cs),
                SizedBox(
                  height: 46,
                  child: FilledButton.tonal(
                    onPressed:
                        app.isSyncing ? null : () => app.syncEverything(),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primaryFixed,
                      foregroundColor: cs.onPrimaryFixed,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (app.isSyncing)
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimaryFixed,
                            ),
                          )
                        else
                          const Icon(Icons.refresh_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          s.refreshAllNow,
                          style: tt.titleSmall?.copyWith(
                            color: cs.onPrimaryFixed,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── DATA & PRIVACY ───────────────────────────────────
          _sectionLabel(tt, cs, s.dataPrivacySection),
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    await app.clearCache();
                    await _loadCacheSize();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s.cacheCleared)),
                      );
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SquircleIcon(
                          size: 40,
                          radius: 14,
                          iconSize: 20,
                          icon: Icons.delete_sweep_outlined,
                          backgroundColor: cs.surfaceContainerHigh,
                          iconColor: cs.onSurface,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.clearOfflineCacheTitle,
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _cacheBytes > 0
                                    ? s.offlineCacheSub(
                                        formatFileSize(_cacheBytes))
                                    : s.offlineCache,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.delete_outline_rounded,
                          size: 20,
                          color: cs.error,
                        ),
                      ],
                    ),
                  ),
                ),
                _divider(cs),
                SizedBox(
                  height: 50,
                  child: FilledButton.tonal(
                    onPressed: () => _confirmLogout(context, app),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.errorContainer,
                      foregroundColor: cs.onErrorContainer,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          s.logoutPortal,
                          style: tt.titleSmall?.copyWith(
                            color: cs.onErrorContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── FOOTER ───────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 14,
                color: cs.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.appVersionFooter,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            s.localStorageFooter,
            textAlign: TextAlign.center,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(TextTheme tt, ColorScheme cs, String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: tt.labelMedium?.copyWith(
          color: cs.onSurfaceVariant,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _divider(ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Container(
        height: 1,
        color: cs.surfaceContainerHighest,
      ),
    );
  }
}
