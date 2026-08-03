import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_empty_state.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';
import 'package:ivr_frontend/core/widgets/stat_card.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/models/trade_licence_models.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/trade_licence_repository.dart';
import 'package:ivr_frontend/features/modules/trade_licences/presentation/widgets/licence_widgets.dart';

/// The trade licence register, with the renewal board as a filtered view of
/// the same list rather than a separate screen — an officer working the
/// renewal season is still looking at licences.
class TradeLicenceRegisterScreen extends StatefulWidget {
  /// Opens straight onto the renewal queue when true.
  final bool renewalMode;

  const TradeLicenceRegisterScreen({super.key, this.renewalMode = false});

  @override
  State<TradeLicenceRegisterScreen> createState() =>
      _TradeLicenceRegisterScreenState();
}

enum _RenewalBucket { expiringSoon, overdue }

class _TradeLicenceRegisterScreenState
    extends State<TradeLicenceRegisterScreen> {
  final _repo = TradeLicenceRepository();
  final _searchCtrl = TextEditingController();

  late Future<TradeLicencePage> _future;
  Future<TradeLicenceStats>? _statsFuture;

  LicenceStatus? _statusFilter;
  String? _categoryFilter;
  String _query = '';
  _RenewalBucket? _bucket;

  @override
  void initState() {
    super.initState();
    if (widget.renewalMode) _bucket = _RenewalBucket.expiringSoon;
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload({bool force = false}) {
    setState(() {
      _future = _repo.listLicences(
        status: _statusFilter,
        category: _categoryFilter,
        query: _query,
        expiringWithinDays:
            _bucket == _RenewalBucket.expiringSoon ? 30 : null,
        overdueOnly: _bucket == _RenewalBucket.overdue ? true : null,
        forceRefresh: force,
      );
      _statsFuture = _repo.fetchStats(forceRefresh: force);
    });
  }

  bool get _hasFilters =>
      _statusFilter != null ||
      _categoryFilter != null ||
      _query.isNotEmpty ||
      _bucket != null;

  void _clearFilters() {
    _searchCtrl.clear();
    _query = '';
    _statusFilter = null;
    _categoryFilter = null;
    _bucket = null;
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return ListScreenShell(
      title: widget.renewalMode ? 'Licence renewals' : 'Trade licences',
      subtitle: widget.renewalMode
          ? 'Expiring, overdue and lapsed licences'
          : 'Register, renewals, inspections and QR verification',
      countLabel: _describeFilters(),
      action: FilledButton.icon(
        onPressed: () => context.go('/municipality/trade-licences/new'),
        icon: const Icon(Icons.add),
        label: const Text('New application'),
      ),
      child: FutureBuilder<TradeLicencePage>(
        future: _future,
        initialData: _repo.getCachedLicences(
          status: _statusFilter,
          category: _categoryFilter,
          query: _query,
          expiringWithinDays: _bucket == _RenewalBucket.expiringSoon ? 30 : null,
          overdueOnly: _bucket == _RenewalBucket.overdue ? true : null,
        ),
        builder: (context, snap) {
          final isLoading =
              snap.connectionState == ConnectionState.waiting && !snap.hasData;

          if (snap.hasError) {
            return AppErrorState(
              message: userFacingMessage(snap.error!),
              onRetry: () => _reload(force: true),
            );
          }

          final page = snap.data ?? TradeLicencePage.empty;

          return RefreshIndicator(
            onRefresh: () async => _reload(force: true),
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                FutureBuilder<TradeLicenceStats>(
                  future: _statsFuture,
                  builder: (context, statsSnap) {
                    final stats = statsSnap.data ?? TradeLicenceStats.empty;
                    return _KpiStrip(
                      stats: stats,
                      isLoading: !statsSnap.hasData,
                      onExpiringTap: () {
                        _bucket = _RenewalBucket.expiringSoon;
                        _statusFilter = null;
                        _reload();
                      },
                      onOverdueTap: () {
                        _bucket = _RenewalBucket.overdue;
                        _statusFilter = null;
                        _reload();
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),
                _filterBar(),
                const SizedBox(height: 20),
                if (isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: AppLoadingState(
                      message: 'Loading register...',
                      skeletonLines: 5,
                      style: AppLoadingStyle.list,
                    ),
                  )
                else if (page.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: AppEmptyState(
                      icon: Icons.storefront_outlined,
                      title: _hasFilters
                          ? 'No licences match these filters'
                          : 'No trade licences yet',
                      subtitle: _hasFilters
                          ? 'Try widening the status or category.'
                          : 'Register the first trade operating within the body\'s limits.',
                      action: _hasFilters
                          ? TextButton(
                              onPressed: _clearFilters,
                              child: const Text('Clear filters'),
                            )
                          : FilledButton.icon(
                              onPressed: () => context
                                  .go('/municipality/trade-licences/new'),
                              icon: const Icon(Icons.add),
                              label: const Text('New application'),
                            ),
                    ),
                  )
                else
                  ...page.items.map((l) => _LicenceRow(licence: l)),
                if (page.items.length < page.total)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Text(
                        'Showing ${page.items.length} of ${page.total} — narrow the search to see more',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filterBar() {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (v) {
                _query = v.trim();
                _reload();
              },
              decoration: InputDecoration(
                hintText: 'Licence no., trade, owner, door no.',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<LicenceStatus?>(
              initialValue: _statusFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Status',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              items: [
                const DropdownMenuItem<LicenceStatus?>(
                  value: null,
                  child: Text('All statuses'),
                ),
                ...LicenceStatus.values.map(
                  (s) => DropdownMenuItem<LicenceStatus?>(
                    value: s,
                    child: Text(s.label),
                  ),
                ),
              ],
              onChanged: (v) {
                _statusFilter = v;
                _bucket = null;
                _reload();
              },
            ),
          ),
          SizedBox(
            width: 190,
            child: DropdownButtonFormField<String?>(
              initialValue: _categoryFilter,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Trade category',
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All categories'),
                ),
                ...kTradeCategories.map(
                  (c) => DropdownMenuItem<String?>(
                    value: c,
                    child: Text(titleCase(c)),
                  ),
                ),
              ],
              onChanged: (v) {
                _categoryFilter = v;
                _reload();
              },
            ),
          ),
          FilterChip(
            label: const Text('Expiring in 30d'),
            selected: _bucket == _RenewalBucket.expiringSoon,
            onSelected: (on) {
              _bucket = on ? _RenewalBucket.expiringSoon : null;
              _statusFilter = null;
              _reload();
            },
          ),
          FilterChip(
            label: const Text('Overdue'),
            selected: _bucket == _RenewalBucket.overdue,
            onSelected: (on) {
              _bucket = on ? _RenewalBucket.overdue : null;
              _statusFilter = null;
              _reload();
            },
          ),
          if (_hasFilters)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  String _describeFilters() {
    if (!_hasFilters) return 'All licences';
    final parts = <String>[
      if (_bucket == _RenewalBucket.expiringSoon) 'Expiring in 30 days',
      if (_bucket == _RenewalBucket.overdue) 'Overdue',
      if (_statusFilter != null) _statusFilter!.label,
      if (_categoryFilter != null) titleCase(_categoryFilter!),
      if (_query.isNotEmpty) '"$_query"',
    ];
    return 'Filtered by ${parts.join(' · ')}';
  }
}

class _KpiStrip extends StatelessWidget {
  final TradeLicenceStats stats;
  final bool isLoading;
  final VoidCallback onExpiringTap;
  final VoidCallback onOverdueTap;

  const _KpiStrip({
    required this.stats,
    required this.isLoading,
    required this.onExpiringTap,
    required this.onOverdueTap,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        int columns = 4;
        if (width < 600) {
          columns = 1;
        } else if (width < 960) {
          columns = 2;
        }

        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 110,
          ),
          children: [
            StatCard(
              title: 'Active licences',
              value: '${stats.active}',
              icon: Icons.storefront_rounded,
              gradient: AppTheme.accentGradient,
              isLoading: isLoading,
            ),
            // The two counters that matter in renewal season are tappable —
            // reading a number you cannot act on is what made the old mock
            // screens useless.
            InkWell(
              onTap: onExpiringTap,
              borderRadius: BorderRadius.circular(16),
              child: StatCard(
                title: 'Expiring in 30 days',
                value: '${stats.expiringSoon}',
                icon: Icons.event_busy_rounded,
                gradient: AppTheme.warningGradient,
                isLoading: isLoading,
              ),
            ),
            InkWell(
              onTap: onOverdueTap,
              borderRadius: BorderRadius.circular(16),
              child: StatCard(
                title: 'Lapsed & unrenewed',
                value: '${stats.overdue}',
                icon: Icons.report_problem_rounded,
                gradient: AppTheme.errorGradient,
                isLoading: isLoading,
              ),
            ),
            StatCard(
              title: 'Collected ${stats.licenceYear}',
              value: money.format(stats.feesCollected),
              icon: Icons.account_balance_wallet_rounded,
              gradient: AppTheme.primaryGradient,
              isLoading: isLoading,
            ),
          ],
        );
      },
    );
  }
}

class _LicenceRow extends StatefulWidget {
  final TradeLicenceSummary licence;

  const _LicenceRow({required this.licence});

  @override
  State<_LicenceRow> createState() => _LicenceRowState();
}

class _LicenceRowState extends State<_LicenceRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final l = widget.licence;
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 640;

        return MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedContainer(
            duration: AppTheme.durationFast,
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(horizontal: isNarrow ? 4 : 8, vertical: 4),
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.primary.withValues(alpha: 0.04)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: _hovered
                    ? AppTheme.primary.withValues(alpha: 0.18)
                    : Colors.transparent,
              ),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(
                horizontal: isNarrow ? 12 : 16,
                vertical: 6,
              ),
              leading: CircleAvatar(
                backgroundColor: l.status.color.withValues(alpha: 0.14),
                child: Icon(Icons.storefront_rounded, color: l.status.color),
              ),
              title: Text(
                '${l.tradeName} · ${l.licenceNumber}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    LicenceStatusBadge(status: l.status),
                    CategoryChip(category: l.tradeCategory),
                    ExpiryChip(licence: l),
                    Text(l.ownerName),
                    Text(l.premisesLabel),
                    Text(
                      l.paymentStatus == 'paid'
                          ? 'Fee paid ${money.format(l.totalFee)}'
                          : 'Due ${money.format(l.outstanding)}',
                      style: TextStyle(
                        color: l.paymentStatus == 'paid'
                            ? AppTheme.accent
                            : AppTheme.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              isThreeLine: isNarrow,
              trailing: isNarrow
                  ? null
                  : Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
              onTap: () => context.go('/municipality/trade-licences/${l.id}'),
            ),
          ),
        );
      },
    );
  }
}
