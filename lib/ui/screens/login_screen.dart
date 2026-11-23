import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../widgets/expressive_widgets.dart';
import 'privacy_policy_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _eclassPwCtrl = TextEditingController();
  bool _obscureEclass = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _eclassPwCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final app = context.read<AppState>();
    final ok = await app.login(
      studentId: _studentIdCtrl.text.trim(),
      eclassPassword: _eclassPwCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) _error = app.lastError ?? app.s.loginFailed;
    });
  }

  InputDecoration _fieldDecoration({
    required ColorScheme cs,
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: cs.surfaceContainerLow,
      prefixIcon: Icon(prefixIcon, size: 20, color: cs.onSurfaceVariant),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.error, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: cs.error, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            top: -80,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 320,
                  height: 320,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        cs.primary.withValues(alpha: 0.14),
                        cs.secondaryContainer.withValues(alpha: 0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: InhaEmblem(
                            size: 80,
                            radius: 26,
                            showVerifiedBadge: true,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          s.appTitle,
                          textAlign: TextAlign.center,
                          style: tt.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            s.loginTagline,
                            textAlign: TextAlign.center,
                            style: tt.bodyMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        ExpressiveCard(
                          borderRadius: 28,
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    s.studentIdLabel,
                                    style: tt.labelMedium?.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.school_outlined,
                                          size: 14, color: cs.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        s.portalIdTag,
                                        style: tt.labelSmall?.copyWith(
                                          color: cs.primary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _studentIdCtrl,
                                textInputAction: TextInputAction.next,
                                style: tt.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: _fieldDecoration(
                                  cs: cs,
                                  hint: s.enterStudentIdHint,
                                  prefixIcon: Icons.badge_outlined,
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                        ? s.fieldRequired
                                        : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    s.eclassPassword,
                                    style: tt.labelMedium?.copyWith(
                                      color: cs.onSurface,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    s.requiredTag,
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant
                                          .withValues(alpha: 0.75),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _eclassPwCtrl,
                                obscureText: _obscureEclass,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                decoration: _fieldDecoration(
                                  cs: cs,
                                  hint: s.enterEclassPasswordHint,
                                  prefixIcon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureEclass
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      size: 20,
                                      color: cs.onSurfaceVariant,
                                    ),
                                    onPressed: () => setState(
                                        () => _obscureEclass = !_obscureEclass),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? s.fieldRequired
                                    : null,
                              ),
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.sync_rounded,
                                        size: 16, color: cs.secondary),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        s.loginSamePasswordNote,
                                        style: tt.bodySmall?.copyWith(
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_error != null) ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.errorContainer,
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
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
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    backgroundColor: cs.primary,
                                    foregroundColor: cs.onPrimary,
                                    shape: const StadiumBorder(),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (_loading) ...[
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: cs.onPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          s.signingIn,
                                          style: tt.labelLarge?.copyWith(
                                            color: cs.onPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ] else ...[
                                        Text(
                                          s.signIn,
                                          style: tt.labelLarge?.copyWith(
                                            color: cs.onPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.arrow_forward_rounded,
                                            size: 19),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Center(
                          child: ExpressiveSegmentedControl<String>(
                            expand: false,
                            activeColor: cs.primaryFixed,
                            activeForeground: cs.onPrimaryFixed,
                            itemPadding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 9),
                            segments: const [
                              ExpressiveSegment(value: 'ru', label: 'RU'),
                              ExpressiveSegment(value: 'en', label: 'EN'),
                            ],
                            selected: app.settings.language,
                            onChanged: (lang) => app.updateSettings(
                              app.settings.copyWith(language: lang),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton.icon(
                            key: const ValueKey('login_privacy_btn'),
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PrivacyPolicyScreen(),
                              ),
                            ),
                            icon: const Icon(Icons.verified_user_outlined,
                                size: 16),
                            label: Text(
                              s.privacyPolicyTitle,
                              style: tt.labelMedium?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_outlined,
                              size: 14,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                s.campusFooter,
                                textAlign: TextAlign.center,
                                style: tt.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          s.appVersion,
                          textAlign: TextAlign.center,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.55),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
