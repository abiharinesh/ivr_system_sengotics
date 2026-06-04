import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/list_screen_shell.dart';

class IvrLogsScreen extends StatelessWidget {
  const IvrLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = List.generate(
      10,
      (index) => _IvrLogItem(
        callId: 'IVR-${4200 + index}',
        callerNumber: '+91-98${20 + index}‑XX‑${40 + index}',
        flowName: index.isEven ? 'Complaint registration' : 'Status check',
        durationLabel: '${30 + index}s',
        result: index.isEven ? 'Complaint captured' : 'Call dropped',
        createdAt: 'Today · ${(8 + index)}:${(index * 3) % 60}'.padRight(11),
      ),
    );

    return ListScreenShell(
      title: 'IVR Call Logs',
      subtitle: 'Inspect recent IVR interactions from citizens',
      countLabel: '${logs.length} call(s)',
      action: OutlinedButton.icon(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Advanced filtering will be available soon.'),
            ),
          );
        },
        icon: const Icon(Icons.filter_list_rounded, size: 18),
        label: const Text('Filters'),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(hPad, 0, hPad, hPad),
            itemBuilder: (context, index) {
          final item = logs[index];
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
                          color: AppTheme.bgSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child:       Icon(
                          Icons.phone_missed_rounded,
                          size: 20,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.callId,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              item.flowName,
                              style:       TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        item.durationLabel,
                        style:       TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                            Icon(
                        Icons.call_rounded,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        item.callerNumber,
                        style:       TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        item.createdAt,
                        style:       TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                              Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: AppTheme.textMuted,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.result,
                            style:       TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Full IVR trace coming soon.'),
                              ),
                            );
                          },
                          child: const Text(
                            'View flow',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: logs.length,
          );
        },
      ),
    );
  }
}

class _IvrLogItem {
  final String callId;
  final String callerNumber;
  final String flowName;
  final String durationLabel;
  final String result;
  final String createdAt;

  _IvrLogItem({
    required this.callId,
    required this.callerNumber,
    required this.flowName,
    required this.durationLabel,
    required this.result,
    required this.createdAt,
  });
}
