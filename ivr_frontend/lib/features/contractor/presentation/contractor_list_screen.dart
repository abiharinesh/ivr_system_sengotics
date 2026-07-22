import 'package:flutter/material.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/api/api_client.dart';

/// Phase 6: Contractor & Work Order list screen
class ContractorListScreen extends StatefulWidget {
  const ContractorListScreen({super.key});

  @override
  State<ContractorListScreen> createState() => _ContractorListScreenState();
}

class _ContractorListScreenState extends State<ContractorListScreen> {
  List<dynamic> _contractors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiClient.instance.get('/api/contractors');
      final list = res is List ? List<dynamic>.from(res) : (res is Map && res['data'] is List ? List<dynamic>.from(res['data']) : []);
      setState(() { _contractors = list; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Contractor'),
        backgroundColor: AppTheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _contractors.isEmpty
                  ? _buildEmpty()
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _contractors.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, i) => _ContractorCard(
                          contractor: _contractors[i] as Map<String, dynamic>,
                          onWorkOrders: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => WorkOrderListScreen(
                                contractorId: _contractors[i]['id'] as int,
                                contractorName: _contractors[i]['name']?.toString() ?? 'Contractor',
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
    );
  }

  Widget _buildError() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, size: 48, color: Colors.red),
        const SizedBox(height: 12),
        Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.engineering_outlined, size: 64, color: AppTheme.textMuted),
        const SizedBox(height: 16),
        Text('No contractors registered yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
        const SizedBox(height: 8),
        Text('Tap the + button to add one.', style: TextStyle(color: AppTheme.textMuted, fontSize: 13)),
      ],
    ),
  );

  void _showCreateDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('New Contractor', style: TextStyle(color: AppTheme.textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(labelText: 'Company Name', labelStyle: TextStyle(color: AppTheme.textMuted)),
              style: TextStyle(color: AppTheme.textPrimary),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: InputDecoration(labelText: 'Phone (E.164)', labelStyle: TextStyle(color: AppTheme.textMuted)),
              style: TextStyle(color: AppTheme.textPrimary),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ApiClient.instance.post('/api/contractors', data: {
                  'name': nameCtrl.text.trim(),
                  'phone': phoneCtrl.text.trim(),
                });
                _load();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }
}

class _ContractorCard extends StatelessWidget {
  final Map<String, dynamic> contractor;
  final VoidCallback onWorkOrders;

  const _ContractorCard({required this.contractor, required this.onWorkOrders});

  @override
  Widget build(BuildContext context) {
    final rating = (contractor['average_rating'] as num?)?.toStringAsFixed(1) ?? '—';
    final status = contractor['status']?.toString() ?? 'active';
    final statusColor = status == 'active' ? AppTheme.accent : AppTheme.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.engineering_outlined, color: AppTheme.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(contractor['name']?.toString() ?? '—',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                    Text(contractor['phone']?.toString() ?? '—',
                        style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(status.toUpperCase(),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.star_rounded, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(rating, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(width: 4),
              Text('rating', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const Spacer(),
              TextButton.icon(
                onPressed: onWorkOrders,
                icon: Icon(Icons.receipt_long_outlined, size: 16, color: AppTheme.primary),
                label: Text('Work Orders', style: TextStyle(color: AppTheme.primary, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Phase 6: Work Orders screen for a specific contractor
class WorkOrderListScreen extends StatefulWidget {
  final int contractorId;
  final String contractorName;

  const WorkOrderListScreen({super.key, required this.contractorId, required this.contractorName});

  @override
  State<WorkOrderListScreen> createState() => _WorkOrderListScreenState();
}

class _WorkOrderListScreenState extends State<WorkOrderListScreen> {
  List<dynamic> _workOrders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final res = await ApiClient.instance.get('/api/work-orders', queryParams: {'contractorId': widget.contractorId});
      final list = res is List ? List<dynamic>.from(res) : (res is Map && res['data'] is List ? List<dynamic>.from(res['data']) : []);
      setState(() { _workOrders = list; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    } finally {
      setState(() { _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: Text('Work Orders — ${widget.contractorName}',
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
              : _workOrders.isEmpty
                  ? Center(
                      child: Text('No work orders found.',
                          style: TextStyle(color: AppTheme.textMuted, fontSize: 15)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _workOrders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _WorkOrderTile(wo: _workOrders[i] as Map<String, dynamic>),
                      ),
                    ),
    );
  }
}

class _WorkOrderTile extends StatelessWidget {
  final Map<String, dynamic> wo;
  const _WorkOrderTile({required this.wo});

  @override
  Widget build(BuildContext context) {
    final status = wo['status']?.toString() ?? 'draft';
    final colors = {
      'draft': Colors.grey,
      'active': AppTheme.accent,
      'completed': Colors.green,
      'cancelled': Colors.red,
    };
    final statusColor = colors[status] ?? AppTheme.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.stroke),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(wo['work_order_number']?.toString() ?? '—',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Text('Total: ₹${wo['total_amount'] ?? 0}',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(status.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
          ),
        ],
      ),
    );
  }
}
