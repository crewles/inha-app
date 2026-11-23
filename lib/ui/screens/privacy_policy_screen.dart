import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/update_service.dart';
import '../../state/app_state.dart';
import '../widgets/app_haptics.dart';
import '../widgets/expressive_widgets.dart';
import 'logs_screen.dart';

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  int _cacheBytes = 0;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final bytes = await context.read<AppState>().getDownloadsCacheBytes();
    if (mounted) setState(() => _cacheBytes = bytes);
  }

  Future<void> _clearCache(AppState app) async {
    if (_clearing) return;
    AppHaptics.medium();
    setState(() => _clearing = true);
    try {
      await app.clearCache();
      await _loadCacheSize();
      if (mounted) {
        showQuickToast(context, app.s.cacheCleared);
      }
    } finally {
      if (mounted) setState(() => _clearing = false);
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
        title: s.privacyPolicyTitle,
        overline: s.portalHeader,
        showBack: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 36),
        children: [
          HeroGradientCard(
            borderRadius: 28,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF4ADE80),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            s.privacyHeroBadge,
                            style: tt.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user_outlined,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  s.privacyHeroTitle,
                  style: tt.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  s.privacyHeroDesc,
                  style: tt.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          s.privacyHeroStatus,
                          style: tt.labelSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          Row(
            children: [
              Icon(Icons.shield_rounded, color: cs.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.privacySectionTitle,
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            s.privacySectionSub,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),

          // Card 1 — On-Device Credentials
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  cs: cs,
                  tt: tt,
                  icon: Icons.vpn_key_rounded,
                  overline: s.privacyCard1Overline,
                  title: s.privacyCard1Title,
                ),
                const SizedBox(height: 12),
                Text(
                  s.privacyCard1Desc,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ExpressivePill(
                      icon: Icons.smartphone_rounded,
                      label: s.privacyChipOnDevice,
                      backgroundColor: cs.primaryFixed,
                      foregroundColor: cs.onPrimaryFixed,
                    ),
                    ExpressivePill(
                      icon: Icons.visibility_off_rounded,
                      label: s.privacyChipNoTracking,
                      backgroundColor: cs.surfaceContainerHigh,
                      foregroundColor: cs.onSurfaceVariant,
                    ),
                    ExpressivePill(
                      icon: Icons.verified_user_outlined,
                      label: s.privacyChipNoServers,
                      backgroundColor: cs.secondaryFixed,
                      foregroundColor: cs.onSecondaryFixed,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 2 — Direct Portal Connections
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  cs: cs,
                  tt: tt,
                  icon: Icons.hub_rounded,
                  overline: s.privacyCard2Overline,
                  title: s.privacyCard2Title,
                ),
                const SizedBox(height: 12),
                Text(
                  s.privacyCard2Desc,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _endpointRow(
                        cs: cs,
                        tt: tt,
                        icon: Icons.school_outlined,
                        host: 'eclass.inha.ac.kr',
                        subtitle: s.privacyEndpointEclassSub,
                        badge: s.privacyBadgeDirect,
                      ),
                      const SizedBox(height: 10),
                      _endpointRow(
                        cs: cs,
                        tt: tt,
                        icon: Icons.analytics_outlined,
                        host: 'ins.inha.uz',
                        subtitle: s.privacyEndpointInsSub,
                        badge: s.privacyBadgeOfficial,
                      ),
                      const SizedBox(height: 10),
                      _endpointRow(
                        cs: cs,
                        tt: tt,
                        icon: Icons.calendar_today_outlined,
                        host: 'iut.edupage.org',
                        subtitle: s.privacyEndpointEdupageSub,
                        badge: s.privacyBadgeDirect,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 3 — Offline Storage & Instant Wipe
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  cs: cs,
                  tt: tt,
                  icon: Icons.folder_copy_outlined,
                  overline: s.privacyCard3Overline,
                  title: s.privacyCard3Title,
                ),
                const SizedBox(height: 12),
                Text(
                  s.privacyCard3Desc,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
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
                        Icons.delete_forever_rounded,
                        size: 20,
                        color: cs.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s.privacyLogoutWipeNote,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurface,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.tonalIcon(
                    onPressed: _clearing ? null : () => _clearCache(app),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primaryFixed,
                      foregroundColor: cs.onPrimaryFixed,
                      shape: const StadiumBorder(),
                    ),
                    icon: _clearing
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.onPrimaryFixed,
                            ),
                          )
                        : const Icon(Icons.cleaning_services_outlined,
                            size: 18),
                    label: Text(
                      s.privacyClearFilesBtn(formatFileSize(_cacheBytes)),
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
          const SizedBox(height: 12),

          // Card 4 — Open Source & Transparent
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  cs: cs,
                  tt: tt,
                  icon: Icons.code_rounded,
                  overline: s.privacyCard4Overline,
                  title: s.privacyCard4Title,
                ),
                const SizedBox(height: 12),
                Text(
                  s.privacyCard4Desc,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    key: const ValueKey('privacy_github_btn'),
                    onPressed: () {
                      AppHaptics.selection();
                      launchUrl(
                        Uri.parse(UpdateService.repoWebUrl),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(
                      s.privacyInspectGithubBtn,
                      style: tt.titleSmall?.copyWith(
                        color: cs.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Card 5 — Optional Diagnostic Logs (Zero Personal Data)
          ExpressiveCard(
            borderRadius: 24,
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(
                  cs: cs,
                  tt: tt,
                  icon: Icons.bug_report_outlined,
                  overline: s.privacyCardLogsOverline,
                  title: s.privacyCardLogsTitle,
                ),
                const SizedBox(height: 12),
                Text(
                  s.privacyCardLogsDesc,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('privacy_open_logs_btn'),
                    onPressed: () {
                      AppHaptics.selection();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LogsScreen()),
                      );
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.primaryFixed,
                      foregroundColor: cs.onPrimaryFixed,
                      shape: const StadiumBorder(),
                    ),
                    icon: const Icon(Icons.article_outlined, size: 18),
                    label: Text(
                      s.privacyOpenLogsBtn,
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
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: cs.onSurfaceVariant.withValues(alpha: 0.75),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  s.privacyFooterNote,
                  textAlign: TextAlign.center,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cardHeader({
    required ColorScheme cs,
    required TextTheme tt,
    required IconData icon,
    required String overline,
    required String title,
  }) {
    return Row(
      children: [
        SquircleIcon(
          size: 46,
          radius: 15,
          iconSize: 22,
          icon: icon,
          backgroundColor: cs.primaryFixed,
          iconColor: cs.onPrimaryFixed,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overline.toUpperCase(),
                style: tt.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _endpointRow({
    required ColorScheme cs,
    required TextTheme tt,
    required IconData icon,
    required String host,
    required String subtitle,
    required String badge,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                host,
                style: tt.labelLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                subtitle,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        ExpressivePill(
          label: badge,
          backgroundColor: cs.primaryFixed,
          foregroundColor: cs.onPrimaryFixed,
          fontWeight: FontWeight.w700,
        ),
      ],
    );
  }
}
