import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _studentIdCtrl = TextEditingController();
  final _eclassPwCtrl = TextEditingController();
  final _insPwCtrl = TextEditingController();
  bool _obscureEclass = true;
  bool _obscureIns = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _studentIdCtrl.dispose();
    _eclassPwCtrl.dispose();
    _insPwCtrl.dispose();
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
      studentId: _studentIdCtrl.text,
      eclassPassword: _eclassPwCtrl.text,
      insPassword: _insPwCtrl.text,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (!ok) _error = app.lastError ?? app.s.loginFailed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          Icons.school_rounded,
                          size: 44,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      s.appTitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.loginSubtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 28),
                    Card.filled(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _studentIdCtrl,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: s.studentId,
                                prefixIcon: const Icon(Icons.badge_outlined),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? s.fieldRequired
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _eclassPwCtrl,
                              obscureText: _obscureEclass,
                              textInputAction: TextInputAction.next,
                              decoration: InputDecoration(
                                labelText: s.eclassPassword,
                                prefixIcon: const Icon(Icons.lock_outline),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureEclass
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(
                                      () => _obscureEclass = !_obscureEclass),
                                ),
                              ),
                              validator: (v) =>
                                  (v == null || v.isEmpty)
                                      ? s.fieldRequired
                                      : null,
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _insPwCtrl,
                              obscureText: _obscureIns,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: s.insPasswordOptional,
                                prefixIcon: const Icon(Icons.key_outlined),
                                border: const OutlineInputBorder(),
                                suffixIcon: IconButton(
                                  icon: Icon(_obscureIns
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined),
                                  onPressed: () => setState(
                                      () => _obscureIns = !_obscureIns),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _error!,
                                  style:
                                      TextStyle(color: cs.onErrorContainer),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _loading ? null : _submit,
                              style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              icon: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.login_rounded),
                              label: Text(_loading ? s.signingIn : s.signIn),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(value: 'ru', label: Text('Русский')),
                          ButtonSegment(value: 'en', label: Text('English')),
                        ],
                        selected: {app.settings.language},
                        onSelectionChanged: (sel) => app.updateSettings(
                          app.settings.copyWith(language: sel.first),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
