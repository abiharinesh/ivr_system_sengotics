import 'dart:async';

import 'package:flutter/material.dart';

import '../../../config/app_theme.dart';
import '../../../core/widgets/app_loading_state.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/widgets/dashboard_panels.dart';
import '../../../core/widgets/nav_guard.dart';
import '../../../core/widgets/template_fabric_canvas.dart';
import '../data/document_template_settings_repository.dart';
import '../data/models/document_template_config.dart';
import 'document_template_layout_panel.dart';

class DocumentTemplatesSettingsScreen extends StatefulWidget {
  const DocumentTemplatesSettingsScreen({
    super.key,
    required this.isSuperAdmin,
  });

  final bool isSuperAdmin;

  @override
  State<DocumentTemplatesSettingsScreen> createState() =>
      _DocumentTemplatesSettingsScreenState();
}

class _DocumentTemplatesSettingsScreenState
    extends State<DocumentTemplatesSettingsScreen>
    with SingleTickerProviderStateMixin, NavGuardMixin {
  static const double _wideBreakpoint = 900;

  late final DocumentTemplateSettingsRepository _repo;
  late TabController _tabs;
  final GlobalKey<TemplateFabricCanvasState> _fabricKey = GlobalKey();

  bool _loading = true;
  String? _error;
  final Map<String, TemplateSettingsEntry> _entries = {};
  final Map<String, DocumentTemplateConfig> _drafts = {};
  final Map<String, DocumentTemplateConfig> _baselines = {};
  final Map<String, Map<String, dynamic>?> _fabricScenes = {};
  final Map<String, String?> _overlaySvgs = {};
  final Map<String, String> _previewHtmlByTemplate = {};
  int _lastTabIndex = 0;
  bool _previewLoading = false;
  bool _saving = false;
  bool _dirty = false;
  int? _previewPanchayatId;
  Timer? _previewDebounce;

  @override
  bool get hasUnsavedChanges => _dirty;

  String get _currentTemplateId => kDocumentTemplateIds[_tabs.index];

  String get _currentPreviewHtml =>
      _previewHtmlByTemplate[_currentTemplateId] ?? '';

  @override
  void initState() {
    super.initState();
    _repo = DocumentTemplateSettingsRepository(isSuperAdmin: widget.isSuperAdmin);
    _tabs = TabController(length: kDocumentTemplateIds.length, vsync: this);
    _tabs.addListener(_onTabChanged);
    _load();
  }

  void _syncFabricEditor() {
    _fabricKey.currentState?.loadEditor(
      fabricScene: _fabricScenes[_currentTemplateId],
      previewHtml: _currentPreviewHtml,
    );
  }

  Future<void> _stashCurrentTabCanvas() async {
    final export = await _fabricKey.currentState?.exportDesign();
    if (export == null) return;
    final id = kDocumentTemplateIds[_lastTabIndex];
    _fabricScenes[id] = export.fabricScene;
    _overlaySvgs[id] = export.overlaySvg;
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    if (_tabs.index != _lastTabIndex) {
      _stashCurrentTabCanvas().then((_) {
        if (!mounted) return;
        _lastTabIndex = _tabs.index;
        setState(() {});
        _syncFabricEditor();
        _schedulePreviewRefresh();
      });
    }
  }

  void _schedulePreviewRefresh() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 300), () {
      _refreshPreviewForTemplate(_currentTemplateId);
    });
  }

  @override
  void dispose() {
    _previewDebounce?.cancel();
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.fetchSettings();
      final list = (data['templates'] as List?) ?? [];
      _entries.clear();
      _drafts.clear();
      _baselines.clear();
      _fabricScenes.clear();
      for (final raw in list) {
        if (raw is! Map) continue;
        final entry = TemplateSettingsEntry.fromJson(Map<String, dynamic>.from(raw));
        _entries[entry.templateId] = entry;
        _drafts[entry.templateId] = widget.isSuperAdmin
            ? (entry.global ?? const DocumentTemplateConfig())
            : (entry.panchayatOverride ?? const DocumentTemplateConfig());
        _baselines[entry.templateId] = _drafts[entry.templateId]!;
        final defs = entry.effective.defaults;
        if (defs?['fabric_scene'] is Map) {
          _fabricScenes[entry.templateId] =
              Map<String, dynamic>.from(defs!['fabric_scene'] as Map);
        }
        _overlaySvgs[entry.templateId] = defs?['overlay_svg']?.toString();
      }
      for (final id in kDocumentTemplateIds) {
        _drafts.putIfAbsent(id, () => const DocumentTemplateConfig());
        _baselines.putIfAbsent(id, () => _drafts[id]!);
        _fabricScenes.putIfAbsent(id, () => null);
        _entries.putIfAbsent(
          id,
          () => TemplateSettingsEntry(
            templateId: id,
            labelTa: id,
            labelEn: id,
            effective: _drafts[id]!,
          ),
        );
      }
      if (!mounted) return;
      setState(() {
        _loading = false;
        _dirty = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _schedulePreviewRefresh();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _patchDraft(DocumentTemplateConfig config) {
    setState(() {
      _drafts[_currentTemplateId] = config;
      _dirty = true;
    });
    _schedulePreviewRefresh();
  }

  Map<String, dynamic> _buildSavePayload() {
    final templates = <String, dynamic>{};
    for (final id in kDocumentTemplateIds) {
      final draft = _drafts[id];
      if (draft == null) continue;
      final json = draft.toJson();
      final defs = Map<String, dynamic>.from(draft.defaults ?? {});
      final scene = _fabricScenes[id];
      if (scene != null && scene.isNotEmpty) defs['fabric_scene'] = scene;
      final svg = _overlaySvgs[id];
      if (svg != null && svg.isNotEmpty) defs['overlay_svg'] = svg;
      if (defs.isNotEmpty) json['defaults'] = defs;
      if (json.isNotEmpty) templates[id] = json;
    }
    return templates;
  }

  Future<void> _persistCurrentFabric() async {
    final export = await _fabricKey.currentState?.exportDesign();
    if (export == null) return;
    _fabricScenes[_currentTemplateId] = export.fabricScene;
    _overlaySvgs[_currentTemplateId] = export.overlaySvg;
    await _repo.saveDesign(
      _currentTemplateId,
      fabricScene: export.fabricScene,
      overlaySvg: export.overlaySvg,
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _persistCurrentFabric();
      await _repo.saveSettings(_buildSavePayload());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
          content: Text('Template design and layout saved'),
          backgroundColor: AppTheme.accent,
        ),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetOverride() async {
    if (widget.isSuperAdmin) return;
    try {
      await _repo.resetPanchayatTemplate(_currentTemplateId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reset to platform default')),
      );
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
      );
    }
  }

  Future<void> _refreshPreviewForTemplate(String templateId) async {
    if (!mounted) return;
    setState(() => _previewLoading = true);
    try {
      if (templateId == _currentTemplateId) {
        await _persistCurrentFabric();
      }
      await _repo.saveSettings(_buildSavePayload());
      final html = await _repo.previewHtml(
        templateId,
        panchayatId: widget.isSuperAdmin ? _previewPanchayatId : null,
      );
      if (!mounted) return;
      setState(() {
        _previewHtmlByTemplate[templateId] = html;
        _previewLoading = false;
      });
      if (templateId == _currentTemplateId) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _syncFabricEditor());
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _previewLoading = false);
      if (templateId == _currentTemplateId) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  Future<void> _preview() => _refreshPreviewForTemplate(_currentTemplateId);

  Widget _layoutPanel(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              'Page & alignment',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: DocumentTemplateLayoutPanel(
              templateId: _currentTemplateId,
              entry: _entries[_currentTemplateId],
              draft: _drafts[_currentTemplateId] ?? const DocumentTemplateConfig(),
              onDraftChanged: _patchDraft,
              showPanchayatHint: !widget.isSuperAdmin,
              showPreviewPanchayatId: widget.isSuperAdmin,
              onPreviewPanchayatIdChanged: (v) {
                _previewPanchayatId = v;
                _schedulePreviewRefresh();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvasPane(BuildContext context) {
    final label = _entries[_currentTemplateId]?.labelEn ?? _currentTemplateId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Document editor — $label',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (_previewLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              TemplateFabricCanvas(
                key: _fabricKey,
                fabricScene: _fabricScenes[_currentTemplateId],
                previewHtml: _currentPreviewHtml,
                onDirty: () {},
              ),
              if (_previewLoading && _currentPreviewHtml.isEmpty)
                const ColoredBox(
                  color: Color(0x88000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _workspace(BuildContext context, BoxConstraints constraints) {
    final wide = constraints.maxWidth >= _wideBreakpoint;
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: _layoutPanel(context)),
          const SizedBox(width: 12),
          Expanded(flex: 7, child: _canvasPane(context)),
        ],
      );
    }
    // On narrow screens give the layout panel and the canvas roughly equal
    // share of the available height. The layout panel's contents are already
    // scrollable, and the canvas keeps its interactive area.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 5, child: _layoutPanel(context)),
        const SizedBox(height: 12),
        Expanded(flex: 6, child: _canvasPane(context)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const AppLoadingState(
        message: 'Loading templates...',
        style: AppLoadingStyle.list,
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: const TextStyle(color: AppTheme.error)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, outer) {
        final isNarrow = outer.maxWidth < 600;
        final headerHPad = isNarrow ? 12.0 : 24.0;
        final workspaceHPad = isNarrow ? 8.0 : 12.0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                headerHPad,
                isNarrow ? 16 : 24,
                headerHPad,
                0,
              ),
              child: DashboardPanel(
                title: 'Document templates',
                subtitle: widget.isSuperAdmin
                    ? 'Edit overlays on the document in the canvas; adjust layout on the left.'
                    : 'Panchayat overrides inherit platform design where not set.',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save all'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _previewLoading ? null : _preview,
                      icon: _previewLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh),
                      label: const Text('Refresh document'),
                    ),
                    if (!widget.isSuperAdmin)
                      TextButton(
                        onPressed: _resetOverride,
                        child: const Text('Reset tab'),
                      ),
                  ],
                ),
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: kDocumentTemplateIds.map((id) {
                final e = _entries[id];
                return Tab(text: e?.labelEn ?? id);
              }).toList(),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  workspaceHPad,
                  8,
                  workspaceHPad,
                  12,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      _workspace(context, constraints),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}