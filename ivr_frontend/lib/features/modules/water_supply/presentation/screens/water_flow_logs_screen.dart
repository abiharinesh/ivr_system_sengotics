import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/widgets/app_shimmer.dart';
import 'package:ivr_frontend/features/modules/water_supply/data/water_repository.dart';
import 'package:ivr_frontend/core/storage/secure_storage.dart';

class WaterFlowLogsScreen extends StatefulWidget {
  const WaterFlowLogsScreen({super.key});

  @override
  State<WaterFlowLogsScreen> createState() => _WaterFlowLogsScreenState();
}

class _WaterFlowLogsScreenState extends State<WaterFlowLogsScreen> {
  final WaterRepository _repository = WaterRepository();
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];
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
    final cached = _repository.getCachedFlowLogs(_panchayatId);
    if (cached != null) {
      _logs = cached;
      _isLoading = false;
      if (mounted) setState(() {});
    } else {
      setState(() => _isLoading = true);
    }
    try {
      final logs = await _repository.getFlowLogs(_panchayatId, forceRefresh: cached == null);
      if (mounted) {
        setState(() {
          _logs = logs;
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
    final bool isMobile = width < 600;

    // Calculate metrics
    final double avgFlow = _logs.isEmpty ? 0 : _logs.map((l) => l['flow_rate_lps'] as double).reduce((a, b) => a + b) / _logs.length;
    final double avgPressure = _logs.isEmpty ? 0 : _logs.map((l) => l['pressure_bar'] as double).reduce((a, b) => a + b) / _logs.length;
    final int lowPressureAlerts = _logs.where((l) => (l['pressure_bar'] as double) < 2.0).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Water Supply Flow Logs'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top KPI Row
              isMobile
                  ? Column(
                      children: [
                        _buildKpiCard('Average Flow Rate', '${avgFlow.toStringAsFixed(1)} LPS', Icons.speed_rounded, Colors.cyan, isLoading: _isLoading),
                        const SizedBox(height: 16),
                        _buildKpiCard('Average Pressure', '${avgPressure.toStringAsFixed(2)} bar', Icons.av_timer_rounded, Colors.purple, isLoading: _isLoading),
                        const SizedBox(height: 16),
                        _buildKpiCard('Low Pressure Warnings', '$lowPressureAlerts logs', Icons.warning_amber_rounded, AppTheme.warning, isLoading: _isLoading),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: _buildKpiCard('Average Flow Rate', '${avgFlow.toStringAsFixed(1)} LPS', Icons.speed_rounded, Colors.cyan, isLoading: _isLoading)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildKpiCard('Average Pressure', '${avgPressure.toStringAsFixed(2)} bar', Icons.av_timer_rounded, Colors.purple, isLoading: _isLoading)),
                        const SizedBox(width: 16),
                        Expanded(child: _buildKpiCard('Low Pressure Warnings', '$lowPressureAlerts alerts', Icons.warning_amber_rounded, AppTheme.warning, isLoading: _isLoading)),
                      ],
                    ),
              const SizedBox(height: 32),

              // Ledger Title
              Text(
                'Historical Telemetry Ledger',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Raw pipeline feed logging pressure sensors and flow rate indicators',
                style: TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Table
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.stroke),
                  boxShadow: AppTheme.softShadow,
                ),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: double.infinity,
                  child: DataTable(
                    columnSpacing: isMobile ? 12 : 24,
                    columns: const [
                      DataColumn(label: Text('Timestamp')),
                      DataColumn(label: Text('Flow Rate (LPS)')),
                      DataColumn(label: Text('Pressure (bar)')),
                      DataColumn(label: Text('Telemetry State')),
                    ],
                    rows: _isLoading
                        ? List.generate(5, (index) => const DataRow(
                            cells: [
                              DataCell(AppShimmer.rectangular(width: 50, height: 12)),
                              DataCell(AppShimmer.rectangular(width: 60, height: 12)),
                              DataCell(AppShimmer.rectangular(width: 60, height: 12)),
                              DataCell(AppShimmer.rectangular(width: 70, height: 12)),
                            ],
                          ))
                        : _logs.map((log) {
                            final timeStr = DateTime.parse(log['logged_at'] as String).toLocal().toString().substring(11, 16);
                            final double press = log['pressure_bar'] as double;
                            final isLow = press < 2.0;

                            return DataRow(
                              cells: [
                                DataCell(Text(timeStr)),
                                DataCell(Text('${log['flow_rate_lps']} LPS')),
                                DataCell(Text('${log['pressure_bar']} bar')),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isLow ? AppTheme.error : AppTheme.accent).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      isLow ? 'CRITICAL DROP' : 'STABLE',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        color: isLow ? AppTheme.error : AppTheme.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKpiCard(String title, String val, IconData icon, Color color, {bool isLoading = false}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                isLoading
                    ? const AppShimmer.rectangular(width: 80, height: 18)
                    : Text(
                        val,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
