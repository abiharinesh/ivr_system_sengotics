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

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final bool isMobile = width < 700;

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

        return isMobile
            ? Column(
                children: skeletonList.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 20.0),
                  child: SizedBox(height: 180, child: s),
                )).toList(),
              )
            : GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.35,
                children: skeletonList,
              );
      }

      return isMobile
          ? Column(
              children: _tanks.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: _buildTankCard(t),
                  )).toList(),
            )
          : GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.35,
              ),
              itemCount: _tanks.length,
              itemBuilder: (context, index) => _buildTankCard(_tanks[index]),
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

              // Tanks & Pumps Grid
              buildGridContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTankCard(Map<String, dynamic> tank) {
    final bool isTank = tank['type'] == 'overhead_tank';
    final double level = tank['current_level_pct'] as double;
    final String pumpStatus = tank['pump_status'] ?? 'off';
    final bool isPumpOn = pumpStatus == 'on';

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isTank ? Colors.cyan : Colors.purple).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isTank ? Icons.opacity_rounded : Icons.offline_bolt_rounded,
                  color: isTank ? Colors.cyan : Colors.purple,
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
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isTank ? 'Overhead Reservoir' : 'Groundwater Pump Station',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (tank['status'] == 'active' ? AppTheme.accent : AppTheme.error).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${tank['status']}'.toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: tank['status'] == 'active' ? AppTheme.accent : AppTheme.error,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Expanded(
            child: Row(
              children: [
                // Visual Indicator
                if (isTank) ...[
                  SizedBox(
                    width: 72,
                    height: 72,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: level / 100,
                          strokeWidth: 8,
                          backgroundColor: AppTheme.stroke,
                          color: level > 25 ? Colors.cyan : AppTheme.error,
                        ),
                        Text(
                          '${level.round()}%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _infoLine('Capacity:', '${(tank['capacity_liters'] as double).round().toString()} L'),
                        _infoLine('Current level:', '${((tank['capacity_liters'] as double) * (level / 100)).round().toString()} L'),
                        _infoLine('Valve tag:', 'V-AN-01'),
                      ],
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isPumpOn ? Icons.play_circle_fill_rounded : Icons.stop_circle_rounded,
                          size: 40,
                          color: isPumpOn ? AppTheme.accent : AppTheme.textMuted,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isPumpOn ? 'PUMP MOTOR RUNNING' : 'PUMP MOTOR STOPPED',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isPumpOn ? AppTheme.accent : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 1,
                    color: AppTheme.stroke,
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Motor Control',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Switch(
                        value: isPumpOn,
                        onChanged: (val) {
                          setState(() {
                            tank['pump_status'] = val ? 'on' : 'off';
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                val ? 'Borewell pump motor started successfully.' : 'Borewell pump motor shut down.',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                        activeThumbColor: AppTheme.primary,
                      ),
                    ],
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoLine(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color ?? AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }
}
