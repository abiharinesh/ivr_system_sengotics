import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/features/dashboard/data/dashboard_models.dart';
import 'package:ivr_frontend/features/dashboard/data/dashboard_repository.dart';
import 'package:ivr_frontend/features/dashboard/presentation/widgets/dashboard_widget_card.dart';

/// The landing page for every signed-in user.
///
/// What appears here is `role_dashboards` for the caller's role, computed
/// server-side. Before this, `/dashboard` served exactly two screens — one for
/// the super admin and one for everybody else — so a Municipal Commissioner
/// and a Sanitary Inspector opened the same panels. Changing somebody's
/// dashboard is now a row edit in the super admin console, not a release.
class RoleDashboardScreen extends StatefulWidget {
  const RoleDashboardScreen({super.key, this.user, this.previewRole});

  /// Used for the greeting and the branch label only; access is decided
  /// server-side from the token.
  final UserModel? user;

  /// Set when an administrator is previewing another role's dashboard.
  final String? previewRole;

  @override
  State<RoleDashboardScreen> createState() => _RoleDashboardScreenState();
}

class _RoleDashboardScreenState extends State<RoleDashboardScreen> {
  final _repo = DashboardRepository();

  RoleDashboardData _data = RoleDashboardData.empty;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(RoleDashboardScreen old) {
    super.didUpdateWidget(old);
    if (widget.previewRole != old.previewRole) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = widget.previewRole == null
          ? await _repo.mine()
          : await _repo.preview(widget.previewRole!);
      if (!mounted) return;
      setState(() {
        _data = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: RefreshIndicator(
        onRefresh: _load,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _data.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _data.isEmpty) return _errorState();
    if (_data.isEmpty) return _emptyState();

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _greeting()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              // Four columns on a desktop console, fewer as it narrows. Panels
              // declare a span, so a map keeps its width instead of being
              // squeezed next to a counter.
              final width = constraints.crossAxisExtent;
              final columns = width < 620
                  ? 1
                  : width < 1000
                      ? 2
                      : width < 1400
                          ? 3
                          : 4;
              return SliverToBoxAdapter(
                child: _grid(columns, width),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _grid(int columns, double width) {
    const gap = 14.0;
    final cellWidth = (width - gap * (columns - 1)) / columns;

    return Wrap(
      spacing: gap,
      runSpacing: gap,
      children: [
        for (final w in _data.widgets)
          SizedBox(
            width: _spanWidth(w, columns, cellWidth, gap),
            height: _heightFor(w),
            child: DashboardWidgetCard(
              data: w,
              onOpen: (route) => context.go(route),
            ),
          ),
      ],
    );
  }

  /// A panel never claims more columns than the grid has.
  double _spanWidth(
    DashboardWidgetData w,
    int columns,
    double cellWidth,
    double gap,
  ) {
    final span = w.columnSpan.clamp(1, columns);
    return cellWidth * span + gap * (span - 1);
  }

  /// Charts, maps and tables need vertical room; a counter does not.
  ///
  /// A bar chart carries axis labels and a trend line carries its own headline
  /// figure above the plot, so the two want different heights even though both
  /// arrive as `bar_chart`.
  double _heightFor(DashboardWidgetData w) => switch (w.widgetType) {
        'map' => 310,
        'table' => 300,
        'bar_chart' => w.series.length > 12 ? 236 : 258,
        'pie_chart' => 232,
        'kpi' => 172,
        _ => 158,
      };

  // ── Chrome ─────────────────────────────────────────────────────────────────

  String get _greetingWord {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _greeting() {
    final u = widget.user;
    final name = u?.email.split('@').first.replaceAll('.', ' ') ?? '';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.previewRole == null
                      ? '$_greetingWord${name.isEmpty ? '' : ', $name'}'
                      : 'Previewing ${_pretty(widget.previewRole!)}',
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      _pretty(_data.role),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primary,
                      ),
                    ),
                    if (_data.generatedAt != null) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                      Text(
                        'as of ${DateFormat('d MMM, h:mm a').format(_data.generatedAt!.toLocal())}',
                        style: TextStyle(fontSize: 12.5, color: AppTheme.textMuted),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (!_data.configured)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Tooltip(
                message: 'No dashboard has been arranged for this role yet, so '
                    'it is showing the general set. Configure it in Role '
                    'management → Dashboards.',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 14, color: AppTheme.warning),
                      SizedBox(width: 6),
                      Text(
                        'Default layout',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Reload',
            onPressed: _loading ? null : _load,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
    );
  }

  Widget _errorState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.cloud_off_rounded, size: 44, color: AppTheme.textMuted),
        const SizedBox(height: 14),
        Text(
          'Could not load your dashboard',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 18),
        Center(
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
          ),
        ),
      ],
    );
  }

  Widget _emptyState() {
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 80),
        Icon(Icons.dashboard_customize_rounded,
            size: 44, color: AppTheme.textMuted),
        const SizedBox(height: 14),
        Text(
          'No panels are configured for ${_pretty(_data.role)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'A super admin can arrange this role\'s dashboard under '
          'Role management → Dashboards.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textMuted),
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
