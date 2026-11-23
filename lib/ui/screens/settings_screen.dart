import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_sheets.dart';
import '../widgets/expressive_widgets.dart';
import 'drafts_screen.dart';
import 'logs_screen.dart';
import 'privacy_policy_screen.dart';
import 'widget_gallery_screen.dart';

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
    final studentName =
        formatPersonName(app.insData?.studentInfo['name'] ?? '');
    final gradeYear = (app.insData?.studentInfo['grade_year'] ?? '').trim();
    final displayName = studentName.isNotEmpty ? studentName : studentId;
    final hasCustomIns = (app.credentials?.insPassword ?? '').trim().isNotEmpty;
    final isIos = !kIsWeb && Platform.isIOS;

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
                GestureDetector(
                  onLongPress: studentId.isEmpty
                      ? null
                      : () async {
                          AppHaptics.medium();
                          await Clipboard.setData(
                              ClipboardData(text: studentId));
                          if (context.mounted) {
                            showQuickToast(context, s.copiedToast(studentId));
                          }
                        },
                  child: Row(
                    children: [
                      InitialsAvatar(
                        name: displayName,
                        imagePath: app.profileAvatarPath,
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
                if (!isIos) ...[
                  _divider(cs),
                  Row(
                    children: [
                      SquircleIcon(
                        size: 40,
                        radius: 14,
                        iconSize: 20,
                        icon: Icons.wallpaper_rounded,
                        backgroundColor: cs.primaryFixed,
                        iconColor: cs.onPrimaryFixed,
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
                ],
                _divider(cs),
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.language_rounded,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
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
                _divider(cs),
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.vibration_rounded,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.hapticsTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            s.hapticsSub,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      key: const ValueKey('switch_haptics'),
                      value: settings.hapticsEnabled,
                      onChanged: (v) async {
                        await app.updateSettings(
                          settings.copyWith(hapticsEnabled: v),
                        );
                        if (v) AppHaptics.medium();
                      },
                    ),
                  ],
                ),
                if (!isIos) ...[
                  _divider(cs),
                  Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const ValueKey('open_widget_gallery_btn'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        AppHaptics.light();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const WidgetGalleryScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 6),
                        child: Row(
                          children: [
                            SquircleIcon(
                              size: 40,
                              radius: 14,
                              iconSize: 20,
                              icon: Icons.widgets_outlined,
                              backgroundColor: cs.primaryFixed,
                              iconColor: cs.onPrimaryFixed,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.homeWidgetsTitle,
                                    style: tt.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    s.homeWidgetsSub,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
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
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.classRemindersTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
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
                if (settings.notifyTimetable) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ExpressiveSegmentedControl<int>(
                      expand: false,
                      itemPadding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      segments: [
                        ExpressiveSegment(
                            value: 5, label: s.isRu ? '5м' : '5m'),
                        ExpressiveSegment(
                            value: 10, label: s.isRu ? '10м' : '10m'),
                        ExpressiveSegment(
                            value: 15, label: s.isRu ? '15м' : '15m'),
                        ExpressiveSegment(
                            value: 30, label: s.isRu ? '30м' : '30m'),
                        ExpressiveSegment(
                            value: 60, label: s.isRu ? '1ч' : '1h'),
                      ],
                      selected: settings.reminderOffsetMinutes,
                      onChanged: (m) => app.updateSettings(
                        settings.copyWith(reminderOffsetMinutes: m),
                      ),
                    ),
                  ),
                ],
                if (!isIos) ...[
                  _divider(cs),
                  Row(
                    children: [
                      SquircleIcon(
                        size: 40,
                        radius: 14,
                        iconSize: 20,
                        icon: Icons.sync_rounded,
                        backgroundColor: cs.primaryFixed,
                        iconColor: cs.onPrimaryFixed,
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
                ],
                _divider(cs),
                Row(
                  children: [
                    SquircleIcon(
                      size: 40,
                      radius: 14,
                      iconSize: 20,
                      icon: Icons.grade_outlined,
                      backgroundColor: cs.primaryFixed,
                      iconColor: cs.onPrimaryFixed,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.gradeAlertsTitle,
                            style: tt.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            s.gradeAlertsSub,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Switch(
                      value: settings.notifyGrades,
                      onChanged: (v) {
                        AppHaptics.selection();
                        app.updateSettings(
                          settings.copyWith(notifyGrades: v),
                        );
                      },
                    ),
                  ],
                ),
                _divider(cs),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('test_notifications_btn'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      AppHaptics.light();
                      showNotificationDiagnosticsSheet(context, app);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          SquircleIcon(
                            size: 40,
                            radius: 14,
                            iconSize: 20,
                            icon: Icons.notifications_paused_outlined,
                            backgroundColor: cs.primaryFixed,
                            iconColor: cs.onPrimaryFixed,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.testNotificationsTitle,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s.testNotificationsSub,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('check_updates_btn'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: app.isCheckingUpdate
                        ? null
                        : () async {
                            AppHaptics.light();
                            final res = await app.checkForUpdate();
                            if (!context.mounted) return;
                            if (res.status == UpdateCheckStatus.available &&
                                res.release != null) {
                              await showUpdateAvailableSheet(
                                  context, res.release!);
                            } else if (res.status ==
                                UpdateCheckStatus.upToDate) {
                              showQuickToast(context, s.upToDateToast);
                            } else if (res.status ==
                                UpdateCheckStatus.unavailable) {
                              showQuickToast(context, s.updateRepoPrivateToast);
                            } else {
                              showQuickToast(context, s.updateCheckFailedToast);
                            }
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          SquircleIcon(
                            size: 40,
                            radius: 14,
                            iconSize: 20,
                            icon: Icons.system_update_rounded,
                            backgroundColor: cs.primaryFixed,
                            iconColor: cs.onPrimaryFixed,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.checkUpdatesTitle,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s.checkUpdatesSub(
                                      UpdateService.currentVersion),
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (app.isCheckingUpdate)
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.primary,
                              ),
                            )
                          else if (app.availableUpdate != null)
                            ExpressivePill(
                              label: s.updateAvailableBadge(
                                  app.availableUpdate!.version),
                              backgroundColor: cs.primary,
                              foregroundColor: cs.onPrimary,
                              fontWeight: FontWeight.w700,
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                _divider(cs),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('settings_drafts_btn'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      AppHaptics.selection();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const DraftsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          SquircleIcon(
                            size: 40,
                            radius: 14,
                            iconSize: 20,
                            icon: Icons.folder_copy_outlined,
                            backgroundColor: cs.primaryFixed,
                            iconColor: cs.onPrimaryFixed,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.draftsTitle,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s.draftsSub,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (app.totalDraftsCount > 0)
                            ExpressivePill(
                              label: '${app.totalDraftsCount}',
                              backgroundColor: cs.tertiaryFixed,
                              foregroundColor: cs.onTertiaryFixed,
                              fontWeight: FontWeight.w700,
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                _divider(cs),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('privacy_policy_btn'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      AppHaptics.selection();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacyPolicyScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          SquircleIcon(
                            size: 40,
                            radius: 14,
                            iconSize: 20,
                            icon: Icons.verified_user_outlined,
                            backgroundColor: cs.primaryFixed,
                            iconColor: cs.onPrimaryFixed,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.privacyPolicyTitle,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s.privacyPolicySub,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _divider(cs),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('settings_logs_btn'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      AppHaptics.selection();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LogsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          SquircleIcon(
                            size: 40,
                            radius: 14,
                            iconSize: 20,
                            icon: Icons.bug_report_outlined,
                            backgroundColor: cs.primaryFixed,
                            iconColor: cs.onPrimaryFixed,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.logsTitle,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s.logsSub,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ExpressivePill(
                            label: app.settings.diagnosticsEnabled
                                ? s.logsStatusOn
                                : s.logsStatusOff,
                            backgroundColor: app.settings.diagnosticsEnabled
                                ? cs.primaryFixed
                                : cs.surfaceContainerHigh,
                            foregroundColor: app.settings.diagnosticsEnabled
                                ? cs.onPrimaryFixed
                                : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _divider(cs),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    key: const ValueKey('github_repo_btn'),
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {
                      AppHaptics.selection();
                      launchUrl(
                        Uri.parse(UpdateService.repoWebUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          SquircleIcon(
                            size: 40,
                            radius: 14,
                            iconSize: 20,
                            icon: Icons.code_rounded,
                            backgroundColor: cs.primaryFixed,
                            iconColor: cs.onPrimaryFixed,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.githubRepoTitle,
                                  style: tt.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  s.githubRepoSub,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 18,
                            color: cs.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _divider(cs),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await app.clearCache();
                      await _loadCacheSize();
                      if (context.mounted) {
                        showQuickToast(context, s.cacheCleared);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: Row(
                        children: [
                          SquircleIcon(
                            size: 40,
                            radius: 14,
                            iconSize: 20,
                            icon: Icons.delete_sweep_outlined,
                            backgroundColor: cs.errorContainer,
                            iconColor: cs.onErrorContainer,
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
