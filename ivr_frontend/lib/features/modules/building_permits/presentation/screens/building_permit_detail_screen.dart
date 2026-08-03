import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/building_permit_repository.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/widgets/noc_checklist_card.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/widgets/permit_documents_card.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/widgets/permit_inspections_card.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/widgets/permit_status_badge.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/widgets/permit_workflow_timeline.dart';

/// The permit file: particulars, clearances, inspections, approval chain,
/// plans, and every action an officer can take on it.
class BuildingPermitDetailScreen extends StatefulWidget {
  final int permitId;

  const BuildingPermitDetailScreen({super.key, required this.permitId});

  @override
  State<BuildingPermitDetailScreen> createState() =>
      _BuildingPermitDetailScreenState();
}

class _BuildingPermitDetailScreenState
    extends State<BuildingPermitDetailScreen> {
  final _repo = BuildingPermitRepository();
  final _picker = ImagePicker();

  late Future<BuildingPermitDetail> _future;
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getPermit(widget.permitId);
  }

  void _reload() {
    setState(() {
      _future = _repo.getPermit(widget.permitId, forceRefresh: true);
    });
  }

  /// Runs a mutation, surfacing failures as a snack bar rather than replacing
  /// the whole screen with an error state — the file is still readable.
  Future<void> _run(Future<void> Function() action, String successMessage) async {
    setState(() => _busy = true);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(successMessage)));
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
    return FutureBuilder<BuildingPermitDetail>(
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
            message: 'Loading permit file...',
            style: AppLoadingStyle.detail,
          );
        }

        final permit = snap.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1040;
            final left = <Widget>[
              _header(permit),
              if (permit.readiness.blockers.isNotEmpty &&
                  !permit.status.isTerminal)
                _blockersBanner(permit),
              if (permit.status == PermitStatus.rejected &&
                  permit.rejectionReason != null)
                _rejectionBanner(permit),
              _particulars(permit),
              _fees(permit),
            ];
            final right = <Widget>[
              NocChecklistCard(
                nocs: permit.nocs,
                readOnly: _busy || permit.status.isTerminal,
                onEdit: (noc) => _editNoc(permit, noc),
                onAdd: () => _addNoc(permit),
              ),
              PermitInspectionsCard(
                inspections: permit.inspections,
                readOnly: _busy || permit.status.isTerminal,
                onSchedule: () => _scheduleInspection(permit),
                onRecord: (i) => _recordInspection(permit, i),
              ),
              PermitWorkflowTimeline(workflow: permit.workflow),
              PermitDocumentsCard(
                documents: permit.documents,
                uploading: _uploading,
                onUpload: () => _uploadDocument(permit),
              ),
              _history(permit),
            ];

            if (!isWide) {
              return ListView(
                padding: const EdgeInsets.all(AppTheme.spaceLg),
                children: [
                  ...left.map(_spaced),
                  ...right.map(_spaced),
                ],
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

  Widget _header(BuildingPermitDetail p) {
    final df = DateFormat.yMMMd();
    final s = p.summary;

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
                      s.applicantName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${s.permitNumber} · ${s.siteLabel}',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PermitStatusBadge(status: s.status),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              if (s.submittedAt != null)
                _chip(Icons.event_note_rounded, 'Filed ${df.format(s.submittedAt!)}'),
              if (p.approvedAt != null)
                _chip(Icons.verified_rounded,
                    'Sanctioned ${df.format(p.approvedAt!)}'),
              if (p.validUntil != null)
                _chip(Icons.hourglass_bottom_rounded,
                    'Valid to ${df.format(p.validUntil!)}'),
              if (p.sla != null) _slaChip(p.sla!),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spaceMd),
          _actionBar(p),
        ],
      ),
    );
  }

  Widget _actionBar(BuildingPermitDetail p) {
    final status = p.status;
    final buttons = <Widget>[];

    if (status.isEditable) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => context
                  .go('/municipality/building-permits/${p.id}/edit'),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit'),
        ),
      );
      buttons.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                    () => _repo.submitPermit(p.id).then((_) {}),
                    'Application submitted — the approval chain and SLA clock have started',
                  ),
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Submit application'),
        ),
      );
    }

    for (final next in status.nextStatuses) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                    () => _repo.changeStatus(p.id, next).then((_) {}),
                    'Moved to ${next.label}',
                  ),
          icon: Icon(_iconForStatus(next), size: 18),
          label: Text('Move to ${next.label.toLowerCase()}'),
        ),
      );
    }

    if (status == PermitStatus.inspection) {
      buttons.add(
        FilledButton.icon(
          onPressed:
              _busy || !p.readiness.canApprove ? null : () => _approve(p),
          icon: const Icon(Icons.verified_rounded, size: 18),
          label: const Text('Approve permit'),
        ),
      );
    }

    if (!status.isTerminal && status != PermitStatus.draft) {
      buttons.add(
        TextButton.icon(
          onPressed: _busy ? null : () => _reject(p),
          icon: const Icon(Icons.block_rounded, size: 18, color: AppTheme.error),
          label: const Text('Reject', style: TextStyle(color: AppTheme.error)),
        ),
      );
    }

    // Withdrawing an application the office never took up — distinct from
    // rejecting one on its merits, which is why it isn't in `nextStatuses`.
    if (status.isEditable) {
      buttons.add(
        TextButton.icon(
          onPressed: _busy ? null : () => _cancel(p),
          icon: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: AppTheme.textMuted,
          ),
          label: Text(
            'Cancel application',
            style: TextStyle(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return Text(
        'This permit is in ${status.label} — no further action is available.',
        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: buttons);
  }

  IconData _iconForStatus(PermitStatus status) {
    switch (status) {
      case PermitStatus.scrutiny:
        return Icons.rule_rounded;
      case PermitStatus.nocPending:
        return Icons.forward_to_inbox_rounded;
      case PermitStatus.inspection:
        return Icons.engineering_rounded;
      case PermitStatus.returned:
        return Icons.undo_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  Widget _blockersBanner(BuildingPermitDetail p) {
    return _banner(
      color: AppTheme.warning,
      icon: Icons.pending_actions_rounded,
      title: 'Before this permit can be sanctioned',
      lines: p.readiness.blockers,
    );
  }

  Widget _rejectionBanner(BuildingPermitDetail p) {
    return _banner(
      color: AppTheme.error,
      icon: Icons.block_rounded,
      title: 'Application rejected',
      lines: [p.rejectionReason!],
    );
  }

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

  Widget _slaChip(PermitSla sla) {
    final df = DateFormat.yMMMd();
    final color = sla.isBreached
        ? AppTheme.error
        : sla.isAtRisk
            ? AppTheme.warning
            : AppTheme.accent;
    final label = sla.resolvedAt != null
        ? 'SLA closed'
        : sla.isBreached
            ? 'SLA breached ${df.format(sla.breachAt)}'
            : 'SLA target ${df.format(sla.targetAt)}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_rounded, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ── Particulars ──────────────────────────────────────────────────────────

  Widget _particulars(BuildingPermitDetail p) {
    final s = p.summary;
    final setbacks = [
      if (p.setbackFrontM != null) 'F ${p.setbackFrontM}',
      if (p.setbackRearM != null) 'R ${p.setbackRearM}',
      if (p.setbackLeftM != null) 'L ${p.setbackLeftM}',
      if (p.setbackRightM != null) 'R ${p.setbackRightM}',
    ].join(' · ');

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.description_outlined, 'Particulars'),
          const SizedBox(height: AppTheme.spaceMd),
          _kvGrid([
            _Kv('Construction type', titleCase(s.constructionType)),
            _Kv('Nature of work', titleCase(s.workNature)),
            _Kv('Plot area', '${s.plotAreaSqm.toStringAsFixed(2)} sqm'),
            _Kv('Built-up area', '${s.builtUpAreaSqm.toStringAsFixed(2)} sqm'),
            _Kv('Floors', '${s.floorsProposed}'),
            if (p.heightM != null) _Kv('Height', '${p.heightM} m'),
            if (setbacks.isNotEmpty) _Kv('Setbacks (m)', setbacks),
            if (p.estimatedCost != null)
              _Kv(
                'Estimated cost',
                NumberFormat.currency(
                  locale: 'en_IN',
                  symbol: '₹',
                  decimalDigits: 0,
                ).format(p.estimatedCost),
              ),
            _Kv('Survey number', s.surveyNumber),
            if (p.subdivisionNo != null) _Kv('Subdivision', p.subdivisionNo!),
            if (p.wardNumber != null) _Kv('Ward', p.wardNumber!),
            if (s.applicantPhone != null) _Kv('Mobile', s.applicantPhone!),
            if (p.applicantEmail != null) _Kv('Email', p.applicantEmail!),
            if (p.applicantAadhaar != null) _Kv('Aadhaar', p.applicantAadhaar!),
            _Kv('Applicant is owner', p.isOwner ? 'Yes' : 'No'),
            if (p.powerOfAttorney != null)
              _Kv('Power of attorney', p.powerOfAttorney!),
            if (p.architectName != null)
              _Kv(
                'Architect',
                '${p.architectName}'
                '${p.architectLicence != null ? ' (${p.architectLicence})' : ''}',
              ),
          ]),
          if (p.applicantAddress != null && p.applicantAddress!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              p.applicantAddress!,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  // ── Fees ─────────────────────────────────────────────────────────────────

  Widget _fees(BuildingPermitDetail p) {
    final money = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final s = p.summary;
    final outstanding = p.outstanding;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _cardTitle(Icons.receipt_long_rounded, 'Fees')),
              if (outstanding > 0 && !p.status.isTerminal)
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : () => _recordPayment(p),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text('Record payment'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _feeRow('Scrutiny fee', money.format(p.scrutinyFee)),
          _feeRow('Permit fee', money.format(p.permitFee)),
          _feeRow('Development charge', money.format(p.developmentFee)),
          const Divider(height: 20),
          _feeRow('Total', money.format(s.totalFee), bold: true),
          _feeRow('Paid', money.format(s.paidAmount)),
          _feeRow(
            outstanding > 0 ? 'Outstanding' : 'Cleared',
            money.format(outstanding),
            color: outstanding > 0 ? AppTheme.warning : AppTheme.accent,
            bold: true,
          ),
          if (p.paymentRef != null && p.paymentRef!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Receipt ${p.paymentRef}',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

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

  // ── History ──────────────────────────────────────────────────────────────

  Widget _history(BuildingPermitDetail p) {
    final df = DateFormat.yMMMd().add_jm();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.history_rounded, 'Audit trail'),
          const SizedBox(height: AppTheme.spaceSm),
          if (p.history.isEmpty)
            Text(
              'No recorded activity yet.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...p.history.take(12).map(
                  (h) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.circle,
                          size: 6,
                          color: AppTheme.textMuted,
                        ),
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

  Widget _cardTitle(IconData icon, String title) {
    return Row(
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
  }

  Widget _kvGrid(List<_Kv> pairs) {
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

  Future<void> _editNoc(BuildingPermitDetail p, PermitNoc noc) async {
    final decision = await showDialog<NocDecision>(
      context: context,
      builder: (_) => NocDecisionDialog(noc: noc),
    );
    if (decision == null) return;

    await _run(
      () => _repo
          .updateNoc(
            p.id,
            noc.id,
            status: decision.status,
            referenceNo: decision.referenceNo,
            remarks: decision.remarks,
          )
          .then((_) {}),
      '${noc.departmentLabel} clearance recorded as ${decision.status.label}',
    );
  }

  Future<void> _addNoc(BuildingPermitDetail p) async {
    final existing = p.nocs.map((n) => n.department).toSet();
    final available =
        kNocDepartments.where((d) => !existing.contains(d)).toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Every department is already listed')),
      );
      return;
    }

    final chosen = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Add a department clearance'),
        children: available
            .map(
              (d) => SimpleDialogOption(
                onPressed: () => Navigator.of(ctx).pop(d),
                child: Text(titleCase(d)),
              ),
            )
            .toList(),
      ),
    );
    if (chosen == null) return;

    await _run(
      () => _repo.addNoc(p.id, chosen),
      '${titleCase(chosen)} clearance added to the checklist',
    );
  }

  Future<void> _scheduleInspection(BuildingPermitDetail p) async {
    final schedule = await showDialog<InspectionSchedule>(
      context: context,
      builder: (_) => const ScheduleInspectionDialog(),
    );
    if (schedule == null) return;

    await _run(
      () => _repo
          .scheduleInspection(
            p.id,
            inspectionType: schedule.inspectionType,
            scheduledFor: schedule.scheduledFor,
          )
          .then((_) {}),
      'Site visit scheduled',
    );
  }

  Future<void> _recordInspection(
    BuildingPermitDetail p,
    PermitInspection inspection,
  ) async {
    final finding = await showDialog<InspectionFinding>(
      context: context,
      builder: (_) => RecordInspectionDialog(inspection: inspection),
    );
    if (finding == null) return;

    await _run(
      () => _repo
          .recordInspection(
            p.id,
            inspection.id,
            isCompliant: finding.isCompliant,
            findings: finding.findings,
          )
          .then((_) {}),
      'Inspection finding recorded',
    );
  }

  Future<void> _recordPayment(BuildingPermitDetail p) async {
    final amountCtrl =
        TextEditingController(text: p.outstanding.toStringAsFixed(0));
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
                      'Outstanding: ₹${p.outstanding.toStringAsFixed(0)}',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              TextField(
                controller: refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Receipt / transaction reference',
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
    amountCtrl.dispose();
    final ref = refCtrl.text.trim();
    refCtrl.dispose();

    if (confirmed != true) return;
    if (amount == null || amount <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a payment amount greater than zero')),
      );
      return;
    }

    await _run(
      () => _repo
          .recordPayment(p.id, amount: amount, paymentRef: ref)
          .then((_) {}),
      'Payment recorded',
    );
  }

  Future<void> _approve(BuildingPermitDetail p) async {
    final monthsCtrl = TextEditingController(text: '36');
    final remarksCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sanction this permit'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'All mandatory clearances are in, fees are paid and a compliant '
                'site inspection is on record.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: monthsCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Validity (months)',
                  helperText: 'Standard TN building permit validity is 36 months',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Remarks / conditions',
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
            child: const Text('Sanction permit'),
          ),
        ],
      ),
    );

    final months = int.tryParse(monthsCtrl.text.trim());
    monthsCtrl.dispose();
    final remarks = remarksCtrl.text.trim();
    remarksCtrl.dispose();

    if (confirmed != true) return;

    await _run(
      () => _repo
          .approvePermit(p.id, validityMonths: months, remarks: remarks)
          .then((_) {}),
      'Permit sanctioned',
    );
  }

  Future<void> _reject(BuildingPermitDetail p) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this application'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: reasonCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              helperText:
                  'The applicant sees this — state something they can act on',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true) return;
    if (reason.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Give a reason of at least 10 characters'),
        ),
      );
      return;
    }

    await _run(
      () => _repo.rejectPermit(p.id, reason).then((_) {}),
      'Application rejected',
    );
  }

  Future<void> _cancel(BuildingPermitDetail p) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel this application?'),
        content: Text(
          '${p.summary.permitNumber} will be closed as cancelled and can no '
          'longer be edited or submitted. This cannot be undone.',
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel application'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _run(
      () => _repo.changeStatus(p.id, PermitStatus.cancelled).then((_) {}),
      'Application cancelled',
    );
  }

  Future<void> _uploadDocument(BuildingPermitDetail p) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await _repo.uploadDocument(
        p.id,
        bytes: bytes,
        fileName: picked.name,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Document uploaded')));
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingMessage(e)),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}

class _Kv {
  final String label;
  final String value;

  const _Kv(this.label, this.value);
}
