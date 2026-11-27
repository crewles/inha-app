import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../services/ai_review_service.dart';
import '../../state/app_state.dart';
import 'app_haptics.dart';
import 'expressive_widgets.dart';

Future<void> showAiConfigSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: cs.surfaceContainerLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AiConfigSheet(),
  );
}

class _AiConfigSheet extends StatefulWidget {
  const _AiConfigSheet();

  @override
  State<_AiConfigSheet> createState() => _AiConfigSheetState();
}

class _AiConfigSheetState extends State<_AiConfigSheet> {
  late String _provider;
  late TextEditingController _baseUrlCtrl;
  late TextEditingController _apiKeyCtrl;
  late TextEditingController _modelCtrl;
  bool _obscureKey = true;
  bool _testing = false;
  bool _saving = false;
  String? _testMessage;
  bool _testSuccess = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().settings;
    _provider = AiReviewService.presetFor(settings.aiProvider).id;
    _baseUrlCtrl = TextEditingController(text: settings.aiBaseUrl);
    _apiKeyCtrl = TextEditingController(text: settings.aiApiKey);
    _modelCtrl = TextEditingController(
      text: settings.aiModel.isNotEmpty
          ? settings.aiModel
          : AiReviewService.presetFor(_provider).defaultModel,
    );
  }

  @override
  void dispose() {
    _baseUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    _modelCtrl.dispose();
    super.dispose();
  }

  void _selectProvider(String id) {
    if (_provider == id) return;
    AppHaptics.selection();
    final nextPreset = AiReviewService.presetFor(id);
    final currentModel = _modelCtrl.text.trim();
    final wasPresetModel = AiReviewService.presets.any(
      (p) =>
          p.defaultModel == currentModel ||
          p.suggestedModels.contains(currentModel),
    );
    setState(() {
      _provider = id;
      _testMessage = null;
      if (currentModel.isEmpty || wasPresetModel) {
        _modelCtrl.text = nextPreset.defaultModel;
      }
      if (!nextPreset.isCustom) {
        _baseUrlCtrl.text = '';
      }
    });
  }

  AppSettings _buildDraftSettings(AppSettings base) {
    final preset = AiReviewService.presetFor(_provider);
    return base.copyWith(
      aiProvider: _provider,
      aiBaseUrl: preset.isCustom ? _baseUrlCtrl.text.trim() : '',
      aiApiKey: _apiKeyCtrl.text.trim(),
      aiModel: _modelCtrl.text.trim(),
    );
  }

  Future<void> _testConnection() async {
    AppHaptics.selection();
    final app = context.read<AppState>();
    final draft = _buildDraftSettings(app.settings);
    setState(() {
      _testing = true;
      _testMessage = null;
    });
    try {
      final reply = await app.aiReviewer.testConnection(draft);
      if (!mounted) return;
      AppHaptics.medium();
      setState(() {
        _testSuccess = true;
        _testMessage = app.s.aiConnectionSuccess(reply);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testSuccess = false;
        _testMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    AppHaptics.medium();
    final app = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final draft = _buildDraftSettings(app.settings);
      await app.updateSettings(draft);
      if (!mounted) return;
      Navigator.of(context).pop();
      showQuickToast(context, app.s.aiSavedToast);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clearKey() async {
    AppHaptics.medium();
    final app = context.read<AppState>();
    _apiKeyCtrl.clear();
    await app.updateSettings(app.settings.copyWith(aiApiKey: ''));
    if (!mounted) return;
    setState(() => _testMessage = null);
    showQuickToast(context, app.s.aiKeyClearedToast);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.s;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final preset = AiReviewService.presetFor(_provider);

    return Padding(
      key: const ValueKey('ai_config_sheet'),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
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
                    child: Text(
                      s.aiConfigTitle,
                      style:
                          tt.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.aiConfigPrivacyNote,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s.aiFreeKeyHint,
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.aiProviderLabel,
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
                  for (final p in AiReviewService.presets)
                    ChoiceChip(
                      key: ValueKey('ai_provider_chip_${p.id}'),
                      label: Text(p.label),
                      selected: _provider == p.id,
                      showCheckmark: false,
                      onSelected: (_) => _selectProvider(p.id),
                    ),
                ],
              ),
              if (preset.isCustom) ...[
                const SizedBox(height: 14),
                TextField(
                  key: const ValueKey('ai_base_url_field'),
                  controller: _baseUrlCtrl,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: s.aiBaseUrlLabel,
                    hintText: s.aiBaseUrlHint,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('ai_api_key_field'),
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: s.aiApiKeyLabel,
                  hintText: s.aiApiKeyHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('ai_model_field'),
                controller: _modelCtrl,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: s.aiModelLabel,
                  hintText: s.aiModelHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
              if (preset.suggestedModels.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final model in preset.suggestedModels)
                      ActionChip(
                        label: Text(
                          model,
                          style: tt.labelSmall,
                        ),
                        onPressed: () {
                          AppHaptics.selection();
                          setState(() => _modelCtrl.text = model);
                        },
                      ),
                  ],
                ),
              ],
              if (_testMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _testSuccess
                        ? cs.secondaryFixed
                        : cs.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        _testSuccess
                            ? Icons.check_circle_outline_rounded
                            : Icons.error_outline_rounded,
                        size: 18,
                        color: _testSuccess
                            ? cs.onSecondaryFixed
                            : cs.onErrorContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _testMessage!,
                          style: tt.bodySmall?.copyWith(
                            color: _testSuccess
                                ? cs.onSecondaryFixed
                                : cs.onErrorContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('ai_test_btn'),
                      onPressed: _testing || _saving ? null : _testConnection,
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: _testing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt_rounded, size: 18),
                      label: Text(
                        _testing ? s.aiTestingConnection : s.aiTestConnectionBtn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      key: const ValueKey('ai_save_btn'),
                      onPressed: _testing || _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text(
                        s.save,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              if (app.settings.aiApiKey.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('ai_clear_btn'),
                  onPressed: _testing || _saving ? null : _clearKey,
                  style: TextButton.styleFrom(foregroundColor: cs.error),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: Text(s.aiClearKeyBtn),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
