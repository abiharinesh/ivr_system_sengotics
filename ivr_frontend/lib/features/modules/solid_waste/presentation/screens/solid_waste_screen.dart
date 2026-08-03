import 'package:flutter/material.dart';

import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/stat_card.dart';
import 'package:ivr_frontend/features/modules/solid_waste/data/models/solid_waste_models.dart';
import 'package:ivr_frontend/features/modules/solid_waste/data/solid_waste_repository.dart';
import 'package:ivr_frontend/features/modules/solid_waste/presentation/widgets/attendance_panel.dart';
import 'package:ivr_frontend/features/modules/solid_waste/presentation/widgets/bins_panel.dart';
import 'package:ivr_frontend/features/modules/solid_waste/presentation/widgets/rounds_panel.dart';

/// Solid waste management (Screen Plan 14 §1).
///
/// Three working surfaces behind one header, because a sanitary inspector's
/// day moves between them constantly: which bins are red, how the morning's
/// rounds are going, and who turned up.
class SolidWasteScreen extends StatefulWidget {
  const SolidWasteScreen({super.key});

  @override
  State<SolidWasteScreen> createState() => _SolidWasteScreenState();
}

class _SolidWasteScreenState extends State<SolidWasteScreen>
    with SingleTickerProviderStateMixin {
  final _repo = SolidWasteRepository();
  late final TabController _tabs;
  late Future<SolidWasteSummary> _summary;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _summary = _repo.fetchSummary();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Any write in a panel can move the headline counters, so they refresh
  /// together rather than going stale behind the tab the user is looking at.
  void _refreshSummary() {
    setState(() => _summary = _repo.fetchSummary(forceRefresh: true));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        FutureBuilder<SolidWasteSummary>(
          future: _summary,
          builder: (context, snap) => _Header(
            summary: snap.data ?? SolidWasteSummary.empty,
            isLoading: !snap.hasData,
          ),
        ),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppTheme.stroke)),
          ),
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(icon: Icon(Icons.delete_outline_rounded), text: 'Bins'),
              Tab(icon: Icon(Icons.local_shipping_outlined), text: 'Rounds'),
              Tab(icon: Icon(Icons.groups_outlined), text: 'Workers'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              BinsPanel(repo: _repo, onChanged: _refreshSummary),
              RoundsPanel(repo: _repo, onChanged: _refreshSummary),
              AttendancePanel(repo: _repo, onChanged: _refreshSummary),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final SolidWasteSummary summary;
  final bool isLoading;

  const _Header({required this.summary, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final p = summary.todayProgress;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          int columns = 4;
          if (width < 600) {
            columns = 1;
          } else if (width < 960) {
            columns = 2;
          }

          return GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              mainAxisExtent: 110,
            ),
            children: [
              StatCard(
                title: 'Bins needing clearing',
                value: '${summary.binsRed}',
                icon: Icons.delete_sweep_rounded,
                gradient: AppTheme.errorGradient,
                delta: summary.binsOverflowing > 0
                    ? '${summary.binsOverflowing} over'
                    : null,
                positiveDelta: false,
                isLoading: isLoading,
              ),
              StatCard(
                title: 'Bins in service',
                value: '${summary.binsActive}',
                icon: Icons.inventory_2_outlined,
                gradient: AppTheme.primaryGradient,
                isLoading: isLoading,
              ),
              StatCard(
                title: "Today's collection",
                value: '${p.percent}%',
                icon: Icons.route_rounded,
                gradient: AppTheme.accentGradient,
                delta: p.total > 0 ? '${p.completed}/${p.total}' : null,
                positiveDelta: p.band != 'behind',
                isLoading: isLoading,
              ),
              StatCard(
                title: 'Workers on duty',
                value: '${summary.workersPresent}',
                icon: Icons.badge_rounded,
                gradient: AppTheme.warningGradient,
                delta: summary.workersAbsent > 0
                    ? '${summary.workersAbsent} absent'
                    : null,
                positiveDelta: summary.workersAbsent == 0,
                isLoading: isLoading,
              ),
            ],
          );
        },
      ),
    );
  }
}
