import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/list_screen_shell.dart';

class VoiceCallsScreen extends StatelessWidget {
  const VoiceCallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder demo data – in a real app this would
    // come from an API / bloc.
    final calls = List.generate(
      8,
      (index) => _VoiceCallItem(
        campaignName: 'Power outage alert #$index',
        status: index.isEven ? 'Completed' : 'In progress',
        recipients: 120 + index * 10,
        answered: 90 + index * 7,
        createdAt: 'Today · ${(9 + index)}:00 AM',
      ),
    );

    return ListScreenShell(
      title: 'Voice Call Campaigns',
      subtitle: 'Broadcast IVR alerts and monitor reach',
      countLabel: '${calls.length} campaign(s)',
      action: ElevatedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
              content: const Text('Voice campaign creation will be available soon.'),
              backgroundColor: AppTheme.primary,
            ),
          );
        },
        icon: const Icon(Icons.add_call, size: 18),
        label: const Text('New Voice Campaign'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
        itemBuilder: (context, index) {
          final item = calls[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.campaign_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.campaignName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.createdAt,
                              style:       TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(child: _StatusChip(label: item.status)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final narrow = constraints.maxWidth < 400;
                      if (narrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                      Icon(
                                  Icons.people_rounded,
                                  size: 16,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${item.recipients} recipients',
                                  style:       TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(width: 12),
                                      Icon(
                                  Icons.phone_in_talk_rounded,
                                  size: 16,
                                  color: AppTheme.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${item.answered} answered',
                                    style:       TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Detailed call report coming soon.'),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.bar_chart_rounded, size: 18),
                              label: const Text('View report'),
                            ),
                          ],
                        );
                      }
                      return Row(
                        children: [
                                Icon(
                            Icons.people_rounded,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.recipients} recipients',
                            style:       TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                                Icon(
                            Icons.phone_in_talk_rounded,
                            size: 16,
                            color: AppTheme.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${item.answered} answered',
                            style:       TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const Spacer(),
                          TextButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Detailed call report coming soon.'),
                                ),
                              );
                            },
                            icon: const Icon(Icons.bar_chart_rounded, size: 18),
                            label: const Text('View report'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: calls.length,
          );
        },
      ),
    );
  }
}

class _VoiceCallItem {
  final String campaignName;
  final String status;
  final int recipients;
  final int answered;
  final String createdAt;

  _VoiceCallItem({
    required this.campaignName,
    required this.status,
    required this.recipients,
    required this.answered,
    required this.createdAt,
  });
}

class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final isCompleted = label.toLowerCase().contains('completed');
    final color = isCompleted ? AppTheme.accent : AppTheme.warning;
    final bg = color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : Icons.timelapse_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
