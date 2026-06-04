import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/stat_card.dart';
import '../../../super_admin/data/models/complaint_model.dart';
import '../../data/electrician_repository.dart';

class ElectricianDashboardScreen extends StatefulWidget {
  const ElectricianDashboardScreen({super.key});

  @override
  State<ElectricianDashboardScreen> createState() =>
      _ElectricianDashboardScreenState();
}

class _ElectricianDashboardScreenState extends State<ElectricianDashboardScreen> {
  final _repo = ElectricianRepository();

  Map<String, dynamic>? _me;
  List<ComplaintModel> _complaints = [];
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        _repo.getMe(),
        _repo.listComplaints(),
      ]);
      final me = Map<String, dynamic>.from(results[0] as Map);
      final raw = results[1] as List<dynamic>;
      final complaints = raw
          .map((e) => ComplaintModel.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
      setState(() {
        _me = me;
        _complaints = complaints;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String? _panchayatHint() {
    final m = _me;
    if (m == null) return null;
    final p = m['panchayat'];
    if (p is Map) {
      final name = p['name']?.toString();
      if (name != null && name.isNotEmpty) return name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.sizeOf(context).width < 600 ? 16.0 : 24.0;

    if (_loading) {
      return const AppLoadingState(
        message: 'Loading dashboard...',
        style: AppLoadingStyle.dashboard,
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade800),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final openStatuses = {'assigned', 'in_progress'};
    final openCount =
        _complaints.where((c) => openStatuses.contains(c.status)).length;
    final awaitingConfirmation = _complaints
        .where((c) => c.status == 'resolved_pending_confirmation')
        .length;
    final total = _complaints.length;
    final panchayat = _panchayatHint();

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              panchayat != null
                  ? 'Working in $panchayat'
                  : 'Electrician home',
              style:       TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quick view of your assigned complaints. Open the full list for details and actions.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final crossAxisCount = w > 720 ? 3 : 1;
                if (crossAxisCount == 1) {
                  return Column(
                    children: [
                      StatCard(
                        title: 'Open jobs',
                        value: openCount.toString(),
                        icon: Icons.electrical_services_rounded,
                        gradient: AppTheme.primaryGradient,
                      ),
                      const SizedBox(height: 12),
                      StatCard(
                        title: 'Awaiting confirmation',
                        value: awaitingConfirmation.toString(),
                        icon: Icons.hourglass_top_rounded,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.warning,
                            AppTheme.warning.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      StatCard(
                        title: 'Total assigned',
                        value: total.toString(),
                        icon: Icons.list_alt_rounded,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.textSecondary,
                            AppTheme.textSecondary.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StatCard(
                        title: 'Open jobs',
                        value: openCount.toString(),
                        icon: Icons.electrical_services_rounded,
                        gradient: AppTheme.primaryGradient,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        title: 'Awaiting confirmation',
                        value: awaitingConfirmation.toString(),
                        icon: Icons.hourglass_top_rounded,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.warning,
                            AppTheme.warning.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: StatCard(
                        title: 'Total assigned',
                        value: total.toString(),
                        icon: Icons.list_alt_rounded,
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.textSecondary,
                            AppTheme.textSecondary.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: () => context.go('/electrician/jobs'),
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('View all jobs'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}