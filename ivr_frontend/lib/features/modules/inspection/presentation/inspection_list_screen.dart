import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../config/app_theme.dart';
import '../../../../core/api/api_client.dart';

/// Phase 7: Field Inspection List screen
class InspectionListScreen extends StatefulWidget {
  const InspectionListScreen({super.key});

  @override
  State<InspectionListScreen> createState() => _InspectionListScreenState();
}

class _InspectionListScreenState extends State<InspectionListScreen> {
  List<dynamic> _inspections = [];
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
      final res = await ApiClient.instance.get('/api/inspections');
      final list = res is List ? List<dynamic>.from(res) : (res is Map && res['data'] is List ? List<dynamic>.from(res['data']) : []);
      setState(() { _inspections = list; });
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
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NewInspectionScreen()),
        ).then((_) => _load()),
        icon: const Icon(Icons.add_task_outlined),
        label: const Text('New Inspection'),
        backgroundColor: AppTheme.primary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                  ],
                ))
              : _inspections.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.checklist_rtl_outlined, size: 64, color: AppTheme.textMuted),
                          const SizedBox(height: 16),
                          Text('No inspections yet.', style: TextStyle(color: AppTheme.textMuted, fontSize: 15)),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _inspections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) => _InspectionCard(inspection: _inspections[i] as Map<String, dynamic>),
                      ),
                    ),
    );
  }
}

class _InspectionCard extends StatelessWidget {
  final Map<String, dynamic> inspection;
  const _InspectionCard({required this.inspection});

  @override
  Widget build(BuildContext context) {
    final gpsLocked = inspection['gps_locked'] == true;
    final score = inspection['overall_score'];
    final status = inspection['status']?.toString() ?? 'pending';
    final createdAt = inspection['created_at'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(inspection['created_at'].toString()).toLocal())
        : '—';

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
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.checklist_rtl_outlined, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inspection #${inspection['id']}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary)),
                    Text(createdAt, style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                  ],
                ),
              ),
              if (score != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Score: $score', style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                gpsLocked ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                size: 14,
                color: gpsLocked ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 4),
              Text(
                gpsLocked ? 'GPS Locked' : 'GPS Not Locked',
                style: TextStyle(fontSize: 12, color: gpsLocked ? Colors.green : Colors.orange),
              ),
              const Spacer(),
              _StatusBadge(status: status),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'pending': Colors.orange,
      'in_progress': AppTheme.primary,
      'completed': Colors.green,
      'failed': Colors.red,
    };
    final c = colors[status] ?? AppTheme.textMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
    );
  }
}

/// Phase 7: New Inspection Screen with GPS capture
class NewInspectionScreen extends StatefulWidget {
  const NewInspectionScreen({super.key});

  @override
  State<NewInspectionScreen> createState() => _NewInspectionScreenState();
}

class _NewInspectionScreenState extends State<NewInspectionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksCtrl = TextEditingController();
  double? _lat, _lng;
  int? _selectedTemplateId;
  List<dynamic> _templates = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final res = await ApiClient.instance.get('/api/inspection-templates');
      final list = res is List ? List<dynamic>.from(res) : (res is Map && res['data'] is List ? List<dynamic>.from(res['data']) : []);
      setState(() { _templates = list; });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        backgroundColor: AppTheme.bgCard,
        title: Text('New Field Inspection', style: TextStyle(color: AppTheme.textPrimary)),
        iconTheme: IconThemeData(color: AppTheme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Template', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              DropdownButtonFormField<int>(
                dropdownColor: AppTheme.bgCard,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.stroke)),
                ),
                hint: Text('Select template', style: TextStyle(color: AppTheme.textMuted)),
                initialValue: _selectedTemplateId,
                items: _templates.map((t) => DropdownMenuItem<int>(
                  value: t['id'] as int,
                  child: Text(t['name']?.toString() ?? 'Template', style: TextStyle(color: AppTheme.textPrimary)),
                )).toList(),
                onChanged: (v) => setState(() => _selectedTemplateId = v),
                validator: (v) => v == null ? 'Please select a template' : null,
              ),
              const SizedBox(height: 20),
              Text('GPS Location', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.bgSurface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.stroke),
                ),
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      _lat != null ? Icons.gps_fixed_rounded : Icons.gps_not_fixed_rounded,
                      color: _lat != null ? Colors.green : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _lat != null ? 'Lat: ${_lat!.toStringAsFixed(5)}  Lng: ${_lng!.toStringAsFixed(5)}' : 'Not captured',
                        style: TextStyle(color: _lat != null ? AppTheme.textPrimary : AppTheme.textMuted, fontSize: 13),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _captureGps,
                      icon: const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('Capture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text('Remarks', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _remarksCtrl,
                maxLines: 3,
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Optional notes...',
                  hintStyle: TextStyle(color: AppTheme.textMuted),
                  filled: true,
                  fillColor: AppTheme.bgSurface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppTheme.stroke)),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submit,
                  icon: _isSubmitting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined),
                  label: Text(_isSubmitting ? 'Submitting...' : 'Submit Inspection'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _captureGps() {
    // Mock GPS capture — in production, use geolocator package
    setState(() {
      _lat = 11.0171;
      _lng = 76.9561;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('GPS coordinates captured!')),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please capture GPS location first.')),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    try {
      await ApiClient.instance.post('/api/inspections', data: {
        'templateId': _selectedTemplateId,
        'locationLat': _lat,
        'locationLng': _lng,
        'remarks': _remarksCtrl.text.trim(),
        'checklistResults': {},
        'overallScore': 100,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inspection submitted successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
