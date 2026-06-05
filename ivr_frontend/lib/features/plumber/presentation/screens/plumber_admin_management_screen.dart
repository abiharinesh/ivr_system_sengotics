import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/widgets/list_screen_shell.dart';
import '../../data/plumber_repository.dart';

const _presetIds = <String>[
  'THIS_MONTH',
  'LAST_3_MONTHS',
  'LAST_6_MONTHS',
  'LAST_12_MONTHS',
];

const _presetLabels = <String>[
  'This month',
  'Last 3 mo',
  'Last 6 mo',
  'Last 12 mo',
];

class PlumberAdminManagementScreen extends StatefulWidget {
  const PlumberAdminManagementScreen({
    super.key,
    required this.forSuperAdmin,
  });

  final bool forSuperAdmin;

  @override
  State<PlumberAdminManagementScreen> createState() =>
      _PlumberAdminManagementScreenState();
}

class _PlumberAdminManagementScreenState
    extends State<PlumberAdminManagementScreen> {
  final _pr = PlumberRepository();

  List<dynamic> _rows = [];
  bool _loading = true;
  String? _error;
  String _exportPreset = _presetIds[0];
  final Set<int> _expanded = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _pr.listPlumbers();
      setState(() {
        _rows = list;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchStats(int plumberId) {
    return _pr.getPlumberStats(
      plumberId: plumberId,
      preset: _exportPreset,
    );
  }

  Future<void> _addPlumber() async {
    final emailC = TextEditingController();
    final passC = TextEditingController();
    final phoneC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text('New Plumber'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: emailC,
                      decoration: const InputDecoration(labelText: 'Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: passC,
                      decoration: const InputDecoration(
                        labelText: 'Password (min 8)',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: phoneC,
                      decoration: const InputDecoration(
                        labelText: 'WhatsApp E.164 (optional)',
                        hintText: '+919876543210',
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true || !mounted) return;
    final phone = phoneC.text.trim();
    try {
      await _pr.createPlumber(
        email: emailC.text.trim(),
        password: passC.text,
        phoneE164: phone.isEmpty ? null : phone,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Plumber created successfully.')));
      }
      await _reload();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _runExport(int plumberUserId) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Starting export...')));
    try {
      final started = await _pr.startExportResolved(
        plumberUserId: plumberUserId,
        preset: _exportPreset,
      );
      final jobId = started['job_id'] as int;
      while (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        final job = await _pr.getExportJob(jobId);
        final st = job['status']?.toString() ?? '';
        if (st == 'failed') {
          final msg = job['error_message']?.toString() ?? 'Export failed';
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
          }
          return;
        }
        if (st == 'ready') {
          final bytes = await _pr.downloadExportZip(jobId);
          final name = 'plumber-export-$jobId.zip';
          await Share.shareXFiles([
            XFile.fromData(bytes, mimeType: 'application/zip', name: name),
          ]);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export ready — share or open ZIP')),
            );
          }
          return;
        }
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListScreenShell(
      title: 'Field Plumbers',
      subtitle:
          widget.forSuperAdmin
              ? 'All panchayats · analytics & ZIP export'
              : 'Your panchayat · analytics & ZIP export',
      countLabel: '${_rows.length} plumber(s)',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          OutlinedButton.icon(
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _addPlumber,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Add Plumber'),
          ),
        ],
      ),
      filters: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_presetIds.length, (i) {
            final sel = _exportPreset == _presetIds[i];
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_presetLabels[i]),
                selected: sel,
                onSelected: (_) {
                  setState(() => _exportPreset = _presetIds[i]);
                },
                selectedColor: AppTheme.primary.withValues(alpha: 0.12),
                checkmarkColor: AppTheme.primary,
              ),
            );
          }),
        ),
      ),
      child: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const AppLoadingState(
        message: 'Loading plumbers...',
        style: AppLoadingStyle.list,
      );
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_rows.isEmpty) {
      return const Center(
        child: Text('No plumbers registered. Tap Add to create one.'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 800;
        final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;

        if (isWide) {
          return GridView.builder(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 8),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 480,
              mainAxisExtent: 290,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final m = Map<String, dynamic>.from(_rows[index] as Map);
              final id = m['id'] as int;
              return _buildStaffCard(m, id, true);
            },
          );
        }

        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          itemCount: _rows.length,
          itemBuilder: (context, index) {
            final m = Map<String, dynamic>.from(_rows[index] as Map);
            final id = m['id'] as int;
            return _buildStaffCard(m, id, false);
          },
        );
      },
    );
  }

  Widget _buildStaffCard(Map<String, dynamic> m, int id, bool showDetailsDirectly) {
    final email = m['email']?.toString() ?? '$id';
    final phone = m['phone_e164']?.toString();
    final pName =
        m['panchayat'] is Map
            ? (m['panchayat'] as Map)['name']?.toString()
            : null;
    final expanded = _expanded.contains(id) || showDetailsDirectly;

    final Widget cardHeader = Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Icon(Icons.person_rounded, color: AppTheme.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                email,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (pName != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.bgSurface,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.stroke, width: 0.8),
                      ),
                      child: Text(
                        pName,
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ),
                  if (phone != null && phone.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15), width: 0.8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.phone_rounded, size: 10, color: AppTheme.accent),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600),
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
    );

    final Widget statsView = FutureBuilder<Map<String, dynamic>>(
      key: ValueKey('$id-$_exportPreset'),
      future: expanded ? _fetchStats(id) : null,
      builder: (context, snap) {
        if (!expanded) return const SizedBox.shrink();
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: AppLoadingState(
              message: 'Loading performance stats...',
              compact: true,
            ),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(snap.error.toString(), style: TextStyle(color: AppTheme.error)),
          );
        }
        final s = snap.data!;
        final a = s['assigned_in_period'] ?? 0;
        final r = s['resolved_in_period'] ?? 0;
        final o = s['open_assigned'] ?? 0;

        Widget buildMetric(String label, String value, IconData icon, Color color) {
          return Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Divider(height: 16),
            Row(
              children: [
                Text(
                  'PERFORMANCE SUMMARY',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textMuted,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                Text(
                  'Period: ${_presetLabels[_presetIds.indexOf(_exportPreset)]}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                buildMetric('Assigned', '$a', Icons.assignment_turned_in_rounded, AppTheme.primary),
                const SizedBox(width: 8),
                buildMetric('Resolved', '$r', Icons.check_circle_rounded, AppTheme.accent),
                const SizedBox(width: 8),
                buildMetric('Active Open', '$o', Icons.pending_actions_rounded, AppTheme.warning),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _runExport(id),
              icon: const Icon(Icons.folder_zip_rounded, size: 14),
              label: const Text('Export Resolved Tasks (ZIP)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        );
      },
    );

    if (showDetailsDirectly) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.stroke, width: 1.2),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            cardHeader,
            Expanded(child: SingleChildScrollView(child: statsView)),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.stroke, width: 1.2),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          key: ValueKey(id),
          onExpansionChanged: (open) {
            setState(() {
              if (open) {
                _expanded.add(id);
              } else {
                _expanded.remove(id);
              }
            });
          },
          shape: const Border(),
          collapsedShape: const Border(),
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
            child: Icon(Icons.person_rounded, color: AppTheme.primary, size: 20),
          ),
          title: Text(
            email,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (pName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSurface,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.stroke, width: 0.8),
                    ),
                    child: Text(
                      pName,
                      style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                if (phone != null && phone.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.15), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.phone_rounded, size: 10, color: AppTheme.accent),
                        const SizedBox(width: 4),
                        Text(
                          phone,
                          style: TextStyle(fontSize: 11, color: AppTheme.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: statsView,
            ),
          ],
        ),
      ),
    );
  }
}
