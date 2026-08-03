import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';
import 'permit_status_badge.dart';

/// Multi-department NOC approval checklist (Screen Plan 14 §6).
///
/// This is the gate on approval: the permit cannot be sanctioned until every
/// mandatory row here is Granted or Not applicable, and the backend enforces
/// the same rule, so the UI is showing state rather than deciding it.
class NocChecklistCard extends StatelessWidget {
  final List<PermitNoc> nocs;
  final bool readOnly;
  final void Function(PermitNoc noc) onEdit;
  final VoidCallback onAdd;

  const NocChecklistCard({
    super.key,
    required this.nocs,
    required this.onEdit,
    required this.onAdd,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final mandatory = nocs.where((n) => n.isMandatory).toList();
    final settled = mandatory
        .where((n) =>
            n.status == NocState.granted || n.status == NocState.notApplicable)
        .length;
    final progress = mandatory.isEmpty ? 0.0 : settled / mandatory.length;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.fact_check_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Department clearances',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (!readOnly)
                TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            mandatory.isEmpty
                ? 'No mandatory clearances listed'
                : '$settled of ${mandatory.length} mandatory clearances settled',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppTheme.bgSurface,
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1 ? AppTheme.accent : AppTheme.warning,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spaceMd),
          if (nocs.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Add the departments whose clearance this proposal needs before submitting.',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            )
          else
            ...nocs.map((noc) => _NocRow(
                  noc: noc,
                  readOnly: readOnly,
                  onEdit: () => onEdit(noc),
                )),
        ],
      ),
    );
  }
}

class _NocRow extends StatelessWidget {
  final PermitNoc noc;
  final bool readOnly;
  final VoidCallback onEdit;

  const _NocRow({
    required this.noc,
    required this.readOnly,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();
    final color = NocStatusBadge.colorFor(noc.status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          onTap: readOnly ? null : onEdit,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: color.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(NocStatusBadge.iconFor(noc.status), size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              noc.departmentLabel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          if (!noc.isMandatory) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(optional)',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (noc.referenceNo != null && noc.referenceNo!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Ref ${noc.referenceNo}'
                            '${noc.clearedAt != null ? ' · ${df.format(noc.clearedAt!)}' : ''}',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      if (noc.remarks != null && noc.remarks!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            noc.remarks!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textMuted,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                NocStatusBadge(state: noc.status),
                if (!readOnly) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 18, color: AppTheme.textMuted),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog for recording a department's decision.
class NocDecisionDialog extends StatefulWidget {
  final PermitNoc noc;

  const NocDecisionDialog({super.key, required this.noc});

  @override
  State<NocDecisionDialog> createState() => _NocDecisionDialogState();
}

class NocDecision {
  final NocState status;
  final String? referenceNo;
  final String? remarks;

  const NocDecision({required this.status, this.referenceNo, this.remarks});
}

class _NocDecisionDialogState extends State<NocDecisionDialog> {
  late NocState _status;
  late final TextEditingController _refCtrl;
  late final TextEditingController _remarksCtrl;

  @override
  void initState() {
    super.initState();
    _status = widget.noc.status;
    _refCtrl = TextEditingController(text: widget.noc.referenceNo ?? '');
    _remarksCtrl = TextEditingController(text: widget.noc.remarks ?? '');
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.noc.departmentLabel} clearance'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Decision',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: NocState.values.map((state) {
                  final selected = _status == state;
                  final color = NocStatusBadge.colorFor(state);
                  return ChoiceChip(
                    label: Text(state.label),
                    selected: selected,
                    onSelected: (_) => setState(() => _status = state),
                    selectedColor: color.withValues(alpha: 0.16),
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: selected ? color : AppTheme.textSecondary,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppTheme.spaceMd),
              TextField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Clearance reference number',
                  hintText: 'e.g. TNFS/CBE/2026/0912',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSm),
              TextField(
                controller: _remarksCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Remarks',
                  hintText: 'Conditions attached to the clearance, if any',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_status == NocState.granted) ...[
                const SizedBox(height: AppTheme.spaceSm),
                Text(
                  'Granting the last mandatory clearance moves the file to site inspection.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            NocDecision(
              status: _status,
              referenceNo: _refCtrl.text.trim(),
              remarks: _remarksCtrl.text.trim(),
            ),
          ),
          child: const Text('Record decision'),
        ),
      ],
    );
  }
}
