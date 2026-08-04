import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/features/dashboard/data/dashboard_models.dart';
import 'package:ivr_frontend/features/dashboard/data/dashboard_repository.dart';
import 'package:ivr_frontend/features/dashboard/presentation/widgets/dashboard_widget_card.dart';

/// Arrange what each role lands on.
///
/// `dashboard_widgets` and `role_dashboards` were designed and never wired, so
/// every role saw one of two hardcoded screens. This pane is the missing half:
/// pick a role, tick the panels, reorder them, and see the result rendered
/// with that role's real figures before saving.
class DashboardLayoutPane extends StatefulWidget {
  const DashboardLayoutPane({super.key, this.onChanged});

  final VoidCallback? onChanged;

  @override
  State<DashboardLayoutPane> createState() => _DashboardLayoutPaneState();
}

class _DashboardLayoutPaneState extends State<DashboardLayoutPane> {
  final _repo = DashboardRepository();

  bool _loading = true;
  bool _saving = false;
  String? _error;

  List<RoleLayout> _layouts = const [];
  List<DashboardWidgetGroup> _palette = const [];

  RoleLayout? _selected;

  /// The working copy. Order matters — it is the layout.
  List<int> _chosen = [];

  RoleDashboardData _preview = RoleDashboardData.empty;
  bool _previewLoading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static String _msg(Object e) => e is ApiException ? e.message : e.toString();

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.layouts(),
        _repo.palette(),
      ]);
      if (!mounted) return;
      setState(() {
        _layouts = results[0] as List<RoleLayout>;
        _palette = results[1] as List<DashboardWidgetGroup>;
        _loading = false;
      });
      final keep = _selected;
      final next = keep == null
          ? (_layouts.isEmpty ? null : _layouts.first)
          : _layouts.where((l) => l.roleName == keep.roleName).firstOrNull ??
              _layouts.firstOrNull;
      if (next != null) _select(next);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _msg(e);
        _loading = false;
      });
    }
  }

  void _select(RoleLayout layout) {
    setState(() {
      _selected = layout;
      _chosen = [...layout.widgetIds];
    });
    _loadPreview(layout.roleName);
  }

  Future<void> _loadPreview(String role) async {
    setState(() => _previewLoading = true);
    try {
      final d = await _repo.preview(role);
      if (!mounted) return;
      setState(() {
        _preview = d;
        _previewLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // The preview is a convenience; the editor below still works without it.
      setState(() => _previewLoading = false);
    }
  }

  bool get _dirty {
    final saved = _selected?.widgetIds ?? const [];
    if (saved.length != _chosen.length) return true;
    for (var i = 0; i < saved.length; i++) {
      if (saved[i] != _chosen[i]) return true;
    }
    return false;
  }

  Future<void> _save() async {
    final role = _selected;
    if (role == null) return;
    setState(() => _saving = true);
    try {
      await _repo.setLayout(role.roleName, _chosen);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${role.displayName} now lands on ${_chosen.length} panel(s).',
          ),
        ),
      );
      widget.onChanged?.call();
      await _load();
      await _loadPreview(role.roleName);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.error,
          content: Text(_msg(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 36, color: AppTheme.error),
            const SizedBox(height: 10),
            Text(_error!, style: TextStyle(color: AppTheme.textMuted)),
            const SizedBox(height: 14),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth > 1080;
        final editor = Column(
          children: [
            Expanded(child: _paletteList()),
            _footer(),
          ],
        );

        if (!wide) {
          return Row(
            children: [
              SizedBox(width: 230, child: _roleList()),
              VerticalDivider(width: 1, color: AppTheme.stroke),
              Expanded(child: editor),
            ],
          );
        }

        return Row(
          children: [
            SizedBox(width: 250, child: _roleList()),
            VerticalDivider(width: 1, color: AppTheme.stroke),
            SizedBox(width: 420, child: editor),
            VerticalDivider(width: 1, color: AppTheme.stroke),
            Expanded(child: _previewPane()),
          ],
        );
      },
    );
  }

  // ── Roles ──────────────────────────────────────────────────────────────────

  Widget _roleList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _layouts.length,
      itemBuilder: (context, i) {
        final l = _layouts[i];
        final selected = _selected?.roleName == l.roleName;
        return InkWell(
          onTap: () => _select(l),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.07)
                  : Colors.transparent,
              border: Border(
                left: BorderSide(
                  width: 3,
                  color: selected ? AppTheme.primary : Colors.transparent,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.configured
                            ? '${l.widgetIds.length} panel(s)'
                            : 'default layout',
                        style: TextStyle(
                          fontSize: 11,
                          color: l.configured
                              ? AppTheme.textMuted
                              : AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!l.configured)
                  const Icon(Icons.circle, size: 7, color: AppTheme.warning),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Palette ────────────────────────────────────────────────────────────────

  Widget _paletteList() {
    final role = _selected;
    if (role == null) {
      return Center(
        child: Text(
          'Pick a role',
          style: TextStyle(color: AppTheme.textMuted),
        ),
      );
    }

    final byId = {
      for (final g in _palette)
        for (final w in g.items) w.id: w,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      children: [
        Text(
          'ON THIS DASHBOARD',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        if (_chosen.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            ),
            child: Text(
              'No panels chosen. This role will fall back to the general set.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          )
        else
          // Reorderable, because the order is the layout the user sees.
          ReorderableListView.builder(
            shrinkWrap: true,
            buildDefaultDragHandles: false,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _chosen.length,
            onReorder: (from, to) {
              setState(() {
                if (to > from) to -= 1;
                final id = _chosen.removeAt(from);
                _chosen.insert(to, id);
              });
            },
            itemBuilder: (context, i) {
              final w = byId[_chosen[i]];
              return Padding(
                key: ValueKey(_chosen[i]),
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: Row(
                    children: [
                      ReorderableDragStartListener(
                        index: i,
                        child: Icon(
                          Icons.drag_indicator_rounded,
                          size: 17,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              w?.title ?? 'Widget #${_chosen[i]}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            if (w != null)
                              Text(
                                '${w.widgetType} · ${w.defaultSize}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        icon: Icon(Icons.close_rounded,
                            size: 16, color: AppTheme.textMuted),
                        onPressed: () => setState(() => _chosen.removeAt(i)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 18),
        Text(
          'AVAILABLE PANELS',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 8),
        for (final group in _palette) _paletteGroup(group),
      ],
    );
  }

  Widget _paletteGroup(DashboardWidgetGroup group) {
    final available = group.items.where((w) => !_chosen.contains(w.id)).toList();
    if (available.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _pretty(group.dataSource),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in available)
                ActionChip(
                  label: Text(w.title, style: const TextStyle(fontSize: 11.5)),
                  avatar: Icon(Icons.add_rounded, size: 14, color: AppTheme.primary),
                  backgroundColor: AppTheme.bgCard,
                  side: BorderSide(color: AppTheme.stroke),
                  onPressed: () => setState(() => _chosen.add(w.id)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.stroke)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _dirty
                  ? '${_chosen.length} panel(s) — unsaved'
                  : '${_chosen.length} panel(s)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: _dirty ? FontWeight.w600 : FontWeight.w400,
                color: _dirty ? AppTheme.warning : AppTheme.textMuted,
              ),
            ),
          ),
          if (_dirty)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => setState(
                        () => _chosen = [...(_selected?.widgetIds ?? const [])],
                      ),
              child: const Text('Discard'),
            ),
          const SizedBox(width: 6),
          FilledButton.icon(
            onPressed: !_dirty || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 16),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  // ── Live preview ───────────────────────────────────────────────────────────

  Widget _previewPane() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            border: Border(bottom: BorderSide(color: AppTheme.stroke)),
          ),
          child: Row(
            children: [
              Icon(Icons.visibility_rounded, size: 16, color: AppTheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _selected == null
                      ? 'Preview'
                      : 'As ${_selected!.displayName} sees it',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (_dirty)
                Text(
                  'saved layout',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
            ],
          ),
        ),
        Expanded(
          child: _previewLoading
              ? const Center(child: CircularProgressIndicator())
              : _preview.isEmpty
                  ? Center(
                      child: Text(
                        'Nothing to preview yet',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(14),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisExtent: 158,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                      itemCount: _preview.widgets.length,
                      itemBuilder: (context, i) =>
                          DashboardWidgetCard(data: _preview.widgets[i]),
                    ),
        ),
      ],
    );
  }

  static String _pretty(String raw) {
    if (raw.isEmpty) return raw;
    final s = raw.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }
}
