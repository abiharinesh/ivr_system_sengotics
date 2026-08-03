import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/models/trade_licence_models.dart';
import 'package:ivr_frontend/features/modules/trade_licences/data/trade_licence_repository.dart';
import 'package:ivr_frontend/features/modules/trade_licences/presentation/widgets/licence_widgets.dart';

/// The licence file: particulars, fees, inspections, the year-by-year renewal
/// chain, certificates, and every action on it.
class TradeLicenceDetailScreen extends StatefulWidget {
  final int licenceId;

  const TradeLicenceDetailScreen({super.key, required this.licenceId});

  @override
  State<TradeLicenceDetailScreen> createState() =>
      _TradeLicenceDetailScreenState();
}

class _TradeLicenceDetailScreenState extends State<TradeLicenceDetailScreen> {
  final _repo = TradeLicenceRepository();
  late Future<TradeLicenceDetail> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getLicence(widget.licenceId);
  }

  void _reload() {
    setState(() {
      _future = _repo.getLicence(widget.licenceId, forceRefresh: true);
    });
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingMessage(e)),
          backgroundColor: AppTheme.error,
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TradeLicenceDetail>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return AppErrorState(
            message: userFacingMessage(snap.error!),
            onRetry: _reload,
          );
        }
        if (!snap.hasData) {
          return const AppLoadingState(
            message: 'Loading licence...',
            style: AppLoadingStyle.detail,
          );
        }

        final l = snap.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1040;
            final left = <Widget>[
              _header(l),
              if (l.readiness.blockers.isNotEmpty && !l.status.isTerminal)
                _banner(
                  color: AppTheme.warning,
                  icon: Icons.pending_actions_rounded,
                  title: 'Before this licence can be granted or renewed',
                  lines: l.readiness.blockers,
                ),
              if (l.status == LicenceStatus.rejected && l.rejectionReason != null)
                _banner(
                  color: AppTheme.error,
                  icon: Icons.block_rounded,
                  title: 'Application rejected',
                  lines: [l.rejectionReason!],
                ),
              if (l.status == LicenceStatus.suspended &&
                  l.suspensionReason != null)
                _banner(
                  color: const Color(0xFFEA580C),
                  icon: Icons.pause_circle_outline_rounded,
                  title: 'Licence suspended',
                  lines: [l.suspensionReason!],
                ),
              _particulars(l),
              _fees(l),
            ];
            final right = <Widget>[
              _statutoryRefs(l),
              _renewalChain(l),
              _inspections(l),
              _certificates(l),
              _history(l),
            ];

            if (!isWide) {
              return ListView(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                children: [...left.map(_spaced), ...right.map(_spaced)],
              );
            }

            return ListView(
              padding: const EdgeInsets.all(AppTheme.spaceLg),
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(children: left.map(_spaced).toList()),
                    ),
                    const SizedBox(width: AppTheme.spaceMd),
                    Expanded(
                      flex: 4,
                      child: Column(children: right.map(_spaced).toList()),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _spaced(Widget child) => Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spaceMd),
        child: child,
      );

  // ── Header & actions ─────────────────────────────────────────────────────

  Widget _header(TradeLicenceDetail l) {
    final s = l.summary;
    final df = DateFormat.yMMMd();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.tradeName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.licenceNumber} · ${s.premisesLabel}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              LicenceStatusBadge(status: s.status),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              CategoryChip(category: s.tradeCategory),
              if (s.licenceYear != null)
                _chip(Icons.calendar_today_rounded, 'Year ${s.licenceYear}'),
              ExpiryChip(licence: s),
              if (l.approvedAt != null)
                _chip(Icons.verified_rounded, 'Granted ${df.format(l.approvedAt!)}'),
              _chip(Icons.person_outline_rounded, s.ownerName),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spaceMd),
          _actionBar(l),
        ],
      ),
    );
  }

  Widget _actionBar(TradeLicenceDetail l) {
    final buttons = <Widget>[];
    final s = l.status;

    if (s.isEditable) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () =>
                  context.go('/municipality/trade-licences/${l.id}/edit'),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
      );
    }

    if (s == LicenceStatus.draft) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                    () => _repo.submit(l.id).then((_) {}),
                    'Application submitted',
                  ),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit'),
        ),
      );
    }

    if (s == LicenceStatus.submitted || s == LicenceStatus.inspection) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _scheduleInspection(l),
          icon: const Icon(Icons.event_available_rounded, size: 18),
          label: const Text('Schedule inspection'),
        ),
      );
      buttons.add(
        FilledButton.icon(
          onPressed:
              _busy || !l.readiness.canApprove ? null : () => _approve(l),
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: const Text('Grant licence'),
        ),
      );
      buttons.add(
        TextButton.icon(
          onPressed: _busy ? null : () => _reject(l),
          icon: const Icon(Icons.block_rounded, size: 18, color: AppTheme.error),
          label: const Text('Reject', style: TextStyle(color: AppTheme.error)),
        ),
      );
    }

    if (s.isRenewable) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy ? null : () => _renew(l),
          icon: const Icon(Icons.autorenew_rounded, size: 18),
          label: const Text('Renew'),
        ),
      );
    }

    if (s == LicenceStatus.approved) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _issueCertificate(l),
          icon: const Icon(Icons.workspace_premium_rounded, size: 18),
          label: const Text('Issue certificate'),
        ),
      );
      buttons.add(
        TextButton.icon(
          onPressed: _busy ? null : () => _suspend(l),
          icon: const Icon(Icons.pause_circle_outline_rounded, size: 18),
          label: const Text('Suspend'),
        ),
      );
    }

    if (s == LicenceStatus.suspended) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                    () => _repo.restore(l.id).then((_) {}),
                    'Suspension lifted',
                  ),
          icon: const Icon(Icons.play_circle_outline_rounded, size: 18),
          label: const Text('Lift suspension'),
        ),
      );
    }

    if (!s.isTerminal) {
      buttons.add(
        TextButton.icon(
          onPressed: _busy ? null : () => _cancel(l),
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: AppTheme.textMuted,
          ),
          label: Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
        ),
      );
    }

    if (buttons.isEmpty) {
      return Text(
        'This licence is ${s.label.toLowerCase()} — no further action is available.',
        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: buttons);
  }

  // ── Cards ────────────────────────────────────────────────────────────────

  Widget _particulars(TradeLicenceDetail l) {
    final s = l.summary;
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.description_outlined, 'Particulars'),
          const SizedBox(height: AppTheme.spaceMd),
          _kvGrid([
            (label: 'Category', value: titleCase(s.tradeCategory)),
            if (s.tradeSubCategory != null)
              (label: 'Sub-category', value: s.tradeSubCategory!),
            (label: 'Floor area', value: '${s.areaSqft.toStringAsFixed(0)} sqft'),
            if (s.motivePowerHp != null && s.motivePowerHp! > 0)
              (label: 'Motive power', value: '${s.motivePowerHp} HP'),
            if (l.workerCount != null)
              (label: 'Workers', value: '${l.workerCount}'),
            if (l.operatingHours != null)
              (label: 'Operating hours', value: l.operatingHours!),
            (label: 'Owner', value: s.ownerName),
            if (l.ownershipType != null)
              (label: 'Legal form', value: titleCase(l.ownershipType!)),
            if (l.signatoryName != null)
              (label: 'Signatory', value: l.signatoryName!),
            if (s.ownerPhone != null) (label: 'Mobile', value: s.ownerPhone!),
            if (l.ownerEmail != null) (label: 'Email', value: l.ownerEmail!),
            if (l.ownerAadhaar != null)
              (label: 'Aadhaar', value: l.ownerAadhaar!),
            if (l.surveyNumber != null)
              (label: 'Survey number', value: l.surveyNumber!),
            (label: 'Premises', value: l.isRented ? 'Rented' : 'Owned'),
            if (l.landlordName != null)
              (label: 'Landlord', value: l.landlordName!),
          ]),
          if (l.description != null && l.description!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              l.description!,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _fees(TradeLicenceDetail l) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final s = l.summary;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _cardTitle(
                  Icons.receipt_long_rounded,
                  'Fees ${s.licenceYear ?? ''}',
                ),
              ),
              if (s.outstanding > 0 && !l.status.isTerminal)
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _recordPayment(l),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Record payment'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _feeRow('Base fee', money.format(l.baseFee)),
          _feeRow('Area component', money.format(l.areaFee)),
          _feeRow('Motive power component', money.format(l.powerFee)),
          if (l.penaltyFee > 0)
            _feeRow(
              'Late renewal penalty',
              money.format(l.penaltyFee),
              color: AppTheme.error,
            ),
          const Divider(height: 20),
          _feeRow('Total', money.format(s.totalFee), bold: true),
          _feeRow('Paid', money.format(s.paidAmount)),
          _feeRow(
            s.outstanding > 0 ? 'Outstanding' : 'Cleared',
            money.format(s.outstanding),
            color: s.outstanding > 0 ? AppTheme.warning : AppTheme.accent,
            bold: true,
          ),
          if (l.paymentRef != null && l.paymentRef!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Receipt ${l.paymentRef}',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statutoryRefs(TradeLicenceDetail l) {
    final refs = l.statutoryRefs;
    final df = DateFormat.yMMMd();
    final now = DateTime.now();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.verified_outlined, 'Statutory references'),
          const SizedBox(height: AppTheme.spaceSm),
          if (refs.isEmpty)
            Text(
              'None recorded. A food business also needs an FSSAI registration, '
              'which is a central licence — this module records the number, it '
              'does not issue it.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...refs.map((r) {
              final lapsed = r.expiry != null && r.expiry!.isBefore(now);
              final color = lapsed ? AppTheme.error : AppTheme.accent;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      lapsed ? Icons.error_outline : Icons.check_circle_outline,
                      size: 16,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            '${r.ref}'
                            '${r.expiry != null ? ' · ${lapsed ? 'lapsed' : 'valid to'} ${df.format(r.expiry!)}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: lapsed ? AppTheme.error : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  /// The year-by-year chain. "Was this shop licensed in 2024-25?" has to be
  /// answerable, so every year is a row, not just the current one.
  Widget _renewalChain(TradeLicenceDetail l) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.history_toggle_off_rounded, 'Licence history'),
          const SizedBox(height: AppTheme.spaceSm),
          if (l.renewals.isEmpty)
            Text(
              'No licence year recorded yet — the chain opens when the licence '
              'is first granted.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...l.renewals.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(
                      color: r.penaltyBand.color.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  r.licenceYear,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (r.isInitialGrant)
                                  Text(
                                    'first grant',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.textMuted,
                                    ),
                                  )
                                else
                                  Text(
                                    r.penaltyBand.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: r.penaltyBand.color,
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              '${money.format(r.totalFee)}'
                              '${r.penaltyFee > 0 ? ' (incl. ${money.format(r.penaltyFee)} penalty)' : ''}'
                              '${r.daysLate > 0 ? ' · ${r.daysLate}d late' : ''}',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        r.isPaid
                            ? Icons.check_circle_rounded
                            : Icons.pending_rounded,
                        size: 18,
                        color: r.isPaid ? AppTheme.accent : AppTheme.warning,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _inspections(TradeLicenceDetail l) {
    final df = DateFormat.yMMMd();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _cardTitle(Icons.engineering_rounded, 'Inspections'),
              ),
              if (!l.status.isTerminal)
                TextButton.icon(
                  onPressed: _busy ? null : () => _scheduleInspection(l),
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: const Text('Schedule'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          if (l.inspections.isEmpty)
            Text(
              l.readiness.requiresInspection
                  ? 'This category needs a compliant premises inspection before the licence can be granted.'
                  : 'No inspection scheduled.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...l.inspections.map((i) {
              final Color color;
              final IconData icon;
              if (!i.isCompleted) {
                color = AppTheme.warning;
                icon = Icons.schedule_rounded;
              } else if (i.isCompliant == true) {
                color = AppTheme.accent;
                icon = Icons.verified_rounded;
              } else {
                color = AppTheme.error;
                icon = Icons.report_problem_rounded;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i.typeLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            i.isCompleted
                                ? '${i.isCompliant == true ? 'Compliant' : 'Not compliant'}'
                                    '${i.inspectedAt != null ? ' · ${df.format(i.inspectedAt!)}' : ''}'
                                : 'Scheduled for ${df.format(i.scheduledFor)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          if (i.violations.isNotEmpty)
                            Text(
                              'Violations: ${i.violations.join(', ')}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.error,
                              ),
                            ),
                          if (i.findings != null && i.findings!.isNotEmpty)
                            Text(
                              i.findings!,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!i.isCompleted && !l.status.isTerminal)
                      TextButton(
                        onPressed: _busy ? null : () => _recordInspection(l, i),
                        child: const Text('Record'),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _certificates(TradeLicenceDetail l) {
    final df = DateFormat.yMMMd();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.workspace_premium_rounded, 'Certificates issued'),
          const SizedBox(height: AppTheme.spaceSm),
          if (l.certificates.isEmpty)
            Text(
              l.status == LicenceStatus.approved
                  ? 'No certificate issued yet — the shopkeeper needs one to display.'
                  : 'A certificate can only be issued once the licence is granted.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...l.certificates.map(
              (c) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  c.isCancelled
                      ? Icons.cancel_outlined
                      : Icons.verified_rounded,
                  color: c.isCancelled ? AppTheme.textMuted : AppTheme.accent,
                ),
                title: Text(
                  '${c.copyLabel} · ${c.licenceYear}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration:
                        c.isCancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                subtitle: Text(
                  '${c.certificateNumber}'
                  '${c.issuedAt != null ? ' · ${df.format(c.issuedAt!)}' : ''}'
                  '${c.isCancelled && c.cancelledReason != null ? ' · ${c.cancelledReason}' : ''}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
                trailing: c.isCancelled || c.verificationToken == null
                    ? null
                    : IconButton(
                        tooltip: 'Show verification QR',
                        icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => LicenceQrDialog(
                            certificate: c,
                            tradeName: l.summary.tradeName,
                          ),
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _history(TradeLicenceDetail l) {
    final df = DateFormat.yMMMd().add_jm();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.history_rounded, 'Audit trail'),
          const SizedBox(height: AppTheme.spaceSm),
          if (l.history.isEmpty)
            Text(
              'No recorded activity yet.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...l.history.take(12).map(
                  (h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(Icons.circle, size: 6, color: AppTheme.textMuted),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            h.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        if (h.createdAt != null)
                          Text(
                            df.format(h.createdAt!),
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  // ── Shared bits ──────────────────────────────────────────────────────────

  Widget _banner({
    required Color color,
    required IconData icon,
    required String title,
    required List<String> lines,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMd),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                ...lines.map(
                  (l) => Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '• $l',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.stroke),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.textMuted),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _cardTitle(IconData icon, String title) => Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      );

  Widget _feeRow(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: color ?? AppTheme.textSecondary,
                fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color ?? AppTheme.textPrimary,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kvGrid(List<({String label, String value})> pairs) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 480 ? 1 : 2;
        return Wrap(
          spacing: AppTheme.spaceMd,
          runSpacing: AppTheme.spaceSm,
          children: pairs.map((kv) {
            final width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - AppTheme.spaceMd) / 2;
            return SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kv.label,
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kv.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<String?> _promptReason({
    required String title,
    required String label,
    String? helper,
    Color? confirmColour,
    String confirmLabel = 'Confirm',
  }) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: ctrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: label,
              helperText: helper,
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: confirmColour != null
                ? FilledButton.styleFrom(backgroundColor: confirmColour)
                : null,
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    final text = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return null;
    if (text.length < 10) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give a reason of at least 10 characters')),
      );
      return null;
    }
    return text;
  }

  Future<void> _approve(TradeLicenceDetail l) async {
    await _run(
      () => _repo.approve(l.id).then((_) {}),
      'Licence granted',
    );
  }

  Future<void> _reject(TradeLicenceDetail l) async {
    final reason = await _promptReason(
      title: 'Reject this application',
      label: 'Reason for rejection',
      helper: 'The applicant sees this — state something they can act on',
      confirmColour: AppTheme.error,
      confirmLabel: 'Reject',
    );
    if (reason == null) return;
    await _run(() => _repo.reject(l.id, reason).then((_) {}), 'Application rejected');
  }

  Future<void> _suspend(TradeLicenceDetail l) async {
    final reason = await _promptReason(
      title: 'Suspend this licence',
      label: 'Reason for suspension',
      helper: 'The trade must stop operating until this is lifted',
      confirmColour: const Color(0xFFEA580C),
      confirmLabel: 'Suspend',
    );
    if (reason == null) return;
    await _run(() => _repo.suspend(l.id, reason).then((_) {}), 'Licence suspended');
  }

  Future<void> _cancel(TradeLicenceDetail l) async {
    final reason = await _promptReason(
      title: 'Cancel this licence',
      label: 'Reason for cancellation',
      helper: 'This is final. Any issued certificate is cancelled with it.',
      confirmColour: AppTheme.error,
      confirmLabel: 'Cancel licence',
    );
    if (reason == null) return;
    await _run(() => _repo.cancel(l.id, reason).then((_) {}), 'Licence cancelled');
  }

  Future<void> _renew(TradeLicenceDetail l) async {
    final days = l.summary.daysToExpiry;
    final late = days != null && days < 0;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renew for the next licence year'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'The next year runs 1 April to 31 March and is charged at the '
                'full annual fee.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              if (late) ...[
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'This licence lapsed ${-days} day(s) ago — a penalty applies, '
                  'and beyond 90 days a fresh application is required instead '
                  'of a renewal.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.warning,
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Renew'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(() => _repo.renew(l.id).then((_) {}), 'Licence renewed');
  }

  Future<void> _issueCertificate(TradeLicenceDetail l) async {
    await _run(
      () => _repo.issueCertificate(l.id).then((_) {}),
      'Certificate issued',
    );
  }

  Future<void> _recordPayment(TradeLicenceDetail l) async {
    final amountCtrl = TextEditingController(
      text: l.summary.outstanding.toStringAsFixed(0),
    );
    final refCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Record a fee payment'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  helperText:
                      'Outstanding: ₹${l.summary.outstanding.toStringAsFixed(0)}',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Receipt reference',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Record'),
          ),
        ],
      ),
    );

    final amount = double.tryParse(amountCtrl.text.trim());
    final ref = refCtrl.text.trim();
    amountCtrl.dispose();
    refCtrl.dispose();
    if (confirmed != true) return;

    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter an amount greater than zero')),
      );
      return;
    }

    await _run(
      () => _repo
          .recordPayment(l.id, amount: amount, paymentRef: ref)
          .then((_) {}),
      'Payment recorded',
    );
  }

  Future<void> _scheduleInspection(TradeLicenceDetail l) async {
    var type = kLicenceInspectionTypes.first;
    var date = DateTime.now().add(const Duration(days: 3));
    final df = DateFormat.yMMMd();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Schedule a premises inspection'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Inspection type',
                    border: OutlineInputBorder(),
                  ),
                  items: kLicenceInspectionTypes
                      .map(
                        (t) => DropdownMenuItem(
                          value: t,
                          child: Text(titleCase(t)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocal(() => type = v ?? type),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Scheduled for',
                    border: OutlineInputBorder(),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: Text(df.format(date))),
                      TextButton(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: date,
                            firstDate:
                                DateTime.now().subtract(const Duration(days: 1)),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setLocal(() => date = picked);
                        },
                        child: const Text('Change'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Schedule'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) return;

    await _run(
      () => _repo
          .scheduleInspection(
            l.id,
            inspectionType: type,
            scheduledFor: date,
          )
          .then((_) {}),
      'Inspection scheduled',
    );
  }

  Future<void> _recordInspection(
    TradeLicenceDetail l,
    LicenceInspection inspection,
  ) async {
    var compliant = true;
    final findingsCtrl = TextEditingController();
    final violationsCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text('${inspection.typeLabel} — finding'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: compliant,
                    onChanged: (v) => setLocal(() => compliant = v),
                    title: Text(
                      compliant
                          ? 'Premises are compliant'
                          : 'Premises are NOT compliant',
                    ),
                    subtitle: Text(
                      compliant
                          ? 'The licence can proceed'
                          : 'Approval stays blocked until a compliant visit is recorded',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  TextField(
                    controller: violationsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Violations (comma separated)',
                      hintText: 'No hand wash, uncovered bins',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSm),
                  TextField(
                    controller: findingsCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Findings',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );

    final findings = findingsCtrl.text.trim();
    final violations = violationsCtrl.text
        .split(',')
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .toList();
    findingsCtrl.dispose();
    violationsCtrl.dispose();
    if (confirmed != true) return;

    await _run(
      () => _repo
          .recordInspection(
            l.id,
            inspection.id,
            isCompliant: compliant,
            findings: findings,
            violations: violations,
          )
          .then((_) {}),
      'Inspection finding recorded',
    );
  }
}
