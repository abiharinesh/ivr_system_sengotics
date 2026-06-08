import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../water_supply/data/water_sync_coordinator.dart';

class AgentPipelineTapCaptureScreen extends StatefulWidget {
  const AgentPipelineTapCaptureScreen({super.key});

  @override
  State<AgentPipelineTapCaptureScreen> createState() =>
      _AgentPipelineTapCaptureScreenState();
}

class _AgentPipelineTapCaptureScreenState
    extends State<AgentPipelineTapCaptureScreen> with SingleTickerProviderStateMixin {
  final _coordinator = WaterSyncCoordinator();
  late final AnimationController _pulseController;

  // Form State
  int _currentStep = 0;
  String _selectedType = 'household_tap'; // 'household_tap', 'public_tap', 'main_pipeline'
  String _selectedMaterial = 'PVC'; // 'PVC', 'HDPE', 'Cast Iron'
  final _diameterController = TextEditingController(text: '25');
  double _lat = 11.2356;
  double _lng = 77.1042;
  double _alt = 12.4;
  double _precision = 0.4;
  String? _capturedPhotoPath;
  bool _isCameraActive = false;
  bool _isCapturing = false;
  bool _isSyncing = false;

  // Map settings
  bool _showSatellite = true;
  double _zoomLevel = 15.0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _coordinator.addListener(_onStateChange);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _diameterController.dispose();
    _coordinator.removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) setState(() {});
  }

  void _resetForm() {
    setState(() {
      _currentStep = 0;
      _selectedType = 'household_tap';
      _selectedMaterial = 'PVC';
      _diameterController.text = '25';
      _capturedPhotoPath = null;
      _isCameraActive = false;
      // randomize coords slightly for next connection
      final r = math.Random();
      _lat = 11.2356 + (r.nextDouble() - 0.5) * 0.005;
      _lng = 77.1042 + (r.nextDouble() - 0.5) * 0.005;
      _alt = 12.0 + r.nextDouble() * 5.0;
      _precision = 0.3 + r.nextDouble() * 0.4;
    });
  }

  void _handleCaptureAsset() {
    if (_capturedPhotoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please capture a photo proof to proceed.'),
          backgroundColor: AppTheme.warning,
        ),
      );
      return;
    }

    final diameterVal = double.tryParse(_diameterController.text) ?? 25.0;

    _coordinator.captureAsset(
      type: _selectedType,
      material: _selectedMaterial,
      diameter: diameterVal,
      latitude: _lat,
      longitude: _lng,
      photoPath: _capturedPhotoPath,
      agentName: 'Ramanathan K.', // Logged in agent
      deviceModel: 'Samsung Galaxy Tab Active 3',
      altitude: _alt,
      precision: double.parse(_precision.toStringAsFixed(2)),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Asset captured successfully and added to offline queue!'),
        backgroundColor: Colors.green,
      ),
    );

    _resetForm();
  }

  Future<void> _handleSync() async {
    if (_coordinator.pendingSyncCount == 0) return;

    setState(() => _isSyncing = true);
    await _coordinator.syncAssets();

    if (mounted) {
      setState(() => _isSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully synced captured assets to Panchayat server!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 700;

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (isCompact) {
            return _buildMobileLayout();
          } else {
            return _buildTabletLayout();
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        // GIS Map (top third)
        Expanded(
          flex: 4,
          child: _buildMapPanel(),
        ),
        // Step Form & Sync list (bottom two thirds)
        Expanded(
          flex: 6,
          child: Container(
            color: AppTheme.bgDark,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildFormCard(),
                  const SizedBox(height: 16),
                  _buildSyncStatusCard(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left Column: Stepper Form & Sync Queue
        Expanded(
          flex: 5,
          child: Container(
            color: AppTheme.bgDark,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  _buildFormCard(),
                  const SizedBox(height: 24),
                  _buildSyncStatusCard(),
                ],
              ),
            ),
          ),
        ),
        // Right Column: Full-height GIS Satellite Map Panel
        Expanded(
          flex: 5,
          child: _buildMapPanel(),
        ),
      ],
    );
  }

  Widget _buildMapPanel() {
    return Stack(
      children: [
        // Simulated Satellite View
        Container(
          color: const Color(0xFF070F1E),
          child: CustomPaint(
            painter: _SatelliteMapPainter(
              pulseAnimation: _pulseController,
              showSatellite: _showSatellite,
              lat: _lat,
              lng: _lng,
              zoomLevel: _zoomLevel,
            ),
            child: Container(),
          ),
        ),

        // Gradient overlay for visual depth
        Positioned.fill(
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),

        // Floating GPS Accuracy Panel
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24, width: 0.5),
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _precision <= 0.5 ? AppTheme.accent : AppTheme.warning,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_precision <= 0.5 ? AppTheme.accent : AppTheme.warning)
                                .withValues(alpha: 0.6),
                            blurRadius: 4 + _pulseController.value * 6,
                            spreadRadius: _pulseController.value * 4,
                          )
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GPS Accuracy: ±${_precision.toStringAsFixed(1)}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Lat: ${_lat.toStringAsFixed(6)}°, Lng: ${_lng.toStringAsFixed(6)}°',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: const Text(
                    'HIGH PRECISION',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Floating Map Controls (Right Side)
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMapControlBtn(
                icon: Icons.layers,
                tooltip: 'Toggle Map Mode',
                onPressed: () {
                  setState(() => _showSatellite = !_showSatellite);
                },
                active: _showSatellite,
              ),
              const SizedBox(height: 8),
              _buildMapControlBtn(
                icon: Icons.add,
                tooltip: 'Zoom In',
                onPressed: () {
                  setState(() {
                    if (_zoomLevel < 18) _zoomLevel += 0.5;
                  });
                },
              ),
              const SizedBox(height: 4),
              _buildMapControlBtn(
                icon: Icons.remove,
                tooltip: 'Zoom Out',
                onPressed: () {
                  setState(() {
                    if (_zoomLevel > 12) _zoomLevel -= 0.5;
                  });
                },
              ),
              const SizedBox(height: 8),
              _buildMapControlBtn(
                icon: Icons.my_location,
                tooltip: 'Recenter GPS',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('GPS lock refreshed. Coordinates updated.'),
                      duration: Duration(milliseconds: 800),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMapControlBtn({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    bool active = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: active
            ? AppTheme.primary
            : const Color(0xFF0F172A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        elevation: 4,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Icon(
              icon,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard() {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.water_drop, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pipeline & Tap Capture',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      'Ooraatchi GIS Grid Registration',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildStepProgress(),
          const Divider(height: 32),
          AnimatedSize(
            duration: AppTheme.durationNormal,
            curve: Curves.easeInOut,
            child: _buildCurrentStepContent(),
          ),
          const SizedBox(height: 24),
          _buildFormActions(),
        ],
      ),
    );
  }

  Widget _buildStepProgress() {
    final steps = ['Asset Type', 'Specs', 'Location', 'Evidence'];
    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final isCompleted = (index ~/ 2) < _currentStep;
          return Expanded(
            child: Container(
              height: 2,
              color: isCompleted ? AppTheme.primary : AppTheme.stroke,
            ),
          );
        }

        final stepIdx = index ~/ 2;
        final isCurrent = stepIdx == _currentStep;
        final isCompleted = stepIdx < _currentStep;

        return Tooltip(
          message: steps[stepIdx],
          child: AnimatedContainer(
            duration: AppTheme.durationFast,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCurrent
                  ? AppTheme.primary
                  : (isCompleted ? AppTheme.primary.withValues(alpha: 0.15) : Colors.transparent),
              border: Border.all(
                color: isCurrent || isCompleted ? AppTheme.primary : AppTheme.strokeStrong,
                width: 2,
              ),
            ),
            child: Center(
              child: isCompleted
                  ? Icon(Icons.check, size: 16, color: AppTheme.primary)
                  : Text(
                      '${stepIdx + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? Colors.white : AppTheme.textSecondary,
                      ),
                    ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1TypeSelection();
      case 1:
        return _buildStep2Specs();
      case 2:
        return _buildStep3Location();
      case 3:
        return _buildStep4Evidence();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1TypeSelection() {
    final types = [
      {
        'id': 'household_tap',
        'title': 'Household Tap',
        'desc': 'Single service connection for residential unit.',
        'icon': Icons.home_outlined
      },
      {
        'id': 'public_tap',
        'title': 'Public/Community Tap',
        'desc': 'Shared water tap serving community points.',
        'icon': Icons.opacity_rounded
      },
      {
        'id': 'main_pipeline',
        'title': 'Main Pipeline Segment',
        'desc': 'High-diameter grid distribution pipeline.',
        'icon': Icons.grid_on_rounded
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Connection/Asset Type',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        ...types.map((type) {
          final isSelected = _selectedType == type['id'];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Material(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.05)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedType = type['id'] as String;
                    // Auto setup diameter defaults
                    if (_selectedType == 'household_tap') {
                      _diameterController.text = '25';
                    } else if (_selectedType == 'public_tap') {
                      _diameterController.text = '50';
                    } else {
                      _diameterController.text = '110';
                    }
                  });
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.stroke,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primary.withValues(alpha: 0.1)
                              : AppTheme.bgSurface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          type['icon'] as IconData,
                          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              type['title'] as String,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              type['desc'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Icon(Icons.check_circle, color: AppTheme.primary, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStep2Specs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Technical Specifications',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _selectedMaterial,
          decoration: const InputDecoration(
            labelText: 'Pipe Material',
            prefixIcon: Icon(Icons.category_outlined, size: 20),
          ),
          items: const [
            DropdownMenuItem(value: 'PVC', child: Text('PVC (Polyvinyl Chloride)')),
            DropdownMenuItem(value: 'HDPE', child: Text('HDPE (High Density Polyethylene)')),
            DropdownMenuItem(value: 'Cast Iron', child: Text('Cast Iron (Metallic)')),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedMaterial = val);
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _diameterController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Pipe Diameter (mm)',
            prefixIcon: Icon(Icons.settings_input_hdmi, size: 20),
            suffixText: 'mm',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.stroke),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.textMuted, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Standard connections usually range between 20mm to 160mm depending on grid hierarchy.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Location() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Location Lock & Coordinates',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.stroke),
          ),
          child: Column(
            children: [
              _buildLocationDetailRow('Latitude', '${_lat.toStringAsFixed(6)}°'),
              const Divider(height: 20),
              _buildLocationDetailRow('Longitude', '${_lng.toStringAsFixed(6)}°'),
              const Divider(height: 20),
              _buildLocationDetailRow('Altitude', '${_alt.toStringAsFixed(1)} m (MSL)'),
              const Divider(height: 20),
              _buildLocationDetailRow(
                'Horizontal Precision',
                '±${_precision.toStringAsFixed(2)} m',
                highlight: _precision <= 0.5,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              final r = math.Random();
              _precision = 0.3 + r.nextDouble() * 0.2;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Refreshed GPS precision coordinates.')),
            );
          },
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.gps_fixed, size: 18),
          label: const Text('Refresh GPS Position'),
        ),
      ],
    );
  }

  Widget _buildLocationDetailRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight ? AppTheme.accent : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStep4Evidence() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Capture Verification Proof',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        if (!_isCameraActive && _capturedPhotoPath == null) ...[
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.camera_alt_outlined, size: 36, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _isCameraActive = true),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Launch Camera'),
                  ),
                ],
              ),
            ),
          )
        ] else if (_isCameraActive) ...[
          // Simulated camera viewport
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primary, width: 2),
            ),
            child: Stack(
              children: [
                // Simulated camera background
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.8,
                    child: Image.network(
                      'https://images.unsplash.com/photo-1542060748-10c28b629f6f?w=600&auto=format&fit=crop&q=60',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Scanner reticle
                Center(
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                // Camera status overlays
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'REC',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Text(
                    'EXIF: GEO-TAGGED',
                    style: TextStyle(
                      color: Colors.greenAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      backgroundColor: Colors.black.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                // Trigger button
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton.filled(
                          onPressed: () => setState(() => _isCameraActive = false),
                          icon: const Icon(Icons.close),
                          style: IconButton.styleFrom(backgroundColor: Colors.red),
                        ),
                        const SizedBox(width: 20),
                        GestureDetector(
                          onTap: () async {
                            setState(() => _isCapturing = true);
                            await Future.delayed(const Duration(milliseconds: 700));
                            setState(() {
                              _capturedPhotoPath =
                                  'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600&auto=format&fit=crop&q=60';
                              _isCameraActive = false;
                              _isCapturing = false;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: _isCapturing
                                  ? const Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          )
        ] else ...[
          // Show captured image preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _capturedPhotoPath!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'IMAGE_PROOF_TAGGED.JPG',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Size: 1.4 MB\nEXIF: ${_lat.toStringAsFixed(4)}°, ${_lng.toStringAsFixed(4)}°',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _capturedPhotoPath = null),
                  child: const Text('Retake'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFormActions() {
    final isLastStep = _currentStep == 3;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 0)
          OutlinedButton(
            onPressed: () => setState(() => _currentStep--),
            child: const Text('Back'),
          )
        else
          const SizedBox.shrink(),
        ElevatedButton(
          onPressed: () {
            if (isLastStep) {
              _handleCaptureAsset();
            } else {
              setState(() => _currentStep++);
            }
          },
          child: Text(isLastStep ? 'Capture Asset' : 'Continue'),
        ),
      ],
    );
  }

  Widget _buildSyncStatusCard() {
    final count = _coordinator.pendingSyncCount;
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (count > 0 ? AppTheme.warning : AppTheme.accent).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              count > 0 ? Icons.sync_problem : Icons.sync,
              color: count > 0 ? AppTheme.warning : AppTheme.accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 0 ? '$count Items Pending Sync' : 'All Connection Data Synced',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  count > 0
                      ? 'Stored locally. Sync to push to admin workspace.'
                      : 'Server connection up to date.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (count > 0)
            ElevatedButton(
              onPressed: _isSyncing ? null : _handleSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accent,
                foregroundColor: Colors.white,
              ),
              child: _isSyncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Sync Now'),
            ),
        ],
      ),
    );
  }
}

class _SatelliteMapPainter extends CustomPainter {
  final double lat;
  final double lng;
  final double zoomLevel;
  final bool showSatellite;
  final Animation<double> pulseAnimation;

  _SatelliteMapPainter({
    required this.lat,
    required this.lng,
    required this.zoomLevel,
    required this.showSatellite,
    required this.pulseAnimation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    if (showSatellite) {
      // Draw simulated satellite dark grid/trench lines
      final bgPaint = Paint()..color = const Color(0xFF0F1B2F);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.04)
        ..strokeWidth = 1.0;

      const spacing = 40.0;
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // Draw simulated green forest bounds
      final forestPaint = Paint()
        ..color = Colors.green.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(size.width * 0.2, size.height * 0.3), 120, forestPaint);
      canvas.drawCircle(Offset(size.width * 0.8, size.height * 0.7), 180, forestPaint);
    } else {
      // Draw generic map vector layout (light slate grey)
      final bgPaint = Paint()..color = const Color(0xFFE2E8F0);
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // Draw grid roads
      final roadPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 24.0;
      canvas.drawLine(Offset(0, size.height * 0.4), Offset(size.width, size.height * 0.5), roadPaint);
      canvas.drawLine(Offset(size.width * 0.3, 0), Offset(size.width * 0.4, size.height), roadPaint);
    }

    // Draw existing pipeline GIS vectors (high-fidelity blue line strings)
    final pipePaint = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.65)
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pipePath = Path()
      ..moveTo(size.width * 0.1, size.height * 0.2)
      ..lineTo(size.width * 0.4, size.height * 0.45)
      ..lineTo(center.dx, center.dy) // connects to target current coords
      ..lineTo(size.width * 0.9, size.height * 0.85);
    canvas.drawPath(pipePath, pipePaint);

    // Draw active taps (blue circles along pipe)
    final tapPaint = Paint()
      ..color = const Color(0xFF1D4ED8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.25, size.height * 0.32), 6, tapPaint);
    canvas.drawCircle(Offset(size.width * 0.7, size.height * 0.68), 6, tapPaint);

    // Pulsing precision circle around current GPS coordinate
    final pulseValue = pulseAnimation.value;
    final radarPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.2 * (1 - pulseValue))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 40 * pulseValue, radarPaint);

    // Current location blue/green GPS dot
    final dotPaint = Paint()
      ..color = const Color(0xFF10B981)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, dotPaint);

    final innerDotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, innerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _SatelliteMapPainter oldDelegate) {
    return oldDelegate.lat != lat ||
        oldDelegate.lng != lng ||
        oldDelegate.showSatellite != showSatellite ||
        oldDelegate.zoomLevel != zoomLevel ||
        oldDelegate.pulseAnimation != pulseAnimation;
  }
}
