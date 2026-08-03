import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';

/// Site visits scheduled against the permit, and their findings.
///
/// Approval needs at least one completed, compliant visit — the backend
/// enforces that, so a non-compliant finding here is a real blocker rather than
/// a note.
class PermitInspectionsCard extends StatelessWidget {
  final List<PermitInspection> inspections;
  final bool readOnly;
  final VoidCallback onSchedule;
  final void Function(PermitInspection inspection) onRecord;

  const PermitInspectionsCard({
    super.key,
    required this.inspections,
    required this.onSchedule,
    required this.onRecord,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.engineering_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Site inspections',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              if (!readOnly)
                TextButton.icon(
                  onPressed: onSchedule,
                  icon: const Icon(Icons.event_available_rounded, size: 18),
                  label: const Text('Schedule'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceSm),
          if (inspections.isEmpty)
            Text(
              'No visits scheduled. A compliant site inspection is required '
              'before the permit can be sanctioned.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...inspections.map((i) {
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
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSurface,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
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
                            if (i.findings != null && i.findings!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  i.findings!,
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
                      if (!readOnly && !i.isCompleted)
                        TextButton(
                          onPressed: () => onRecord(i),
                          child: const Text('Record finding'),
                        ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Result of the schedule dialog.
class InspectionSchedule {
  final String inspectionType;
  final DateTime scheduledFor;

  const InspectionSchedule({
    required this.inspectionType,
    required this.scheduledFor,
  });
}

class ScheduleInspectionDialog extends StatefulWidget {
  const ScheduleInspectionDialog({super.key});

  @override
  State<ScheduleInspectionDialog> createState() =>
      _ScheduleInspectionDialogState();
}

class _ScheduleInspectionDialogState extends State<ScheduleInspectionDialog> {
  String _type = kInspectionTypes.first;
  DateTime _date = DateTime.now().add(const Duration(days: 3));

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd();

    return AlertDialog(
      title: const Text('Schedule a site visit'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Inspection type',
                border: OutlineInputBorder(),
              ),
              items: kInspectionTypes
                  .map(
                    (t) => DropdownMenuItem(value: t, child: Text(titleCase(t))),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: AppTheme.spaceMd),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Scheduled for',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(child: Text(df.format(_date))),
                  TextButton(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(
                          const Duration(days: 365),
                        ),
                      );
                      if (picked != null) setState(() => _date = picked);
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
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            InspectionSchedule(inspectionType: _type, scheduledFor: _date),
          ),
          child: const Text('Schedule'),
        ),
      ],
    );
  }
}

/// Result of the record-finding dialog.
class InspectionFinding {
  final bool isCompliant;
  final String findings;

  const InspectionFinding({required this.isCompliant, required this.findings});
}

class RecordInspectionDialog extends StatefulWidget {
  final PermitInspection inspection;

  const RecordInspectionDialog({super.key, required this.inspection});

  @override
  State<RecordInspectionDialog> createState() => _RecordInspectionDialogState();
}

class _RecordInspectionDialogState extends State<RecordInspectionDialog> {
  bool _compliant = true;
  final _findingsCtrl = TextEditingController();

  @override
  void dispose() {
    _findingsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.inspection.typeLabel} — finding'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _compliant,
              onChanged: (v) => setState(() => _compliant = v),
              title: Text(
                _compliant
                    ? 'Site is compliant with the sanctioned plan'
                    : 'Site is NOT compliant',
              ),
              subtitle: Text(
                _compliant
                    ? 'The permit can proceed to approval'
                    : 'Approval stays blocked until a compliant visit is recorded',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ),
            const SizedBox(height: AppTheme.spaceSm),
            TextField(
              controller: _findingsCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Findings',
                hintText: 'Measurements taken, deviations observed, conditions',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppTheme.spaceXs),
            Text(
              'A recorded finding cannot be overwritten — schedule another visit '
              'if the site changes.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            InspectionFinding(
              isCompliant: _compliant,
              findings: _findingsCtrl.text.trim(),
            ),
          ),
          child: const Text('Record finding'),
        ),
      ],
    );
  }
}
