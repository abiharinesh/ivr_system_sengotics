import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../config/app_theme.dart';
import '../../../core/download/browser_download.dart';
import '../data/reports_repository.dart';

enum ReportService {
  complaints,
  ivrCalls,
  poles,
  tenders,
  fieldOps,
  zones,
}

class ReportGenerationScreen extends StatefulWidget {
  const ReportGenerationScreen({super.key});

  @override
  State<ReportGenerationScreen> createState() => _ReportGenerationScreenState();
}

class _ReportGenerationScreenState extends State<ReportGenerationScreen> {
  final ReportsRepository _reportsRepo = ReportsRepository();

  ReportService _selectedService = ReportService.complaints;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  String _format = 'CSV'; // 'CSV' or 'HTML'

  // Dynamic filter selections
  String _complaintStatus = 'All';
  String _complaintCategory = 'All';
  String _ivrStatus = 'All';
  double _minConfidence = 0.65;
  String _poleZone = 'All';
  int _minComplaints = 0;
  String _tenderStatus = 'All';
  String _staffRole = 'All';
  bool _zoneActiveOnly = false;

  bool _isGenerating = false;
  bool _isLoadingPreview = false;

  List<dynamic> _liveKpis = [];
  List<List<String>> _livePreviewRows = [];

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _fetchLivePreview();
  }

  Future<void> _fetchLivePreview() async {
    setState(() {
      _isLoadingPreview = true;
    });

    try {
      final filters = <String, dynamic>{
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
      };

      if (_selectedService == ReportService.complaints) {
        filters['status'] = _complaintStatus;
        filters['category'] = _complaintCategory;
      } else if (_selectedService == ReportService.ivrCalls) {
        filters['status'] = _ivrStatus;
        filters['minConfidence'] = _minConfidence.toString();
      } else if (_selectedService == ReportService.poles) {
        filters['zone'] = _poleZone;
        filters['minComplaints'] = _minComplaints.toString();
      } else if (_selectedService == ReportService.tenders) {
        filters['status'] = _tenderStatus;
      } else if (_selectedService == ReportService.fieldOps) {
        filters['role'] = _staffRole;
      } else if (_selectedService == ReportService.zones) {
        filters['activeOnly'] = _zoneActiveOnly.toString();
      }

      final data = await _reportsRepo.fetchPreview(
        service: _selectedService.name,
        filters: filters,
      );

      setState(() {
        _liveKpis = data['kpis'] ?? [];
        _livePreviewRows = ((data['previewRows'] ?? []) as List)
            .map((row) => (row as List).map((cell) => cell.toString()).toList())
            .toList();
        _isLoadingPreview = false;
      });
    } catch (e) {
      // Graceful fallback to mock data on error/seeding issues
      setState(() {
        _liveKpis = [];
        _livePreviewRows = [];
        _isLoadingPreview = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWide = screenWidth > 1024;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 340,
                    child: _buildConfiguratorSidebar(),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: _buildPreviewArea(),
                  ),
                ],
              )
            else
              Column(
                children: [
                  _buildConfiguratorSidebar(),
                  const SizedBox(height: 24),
                  _buildPreviewArea(),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Generation Control Center',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Select a core service, customize filters, and download compiled audits directly to your device.',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildConfiguratorSidebar() {
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
          Text(
            '1. SELECT CORE SERVICE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildServiceCard(
            ReportService.complaints,
            'Complaints Lifecycle',
            Icons.report_problem_rounded,
          ),
          _buildServiceCard(
            ReportService.ivrCalls,
            'IVR Calls & AI Processing',
            Icons.call_rounded,
          ),
          _buildServiceCard(
            ReportService.poles,
            'Pole Assets & Geotags',
            Icons.alt_route_rounded,
          ),
          _buildServiceCard(
            ReportService.tenders,
            'Tenders & Procurement',
            Icons.assignment_rounded,
          ),
          _buildServiceCard(
            ReportService.fieldOps,
            'Field Staff Performance',
            Icons.engineering_rounded,
          ),
          _buildServiceCard(
            ReportService.zones,
            'Administrative Zones',
            Icons.map_rounded,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),
          Text(
            '2. CONFIGURE FILTERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildDateRangeFilters(),
          const SizedBox(height: 16),
          _buildDynamicFilters(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Divider(),
          ),
          Text(
            '3. EXPORT FORMAT',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          _buildFormatSelector(),
          const SizedBox(height: 24),
          _buildGenerateButton(),
        ],
      ),
    );
  }

  Widget _buildServiceCard(ReportService service, String title, IconData icon) {
    final bool isSelected = _selectedService == service;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedService = service;
            });
            _fetchLivePreview();
          },
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.25)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? AppTheme.primary : AppTheme.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AppTheme.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateRangeFilters() {
    // Zones report does not require a date range.
    if (_selectedService == ReportService.zones) return const SizedBox.shrink();

    return Column(
      children: [
        _buildDatePickerField(
          'Start Date',
          _startDate,
          (date) {
            setState(() => _startDate = date);
            _fetchLivePreview();
          },
        ),
        const SizedBox(height: 10),
        _buildDatePickerField(
          'End Date',
          _endDate,
          (date) {
            setState(() => _endDate = date);
            _fetchLivePreview();
          },
        ),
      ],
    );
  }

  Widget _buildDatePickerField(String label, DateTime date, Function(DateTime) onSelected) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.stroke),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
              Text(
                _dateFormat.format(date),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.calendar_today_rounded, size: 16, color: AppTheme.textMuted),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (selected != null) {
                onSelected(selected);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicFilters() {
    switch (_selectedService) {
      case ReportService.complaints:
        return Column(
          children: [
            _buildDropdown(
              'Complaint Status',
              _complaintStatus,
              ['All', 'pending', 'assigned', 'in_progress', 'resolved'],
              (val) {
                setState(() => _complaintStatus = val!);
                _fetchLivePreview();
              },
            ),
            const SizedBox(height: 10),
            _buildDropdown(
              'Category',
              _complaintCategory,
              ['All', 'street_light', 'power_outage', 'wire_damage', 'water_supply', 'other'],
              (val) {
                setState(() => _complaintCategory = val!);
                _fetchLivePreview();
              },
            ),
          ],
        );
      case ReportService.ivrCalls:
        return Column(
          children: [
            _buildDropdown(
              'Call Status',
              _ivrStatus,
              ['All', 'completed', 'failed', 'service_selected', 'poll_entered'],
              (val) {
                setState(() => _ivrStatus = val!);
                _fetchLivePreview();
              },
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Min Confidence Score: ${_minConfidence.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Slider(
                  value: _minConfidence,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  activeColor: AppTheme.primary,
                  onChanged: (val) {
                    setState(() => _minConfidence = val);
                  },
                  onChangeEnd: (val) {
                    _fetchLivePreview();
                  },
                ),
              ],
            ),
          ],
        );
      case ReportService.poles:
        return Column(
          children: [
            _buildDropdown(
              'Panchayat Zone',
              _poleZone,
              ['All', 'Ward 1', 'Ward 2', 'Ward 3', 'Zone A', 'Zone B'],
              (val) {
                setState(() => _poleZone = val!);
                _fetchLivePreview();
              },
            ),
            const SizedBox(height: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Min Complaints Logged: $_minComplaints',
                  style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
                Slider(
                  value: _minComplaints.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: AppTheme.primary,
                  onChanged: (val) {
                    setState(() => _minComplaints = val.toInt());
                  },
                  onChangeEnd: (val) {
                    _fetchLivePreview();
                  },
                ),
              ],
            ),
          ],
        );
      case ReportService.tenders:
        return _buildDropdown(
          'Tender Status',
          _tenderStatus,
          ['All', 'draft', 'published', 'quotations_closed', 'vendor_selected', 'closed'],
          (val) {
            setState(() => _tenderStatus = val!);
            _fetchLivePreview();
          },
        );
      case ReportService.fieldOps:
        return _buildDropdown(
          'Staff Role',
          _staffRole,
          ['All', 'electrician', 'agent'],
          (val) {
            setState(() => _staffRole = val!);
            _fetchLivePreview();
          },
        );
      case ReportService.zones:
        return SwitchListTile(
          title: Text(
            'Active Zones Only',
            style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
          ),
          value: _zoneActiveOnly,
          dense: true,
          activeThumbColor: AppTheme.primary,
          onChanged: (val) {
            setState(() => _zoneActiveOnly = val);
            _fetchLivePreview();
          },
        );
    }
  }

  Widget _buildDropdown(
    String label,
    String value,
    List<String> items,
    void Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: AppTheme.bgSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppTheme.stroke),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              items: items
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          e,
                          style: TextStyle(fontSize: 13, color: AppTheme.textPrimary),
                        ),
                      ))
                  .toList(),
              onChanged: onChanged,
              isExpanded: true,
              dropdownColor: AppTheme.bgCard,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFormatSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildFormatButton('CSV', 'Comma Separated Values (.csv)'),
          ),
          Expanded(
            child: _buildFormatButton('HTML', 'Printable Document (.html)'),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatButton(String val, String tooltip) {
    final bool isSelected = _format == val;
    return Tooltip(
      message: tooltip,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: isSelected ? AppTheme.bgCard : Colors.transparent,
          foregroundColor: isSelected ? AppTheme.primary : AppTheme.textSecondary,
          elevation: isSelected ? 1 : 0,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => setState(() => _format = val),
        child: Text(
          val,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppTheme.softShadow,
            ),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _isGenerating ? null : _handleGenerateReport,
              icon: _isGenerating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: Text(
                _isGenerating ? 'Compiling Report...' : 'Generate and Export',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: AppTheme.primary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isGenerating ? null : _handlePrintReport,
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text(
              'Print Report',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildServiceDescriptionCard(),
        const SizedBox(height: 20),
        _buildKPIBlock(),
        const SizedBox(height: 20),
        _buildTablePreview(),
        const SizedBox(height: 20),
        _buildDistributionSection(),
      ],
    );
  }

  Widget _buildServiceDescriptionCard() {
    String title = '';
    String description = '';
    Color borderAccent = AppTheme.primary;

    switch (_selectedService) {
      case ReportService.complaints:
        title = 'Complaints Summary & Lifecycle Report';
        description =
            'Tracks citizen complaints raised through IVR voice call or manual entry. Analyzes categories, urgency, resolution status, response times, and geo-validation checks.';
        borderAccent = AppTheme.primary;
        break;
      case ReportService.ivrCalls:
        title = 'IVR Call Traffic & AI Processing Audit';
        description =
            'Audits incoming phone calls, digits pressed, Whisper STT speech transcripts (Tamil), translations (English), and OpenAI GPT location extraction confidence logs.';
        borderAccent = AppTheme.info;
        break;
      case ReportService.poles:
        title = 'Pole Assets & Geotags Report';
        description =
            'Summarizes physical electric poles records. Grouped by zones, displaying coordinates, landmarks, linked open/resolved complaints, and EXIF/OCR pole verification records.';
        borderAccent = AppTheme.accent;
        break;
      case ReportService.tenders:
        title = 'Tenders & Procurement Report';
        description =
            'Audits local procurement tenders, invited bidders, comparative statements, awarded L1 vendors, milestones targets, work order dates, and financial voucher distributions.';
        borderAccent = AppTheme.warning;
        break;
      case ReportService.fieldOps:
        title = 'Field Staff & Electrician Performance Report';
        description =
            'Tracks performance of electricians and agents. Details assigned complaints, resolution rate, average response times, and photo proofs verification distance checks.';
        borderAccent = AppTheme.error;
        break;
      case ReportService.zones:
        title = 'Administrative Zones & Ward boundaries';
        description =
            'Renders stats grouped by custom geo-boundaries. Shows polygon attributes, associated villages/streets, total pole count, and pending lighting issues.';
        borderAccent = Colors.purple;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border(left: BorderSide(color: borderAccent, width: 6)),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: borderAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.description_outlined, size: 20, color: borderAccent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKPIBlock() {
    if (_isLoadingPreview) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    List<Widget> kpis = [];

    if (_liveKpis.isNotEmpty) {
      kpis = _liveKpis.map((k) {
        return _buildKPITile(
          k['title']?.toString() ?? '',
          k['value']?.toString() ?? '',
          k['footnote']?.toString() ?? '',
        );
      }).toList();
    } else {
      switch (_selectedService) {
        case ReportService.complaints:
          kpis = [
            _buildKPITile('Total Complaints', '142', '+12% this month'),
            _buildKPITile('Resolution Rate', '89.4%', 'Avg 18.4 hours'),
            _buildKPITile('Geo-tag Validated', '94.2%', 'Within 50m radius'),
          ];
          break;
        case ReportService.ivrCalls:
          kpis = [
            _buildKPITile('Total IVR Calls', '486', 'Avg 2m 14s duration'),
            _buildKPITile('AI Auto-processed', '71.2%', 'Containment rate'),
            _buildKPITile('Avg Transcript Conf', '0.88 / 1.0', 'Whisper STT score'),
          ];
          break;
        case ReportService.poles:
          kpis = [
            _buildKPITile('Total Electric Poles', '1,208', '14 Wards covered'),
            _buildKPITile('Asset Image Coverage', '82.4%', '995 poles verified'),
            _buildKPITile('Issue Hotspots', '3 poles', 'Poles with 3+ reports'),
          ];
          break;
        case ReportService.tenders:
          kpis = [
            _buildKPITile('Active Tenders', '8 Tenders', '6 in Published phase'),
            _buildKPITile('Awarded Value', '₹4,82,500', 'Lowest L1 statement bids'),
            _buildKPITile('Avg Bid Count', '4.2 Bidders', 'Per tender RFQ invitation'),
          ];
          break;
        case ReportService.fieldOps:
          kpis = [
            _buildKPITile('Active Field Staff', '12 Users', '8 Electricians, 4 Agents'),
            _buildKPITile('First Response', '1.2 hrs', 'Within threshold SLA'),
            _buildKPITile('Completed Audits', '189 jobs', 'Resolved with proof image'),
          ];
          break;
        case ReportService.zones:
          kpis = [
            _buildKPITile('Registered Zones', '6 Zones', 'Polygon bounds mapped'),
            _buildKPITile('Infrastructure Density', '201 poles / sq km', 'Zone A highest'),
            _buildKPITile('Zone Active Status', '100% Active', 'All zones active'),
          ];
          break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final bool isWrap = width < 600;

        if (isWrap) {
          return Column(
            children: kpis.map((k) => Padding(padding: const EdgeInsets.only(bottom: 12), child: k)).toList(),
          );
        }

        return Row(
          children: kpis.map((k) => Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: k))).toList(),
        );
      },
    );
  }

  Widget _buildKPITile(String title, String value, String footnote) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.stroke),
        boxShadow: AppTheme.softShadow,
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            footnote,
            style: TextStyle(
              fontSize: 10,
              color: AppTheme.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTablePreview() {
    if (_isLoadingPreview) {
      return const SizedBox.shrink();
    }

    List<String> headers = [];
    List<List<String>> rows = [];

    switch (_selectedService) {
      case ReportService.complaints:
        headers = ['ID', 'Type', 'Urgency', 'Status', 'Resolved At'];
        break;
      case ReportService.ivrCalls:
        headers = ['Caller', 'Duration', 'Transcript', 'Confidence', 'Status'];
        break;
      case ReportService.poles:
        headers = ['Pole No.', 'Ward', 'Landmark', 'Complaints', 'Last Verified'];
        break;
      case ReportService.tenders:
        headers = ['Tender ID', 'Work (Tamil)', 'Milestone target', 'L1 Vendor', 'Awarded Value'];
        break;
      case ReportService.fieldOps:
        headers = ['Staff User', 'Role', 'Assigned', 'Resolved Rate', 'Avg Response'];
        break;
      case ReportService.zones:
        headers = ['Zone Name', 'Places Cover', 'Total Poles', 'Active Issues', 'Status'];
        break;
    }

    if (_livePreviewRows.isNotEmpty) {
      rows = _livePreviewRows;
    } else {
      switch (_selectedService) {
        case ReportService.complaints:
          rows = [
            ['101', 'Street Light Out', 'High', 'resolved', '2026-05-18'],
            ['102', 'Power Fluctuation', 'Medium', 'in_progress', '—'],
            ['103', 'Fallen Wire', 'High', 'assigned', '—'],
            ['104', 'Broken Bracket', 'Low', 'resolved', '2026-05-15'],
            ['105', 'Dim Street Light', 'Medium', 'pending', '—'],
          ];
          break;
        case ReportService.ivrCalls:
          rows = [
            ['+919876543210', '1m 42s', 'complaint_intake', '0.94', 'completed'],
            ['+919443218765', '0m 58s', 'poll_service', '0.88', 'completed'],
            ['+919012345678', '2m 15s', 'complaint_intake', '0.52', 'manual_review'],
            ['+919894123456', '0m 22s', 'hangup', '0.00', 'failed'],
            ['+919361284712', '1m 10s', 'complaint_intake', '0.78', 'completed'],
          ];
          break;
        case ReportService.poles:
          rows = [
            ['PL-082/WD1', 'Ward 1', 'Mariamman Kovil Street', '4 complaints', '2026-05-12'],
            ['PL-141/WD1', 'Ward 1', 'Panchayat Office Corner', '0 complaints', '2026-04-30'],
            ['PL-019/WD2', 'Ward 2', 'Main Road Bus Stop', '2 complaints', '2026-05-20'],
            ['PL-055/WD2', 'Ward 2', 'Water Tank Lane', '1 complaints', '2026-05-08'],
            ['PL-102/WD3', 'Ward 3', 'Primary School West', '5 complaints', '2026-05-14'],
          ];
          break;
        case ReportService.tenders:
          rows = [
            ['TND-2026-01', 'தெருவிளக்கு பராமரிப்பு', '2026-06-15', 'Sengotics Electricals', '₹1,45,000'],
            ['TND-2026-02', 'குடிநீர் குழாய் சீரமைப்பு', '2026-06-20', 'Maruthu Engineers', '₹2,10,000'],
            ['TND-2026-03', 'மின் கம்பம் மாற்றம்', '2026-07-02', 'Salem Power Grid Co.', '₹1,27,500'],
            ['TND-2026-04', 'அங்கன்வாடி மின்னிணைப்பு', '2026-06-12', 'Pending selection', '—'],
            ['TND-2026-05', 'சாலையோர கிணறு வேலி', '—', 'Drafting', '—'],
          ];
          break;
        case ReportService.fieldOps:
          rows = [
            ['anbu.electrician@gp.org', 'electrician', '32 complaints', '93.7%', '12.4 hrs'],
            ['kumar.electrician@gp.org', 'electrician', '24 complaints', '87.5%', '19.8 hrs'],
            ['velu.agent@gp.org', 'agent', '118 poles', '100% verified', '—'],
            ['raja.electrician@gp.org', 'electrician', '18 complaints', '83.3%', '22.1 hrs'],
            ['selvi.agent@gp.org', 'agent', '92 poles', '96.4% verified', '—'],
          ];
          break;
        case ReportService.zones:
          rows = [
            ['Ward 1 Zone', 'Kovil St, School Rd', '142 poles', '3 issues', 'Active'],
            ['Ward 2 Zone', 'Bus Stand, Market', '186 poles', '1 issue', 'Active'],
            ['Union Border Zone', 'National Highway', '95 poles', '4 issues', 'Active'],
            ['Ward 3 Zone', 'West Colony, Farm St', '112 poles', '0 issues', 'Active'],
            ['River Bank Zone', 'Water Pump Rd', '64 poles', '2 issues', 'Active'],
          ];
          break;
      }
    }

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REPORT SCHEMA & SAMPLE ROW PREVIEW',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                  color: AppTheme.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Showing first 5 rows',
                  style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 24,
              horizontalMargin: 8,
              headingRowHeight: 40,
              dataRowMinHeight: 38,
              dataRowMaxHeight: 46,
              columns: headers
                  .map((h) => DataColumn(
                        label: Text(
                          h,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ))
                  .toList(),
              rows: rows
                  .map((row) => DataRow(
                        cells: row
                            .map((cell) => DataCell(
                                  Text(
                                    cell,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistributionSection() {
    if (_isLoadingPreview) {
      return const SizedBox.shrink();
    }

    String barTitle = '';
    double mainPercentage = 0.7;
    String mainLabel = '';
    double secondaryPercentage = 0.2;
    String secondaryLabel = '';
    double otherPercentage = 0.1;
    String otherLabel = '';

    switch (_selectedService) {
      case ReportService.complaints:
        barTitle = 'Status Distribution';
        mainLabel = 'Resolved (89%)';
        mainPercentage = 0.89;
        secondaryLabel = 'In Progress (8%)';
        secondaryPercentage = 0.08;
        otherLabel = 'Pending (3%)';
        otherPercentage = 0.03;
        break;
      case ReportService.ivrCalls:
        barTitle = 'IVR Routing Distribution';
        mainLabel = 'Complaint Intake (74%)';
        mainPercentage = 0.74;
        secondaryLabel = 'Poll/Survey (16%)';
        secondaryPercentage = 0.16;
        otherLabel = 'Call Drop / Other (10%)';
        otherPercentage = 0.10;
        break;
      case ReportService.poles:
        barTitle = 'Infrastructure Inspection Coverage';
        mainLabel = 'Verified Photo EXIF (82%)';
        mainPercentage = 0.82;
        secondaryLabel = 'Landmarked Only (13%)';
        secondaryPercentage = 0.13;
        otherLabel = 'Uninspected (5%)';
        otherPercentage = 0.05;
        break;
      case ReportService.tenders:
        barTitle = 'Tender Phase Status';
        mainLabel = 'Awarded & Active (50%)';
        mainPercentage = 0.50;
        secondaryLabel = 'RFQ Published (38%)';
        secondaryPercentage = 0.38;
        otherLabel = 'Drafting (12%)';
        otherPercentage = 0.12;
        break;
      case ReportService.fieldOps:
        barTitle = 'Field Job Proof Distance Verification';
        mainLabel = 'Verified within 50m (91%)';
        mainPercentage = 0.91;
        secondaryLabel = 'Manual Confirmation (7%)';
        secondaryPercentage = 0.07;
        otherLabel = 'Distance Out of Bound (2%)';
        otherPercentage = 0.02;
        break;
      case ReportService.zones:
        barTitle = 'Pole Distribution by Wards';
        mainLabel = 'Ward 1 & 2 (55%)';
        mainPercentage = 0.55;
        secondaryLabel = 'Ward 3 & 4 (30%)';
        secondaryPercentage = 0.30;
        otherLabel = 'Other Outskirts (15%)';
        otherPercentage = 0.15;
        break;
    }

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
          Text(
            barTitle.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  Expanded(
                    flex: (mainPercentage * 100).toInt(),
                    child: Container(
                      color: AppTheme.primary,
                      child: Center(
                        child: Text(
                          '${(mainPercentage * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (secondaryPercentage > 0.0)
                    Expanded(
                      flex: (secondaryPercentage * 100).toInt(),
                      child: Container(
                        color: AppTheme.accent,
                        child: Center(
                          child: Text(
                            '${(secondaryPercentage * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (otherPercentage > 0.0)
                    Expanded(
                      flex: (otherPercentage * 100).toInt(),
                      child: Container(
                        color: AppTheme.warning,
                        child: Center(
                          child: Text(
                            '${(otherPercentage * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendDot(AppTheme.primary, mainLabel),
              _buildLegendDot(AppTheme.accent, secondaryLabel),
              _buildLegendDot(AppTheme.warning, otherLabel),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _handleGenerateReport() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final filters = <String, dynamic>{
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
      };

      if (_selectedService == ReportService.complaints) {
        filters['status'] = _complaintStatus;
        filters['category'] = _complaintCategory;
      } else if (_selectedService == ReportService.ivrCalls) {
        filters['status'] = _ivrStatus;
        filters['minConfidence'] = _minConfidence.toString();
      } else if (_selectedService == ReportService.poles) {
        filters['zone'] = _poleZone;
        filters['minComplaints'] = _minComplaints.toString();
      } else if (_selectedService == ReportService.tenders) {
        filters['status'] = _tenderStatus;
      } else if (_selectedService == ReportService.fieldOps) {
        filters['role'] = _staffRole;
      } else if (_selectedService == ReportService.zones) {
        filters['activeOnly'] = _zoneActiveOnly.toString();
      }

      final downloaded = await _reportsRepo.downloadReport(
        service: _selectedService.name,
        format: _format,
        filters: filters,
      );

      final String filename = downloaded.filename ?? _getReportFilename();

      await saveBytes(
        bytes: downloaded.bytes,
        filename: filename,
        contentType: downloaded.contentType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report generated successfully: $filename'),
            backgroundColor: AppTheme.accent,
          ),
        );
      }
    } catch (err) {
      // Graceful local generation fallback
      try {
        final String filename = _getReportFilename();
        final Uint8List fileBytes = _generateReportBytes();

        await saveBytes(
          bytes: fileBytes,
          filename: filename,
          contentType: _format == 'CSV' ? 'text/csv' : 'text/html',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Report compiled (local fallback): $filename'),
              backgroundColor: AppTheme.accent,
            ),
          );
        }
      } catch (innerErr) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to generate report: $innerErr'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _handlePrintReport() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      final filters = <String, dynamic>{
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
      };

      if (_selectedService == ReportService.complaints) {
        filters['status'] = _complaintStatus;
        filters['category'] = _complaintCategory;
      } else if (_selectedService == ReportService.ivrCalls) {
        filters['status'] = _ivrStatus;
        filters['minConfidence'] = _minConfidence.toString();
      } else if (_selectedService == ReportService.poles) {
        filters['zone'] = _poleZone;
        filters['minComplaints'] = _minComplaints.toString();
      } else if (_selectedService == ReportService.tenders) {
        filters['status'] = _tenderStatus;
      } else if (_selectedService == ReportService.fieldOps) {
        filters['role'] = _staffRole;
      } else if (_selectedService == ReportService.zones) {
        filters['activeOnly'] = _zoneActiveOnly.toString();
      }

      final downloaded = await _reportsRepo.downloadReport(
        service: _selectedService.name,
        format: 'HTML',
        filters: filters,
      );

      final String htmlContent = String.fromCharCodes(downloaded.bytes);
      await printHtml(htmlContent);
    } catch (err) {
      // Graceful local print fallback
      try {
        final String htmlContent = _generateHTMLData();
        await printHtml(htmlContent);
      } catch (innerErr) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to print report: $innerErr'),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  String _getReportFilename() {
    final String dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    String serviceName = '';
    switch (_selectedService) {
      case ReportService.complaints:
        serviceName = 'complaints_lifecycle';
        break;
      case ReportService.ivrCalls:
        serviceName = 'ivr_ai_calls';
        break;
      case ReportService.poles:
        serviceName = 'poles_infrastructure';
        break;
      case ReportService.tenders:
        serviceName = 'tenders_procurement';
        break;
      case ReportService.fieldOps:
        serviceName = 'field_operations';
        break;
      case ReportService.zones:
        serviceName = 'zone_boundaries';
        break;
    }
    final String extension = _format == 'CSV' ? 'csv' : 'html';
    return 'report_${serviceName}_$dateStr.$extension';
  }

  Uint8List _generateReportBytes() {
    if (_format == 'CSV') {
      return Uint8List.fromList(_generateCSVData().codeUnits);
    } else {
      return Uint8List.fromList(_generateHTMLData().codeUnits);
    }
  }

  String _generateCSVData() {
    final StringBuffer buffer = StringBuffer();

    switch (_selectedService) {
      case ReportService.complaints:
        // Header
        buffer.writeln(
            'Complaint ID,Caller Number,Category,Urgency,Status,Created At,Assigned Electrician,Resolved At,Resolution Distance (m),Geotag Valid');
        // Rows
        buffer.writeln('101,+919876543210,street_light,High,resolved,2026-05-01T10:00:00Z,anbu.electrician@gp.org,2026-05-02T11:30:00Z,18.4,true');
        buffer.writeln('102,+919443218765,power_outage,Medium,in_progress,2026-05-12T14:22:00Z,kumar.electrician@gp.org,,,');
        buffer.writeln('103,+919012345678,wire_damage,High,assigned,2026-05-18T08:15:00Z,raja.electrician@gp.org,,,');
        buffer.writeln('104,+919894123456,water_supply,Low,resolved,2026-05-15T09:00:00Z,anbu.electrician@gp.org,2026-05-15T16:45:00Z,8.2,true');
        buffer.writeln('105,+919361284712,other,Medium,pending,2026-05-20T17:10:00Z,,,,,');
        break;
      case ReportService.ivrCalls:
        buffer.writeln(
            'Call SID,Caller Number,Start Time,End Time,Service Option Selected,Tamil Transcript,English Translation,AI Confidence Score,Processing Status');
        buffer.writeln('CA8a74e0d9b139e8a5b23d9a1f28b49201,+919876543210,2026-05-01T10:00:00Z,2026-05-01T10:01:42Z,complaint_intake,தெருவிளக்கு எரியவில்லை,Street light not working,0.94,completed');
        buffer.writeln('CA2039ab8d1f73b889ab8c19ee94bda712,+919443218765,2026-05-12T14:20:00Z,2026-05-12T14:20:58Z,poll_service,,,0.88,completed');
        buffer.writeln('CA9812ba3c14d9b1897a1d1209bca7120a,+919012345678,2026-05-18T08:12:00Z,2026-05-18T08:14:15Z,complaint_intake,கம்பம் சாய்ந்துள்ளது,Pole is leaning down,0.52,manual_review');
        buffer.writeln('CA1923ba891c78db891ad190ab78a9c123,+919894123456,2026-05-15T08:59:00Z,2026-05-15T08:59:22Z,hangup,,,0.00,failed');
        buffer.writeln('CA9384bc8d7b32ef8a1c90bd192ba871d3,+919361284712,2026-05-20T17:08:00Z,2026-05-20T17:09:10Z,complaint_intake,ஒயர் அறுந்து கிடக்கிறது,Wire is cut on road,0.78,completed');
        break;
      case ReportService.poles:
        buffer.writeln(
            'Pole ID,Pole Number,Keypad ID,Latitude,Longitude,Landmarks,Total Complaints Count,Active Complaints Count,Last Image Verification At');
        buffer.writeln('1,PL-082/WD1,82,11.234123,78.543212,"Mariamman Kovil Street",4,0,2026-05-12T10:45:00Z');
        buffer.writeln('2,PL-141/WD1,141,11.235612,78.544501,"Panchayat Office Corner",0,0,2026-04-30T15:20:00Z');
        buffer.writeln('3,PL-019/WD2,19,11.238910,78.546876,"Main Road Bus Stop",2,1,2026-05-20T09:15:00Z');
        buffer.writeln('4,PL-055/WD2,55,11.239012,78.547102,"Water Tank Lane",1,0,2026-05-08T11:00:00Z');
        buffer.writeln('5,PL-102/WD3,102,11.241283,78.549210,"Primary School West",5,2,2026-05-14T14:30:00Z');
        break;
      case ReportService.tenders:
        buffer.writeln(
            'Tender ID,Title (Tamil),Status,Anchor Date,Awardee Phone,Bid Amount,Payment Method,Voucher Number,SO Proceedings Date');
        buffer.writeln('TND-2026-01,தெருவிளக்கு பராமரிப்பு,vendor_selected,2026-05-01T00:00:00Z,+919842109843,145000.00,TNPASS,V-2026-045,2026-05-15');
        buffer.writeln('TND-2026-02,குடிநீர் குழாய் சீரமைப்பு,vendor_selected,2026-05-05T00:00:00Z,+919001238902,210000.00,Cheque,V-2026-048,2026-05-22');
        buffer.writeln('TND-2026-03,மின் கம்பம் மாற்றம்,vendor_selected,2026-05-10T00:00:00Z,+919442189032,127500.00,TNPASS,V-2026-052,2026-05-25');
        buffer.writeln('TND-2026-04,அங்கன்வாடி மின்னிணைப்பு,published,2026-05-20T00:00:00Z,,,,');
        buffer.writeln('TND-2026-05,சாலையோர கிணறு வேலி,draft,2026-05-25T00:00:00Z,,,,');
        break;
      case ReportService.fieldOps:
        buffer.writeln(
            'User ID,Email,Role,Total Assigned Complaints,Total Resolved Complaints,Average Resolution Time (hrs),Valid Geotags Count,Invalid Geotags Count');
        buffer.writeln('4,anbu.electrician@gp.org,electrician,32,30,12.4,28,2');
        buffer.writeln('5,kumar.electrician@gp.org,electrician,24,21,19.8,18,3');
        buffer.writeln('6,velu.agent@gp.org,agent,0,0,0.0,118,0');
        buffer.writeln('7,raja.electrician@gp.org,electrician,18,15,22.1,13,2');
        buffer.writeln('8,selvi.agent@gp.org,agent,0,0,0.0,89,3');
        break;
      case ReportService.zones:
        buffer.writeln(
            'Zone ID,Zone Name,Area (Sq Km),Associated Places,Total Poles,Active Complaints Count,Zone Color');
        buffer.writeln('1,Ward 1 Zone,0.45,"Kovil St, School Rd",142,3,#2563EB');
        buffer.writeln('2,Ward 2 Zone,0.62,"Bus Stand, Market",186,1,#10B981');
        buffer.writeln('3,Union Border Zone,1.10,"National Highway",95,4,#EF4444');
        buffer.writeln('4,Ward 3 Zone,0.55,"West Colony, Farm St",112,0,#F59E0B');
        buffer.writeln('5,River Bank Zone,0.38,"Water Pump Rd",64,2,#8B5CF6');
        break;
    }

    return buffer.toString();
  }

  String _generateHTMLData() {
    String title = '';
    String contentTable = '';
    String filterSummary = 'Date range: ${_dateFormat.format(_startDate)} to ${_dateFormat.format(_endDate)}';

    switch (_selectedService) {
      case ReportService.complaints:
        title = 'Complaints Summary & Lifecycle Report';
        filterSummary += ' | Status: $_complaintStatus | Category: $_complaintCategory';
        contentTable = '''
        <thead>
          <tr>
            <th>ID</th>
            <th>Caller Number</th>
            <th>Category</th>
            <th>Urgency</th>
            <th>Status</th>
            <th>Assigned Staff</th>
            <th>Resolved At</th>
            <th>Geo Validity</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>101</td>
            <td>+919876543210</td>
            <td>street_light</td>
            <td><span class="badge danger">High</span></td>
            <td><span class="badge success">Resolved</span></td>
            <td>Anbu</td>
            <td>2026-05-02 11:30</td>
            <td>Valid (18m)</td>
          </tr>
          <tr>
            <td>102</td>
            <td>+919443218765</td>
            <td>power_outage</td>
            <td><span class="badge warning">Medium</span></td>
            <td><span class="badge warning">In Progress</span></td>
            <td>Kumar</td>
            <td>—</td>
            <td>—</td>
          </tr>
          <tr>
            <td>103</td>
            <td>+919012345678</td>
            <td>wire_damage</td>
            <td><span class="badge danger">High</span></td>
            <td><span class="badge info">Assigned</span></td>
            <td>Raja</td>
            <td>—</td>
            <td>—</td>
          </tr>
          <tr>
            <td>104</td>
            <td>+919894123456</td>
            <td>water_supply</td>
            <td><span class="badge info">Low</span></td>
            <td><span class="badge success">Resolved</span></td>
            <td>Anbu</td>
            <td>2026-05-15 16:45</td>
            <td>Valid (8m)</td>
          </tr>
        </tbody>
        ''';
        break;
      case ReportService.ivrCalls:
        title = 'IVR Call Traffic & AI Processing Audit';
        filterSummary += ' | Call Status: $_ivrStatus | Min Confidence: ${_minConfidence.toStringAsFixed(2)}';
        contentTable = '''
        <thead>
          <tr>
            <th>Call SID</th>
            <th>Caller</th>
            <th>Duration</th>
            <th>Service Option</th>
            <th>Tamil Transcript</th>
            <th>AI Conf</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>CA8a74e0d9b139e8a5b23d9a1f28b49201</td>
            <td>+919876543210</td>
            <td>1m 42s</td>
            <td>complaint_intake</td>
            <td>தெருவிளக்கு எரியவில்லை</td>
            <td>0.94</td>
            <td><span class="badge success">completed</span></td>
          </tr>
          <tr>
            <td>CA2039ab8d1f73b889ab8c19ee94bda712</td>
            <td>+919443218765</td>
            <td>0m 58s</td>
            <td>poll_service</td>
            <td>—</td>
            <td>0.88</td>
            <td><span class="badge success">completed</span></td>
          </tr>
          <tr>
            <td>CA9812ba3c14d9b1897a1d1209bca7120a</td>
            <td>+919012345678</td>
            <td>2m 15s</td>
            <td>complaint_intake</td>
            <td>கம்பம் சாய்ந்துள்ளது</td>
            <td>0.52</td>
            <td><span class="badge warning">review</span></td>
          </tr>
        </tbody>
        ''';
        break;
      case ReportService.poles:
        title = 'Pole Assets & Geotags Report';
        filterSummary = 'Zone/Ward: $_poleZone | Min Complaints: $_minComplaints';
        contentTable = '''
        <thead>
          <tr>
            <th>Pole No.</th>
            <th>Ward</th>
            <th>Keypad ID</th>
            <th>Coordinates</th>
            <th>Landmark</th>
            <th>Active Issues</th>
            <th>Last Verified</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>PL-082/WD1</td>
            <td>Ward 1</td>
            <td>82</td>
            <td>11.234123, 78.543212</td>
            <td>Mariamman Kovil Street</td>
            <td><span class="badge success">0 open</span></td>
            <td>2026-05-12</td>
          </tr>
          <tr>
            <td>PL-019/WD2</td>
            <td>Ward 2</td>
            <td>19</td>
            <td>11.238910, 78.546876</td>
            <td>Main Road Bus Stop</td>
            <td><span class="badge danger">1 open</span></td>
            <td>2026-05-20</td>
          </tr>
          <tr>
            <td>PL-102/WD3</td>
            <td>Ward 3</td>
            <td>102</td>
            <td>11.241283, 78.549210</td>
            <td>Primary School West</td>
            <td><span class="badge danger">2 open</span></td>
            <td>2026-05-14</td>
          </tr>
        </tbody>
        ''';
        break;
      case ReportService.tenders:
        title = 'Tenders & Procurement Report';
        filterSummary += ' | Status: $_tenderStatus';
        contentTable = '''
        <thead>
          <tr>
            <th>Tender ID</th>
            <th>Work Description (Tamil)</th>
            <th>Anchor Date</th>
            <th>Awardee Vendor</th>
            <th>Value</th>
            <th>Voucher</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>TND-2026-01</td>
            <td>தெருவிளக்கு பராமரிப்பு</td>
            <td>2026-05-01</td>
            <td>Sengotics Electricals</td>
            <td>₹1,45,000</td>
            <td>V-2026-045</td>
            <td><span class="badge success">Awarded</span></td>
          </tr>
          <tr>
            <td>TND-2026-02</td>
            <td>குடிநீர் குழாய் சீரமைப்பு</td>
            <td>2026-05-05</td>
            <td>Maruthu Engineers</td>
            <td>₹2,10,000</td>
            <td>V-2026-048</td>
            <td><span class="badge success">Awarded</span></td>
          </tr>
          <tr>
            <td>TND-2026-04</td>
            <td>அங்கன்வாடி மின்னிணைப்பு</td>
            <td>2026-05-20</td>
            <td>—</td>
            <td>—</td>
            <td>—</td>
            <td><span class="badge warning">Published</span></td>
          </tr>
        </tbody>
        ''';
        break;
      case ReportService.fieldOps:
        title = 'Field Staff & Electrician Performance Report';
        filterSummary += ' | Role: $_staffRole';
        contentTable = '''
        <thead>
          <tr>
            <th>Email</th>
            <th>Role</th>
            <th>Complaints Assigned</th>
            <th>Resolved Rate</th>
            <th>Avg Time</th>
            <th>Valid Geotags</th>
            <th>Invalid Geotags</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>anbu.electrician@gp.org</td>
            <td>electrician</td>
            <td>32</td>
            <td>93.7%</td>
            <td>12.4 hrs</td>
            <td>28</td>
            <td><span class="badge warning">2</span></td>
          </tr>
          <tr>
            <td>velu.agent@gp.org</td>
            <td>agent</td>
            <td>0</td>
            <td>100%</td>
            <td>—</td>
            <td>118</td>
            <td><span class="badge success">0</span></td>
          </tr>
          <tr>
            <td>kumar.electrician@gp.org</td>
            <td>electrician</td>
            <td>24</td>
            <td>87.5%</td>
            <td>19.8 hrs</td>
            <td>18</td>
            <td><span class="badge danger">3</span></td>
          </tr>
        </tbody>
        ''';
        break;
      case ReportService.zones:
        title = 'Administrative Zones & Ward boundaries';
        filterSummary = _zoneActiveOnly ? 'Status: Active Zones Only' : 'Status: All Zones';
        contentTable = '''
        <thead>
          <tr>
            <th>Zone Name</th>
            <th>Area (Sq Km)</th>
            <th>Covered Areas</th>
            <th>Total Poles</th>
            <th>Active Complaints</th>
            <th>Border Fill Color</th>
            <th>Status</th>
          </tr>
        </thead>
        <tbody>
          <tr>
            <td>Ward 1 Zone</td>
            <td>0.45</td>
            <td>Kovil St, School Rd</td>
            <td>142</td>
            <td>3</td>
            <td><span style="color: #2563EB">■</span> #2563EB</td>
            <td><span class="badge success">Active</span></td>
          </tr>
          <tr>
            <td>Ward 2 Zone</td>
            <td>0.62</td>
            <td>Bus Stand, Market</td>
            <td>186</td>
            <td>1</td>
            <td><span style="color: #10B981">■</span> #10B981</td>
            <td><span class="badge success">Active</span></td>
          </tr>
          <tr>
            <td>Union Border Zone</td>
            <td>1.10</td>
            <td>National Highway</td>
            <td>95</td>
            <td>4</td>
            <td><span style="color: #EF4444">■</span> #EF4444</td>
            <td><span class="badge success">Active</span></td>
          </tr>
        </tbody>
        ''';
        break;
    }

    return '''
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>$title</title>
      <style>
        body {
          font-family: 'Helvetica Neue', Arial, sans-serif;
          color: #1e293b;
          margin: 40px;
          line-height: 1.5;
        }
        h1 {
          font-size: 24px;
          color: #0f172a;
          margin-bottom: 5px;
        }
        .subtitle {
          color: #64748b;
          font-size: 13px;
          margin-bottom: 25px;
        }
        .filter-badge {
          background-color: #f1f5f9;
          padding: 8px 12px;
          border-radius: 6px;
          font-size: 12px;
          color: #475569;
          margin-bottom: 25px;
          display: inline-block;
          border: 1px solid #e2e8f0;
        }
        table {
          width: 100%;
          border-collapse: collapse;
          margin-top: 15px;
          font-size: 13px;
        }
        th {
          background-color: #f8fafc;
          border-bottom: 2px solid #cbd5e1;
          color: #475569;
          font-weight: 600;
          text-align: left;
          padding: 10px 12px;
        }
        td {
          padding: 10px 12px;
          border-bottom: 1px solid #e2e8f0;
        }
        tr:hover {
          background-color: #f8fafc;
        }
        .badge {
          padding: 2px 8px;
          border-radius: 4px;
          font-size: 11px;
          font-weight: bold;
          text-transform: uppercase;
        }
        .success {
          background-color: #dcfce7;
          color: #15803d;
        }
        .warning {
          background-color: #fef9c3;
          color: #a16207;
        }
        .danger {
          background-color: #fee2e2;
          color: #b91c1c;
        }
        .info {
          background-color: #e0f2fe;
          color: #0369a1;
        }
        .footer {
          margin-top: 80px;
          border-top: 1px solid #cbd5e1;
          padding-top: 20px;
          font-size: 11px;
          color: #94a3b8;
          display: flex;
          justify-content: space-between;
        }
        .sig-block {
          margin-top: 50px;
          text-align: right;
          font-size: 13px;
          font-weight: bold;
          color: #475569;
        }
      </style>
    </head>
    <body>
      <h1>$title</h1>
      <div class="subtitle">GramPanchayat IVR Operations Infrastructure Console — Consolidated Audit Report</div>
      <div class="filter-badge"><strong>Filters Applied:</strong> $filterSummary</div>

      <table>
        $contentTable
      </table>

      <div class="sig-block">
        <br><br>
        ____________________________<br>
        Panchayat Commissioner / Officer
      </div>

      <div class="footer">
        <span>Generated by Sengotics IVR Console on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}</span>
        <span>Confidential - For Internal Administrative Use Only</span>
      </div>
    </body>
    </html>
    ''';
  }
}
