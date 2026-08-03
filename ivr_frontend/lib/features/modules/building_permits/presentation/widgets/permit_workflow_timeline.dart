import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_card.dart';
import 'package:ivr_frontend/features/modules/building_permits/data/models/building_permit_models.dart';

/// Approval chain for the permit, read from the shared workflow engine.
///
/// The steps and their order come from the council's published
/// `building_permit_approval` template, so a body that routes through a Town
/// Planning Officer before the Commissioner sees exactly that here without any
/// module-specific code.
class PermitWorkflowTimeline extends StatelessWidget {
  final PermitWorkflow? workflow;

  const PermitWorkflowTimeline({super.key, required this.workflow});

  @override
  Widget build(BuildContext context) {
    final wf = workflow;

    return AppCard(
      padding: const EdgeInsets.all(AppTheme.spaceLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.account_tree_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'Approval chain',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spaceMd),
          if (wf == null)
            Text(
              'No approval chain running. It starts when the application is '
              'submitted, provided a "building_permit_approval" workflow '
              'template is published for this branch.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else if (wf.steps.isEmpty)
            Text(
              'The workflow template has no steps configured.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            )
          else
            ...wf.steps.asMap().entries.map(
                  (e) => _StepRow(
                    step: e.value,
                    isLast: e.key == wf.steps.length - 1,
                  ),
                ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final PermitWorkflowStep step;
  final bool isLast;

  const _StepRow({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();

    Color color;
    IconData icon;
    if (step.action == 'approved' || step.action == 'executed') {
      color = AppTheme.accent;
      icon = Icons.check_circle_rounded;
    } else if (step.action == 'rejected') {
      color = AppTheme.error;
      icon = Icons.cancel_rounded;
    } else if (step.action == 'returned') {
      color = const Color(0xFFEA580C);
      icon = Icons.undo_rounded;
    } else if (step.isCurrent) {
      color = AppTheme.warning;
      icon = Icons.radio_button_checked_rounded;
    } else {
      color = AppTheme.textMuted;
      icon = Icons.radio_button_unchecked_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(icon, size: 18, color: color),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: AppTheme.stroke,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          titleCase(step.roleName),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        titleCase(step.actionType),
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      if (step.isCurrent) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.warning.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'With them now',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (step.actedAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '${titleCase(step.action ?? '')} · ${df.format(step.actedAt!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  if (step.comments != null && step.comments!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        step.comments!,
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
          ),
        ],
      ),
    );
  }
}
