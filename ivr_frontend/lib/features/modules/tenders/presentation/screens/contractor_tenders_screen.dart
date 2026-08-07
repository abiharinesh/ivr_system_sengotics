import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/tenders/data/contractor_portal_repository.dart';

/// What a contractor signs in to see: the tenders they were invited to bid on.
///
/// This replaces four static HTML pages served through an iframe. They could
/// not have been anything else — `contractors` and `users` were unrelated
/// tables, so nothing connected the person signing in to any of the registered
/// firms and "your tenders" had no way to decide whose.
///
/// Ordered by what needs answering. An invitation still awaiting a quote comes
/// first, soonest deadline at the top, because that is the reason somebody
/// opens this screen.
class ContractorTendersScreen extends StatefulWidget {
  const ContractorTendersScreen({super.key, this.repository});

  /// Injected by tests. The screen builds its own against the live API when
  /// this is null.
  final ContractorPortalRepository? repository;

  @override
  State<ContractorTendersScreen> createState() =>
      _ContractorTendersScreenState();
}

class _ContractorTendersScreenState extends State<ContractorTendersScreen> {
  late final _repo = widget.repository ?? ContractorPortalRepository();

  ContractorPortal _portal = ContractorPortal.empty;
  bool _loading = true;
  String? _error;
  InviteState? _filter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final portal = await _repo.myTenders();
      if (!mounted) return;
      setState(() {
        _portal = portal;
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

  List<InvitedTender> get _visible => _filter == null
      ? _portal.tenders
      : _portal.tenders.where((t) => t.state == _filter).toList();

  @override
  Widget build(BuildContext context) {
    if (_loading && _portal.tenders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _portal.tenders.isEmpty) {
      return _errorState();
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _header(),
          const SizedBox(height: 14),
          if (_portal.blacklisted) ...[
            _blacklistedBanner(),
            const SizedBox(height: 14),
          ],
          _filters(),
          const SizedBox(height: 12),
          if (_visible.isEmpty)
            _emptyState()
          else
            ..._visible.map(_tenderCard),
        ],
      ),
    );
  }

  Widget _header() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _portal.contractorName.isEmpty
                    ? 'Your tenders'
                    : _portal.contractorName,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _portal.awaiting == 0
                    ? 'Nothing is waiting on you'
                    : '${_portal.awaiting} '
                        '${_portal.awaiting == 1 ? 'invitation needs' : 'invitations need'} '
                        'your quote',
                style: TextStyle(
                  fontSize: 13,
                  color: _portal.awaiting == 0
                      ? AppTheme.textMuted
                      : AppTheme.warning,
                  fontWeight:
                      _portal.awaiting == 0 ? FontWeight.w400 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Reload',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  Widget _blacklistedBanner() => Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.block_rounded, size: 18, color: AppTheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Your firm is currently blacklisted. New quotations will not '
                'be accepted until the council lifts it.',
                style: TextStyle(
                    fontSize: 12.5, height: 1.35, color: AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _filters() {
    Widget chip(String label, InviteState? state, int count) {
      final selected = _filter == state;
      return FilterChip(
        label: Text('$label ($count)', style: const TextStyle(fontSize: 12)),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => setState(() => _filter = selected ? null : state),
        backgroundColor: AppTheme.bgCard,
        selectedColor: AppTheme.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppTheme.textSecondary,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide(color: AppTheme.stroke),
      );
    }

    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        chip('All', null, _portal.invited),
        chip('Needs a quote', InviteState.awaitingQuote, _portal.awaiting),
        chip('Submitted', InviteState.submitted, _portal.submitted),
        chip('Closed', InviteState.closed, _portal.closed),
      ],
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
        child: Column(
          children: [
            Icon(Icons.gavel_rounded, size: 40, color: AppTheme.textMuted),
            const SizedBox(height: 12),
            Text(
              _filter == null
                  ? 'No invitations yet'
                  : 'Nothing in this state',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _filter == null
                  ? 'When a council invites your firm to quote on a work, it '
                      'will appear here.'
                  : 'Try another filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppTheme.textMuted),
            ),
          ],
        ),
      );

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40, color: AppTheme.error),
              const SizedBox(height: 12),
              Text(
                'Could not load your tenders',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                _error!.replaceFirst('Exception: ', ''),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, height: 1.4, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      );

  ({String label, Color color, IconData icon}) _stateChrome(InvitedTender t) {
    return switch (t.state) {
      InviteState.awaitingQuote => (
          label: t.isUrgent ? 'Closing soon' : 'Needs your quote',
          color: t.isUrgent ? AppTheme.error : AppTheme.warning,
          icon: Icons.schedule_rounded,
        ),
      InviteState.submitted => (
          label: t.won ? 'Awarded to you' : 'Quote submitted',
          color: AppTheme.accent,
          icon: t.won ? Icons.emoji_events_rounded : Icons.check_circle_rounded,
        ),
      InviteState.closed => (
          label: 'Closed',
          color: AppTheme.textMuted,
          icon: Icons.lock_clock_rounded,
        ),
      InviteState.withdrawn => (
          label: 'Withdrawn',
          color: AppTheme.textMuted,
          icon: Icons.remove_circle_outline_rounded,
        ),
    };
  }

  Widget _tenderCard(InvitedTender t) {
    final money = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    final fmt = DateFormat('d MMM yyyy');
    final chrome = _stateChrome(t);
    final days = t.daysLeft;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: t.isUrgent
              ? AppTheme.error.withValues(alpha: 0.35)
              : AppTheme.stroke,
        ),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: () => context.go('/tenders/${t.tenderId}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        t.title,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: chrome.color.withValues(alpha: 0.11),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: chrome.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(chrome.icon, size: 12, color: chrome.color),
                          const SizedBox(width: 5),
                          Text(
                            chrome.label,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: chrome.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 14,
                  runSpacing: 5,
                  children: [
                    if (t.branch != null)
                      _meta(Icons.account_balance_rounded, t.branch!),
                    _meta(Icons.list_alt_rounded,
                        '${t.lineItemCount} line item${t.lineItemCount == 1 ? '' : 's'}'),
                    if (t.expiresAt != null)
                      _meta(
                        Icons.event_rounded,
                        t.state == InviteState.awaitingQuote && days != null
                            ? (days < 0
                                ? 'Closed ${fmt.format(t.expiresAt!.toLocal())}'
                                : days == 0
                                    ? 'Closes today'
                                    : 'Closes in $days day${days == 1 ? '' : 's'}')
                            : 'Closed ${fmt.format(t.expiresAt!.toLocal())}',
                        emphasise: t.isUrgent,
                      ),
                  ],
                ),
                if (t.myQuote != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_rounded,
                            size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You quoted ${money.format(t.myQuote!.amount)}'
                            '${t.myQuote!.submittedAt == null ? '' : ' on ${fmt.format(t.myQuote!.submittedAt!.toLocal())}'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text, {bool emphasise = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 13,
              color: emphasise ? AppTheme.error : AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: emphasise ? FontWeight.w700 : FontWeight.w400,
              color: emphasise ? AppTheme.error : AppTheme.textMuted,
            ),
          ),
        ],
      );
}
