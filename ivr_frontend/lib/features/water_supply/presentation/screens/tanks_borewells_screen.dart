import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../../data/water_repository.dart';
import '../../../../core/storage/secure_storage.dart';

class TanksBorewellsScreen extends StatefulWidget {
  const TanksBorewellsScreen({super.key});

  @override
  State<TanksBorewellsScreen> createState() => _TanksBorewellsScreenState();
}

class _TanksBorewellsScreenState extends State<TanksBorewellsScreen> {
  final WaterRepository _repository = WaterRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _tanks = [];
  int _panchayatId = 27; // Default fallback to 27 (Thayanur)
  final Map<int, bool> _togglingPumps = {};

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    final savedId = await SecureStorageService.getPanchayatId();
    if (savedId != null) {
      _panchayatId = savedId;
    }
    await _loadData();
  }

  Future<void> _loadData() async {
    final cached = _repository.getCachedTanks(_panchayatId);
    if (cached != null) {
      _tanks = cached;
      _isLoading = false;
      if (mounted) setState(() {});
    } else {
      setState(() => _isLoading = true);
    }
    try {
      final tanks = await _repository.getTanks(_panchayatId, forceRefresh: cached == null);
      if (mounted) {
        setState(() {
          _tanks = tanks;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _togglePump(Map<String, dynamic> tank, bool targetVal) async {
    final tankId = tank['id'] as int;
    setState(() {
      _togglingPumps[tankId] = true;
    });

    // Simulate SCADA network command delay
    await Future.delayed(const Duration(milliseconds: 700));

    if (mounted) {
      setState(() {
        tank['pump_status'] = targetVal ? 'on' : 'off';
        _togglingPumps[tankId] = false;
      });

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                targetVal ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                targetVal
                    ? '${tank['name']} started successfully.'
                    : '${tank['name']} shut down.',
              ),
            ],
          ),
          backgroundColor: targetVal ? AppTheme.accent : Colors.grey.shade900,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;

    Widget buildGridContent() {
      if (_isLoading) {
        final skeletonList = List.generate(4, (index) => Container(
          decoration: BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.stroke),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppShimmer.rounded(width: 42, height: 42),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppShimmer.rectangular(width: 120, height: 16),
                        SizedBox(height: 6),
                        AppShimmer.rectangular(width: 80, height: 10),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              const Expanded(
                child: Row(
                  children: [
                    AppShimmer.circular(width: 72, height: 72),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppShimmer.rectangular(width: 100, height: 10),
                          SizedBox(height: 6),
                          AppShimmer.rectangular(width: 100, height: 10),
                          SizedBox(height: 6),
                          AppShimmer.rectangular(width: 80, height: 10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ));

        return Wrap(
          spacing: 24,
          runSpacing: 24,
          children: skeletonList.map((s) => SizedBox(
            width: width > 1200
                ? (width - 48 - 48) / 3
                : (width > 750
                    ? (width - 48 - 24) / 2
                    : width - 48),
            height: 220,
            child: s,
          )).toList(),
        );
      }

      if (_tanks.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Column(
              children: [
                Icon(Icons.layers_clear_rounded, size: 48, color: AppTheme.textMuted),
                const SizedBox(height: 12),
                Text(
                  'No reservoirs or borewell stations found.',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        );
      }

      return Wrap(
        spacing: 24,
        runSpacing: 24,
        children: _tanks.map((t) => SizedBox(
          width: width > 1200
              ? (width - 48 - 48) / 3
              : (width > 750
                  ? (width - 48 - 24) / 2
                  : width - 48),
          child: _buildTankCard(t),
        )).toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservoirs & Borewell Stations'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Intro Section
              Text(
                'Panchayat Telemetry Console',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Live capacities of overhead reservoirs and groundwater borewell stations',
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Summary Metrics Section
              _buildSummaryCards(),
              const SizedBox(height: 28),

              Text(
                'Telemetry Stations',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),

              // Tanks & Pumps Grid
              buildGridContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    double totalCapacity = 0;
    double currentVolume = 0;
    int activePumpsCount = 0;
    int totalTanks = 0;
    int totalPumps = 0;

    for (final tank in _tanks) {
      if (tank['type'] == 'overhead_tank') {
        totalTanks++;
        final cap = (tank['capacity_liters'] as num? ?? 0.0).toDouble();
        totalCapacity += cap;
        currentVolume += cap * (((tank['current_level_pct'] as num? ?? 0.0).toDouble()) / 100.0);
      } else if (tank['type'] == 'borewell_pump') {
        totalPumps++;
        if (tank['pump_status'] == 'on') {
          activePumpsCount++;
        }
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth = constraints.maxWidth > 800
            ? (constraints.maxWidth - 48) / 3
            : constraints.maxWidth;

        final cards = [
          _buildSummaryCard(
            title: 'Water Reserves',
            value: '${(currentVolume / 1000).toStringAsFixed(1)}k / ${(totalCapacity / 1000).toStringAsFixed(0)}k L',
            subtitle: '$totalTanks Overhead Reservoirs',
            icon: Icons.storage_rounded,
            iconColor: Colors.cyan,
            progress: totalCapacity > 0 ? currentVolume / totalCapacity : 0.0,
          ),
          _buildSummaryCard(
            title: 'Active Borewells',
            value: '$activePumpsCount / $totalPumps',
            subtitle: '$activePumpsCount pumps running live',
            icon: Icons.offline_bolt_rounded,
            iconColor: Colors.purple,
            progress: totalPumps > 0 ? activePumpsCount / totalPumps : 0.0,
          ),
          _buildSummaryCard(
            title: 'System Telemetry',
            value: 'Optimal',
            subtitle: 'Last update: Just now',
            icon: Icons.sensors_rounded,
            iconColor: AppTheme.accent,
            progress: 1.0,
          ),
        ];

        if (constraints.maxWidth > 800) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
          );
        } else {
          return Column(
            children: cards.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: c,
            )).toList(),
          );
        }
      },
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required double progress,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppTheme.stroke,
              valueColor: AlwaysStoppedAnimation<Color>(iconColor),
            ),
          ),
        ],
      ),
    );
  }

  double getCapacity(Map<String, dynamic> tank) => (tank['capacity_liters'] as num? ?? 0.0).toDouble();
  double getLevel(Map<String, dynamic> tank) => (tank['current_level_pct'] as num? ?? 0.0).toDouble();

  String _formatNumber(double val) {
    final int rounded = val.round();
    final String str = rounded.toString();
    final RegExp reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  Widget _buildStatusBadge(bool isActive, String statusText) {
    final statusColor = isActive ? AppTheme.accent : AppTheme.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PulsingStatusDot(color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: statusColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTankCard(Map<String, dynamic> tank) {
    final bool isTank = tank['type'] == 'overhead_tank';
    if (isTank) {
      return _buildWaterTankCard(tank);
    } else {
      return _buildPumpCard(tank);
    }
  }

  Widget _buildWaterTankCard(Map<String, dynamic> tank) {
    final double level = getLevel(tank);
    final double capacity = getCapacity(tank);
    final double currentVolume = capacity * (level / 100.0);
    final bool isActive = tank['status'] == 'active';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              color: Colors.cyan.shade400,
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.cyan.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.opacity_rounded,
                          color: Colors.cyan.shade600,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tank['name'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Overhead Reservoir',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(isActive, tank['status'] as String),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _WaterTankVisual(levelPct: level),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_formatNumber(currentVolume)} L',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: level > 25 ? Colors.cyan.shade700 : AppTheme.error,
                              ),
                            ),
                            Text(
                              'Current Volume (${level.round()}%)',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.dns_rounded, size: 13, color: AppTheme.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Capacity:',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_formatNumber(capacity)} L',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.bgSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.settings_input_component_rounded, size: 13, color: AppTheme.textMuted),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Valve Tag:',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                  const Spacer(),
                                  Text(
                                    'V-AN-01',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPumpCard(Map<String, dynamic> tank) {
    final String pumpStatus = tank['pump_status'] ?? 'off';
    final bool isPumpOn = pumpStatus == 'on';
    final bool isActive = tank['status'] == 'active';
    final activeColor = Colors.purple.shade400;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 4,
              color: activeColor,
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.offline_bolt_rounded,
                          color: activeColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tank['name'] as String,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Groundwater Pump Station',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _buildStatusBadge(isActive, tank['status'] as String),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _PumpVisual(isAnimating: isPumpOn),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPumpOn ? '15.4 L/s' : '0.0 L/s',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: isPumpOn ? AppTheme.accent : AppTheme.textMuted,
                              ),
                            ),
                            Text(
                              'Discharge Flow Rate',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgSurface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPumpOn ? '4.5 kW' : '0.0 kW',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Power Draw',
                                          style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                                    decoration: BoxDecoration(
                                      color: AppTheme.bgSurface,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          isPumpOn ? '8.2 A' : '0.0 A',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          'Current',
                                          style: TextStyle(fontSize: 9, color: AppTheme.textMuted),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isPumpOn
                          ? Colors.purple.withValues(alpha: 0.05)
                          : AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPumpOn
                            ? Colors.purple.withValues(alpha: 0.1)
                            : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.power_settings_new_rounded,
                              size: 16,
                              color: isPumpOn ? Colors.purpleAccent : AppTheme.textMuted,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'PUMP MOTOR CONTROL',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isPumpOn ? Colors.purple.shade700 : AppTheme.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                        _buildSwitchOrLoader(tank, isPumpOn),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildSwitchOrLoader(Map<String, dynamic> tank, bool isPumpOn) {
    final tankId = tank['id'] as int;
    final bool isToggling = _togglingPumps[tankId] == true;

    if (isToggling) {
      return const SizedBox(
        width: 48,
        height: 32,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.purpleAccent),
            ),
          ),
        ),
      );
    }

    return Switch(
      value: isPumpOn,
      onChanged: (val) => _togglePump(tank, val),
      activeThumbColor: Colors.purpleAccent,
      activeTrackColor: Colors.purple.withValues(alpha: 0.38),
      inactiveThumbColor: AppTheme.textMuted,
      inactiveTrackColor: AppTheme.stroke,
    );
  }
}

class _RotatingPumpIcon extends StatefulWidget {
  final bool isAnimating;
  const _RotatingPumpIcon({required this.isAnimating});

  @override
  State<_RotatingPumpIcon> createState() => _RotatingPumpIconState();
}

class _RotatingPumpIconState extends State<_RotatingPumpIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _RotatingPumpIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _controller.repeat();
      } else {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: (widget.isAnimating ? Colors.purple : AppTheme.textMuted).withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.toys_rounded,
          color: widget.isAnimating ? Colors.purpleAccent : AppTheme.textMuted,
          size: 28,
        ),
      ),
    );
  }
}



class _PulsingStatusDot extends StatefulWidget {
  final Color color;
  const _PulsingStatusDot({required this.color});

  @override
  State<_PulsingStatusDot> createState() => _PulsingStatusDotState();
}

class _PulsingStatusDotState extends State<_PulsingStatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.4 + 0.6 * _controller.value),
                blurRadius: 3.0 + 3.0 * _controller.value,
                spreadRadius: 0.5 + 1.0 * _controller.value,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WaterTankVisual extends StatefulWidget {
  final double levelPct; // 0 to 100
  const _WaterTankVisual({required this.levelPct});

  @override
  State<_WaterTankVisual> createState() => _WaterTankVisualState();
}

class _WaterTankVisualState extends State<_WaterTankVisual> with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(60, 96),
          painter: _LiquidTankPainter(
            progress: widget.levelPct / 100.0,
            wavePhase: _waveController.value * 2 * math.pi,
          ),
        );
      },
    );
  }
}

class _LiquidTankPainter extends CustomPainter {
  final double progress;
  final double wavePhase;

  _LiquidTankPainter({required this.progress, required this.wavePhase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final r = size.width / 8; // radius for top/bottom caps of cylinder
    
    // 1. Draw water liquid inside the cylinder container (if progress > 0)
    if (progress > 0) {
      final fillHeight = size.height * progress;
      final fillTop = size.height - fillHeight;
      final liquidPath = Path();
      
      // Start from bottom left corner
      liquidPath.moveTo(0, size.height - r);
      // Bottom curved cap
      liquidPath.quadraticBezierTo(0, size.height, r, size.height);
      liquidPath.lineTo(size.width - r, size.height);
      liquidPath.quadraticBezierTo(size.width, size.height, size.width, size.height - r);
      // Go up to the liquid surface level
      liquidPath.lineTo(size.width, fillTop);
      
      // Draw wave on top surface of water
      // Draw a sine wave from right (size.width) to left (0)
      final waveAmplitude = progress > 0.05 && progress < 0.95 ? 3.0 : 0.0;
      for (double x = size.width; x >= 0; x -= 2) {
        final double y = fillTop + waveAmplitude * math.sin((x / size.width) * 2 * math.pi + wavePhase);
        liquidPath.lineTo(x, y);
      }
      liquidPath.close();

      // Liquid gradient
      final rect = Rect.fromLTWH(0, fillTop - 5, size.width, fillHeight + 5);
      paint.shader = LinearGradient(
        colors: progress > 0.25 
            ? [Colors.cyan.shade600, Colors.cyanAccent.shade700]
            : [AppTheme.error.withValues(alpha: 0.8), AppTheme.error],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect);
      
      canvas.drawPath(liquidPath, paint);
    }
    
    // 2. Draw outer cylinder container frame (glass container)
    final glassPaint = Paint()
      ..color = AppTheme.strokeStrong
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
      
    final containerPath = Path();
    containerPath.moveTo(0, r);
    // Top curved cap outline
    containerPath.quadraticBezierTo(0, 0, r, 0);
    containerPath.lineTo(size.width - r, 0);
    containerPath.quadraticBezierTo(size.width, 0, size.width, r);
    // Right side wall
    containerPath.lineTo(size.width, size.height - r);
    // Bottom curved cap outline
    containerPath.quadraticBezierTo(size.width, size.height, size.width - r, size.height);
    containerPath.lineTo(r, size.height);
    containerPath.quadraticBezierTo(0, size.height, 0, size.height - r);
    containerPath.close();
    
    canvas.drawPath(containerPath, glassPaint);

    // 3. Draw tick marks on the container side
    final tickPaint = Paint()
      ..color = AppTheme.textMuted.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    
    final ticks = [0.25, 0.5, 0.75];
    for (final tick in ticks) {
      final y = size.height * (1.0 - tick);
      canvas.drawLine(Offset(0, y), Offset(6, y), tickPaint);
      canvas.drawLine(Offset(size.width - 6, y), Offset(size.width, y), tickPaint);
    }

    // 4. Draw a glossy reflection highlight overlay
    final glossPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        colors: [Colors.white.withValues(alpha: 0.18), Colors.white.withValues(alpha: 0.0)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    
    final glossPath = Path();
    glossPath.moveTo(0, r);
    glossPath.quadraticBezierTo(0, 0, r, 0);
    glossPath.lineTo(size.width * 0.25, 0);
    glossPath.lineTo(size.width * 0.25, size.height);
    glossPath.lineTo(r, size.height);
    glossPath.quadraticBezierTo(0, size.height, 0, size.height - r);
    glossPath.close();
    
    canvas.drawPath(glossPath, glossPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidTankPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.wavePhase != wavePhase;
  }
}

class _PumpVisual extends StatefulWidget {
  final bool isAnimating;
  const _PumpVisual({required this.isAnimating});

  @override
  State<_PumpVisual> createState() => _PumpVisualState();
}

class _PumpVisualState extends State<_PumpVisual> with TickerProviderStateMixin {
  late final AnimationController _rotationController;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    if (widget.isAnimating) {
      _rotationController.repeat();
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant _PumpVisual oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating != oldWidget.isAnimating) {
      if (widget.isAnimating) {
        _rotationController.repeat();
        _pulseController.repeat(reverse: true);
      } else {
        _rotationController.stop();
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = Colors.purple.shade400;
    final inactiveColor = AppTheme.textMuted;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final double pulse = widget.isAnimating ? 1.0 + 0.08 * _pulseController.value : 1.0;
        final double glowAlpha = widget.isAnimating ? 0.2 + 0.1 * _pulseController.value : 0.05;

        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer glowing ring
            Container(
              width: 80 * pulse,
              height: 80 * pulse,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: (widget.isAnimating ? activeColor : inactiveColor).withValues(alpha: 0.15),
                  width: 3.0,
                ),
                boxShadow: widget.isAnimating
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: glowAlpha),
                          blurRadius: 16.0,
                          spreadRadius: 2.0,
                        )
                      ]
                    : null,
              ),
            ),
            // Middle ring
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (widget.isAnimating ? activeColor : inactiveColor).withValues(alpha: 0.08),
                border: Border.all(
                  color: (widget.isAnimating ? activeColor : inactiveColor).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
            ),
            // Inner spinning fan
            RotationTransition(
              turns: _rotationController,
              child: Icon(
                Icons.autorenew_rounded,
                color: widget.isAnimating ? activeColor : inactiveColor,
                size: 32,
              ),
            ),
          ],
        );
      },
    );
  }
}
