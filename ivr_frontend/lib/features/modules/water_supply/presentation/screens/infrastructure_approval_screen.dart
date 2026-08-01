import 'package:flutter/material.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/features/modules/water_supply/data/water_sync_coordinator.dart';

class InfrastructureApprovalScreen extends StatefulWidget {
  const InfrastructureApprovalScreen({super.key});

  @override
  State<InfrastructureApprovalScreen> createState() =>
      _InfrastructureApprovalScreenState();
}

class _InfrastructureApprovalScreenState
    extends State<InfrastructureApprovalScreen> {
  final _coordinator = WaterSyncCoordinator();
  CapturedAsset? _selectedAsset;
  final _commentController = TextEditingController();
  String _activeTab = 'pending'; // 'pending', 'history'
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _coordinator.addListener(_onStateChange);
    _selectFirstPending();
  }

  @override
  void dispose() {
    _coordinator.removeListener(_onStateChange);
    _commentController.dispose();
    super.dispose();
  }

  void _onStateChange() {
    if (mounted) {
      setState(() {
        // If selected asset is updated, refresh selection
        if (_selectedAsset != null) {
          final updated = _coordinator.assets.firstWhere(
            (a) => a.id == _selectedAsset!.id,
            orElse: () => _selectedAsset!,
          );
          _selectedAsset = updated;
        } else {
          _selectFirstPending();
        }
      });
    }
  }

  void _selectFirstPending() {
    final pending = _coordinator.pendingApproval;
    if (pending.isNotEmpty) {
      _selectedAsset = pending.first;
      _commentController.text = _selectedAsset?.comment ?? '';
    } else {
      final all = _coordinator.assets;
      if (all.isNotEmpty) {
        _selectedAsset = all.first;
        _commentController.text = _selectedAsset?.comment ?? '';
      } else {
        _selectedAsset = null;
      }
    }
  }

  Future<void> _handleApprove() async {
    if (_selectedAsset == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    try {
      await _coordinator.approveAsset(_selectedAsset!.id, _commentController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Asset #${_selectedAsset!.id} approved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleReject() async {
    if (_selectedAsset == null || _isProcessing) return;
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a rejection comment explaining the reason.'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    setState(() => _isProcessing = true);
    try {
      await _coordinator.rejectAsset(_selectedAsset!.id, _commentController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Asset #${_selectedAsset!.id} has been rejected.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 900;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _buildMetricsRow(isMobile),
              const SizedBox(height: 20),
              Expanded(
                child: isMobile ? _buildMobileView() : _buildDesktopView(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Infrastructure Approval Workspace',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            Text(
              'Verify EXIF and GIS data submitted by field agents',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _isProcessing
              ? null
              : () async {
                  setState(() => _isProcessing = true);
                  await _coordinator.loadFromBackend();
                  if (mounted) {
                    setState(() => _isProcessing = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Refreshed data from server.')),
                    );
                  }
                },
        ),
      ],
    );
  }

  Widget _buildMetricsRow(bool isMobile) {
    final double spacing = isMobile ? 8 : 16;
    final double cardWidth = (MediaQuery.sizeOf(context).width - 32 - (spacing * 3)) / 4;

    final metrics = [
      {
        'title': 'Pending Approvals',
        'value': '${_coordinator.pendingApprovalCount}',
        'color': AppTheme.warning,
        'icon': Icons.hourglass_empty_rounded,
      },
      {
        'title': 'Approved Assets',
        'value': '${_coordinator.approvedCount}',
        'color': AppTheme.accent,
        'icon': Icons.check_circle_outline_rounded,
      },
      {
        'title': 'Rejected Assets',
        'value': '${_coordinator.rejectedCount}',
        'color': AppTheme.error,
        'icon': Icons.cancel_outlined,
      },
      {
        'title': 'Database Sync',
        'value': _coordinator.pendingSyncCount > 0 ? 'Pending' : 'Healthy',
        'color': _coordinator.pendingSyncCount > 0 ? AppTheme.warning : AppTheme.accent,
        'icon': Icons.cloud_done_outlined,
      },
    ];

    if (isMobile) {
      return SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: metrics.length,
          separatorBuilder: (_, __) => SizedBox(width: spacing),
          itemBuilder: (context, i) {
            return Container(
              width: cardWidth.clamp(140.0, 220.0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.stroke),
              ),
              child: Row(
                children: [
                  Icon(
                    metrics[i]['icon'] as IconData,
                    color: metrics[i]['color'] as Color,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          metrics[i]['title'] as String,
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          metrics[i]['value'] as String,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    return Row(
      children: metrics.map((m) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (m['color'] as Color).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    m['icon'] as IconData,
                    color: m['color'] as Color,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m['title'] as String,
                        style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                      ),
                      Text(
                        m['value'] as String,
                        style: TextStyle(
                          fontSize: 18,
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
        );
      }).toList(),
    );
  }

  Widget _buildMobileView() {
    return Column(
      children: [
        _buildTabs(),
        const SizedBox(height: 8),
        Expanded(
          child: _selectedAsset == null
              ? _buildRosterList()
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back),
                            onPressed: () => setState(() => _selectedAsset = null),
                          ),
                          Text(
                            'Back to list',
                            style: TextStyle(color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      _buildDetailsWorkspace(),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDesktopView() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left master list
        Expanded(
          flex: 4,
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.stroke),
            ),
            child: Column(
              children: [
                _buildTabs(),
                Expanded(child: _buildRosterList()),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right details workspace
        Expanded(
          flex: 6,
          child: _selectedAsset == null
              ? Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.checklist, size: 48, color: AppTheme.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Select a ticket to review verification proofs',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.stroke),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: _buildDetailsWorkspace(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.stroke)),
      ),
      child: Row(
        children: [
          _buildTabBtn('pending', 'Pending Review'),
          const SizedBox(width: 8),
          _buildTabBtn('history', 'Archive / History'),
        ],
      ),
    );
  }

  Widget _buildTabBtn(String tab, String label) {
    final isActive = _activeTab == tab;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _activeTab = tab;
            _selectFirstForActiveTab();
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: AppTheme.durationFast,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isActive ? AppTheme.primary : AppTheme.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _selectFirstForActiveTab() {
    final list = _activeTab == 'pending'
        ? _coordinator.pendingApproval
        : [..._coordinator.approved, ..._coordinator.rejected];
    if (list.isNotEmpty) {
      _selectedAsset = list.first;
      _commentController.text = _selectedAsset?.comment ?? '';
    } else {
      _selectedAsset = null;
    }
  }

  Widget _buildRosterList() {
    final list = _activeTab == 'pending'
        ? _coordinator.pendingApproval
        : [..._coordinator.approved, ..._coordinator.rejected];

    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: AppTheme.textMuted),
            const SizedBox(height: 8),
            Text(
              'No items in this filter queue',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, idx) {
        final asset = list[idx];
        final isSelected = _selectedAsset?.id == asset.id;

        IconData icon;
        String typeLabel;
        if (asset.type == 'household_tap') {
          icon = Icons.home_outlined;
          typeLabel = 'Household Tap';
        } else if (asset.type == 'public_tap') {
          icon = Icons.opacity;
          typeLabel = 'Public Tap';
        } else {
          icon = Icons.grid_on_rounded;
          typeLabel = 'Pipeline Line';
        }

        return Container(
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.bgSurface : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.stroke,
            ),
          ),
          child: ListTile(
            onTap: () {
              setState(() {
                _selectedAsset = asset;
                _commentController.text = asset.comment ?? '';
              });
            },
            leading: CircleAvatar(
              backgroundColor: isSelected
                  ? AppTheme.primary
                  : AppTheme.bgSurface,
              foregroundColor: isSelected ? Colors.white : AppTheme.textSecondary,
              child: Icon(icon, size: 18),
            ),
            title: Text(
              typeLabel,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            subtitle: Text(
              'By: ${asset.agentName} • ${asset.material} ${asset.diameter.toInt()}mm',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
            trailing: _buildStatusBadge(asset.status),
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String label;
    if (status == 'pending_approval') {
      color = AppTheme.warning;
      label = 'PENDING';
    } else if (status == 'approved') {
      color = AppTheme.accent;
      label = 'APPROVED';
    } else {
      color = AppTheme.error;
      label = 'REJECTED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildDetailsWorkspace() {
    if (_selectedAsset == null) return const SizedBox.shrink();

    final asset = _selectedAsset!;
    String typeLabel = asset.type == 'household_tap'
        ? 'Household Tap'
        : (asset.type == 'public_tap' ? 'Public/Community Tap' : 'Main Pipeline Segment');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TICKET #${asset.id}',
                  style: TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            _buildStatusBadge(asset.status),
          ],
        ),
        const SizedBox(height: 16),

        // GIS Preview Panel
        Text(
          'GIS LOCATION PREVIEW',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1B2F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.stroke),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              children: [
                // Simulated Vector GIS grid
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GISMapPainter(
                      assetLat: asset.latitude,
                      assetLng: asset.longitude,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'GIS Ward: Ward 3 Boundaries • Scale 1:200',
                      style: TextStyle(color: Colors.white, fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // EXIF & Proof side-by-side
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXIF METADATA MATCH',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.stroke),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildExifMetaItem('Device', asset.deviceModel ?? 'Rugged Field Tab'),
                        _buildExifMetaItem('Altitude', '${asset.altitude?.toStringAsFixed(1)} m'),
                        _buildExifMetaItem('Accuracy', '±${asset.precision?.toStringAsFixed(1)} m'),
                        _buildExifMetaItem(
                          'Timestamp',
                          '${asset.submittedAt.hour}:${asset.submittedAt.minute.toString().padLeft(2, '0')}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VERIFICATION PHOTO',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.stroke),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        asset.photoPath ?? 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600&auto=format&fit=crop&q=60',
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image, color: Colors.grey),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Action console
        const Divider(height: 24),
        Text(
          'ADMINISTRATIVE REVIEW CONSOLE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.textMuted,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _commentController,
          enabled: asset.status == 'pending_approval' && !_isProcessing,
          maxLines: 2,
          decoration: const InputDecoration(
            hintText: 'Enter approval or rejection comments (e.g. verified grid dimensions, coordinates matched, etc.)',
          ),
        ),
        const SizedBox(height: 16),
        if (asset.status == 'pending_approval')
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _handleReject,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.error),
                    foregroundColor: AppTheme.error,
                  ),
                  child: const Text('Reject Connection'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _handleApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Approve Infrastructure'),
                ),
              ),
            ],
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (asset.status == 'approved' ? AppTheme.accent : AppTheme.error)
                  .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (asset.status == 'approved' ? AppTheme.accent : AppTheme.error)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  asset.status == 'approved' ? Icons.check_circle : Icons.cancel,
                  color: asset.status == 'approved' ? AppTheme.accent : AppTheme.error,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.status == 'approved' ? 'Approved' : 'Rejected',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: asset.status == 'approved' ? AppTheme.accent : AppTheme.error,
                        ),
                      ),
                      Text(
                        asset.comment != null && asset.comment!.isNotEmpty
                            ? 'Comment: ${asset.comment}'
                            : 'No comments left.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildExifMetaItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          Text(
            val,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GISMapPainter extends CustomPainter {
  final double assetLat;
  final double assetLng;

  _GISMapPainter({required this.assetLat, required this.assetLng});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Draw background
    final bgPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 30) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }

    // Draw Ward boundary polygon
    final polyPaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = Colors.blue.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final boundary = Path()
      ..moveTo(size.width * 0.1, size.height * 0.1)
      ..lineTo(size.width * 0.9, size.height * 0.2)
      ..lineTo(size.width * 0.8, size.height * 0.8)
      ..lineTo(size.width * 0.2, size.height * 0.9)
      ..close();
    canvas.drawPath(boundary, polyPaint);
    canvas.drawPath(boundary, strokePaint);

    // Draw water main pipeline grid lines
    final pipePaint = Paint()
      ..color = Colors.cyanAccent.withValues(alpha: 0.5)
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final pipe = Path()
      ..moveTo(size.width * 0.3, size.height * 0.2)
      ..lineTo(center.dx, center.dy)
      ..lineTo(size.width * 0.7, size.height * 0.7);
    canvas.drawPath(pipe, pipePaint);

    // Draw Target asset GPS Coordinate pin
    final pinPaint = Paint()
      ..color = AppTheme.warning
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 8, pinPaint);

    final innerPinPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 3, innerPinPaint);

    // Text labels for coordinates
    final tp = TextPainter(
      text: TextSpan(
        text: 'Asset GPS: ${assetLat.toStringAsFixed(5)}, ${assetLng.toStringAsFixed(5)}',
        style: const TextStyle(color: Colors.yellowAccent, fontSize: 8, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - (tp.width / 2), center.dy - 22));
  }

  @override
  bool shouldRepaint(covariant _GISMapPainter oldDelegate) {
    return oldDelegate.assetLat != assetLat || oldDelegate.assetLng != assetLng;
  }
}
