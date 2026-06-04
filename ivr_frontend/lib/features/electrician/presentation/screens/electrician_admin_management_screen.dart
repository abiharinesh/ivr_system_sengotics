import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/app_theme.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/api/api_exceptions.dart';
import '../../../../core/widgets/list_screen_shell.dart';
import '../../../panchayat_admin/data/panchayat_admin_repository.dart';
import '../../../super_admin/data/super_admin_repository.dart';

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

/// Admin-side electrician operations (super admin + panchayat admin).
class ElectricianAdminManagementScreen extends StatefulWidget {
  const ElectricianAdminManagementScreen({
    super.key,
    required this.forSuperAdmin,
  });

  final bool forSuperAdmin;

  @override
  State<ElectricianAdminManagementScreen> createState() =>
      _ElectricianAdminManagementScreenState();
}

class _ElectricianAdminManagementScreenState
    extends State<ElectricianAdminManagementScreen> {
  final _pa = PanchayatAdminRepository();
  final _sa = SuperAdminRepository();

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
      final list =
          widget.forSuperAdmin
              ? await _sa.listElectricians()
              : await _pa.listElectricians();
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

  Future<Map<String, dynamic>> _fetchStats(int electricianId) {
    return widget.forSuperAdmin
        ? _sa.getElectricianStats(
          electricianId: electricianId,
          preset: _exportPreset,
        )
        : _pa.getElectricianStats(
          electricianId: electricianId,
          preset: _exportPreset,
        );
  }

  Future<void> _addElectrician() async {
    final emailC = TextEditingController();
    final passC = TextEditingController();
    final phoneC = TextEditingController();
    int? panchayatId;
    List<DropdownMenuItem<int>>? pItems;

    if (widget.forSuperAdmin) {
      try {
        final ps = await _sa.listPanchayats();
        pItems =
            ps
                .map((x) => DropdownMenuItem(value: x.id, child: Text(x.name)))
                .toList();
        if (ps.isNotEmpty) panchayatId = ps.first.id;
        if (ps.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No panchayats found. Create one first.'),
              ),
            );
          }
          return;
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not load panchayats')),
          );
        }
        return;
      }
    }

    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSt) {
            return AlertDialog(
              title: const Text('New electrician'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (pItems != null && pItems.isNotEmpty) ...[
                      DropdownButtonFormField<int>(
                        initialValue: panchayatId,
                        decoration: const InputDecoration(
                          labelText: 'Panchayat',
                        ),
                        items: pItems,
                        onChanged: (v) => setSt(() => panchayatId = v),
                      ),
                      const SizedBox(height: 12),
                    ],
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
    if (widget.forSuperAdmin && (panchayatId == null)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a panchayat')));
      return;
    }
    final phone = phoneC.text.trim();
    try {
      if (widget.forSuperAdmin) {
        await _sa.createElectrician(
          panchayatId: panchayatId!,
          email: emailC.text.trim(),
          password: passC.text,
          phoneE164: phone.isEmpty ? null : phone,
        );
      } else {
        await _pa.createElectrician(
          email: emailC.text.trim(),
          password: passC.text,
          phoneE164: phone.isEmpty ? null : phone,
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Electrician created')));
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

  Future<void> _runExport(int electricianUserId) async {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Starting export...')));
    try {
      final started =
          widget.forSuperAdmin
              ? await _sa.startExportResolved(
                electricianUserId: electricianUserId,
                preset: _exportPreset,
              )
              : await _pa.startExportResolved(
                electricianUserId: electricianUserId,
                preset: _exportPreset,
              );
      final jobId = started['job_id'] as int;
      while (mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        final job =
            widget.forSuperAdmin
                ? await _sa.getExportJob(jobId)
                : await _pa.getExportJob(jobId);
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
          final bytes =
              widget.forSuperAdmin
                  ? await _sa.downloadExportZip(jobId)
                  : await _pa.downloadExportZip(jobId);
          final name = 'electrician-export-$jobId.zip';
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
      title: 'Field electricians',
      subtitle:
          widget.forSuperAdmin
              ? 'All panchayats · analytics & ZIP export'
              : 'Your panchayat · analytics & ZIP export',
      countLabel: '${_rows.length} electrician(s)',
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
            onPressed: _addElectrician,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Add'),
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
        message: 'Loading electricians...',
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
        child: Text('No electricians yet. Tap Add to create one.'),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
        return ListView.builder(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          itemCount: _rows.length,
          itemBuilder: (context, index) {
            final m = Map<String, dynamic>.from(_rows[index] as Map);
            final id = m['id'] as int;
            final email = m['email']?.toString() ?? '$id';
            final phone = m['phone_e164']?.toString();
            final pName =
                m['panchayat'] is Map
                    ? (m['panchayat'] as Map)['name']?.toString()
                    : null;
            final expanded = _expanded.contains(id);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
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
                title: Text(
                  email,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (pName != null) pName,
                    if (phone != null && phone.isNotEmpty) phone,
                  ].join(' · '),
                  style: const TextStyle(fontSize: 12),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: FutureBuilder<Map<String, dynamic>>(
                      key: ValueKey('$id-$_exportPreset'),
                      future: expanded ? _fetchStats(id) : null,
                      builder: (context, snap) {
                        if (!expanded) return const SizedBox.shrink();
                        if (snap.connectionState != ConnectionState.done) {
                          return const Padding(
                            padding: EdgeInsets.all(12),
                            child: AppLoadingState(
                              message: 'Loading stats...',
                              compact: true,
                            ),
                          );
                        }
                        if (snap.hasError) {
                          return Text(snap.error.toString());
                        }
                        final s = snap.data!;
                        final a = s['assigned_in_period'];
                        final r = s['resolved_in_period'];
                        final o = s['open_assigned'];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Preset: $_exportPreset',
                              style:       TextStyle(
                                color: AppTheme.textMuted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 16,
                              runSpacing: 8,
                              children: [
                                Text('Assigned in range: $a'),
                                Text('Resolved in range: $r'),
                                Text('Open jobs: $o'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: () => _runExport(id),
                              icon: const Icon(
                                Icons.folder_zip_outlined,
                                size: 18,
                              ),
                              label: const Text('Export resolved (ZIP)'),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}