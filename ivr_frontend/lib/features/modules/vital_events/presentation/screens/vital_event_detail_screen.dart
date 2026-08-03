import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/core/widgets/app_error_state.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/models/vital_event_models.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/vital_event_repository.dart';
import 'package:ivr_frontend/features/modules/vital_events/presentation/widgets/certificate_card.dart';
import 'package:ivr_frontend/features/modules/vital_events/presentation/widgets/vital_status_badge.dart';

/// A single register entry: particulars, the registrar's actions, certificates
/// issued against it, supporting documents and the audit trail.
class VitalEventDetailScreen extends StatefulWidget {
  final int eventId;

  const VitalEventDetailScreen({super.key, required this.eventId});

  @override
  State<VitalEventDetailScreen> createState() => _VitalEventDetailScreenState();
}

class _VitalEventDetailScreenState extends State<VitalEventDetailScreen> {
  final _repo = VitalEventRepository();
  final _picker = ImagePicker();

  late Future<VitalEventDetail> _future;
  bool _busy = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _future = _repo.getEvent(widget.eventId);
  }

  void _reload() {
    setState(() {
      _future = _repo.getEvent(widget.eventId, forceRefresh: true);
    });
  }

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
    return FutureBuilder<VitalEventDetail>(
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
            message: 'Loading register entry...',
            style: AppLoadingStyle.detail,
          );
        }

        final e = snap.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 1040;
            final left = <Widget>[
              _header(e),
              if (e.readiness.blockers.isNotEmpty &&
                  e.status != VitalStatus.rejected)
                _blockersBanner(e),
              if (e.status == VitalStatus.rejected && e.rejectionReason != null)
                _banner(
                  color: AppTheme.error,
                  icon: Icons.block_rounded,
                  title: 'Report rejected',
                  lines: [e.rejectionReason!],
                ),
              if (e.correctionNote != null)
                _banner(
                  color: AppTheme.info,
                  icon: Icons.edit_note_rounded,
                  title: 'Corrected under s.15',
                  lines: [e.correctionNote!],
                ),
              _particulars(e),
              _informant(e),
            ];
            final right = <Widget>[
              CertificatesCard(
                certificates: e.certificates,
                canIssue: e.status.isInRegister,
                busy: _busy,
                onIssue: () => _issueCertificate(e),
                onShowQr: (c) => showDialog<void>(
                  context: context,
                  builder: (_) => CertificateQrDialog(
                    certificate: c,
                    subjectName: e.summary.subjectName,
                  ),
                ),
                onCancel: (c) => _cancelCertificate(e, c),
              ),
              _documents(e),
              _history(e),
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

  Widget _header(VitalEventDetail e) {
    final df = DateFormat.yMMMd();
    final s = e.summary;

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
                      s.subjectName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.registrationNumber != null
                          ? 'Register no. ${s.registrationNumber}'
                          : 'Not yet entered in the register',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  VitalStatusBadge(status: s.status),
                  const SizedBox(height: 6),
                  EventTypeChip(type: s.eventType),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _chip(
                Icons.event_rounded,
                '${s.eventType == VitalEventType.birth ? 'Born' : 'Died'} '
                '${df.format(s.eventDate)}'
                '${s.eventTime != null ? ' at ${s.eventTime}' : ''}',
              ),
              if (e.reportedAt != null)
                _chip(Icons.inbox_rounded, 'Reported ${df.format(e.reportedAt!)}'),
              if (s.registeredAt != null)
                _chip(
                  Icons.verified_rounded,
                  'Registered ${df.format(s.registeredAt!)}',
                ),
              DelayBandChip(
                band: e.readiness.delayBand,
                delayDays: e.readiness.delayDays,
              ),
              _chip(Icons.source_rounded, s.reportingSource.label),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spaceMd),
          _actionBar(e),
        ],
      ),
    );
  }

  Widget _actionBar(VitalEventDetail e) {
    final buttons = <Widget>[];

    if (e.status == VitalStatus.reported) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                    () => _repo.verifyEntry(e.id).then((_) {}),
                    'Particulars verified',
                  ),
          icon: const Icon(Icons.fact_check_rounded, size: 18),
          label: const Text('Verify particulars'),
        ),
      );
    }

    if (e.status == VitalStatus.verified) {
      buttons.add(
        FilledButton.icon(
          onPressed: _busy ? null : () => _register(e),
          icon: const Icon(Icons.app_registration_rounded, size: 18),
          label: const Text('Enter in register'),
        ),
      );
    }

    if (e.status.isInRegister) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: _busy ? null : () => _correct(e),
          icon: const Icon(Icons.edit_note_rounded, size: 18),
          label: const Text('Correct entry (s.15)'),
        ),
      );
    }

    if (e.status == VitalStatus.reported || e.status == VitalStatus.verified) {
      buttons.add(
        TextButton.icon(
          onPressed: _busy ? null : () => _reject(e),
          icon: const Icon(Icons.block_rounded, size: 18, color: AppTheme.error),
          label: const Text('Reject', style: TextStyle(color: AppTheme.error)),
        ),
      );
    }

    if (buttons.isEmpty) {
      return Text(
        'This entry is ${e.status.label.toLowerCase()} — no further action is available.',
        style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
      );
    }

    return Wrap(spacing: 10, runSpacing: 10, children: buttons);
  }

  Widget _blockersBanner(VitalEventDetail e) => _banner(
        color: DelayBandChip.colorFor(e.readiness.delayBand),
        icon: Icons.pending_actions_rounded,
        title: 'Before this entry can be registered',
        lines: e.readiness.blockers,
      );

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

  // ── Particulars ──────────────────────────────────────────────────────────

  Widget _particulars(VitalEventDetail e) {
    final pairs = <({String label, String value})>[];
    final df = DateFormat.yMMMd();

    if (e.eventType == VitalEventType.birth) {
      final b = e.birth;
      if (b != null) {
        pairs.addAll([
          (label: 'Name of child', value: b.displayName),
          (label: 'Sex', value: titleCase(b.sex)),
          if (b.weightKg != null)
            (label: 'Weight at birth', value: '${b.weightKg} kg'),
          if (b.deliveryType != null)
            (label: 'Delivery', value: titleCase(b.deliveryType!)),
          (label: 'Mother', value: b.motherName),
          if (b.motherOccupation != null)
            (label: 'Mother\'s occupation', value: b.motherOccupation!),
          if (b.motherAgeAtBirth != null)
            (label: 'Mother\'s age at birth', value: '${b.motherAgeAtBirth}'),
          if (b.motherAadhaar != null)
            (label: 'Mother\'s Aadhaar', value: b.motherAadhaar!),
          if (b.fatherName != null) (label: 'Father', value: b.fatherName!),
          if (b.fatherOccupation != null)
            (label: 'Father\'s occupation', value: b.fatherOccupation!),
          if (b.fatherAadhaar != null)
            (label: 'Father\'s Aadhaar', value: b.fatherAadhaar!),
          if (b.birthOrder != null)
            (label: 'Birth order', value: '${b.birthOrder}'),
          if (b.isMultipleBirth)
            (
              label: 'Multiple birth',
              value: 'Yes${b.multipleBirthOrder != null ? ' (#${b.multipleBirthOrder})' : ''}',
            ),
        ]);
      }
    } else {
      final d = e.death;
      if (d != null) {
        pairs.addAll([
          (label: 'Name of deceased', value: d.deceasedName),
          (label: 'Sex', value: titleCase(d.sex)),
          (label: 'Age', value: d.ageLabel),
          if (d.fatherName != null) (label: 'Father', value: d.fatherName!),
          if (d.spouseName != null) (label: 'Spouse', value: d.spouseName!),
          if (d.occupation != null)
            (label: 'Occupation', value: d.occupation!),
          if (d.causeOfDeath != null)
            (label: 'Cause of death', value: d.causeOfDeath!),
          if (d.causeCategory != null)
            (label: 'Category', value: titleCase(d.causeCategory!)),
          (
            label: 'Medically certified',
            value: d.medicallyCertified ? 'Yes' : 'No',
          ),
          if (d.certifyingDoctor != null)
            (
              label: 'Certifying doctor',
              value:
                  '${d.certifyingDoctor}${d.doctorRegNo != null ? ' (${d.doctorRegNo})' : ''}',
            ),
          if (d.disposalMethod != null)
            (label: 'Disposal', value: titleCase(d.disposalMethod!)),
          if (d.disposalPlace != null)
            (label: 'Place of disposal', value: d.disposalPlace!),
          if (d.disposalDate != null)
            (label: 'Date of disposal', value: df.format(d.disposalDate!)),
        ]);
      }
    }

    pairs.addAll([
      (label: 'Place type', value: titleCase(e.summary.placeType)),
      if (e.summary.placeName != null)
        (label: 'Place', value: e.summary.placeName!),
      if (e.hospitalName != null)
        (
          label: 'Hospital',
          value:
              '${e.hospitalName}${e.hospitalRegNo != null ? ' (${e.hospitalRegNo})' : ''}',
        ),
      if (e.delayApprovalRef != null)
        (label: 'Late-entry authority', value: e.delayApprovalRef!),
    ]);

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            Icons.description_outlined,
            e.eventType == VitalEventType.birth
                ? 'Particulars (Form 1)'
                : 'Particulars (Form 2)',
          ),
          const SizedBox(height: AppTheme.spaceMd),
          _kvGrid(pairs),
          if (e.placeAddress != null && e.placeAddress!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              e.placeAddress!,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _informant(VitalEventDetail e) {
    final s = e.summary;
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.record_voice_over_outlined, 'Informant'),
          const SizedBox(height: AppTheme.spaceMd),
          _kvGrid([
            (label: 'Name', value: s.informantName),
            (label: 'Relationship', value: titleCase(s.informantRelation)),
            if (s.informantPhone != null)
              (label: 'Mobile', value: s.informantPhone!),
            if (e.informantAadhaar != null)
              (label: 'Aadhaar', value: e.informantAadhaar!),
          ]),
          if (e.informantAddress != null && e.informantAddress!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spaceSm),
            Text(
              e.informantAddress!,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _documents(VitalEventDetail e) {
    final df = DateFormat.yMMMd();
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _cardTitle(Icons.folder_open_rounded, 'Supporting documents'),
              ),
              TextButton.icon(
                onPressed: _uploading ? null : () => _uploadDocument(e),
                icon: _uploading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded, size: 18),
                label: Text(_uploading ? 'Uploading...' : 'Upload'),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          if (e.documents.isEmpty)
            Text(
              e.eventType == VitalEventType.birth
                  ? 'Attach the hospital report or the informant\'s declaration.'
                  : 'Attach the medical certificate of cause of death, or the affidavit for a late entry.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...e.documents.map(
              (d) => ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  d.isPdf ? Icons.picture_as_pdf_rounded : Icons.image_outlined,
                  color: d.isPdf ? AppTheme.error : AppTheme.info,
                ),
                title: Text(
                  d.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  d.createdAt != null ? df.format(d.createdAt!) : d.fileName,
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _history(VitalEventDetail e) {
    final df = DateFormat.yMMMd().add_jm();
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(Icons.history_rounded, 'Audit trail'),
          const SizedBox(height: AppTheme.spaceSm),
          if (e.history.isEmpty)
            Text(
              'No recorded activity yet.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...e.history.take(12).map(
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

  Future<void> _register(VitalEventDetail e) async {
    final refCtrl = TextEditingController(text: e.delayApprovalRef ?? '');
    final needsRef = e.readiness.requiresApprovalRef;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enter in the register'),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'A serial number will be allotted from this unit\'s '
                '${e.eventType == VitalEventType.birth ? 'birth' : 'death'} register. '
                'This is the legal act of registration and cannot be undone — '
                'later changes go through a correction under s.15.',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              ),
              if (needsRef) ...[
                const SizedBox(height: AppTheme.spaceMd),
                Text(
                  e.readiness.delayReason,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: DelayBandChip.colorFor(e.readiness.delayBand),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: refCtrl,
                  decoration: InputDecoration(
                    labelText: e.readiness.delayBand == DelayBand.magistrateOrder
                        ? 'Magistrate\'s order reference *'
                        : 'Written permission reference *',
                    hintText: 'DR/CBE/2026/118',
                    border: const OutlineInputBorder(),
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
            child: const Text('Register'),
          ),
        ],
      ),
    );

    final ref = refCtrl.text.trim();
    refCtrl.dispose();
    if (confirmed != true) return;

    if (needsRef && ref.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Record the authorising reference before registering'),
        ),
      );
      return;
    }

    await _run(
      () => _repo.registerEntry(e.id, delayApprovalRef: ref).then((_) {}),
      'Entry registered',
    );
  }

  Future<void> _reject(VitalEventDetail e) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject this report'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: reasonCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Reason for rejection',
              helperText: 'The informant sees this — state something they can act on',
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
        const SnackBar(content: Text('Give a reason of at least 10 characters')),
      );
      return;
    }

    await _run(
      () => _repo.rejectEntry(e.id, reason).then((_) {}),
      'Report rejected',
    );
  }

  /// Correction under s.15. Only the fields most often wrong are offered —
  /// anything deeper is a fresh entry, not an amendment.
  Future<void> _correct(VitalEventDetail e) async {
    final isBirth = e.eventType == VitalEventType.birth;
    final noteCtrl = TextEditingController();
    final nameCtrl = TextEditingController(
      text: isBirth ? (e.birth?.childName ?? '') : (e.death?.deceasedName ?? ''),
    );
    final liveCount = e.liveCertificates.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Correct the entry (s.15)'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The previous values are kept in the audit trail. '
                  '${liveCount > 0 ? 'The $liveCount certificate(s) already issued will be cancelled, since they would otherwise contradict the register.' : ''}',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: AppTheme.spaceMd),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: isBirth ? 'Name of child' : 'Name of deceased',
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSm),
                TextField(
                  controller: noteCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Why this correction is being made *',
                    hintText: 'Per affidavit dated 12 May 2026 …',
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
            child: const Text('Record correction'),
          ),
        ],
      ),
    );

    final note = noteCtrl.text.trim();
    final name = nameCtrl.text.trim();
    noteCtrl.dispose();
    nameCtrl.dispose();
    if (confirmed != true) return;

    if (note.length < 10) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('A correction must record why it was made')),
      );
      return;
    }

    // The backend requires the full particulars block, so send the existing
    // values with the corrected name folded in.
    final Map<String, dynamic>? birth = isBirth && e.birth != null
        ? {
            'sex': e.birth!.sex,
            'mother_name': e.birth!.motherName,
            if (name.isNotEmpty) 'child_name': name,
            if (e.birth!.fatherName != null) 'father_name': e.birth!.fatherName,
          }
        : null;
    final Map<String, dynamic>? death = !isBirth && e.death != null
        ? {
            'deceased_name': name.isNotEmpty ? name : e.death!.deceasedName,
            'sex': e.death!.sex,
            if (e.death!.ageYears != null) 'age_years': e.death!.ageYears,
            if (e.death!.ageMonths != null) 'age_months': e.death!.ageMonths,
            if (e.death!.ageDays != null) 'age_days': e.death!.ageDays,
          }
        : null;

    await _run(
      () => _repo
          .correctEntry(e.id, correctionNote: note, birth: birth, death: death)
          .then((_) {}),
      'Correction recorded',
    );
  }

  Future<void> _issueCertificate(VitalEventDetail e) async {
    final request = await showDialog<CertificateIssueRequest>(
      context: context,
      builder: (_) => IssueCertificateDialog(
        subjectName: e.summary.subjectName,
      ),
    );
    if (request == null) return;

    await _run(
      () => _repo
          .issueCertificate(
            e.id,
            issuedTo: request.issuedTo,
            issuedToRelation: request.issuedToRelation,
            purpose: request.purpose,
            feeAmount: request.feeAmount,
            paymentRef: request.paymentRef,
          )
          .then((_) {}),
      'Certificate issued',
    );
  }

  Future<void> _cancelCertificate(
    VitalEventDetail e,
    VitalCertificate certificate,
  ) async {
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Cancel ${certificate.copyLabel.toLowerCase()}'),
        content: SizedBox(
          width: 420,
          child: TextField(
            controller: reasonCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Why is it being cancelled?',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Cancel certificate'),
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
        const SnackBar(content: Text('Record why the certificate is cancelled')),
      );
      return;
    }

    await _run(
      () => _repo
          .cancelCertificate(e.id, certificate.id, reason)
          .then((_) {}),
      'Certificate cancelled',
    );
  }

  Future<void> _uploadDocument(VitalEventDetail e) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _uploading = true);
    try {
      final bytes = await picked.readAsBytes();
      await _repo.uploadDocument(e.id, bytes: bytes, fileName: picked.name);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Document uploaded')));
      _reload();
    } catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(userFacingMessage(err)),
          backgroundColor: AppTheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
}
