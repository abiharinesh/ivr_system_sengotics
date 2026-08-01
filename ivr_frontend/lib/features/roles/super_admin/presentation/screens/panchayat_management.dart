import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/widgets/app_loading_state.dart';
import 'package:ivr_frontend/core/widgets/empty_state.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/panchayat_bloc.dart';

// ---------------------------------------------------------------------------
//  Panchayat & Branding Hub — merged screen
//  • Left/Top panel: branch list with logo + branding preview chips
//  • Right/Bottom panel: tabbed detail (Branch | Branding | Admin User)
// ---------------------------------------------------------------------------

class PanchayatManagement extends StatefulWidget {
  const PanchayatManagement({super.key});

  @override
  State<PanchayatManagement> createState() => _PanchayatManagementState();
}

class _PanchayatManagementState extends State<PanchayatManagement> {
  List<dynamic> _cachedPanchayats = [];
  dynamic _selected; // currently selected panchayat for detail panel

  // Preset names per branch type
  static const Map<String, Map<String, String>> _namePresets = {
    'VILLAGE_PANCHAYAT': {'ta': 'கிராம ஊராட்சி குரல்', 'en': 'Grama Ooratchi Kural'},
    'PANCHAYAT_UNION': {'ta': 'ஊராட்சி ஒன்றிய குரல்', 'en': 'Ooratchi Union Kural'},
    'DISTRICT_PANCHAYAT': {'ta': 'மாவட்ட ஊராட்சி குரல்', 'en': 'District Ooratchi Kural'},
    'TOWN_PANCHAYAT': {'ta': 'பேரூராட்சி குரல்', 'en': 'Peeraatchi Kural'},
    'MUNICIPALITY': {'ta': 'நகராட்சி குரல்', 'en': 'Nagaraatchi Kural'},
    'MUNICIPAL_CORPORATION': {'ta': 'மாநகராட்சி குரல்', 'en': 'Maanagaraatchi Kural'},
  };

  @override
  void initState() {
    super.initState();
    context.read<PanchayatBloc>().add(LoadPanchayats());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PanchayatBloc, PanchayatState>(
      listener: (context, state) {
        if (state is PanchayatActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: AppTheme.accent,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          context.read<PanchayatBloc>().add(LoadPanchayats());
        }
        if (state is PanchayatError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(state.message)),
                ],
              ),
              backgroundColor: AppTheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        // Keep selected panchayat in sync after reload
        if (state is PanchayatLoaded && _selected != null) {
          final updated = state.panchayats.where((p) => p.id == _selected.id);
          if (updated.isNotEmpty) {
            setState(() => _selected = updated.first);
          }
        }
      },
      builder: (context, state) {
        final isLoading = state is PanchayatLoading ||
            (state is PanchayatInitial && _cachedPanchayats.isEmpty);
        if (state is PanchayatLoaded) {
          _cachedPanchayats = state.panchayats;
        }
        return _buildBody(context, _cachedPanchayats, isLoading: isLoading);
      },
    );
  }

  Widget _buildBody(BuildContext context, List<dynamic> panchayats,
      {bool isLoading = false}) {
    final w = MediaQuery.sizeOf(context).width;
    final isWide = w >= 900;

    // Header action row
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primary, AppTheme.accent],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Panchayat & Branding Hub',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          isLoading
                              ? 'Loading…'
                              : '${panchayats.length} branch(es) — tap to configure branding',
                          style: TextStyle(
                              fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed:
                isLoading ? null : () => _showCreateDialog(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const Text('New Panchayat'),
          ),
        ],
      ),
    );

    if (isLoading) {
      return Column(
        children: [
          header,
          const SizedBox(height: 24),
          const Expanded(
            child: AppLoadingState(
              message: 'Loading panchayat records…',
              style: AppLoadingStyle.list,
            ),
          ),
        ],
      );
    }

    if (panchayats.isEmpty) {
      return Column(
        children: [
          header,
          Expanded(
            child: EmptyState(
              icon: Icons.account_balance_rounded,
              title: 'No Panchayats Found',
              subtitle:
                  'Create your first panchayat branch to configure branding and admin access',
              action: ElevatedButton.icon(
                onPressed: () => _showCreateDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('Add Panchayat'),
              ),
            ),
          ),
        ],
      );
    }

    // Wide: two-panel layout (list | detail)
    // Narrow: list only, detail opens as bottom sheet
    if (isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // LEFT: Branch list
                SizedBox(
                  width: 320,
                  child: _buildBranchList(context, panchayats),
                ),
                Container(
                  width: 1,
                  color: Colors.grey.shade200,
                ),
                // RIGHT: Detail panel
                Expanded(
                  child: _selected == null
                      ? _buildSelectPrompt()
                      : _buildDetailPanel(context, _selected),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          header,
          const SizedBox(height: 12),
          Expanded(child: _buildBranchList(context, panchayats)),
        ],
      );
    }
  }

  // ── Branch List ──────────────────────────────────────────────────────────

  Widget _buildBranchList(BuildContext context, List<dynamic> panchayats) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: panchayats.length,
      itemBuilder: (context, index) {
        final p = panchayats[index];
        final isActive = _selected?.id == p.id;
        return _BranchCard(
          panchayat: p,
          isActive: isActive,
          onTap: () {
            final w = MediaQuery.sizeOf(context).width;
            if (w >= 900) {
              setState(() => _selected = p);
            } else {
              _showDetailBottomSheet(context, p);
            }
          },
          onEdit: () => _showEditDialog(context, p),
          onDelete: () => _showDeleteDialog(context, p.id, p.name),
        );
      },
    );
  }

  Widget _buildSelectPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded,
              size: 56, color: AppTheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            'Select a branch to configure',
            style: TextStyle(
                fontSize: 16,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap any panchayat on the left to manage its branding and details',
            style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Detail Panel (tabs) ──────────────────────────────────────────────────

  Widget _buildDetailPanel(BuildContext context, dynamic p) {
    return DefaultTabController(
      length: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Panel header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                _BranchLogo(logoUrl: p.logoUrl, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        '${(p.branchType ?? 'VILLAGE_PANCHAYAT').replaceAll('_', ' ')} · ${p.branchCode ?? 'No Code'}',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit_note_rounded,
                          color: AppTheme.primary),
                      tooltip: 'Edit Branch Details',
                      onPressed: () => _showEditDialog(context, p),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: AppTheme.error),
                      tooltip: 'Delete Branch',
                      onPressed: () =>
                          _showDeleteDialog(context, p.id, p.name),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Tabs
          TabBar(
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primary,
            indicatorWeight: 3,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            tabs: const [
              Tab(icon: Icon(Icons.business_rounded, size: 18), text: 'Branch'),
              Tab(
                  icon: Icon(Icons.palette_rounded, size: 18),
                  text: 'Software Branding'),
              Tab(
                  icon: Icon(Icons.admin_panel_settings_rounded, size: 18),
                  text: 'Admin Info'),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              children: [
                _BranchDetailsTab(panchayat: p),
                _BrandingTab(panchayat: p, namePresets: _namePresets),
                _AdminInfoTab(panchayat: p),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDetailBottomSheet(BuildContext context, dynamic p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: context.read<PanchayatBloc>(),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (_, controller) => Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: _buildDetailPanel(context, p),
          ),
        ),
      ),
    );
  }

  // ── Dialogs ──────────────────────────────────────────────────────────────

  void _showCreateDialog(BuildContext context) {
    _showPanchayatDialog(context, null);
  }

  void _showEditDialog(BuildContext context, dynamic p) {
    _showPanchayatDialog(context, p);
  }

  void _showPanchayatDialog(BuildContext context, dynamic existing) {
    final isEdit = existing != null;

    final nameC = TextEditingController(text: isEdit ? existing.name : '');
    final codeC =
        TextEditingController(text: isEdit ? (existing.branchCode ?? '') : '');
    final districtC = TextEditingController(
        text: isEdit ? (existing.district ?? '') : '');
    final ivrC = TextEditingController(
        text: isEdit ? (existing.ivrNumber ?? '') : '');
    final contactPhoneC =
        TextEditingController(text: isEdit ? (existing.contactPhone ?? '') : '');
    final contactEmailC =
        TextEditingController(text: isEdit ? (existing.contactEmail ?? '') : '');
    final addressC =
        TextEditingController(text: isEdit ? (existing.address ?? '') : '');

    final softTaC = TextEditingController(
        text: isEdit ? (existing.softwareNameTa ?? '') : '');
    final softEnC = TextEditingController(
        text: isEdit ? (existing.softwareNameEn ?? '') : '');
    final taglineTaC = TextEditingController(
        text: isEdit ? (existing.softwareTaglineTa ?? '') : '');
    final taglineEnC = TextEditingController(
        text: isEdit ? (existing.softwareTaglineEn ?? '') : '');
    final logoUrlC =
        TextEditingController(text: isEdit ? (existing.logoUrl ?? '') : '');
    final primaryColorC = TextEditingController(
        text: isEdit ? (existing.primaryColor ?? '#1E3A8A') : '#1E3A8A');
    final secondaryColorC = TextEditingController(
        text: isEdit ? (existing.secondaryColor ?? '#0EA5E9') : '#0EA5E9');
    final welcomeAudioC = TextEditingController(
        text: isEdit ? (existing.welcomeAudioUrl ?? '') : '');

    final adminEmailC = TextEditingController();
    final adminPassC = TextEditingController();
    final adminPhoneC = TextEditingController();
    final adminNameC = TextEditingController();

    String selectedBranchType =
        isEdit ? (existing.branchType ?? 'VILLAGE_PANCHAYAT') : 'VILLAGE_PANCHAYAT';
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Color? tryParseColor(String hex) {
            final clean = hex.replaceAll('#', '').trim();
            if (clean.length != 6) return null;
            final v = int.tryParse(clean, radix: 16);
            return v == null ? null : Color(0xFF000000 | v);
          }

          final previewPrimary =
              tryParseColor(primaryColorC.text) ?? AppTheme.primary;
          final previewNameTa = softTaC.text.isNotEmpty
              ? softTaC.text
              : (_namePresets[selectedBranchType]?['ta'] ?? 'ஊராட்சி குரல்');
          final previewNameEn = softEnC.text.isNotEmpty
              ? softEnC.text
              : (_namePresets[selectedBranchType]?['en'] ?? 'Ooratchi Kural');
          final previewTagline = taglineTaC.text.isNotEmpty
              ? taglineTaC.text
              : 'குடிமக்கள் சேவை மையம்';

          return DefaultTabController(
            length: isEdit ? 2 : 3,
            child: AlertDialog(
              backgroundColor: AppTheme.bgCard,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              titlePadding:
                  const EdgeInsets.fromLTRB(24, 20, 24, 0),
              contentPadding: EdgeInsets.zero,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isEdit
                              ? Icons.edit_note_rounded
                              : Icons.add_location_alt_rounded,
                          color: AppTheme.primary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEdit
                                ? 'Edit: ${existing.name}'
                                : 'New Panchayat & Branding',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            isEdit
                                ? 'Update branch details and software branding'
                                : 'Configure branch, branding & admin credentials',
                            style: TextStyle(
                                fontSize: 11, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TabBar(
                    labelColor: AppTheme.primary,
                    unselectedLabelColor: AppTheme.textMuted,
                    indicatorColor: AppTheme.primary,
                    indicatorWeight: 3,
                    tabs: [
                      const Tab(
                          icon: Icon(Icons.business_rounded, size: 16),
                          text: 'Branch'),
                      Tab(
                          icon: const Icon(Icons.palette_rounded, size: 16),
                          text: isEdit ? 'Branding' : 'Branding'),
                      if (!isEdit)
                        const Tab(
                            icon:
                                Icon(Icons.person_add_rounded, size: 16),
                            text: 'Admin'),
                    ],
                  ),
                ],
              ),
              content: SizedBox(
                width: 560,
                height: 440,
                child: Form(
                  key: formKey,
                  child: TabBarView(
                    children: [
                      // ─── Tab 1: Branch Details ───
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: nameC,
                              decoration: InputDecoration(
                                labelText: 'Panchayat / Branch Name *',
                                prefixIcon:
                                    const Icon(Icons.location_city_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().isEmpty
                                      ? 'Required'
                                      : null,
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: selectedBranchType,
                              decoration: InputDecoration(
                                labelText: 'Branch Type',
                                prefixIcon:
                                    const Icon(Icons.account_tree_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'VILLAGE_PANCHAYAT',
                                    child: Text('Village Panchayat')),
                                DropdownMenuItem(
                                    value: 'PANCHAYAT_UNION',
                                    child: Text('Panchayat Union')),
                                DropdownMenuItem(
                                    value: 'DISTRICT_PANCHAYAT',
                                    child: Text('District Panchayat')),
                                DropdownMenuItem(
                                    value: 'TOWN_PANCHAYAT',
                                    child: Text('Town Panchayat')),
                                DropdownMenuItem(
                                    value: 'MUNICIPALITY',
                                    child: Text('Municipality')),
                                DropdownMenuItem(
                                    value: 'MUNICIPAL_CORPORATION',
                                    child: Text('Municipal Corporation')),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setDialogState(() {
                                    selectedBranchType = v;
                                    // Auto-fill preset if fields are empty
                                    if (softTaC.text.isEmpty) {
                                      softTaC.text =
                                          _namePresets[v]?['ta'] ?? '';
                                    }
                                    if (softEnC.text.isEmpty) {
                                      softEnC.text =
                                          _namePresets[v]?['en'] ?? '';
                                    }
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: codeC,
                                    decoration: InputDecoration(
                                      labelText: 'Branch Code',
                                      hintText: 'TN-PNC-02',
                                      prefixIcon:
                                          const Icon(Icons.qr_code_rounded),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: districtC,
                                    decoration: InputDecoration(
                                      labelText: 'District',
                                      prefixIcon:
                                          const Icon(Icons.map_rounded),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: ivrC,
                              decoration: InputDecoration(
                                labelText: 'IVR Hotline Number',
                                prefixIcon:
                                    const Icon(Icons.phone_in_talk_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: contactPhoneC,
                                    decoration: InputDecoration(
                                      labelText: 'Contact Phone',
                                      prefixIcon:
                                          const Icon(Icons.phone_outlined),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: contactEmailC,
                                    decoration: InputDecoration(
                                      labelText: 'Contact Email',
                                      prefixIcon:
                                          const Icon(Icons.email_outlined),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: addressC,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Office Address',
                                prefixIcon:
                                    const Icon(Icons.location_on_outlined),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Tab 2: Software Branding ───
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Quick preset chips
                            const _SectionLabel(
                                icon: Icons.auto_awesome,
                                label: 'Quick Presets'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: _namePresets.keys.map((type) {
                                final isActive = type == selectedBranchType;
                                return ActionChip(
                                  label: Text(
                                    type.replaceAll('_', ' '),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isActive
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                    ),
                                  ),
                                  backgroundColor: isActive
                                      ? AppTheme.primary
                                      : Colors.grey.shade100,
                                  onPressed: () {
                                    setDialogState(() {
                                      selectedBranchType = type;
                                      softTaC.text =
                                          _namePresets[type]?['ta'] ?? '';
                                      softEnC.text =
                                          _namePresets[type]?['en'] ?? '';
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 16),

                            // Live preview mini card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: previewPrimary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: logoUrlC.text.trim().isNotEmpty
                                        ? ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: Image.network(
                                              ApiConfig.fileUrl(
                                                  logoUrlC.text.trim()),
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  const Icon(
                                                Icons.location_city,
                                                color: Colors.white70,
                                                size: 20,
                                              ),
                                            ),
                                          )
                                        : const Icon(Icons.location_city,
                                            color: Colors.white70, size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          previewNameTa,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          previewNameEn,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                            fontSize: 11,
                                          ),
                                        ),
                                        Text(
                                          previewTagline,
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.6),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            const _SectionLabel(
                                icon: Icons.translate_rounded,
                                label: 'Software Name'),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: softTaC,
                              decoration: InputDecoration(
                                labelText: 'Software Name (Tamil)',
                                hintText: 'எ.கா. நகராட்சி குரல்',
                                prefixIcon:
                                    const Icon(Icons.translate_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: softEnC,
                              decoration: InputDecoration(
                                labelText: 'Software Name (English)',
                                hintText: 'e.g. Nagaraatchi Kural',
                                prefixIcon:
                                    const Icon(Icons.font_download_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 14),

                            const _SectionLabel(
                                icon: Icons.subtitles_rounded,
                                label: 'Taglines'),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: taglineTaC,
                              decoration: InputDecoration(
                                labelText: 'Tagline (Tamil)',
                                hintText: 'குடிமக்கள் சேவை மையம்',
                                prefixIcon:
                                    const Icon(Icons.short_text_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: taglineEnC,
                              decoration: InputDecoration(
                                labelText: 'Tagline (English)',
                                hintText: 'Citizen Service Portal',
                                prefixIcon:
                                    const Icon(Icons.short_text_rounded),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 14),

                            const _SectionLabel(
                                icon: Icons.image_outlined,
                                label: 'Logo & Assets'),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: logoUrlC,
                              decoration: InputDecoration(
                                labelText: 'Logo / Emblem URL',
                                hintText: 'https://example.com/logo.png',
                                prefixIcon:
                                    const Icon(Icons.image_outlined),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (_) => setDialogState(() {}),
                            ),
                            const SizedBox(height: 14),

                            const _SectionLabel(
                                icon: Icons.palette_rounded,
                                label: 'Theme Colors'),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: primaryColorC,
                                    decoration: InputDecoration(
                                      labelText: 'Primary Color',
                                      hintText: '#1E3A8A',
                                      prefixIcon: Icon(
                                        Icons.circle,
                                        color: tryParseColor(
                                                primaryColorC.text) ??
                                            AppTheme.primary,
                                      ),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: secondaryColorC,
                                    decoration: InputDecoration(
                                      labelText: 'Secondary Color',
                                      hintText: '#0EA5E9',
                                      prefixIcon: Icon(
                                        Icons.circle_outlined,
                                        color: tryParseColor(
                                                secondaryColorC.text) ??
                                            AppTheme.accent,
                                      ),
                                      border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(10)),
                                    ),
                                    onChanged: (_) => setDialogState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            const _SectionLabel(
                                icon: Icons.record_voice_over_rounded,
                                label: 'IVR Voice Greeting'),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: welcomeAudioC,
                              decoration: InputDecoration(
                                labelText: 'Welcome Audio URL (optional)',
                                hintText: 'https://storage.com/welcome.mp3',
                                prefixIcon:
                                    const Icon(Icons.audio_file_outlined),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Tab 3: Admin User (create-only) ───
                      if (!isEdit)
                        SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: AppTheme.primary
                                          .withValues(alpha: 0.15)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        color: AppTheme.primary, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Leave email blank to skip admin user creation. You can add users later from User Management.',
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondary),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: adminNameC,
                                decoration: InputDecoration(
                                  labelText: 'Panchayat Officer Name',
                                  prefixIcon:
                                      const Icon(Icons.badge_rounded),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: adminEmailC,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'Admin Email Address',
                                  prefixIcon:
                                      const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: adminPassC,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText:
                                      'Password (default: Password\u0040123)',
                                  prefixIcon:
                                      const Icon(Icons.lock_outline),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: adminPhoneC,
                                decoration: InputDecoration(
                                  labelText: 'Admin Mobile (+91…)',
                                  prefixIcon:
                                      const Icon(Icons.smartphone_rounded),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  icon: Icon(
                      isEdit ? Icons.save_rounded : Icons.check_circle_outline,
                      size: 18),
                  label:
                      Text(isEdit ? 'Save Changes' : 'Create & Initialize'),
                  onPressed: () {
                    if (!formKey.currentState!.validate()) return;

                    if (isEdit) {
                      // Update branch details
                      final branchData = <String, dynamic>{
                        'name': nameC.text.trim(),
                      };
                      if (ivrC.text.isNotEmpty) {
                        branchData['ivr_number'] = ivrC.text.trim();
                      }
                      if (contactPhoneC.text.isNotEmpty) {
                        branchData['contact_phone'] = contactPhoneC.text.trim();
                      }
                      if (contactEmailC.text.isNotEmpty) {
                        branchData['contact_email'] = contactEmailC.text.trim();
                      }
                      if (addressC.text.isNotEmpty) {
                        branchData['address'] = addressC.text.trim();
                      }
                      context
                          .read<PanchayatBloc>()
                          .add(UpdatePanchayat(existing.id, branchData));

                      // Update branding separately (via proper endpoint)
                      final brandingData = <String, dynamic>{
                        'software_name_ta': softTaC.text.trim(),
                        'software_name_en': softEnC.text.trim(),
                        'software_tagline_ta': taglineTaC.text.trim(),
                        'software_tagline_en': taglineEnC.text.trim(),
                        'logo_url': logoUrlC.text.trim(),
                        'primary_color': primaryColorC.text.trim(),
                        'secondary_color': secondaryColorC.text.trim(),
                        'welcome_audio_url': welcomeAudioC.text.trim(),
                      };
                      context
                          .read<PanchayatBloc>()
                          .add(UpdateBranding(existing.id, brandingData));
                    } else {
                      // Unified create
                      final data = <String, dynamic>{
                        'name': nameC.text.trim(),
                        'branch_type': selectedBranchType,
                      };
                      if (codeC.text.isNotEmpty) {
                        data['branch_code'] = codeC.text.trim();
                      }
                      if (districtC.text.isNotEmpty) {
                        data['district'] = districtC.text.trim();
                      }
                      if (ivrC.text.isNotEmpty) {
                        data['ivr_number'] = ivrC.text.trim();
                      }
                      if (contactPhoneC.text.isNotEmpty) {
                        data['contact_phone'] = contactPhoneC.text.trim();
                      }
                      if (contactEmailC.text.isNotEmpty) {
                        data['contact_email'] = contactEmailC.text.trim();
                      }
                      if (addressC.text.isNotEmpty) {
                        data['address'] = addressC.text.trim();
                      }
                      if (softTaC.text.isNotEmpty) {
                        data['software_name_ta'] = softTaC.text.trim();
                      }
                      if (softEnC.text.isNotEmpty) {
                        data['software_name_en'] = softEnC.text.trim();
                      }
                      if (taglineTaC.text.isNotEmpty) {
                        data['software_tagline_ta'] = taglineTaC.text.trim();
                      }
                      if (taglineEnC.text.isNotEmpty) {
                        data['software_tagline_en'] = taglineEnC.text.trim();
                      }
                      if (logoUrlC.text.isNotEmpty) {
                        data['logo_url'] = logoUrlC.text.trim();
                      }
                      if (primaryColorC.text.isNotEmpty) {
                        data['primary_color'] = primaryColorC.text.trim();
                      }
                      if (secondaryColorC.text.isNotEmpty) {
                        data['secondary_color'] = secondaryColorC.text.trim();
                      }
                      if (welcomeAudioC.text.isNotEmpty) {
                        data['welcome_audio_url'] = welcomeAudioC.text.trim();
                      }
                      if (adminEmailC.text.isNotEmpty) {
                        data['admin_email'] = adminEmailC.text.trim();
                        if (adminNameC.text.isNotEmpty) {
                          data['admin_name'] = adminNameC.text.trim();
                        }
                        if (adminPassC.text.isNotEmpty) {
                          data['admin_password'] = adminPassC.text.trim();
                        }
                        if (adminPhoneC.text.isNotEmpty) {
                          data['admin_phone'] = adminPhoneC.text.trim();
                        }
                      }
                      context
                          .read<PanchayatBloc>()
                          .add(CreateUnifiedPanchayat(data));
                    }

                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: AppTheme.error, size: 24),
            const SizedBox(width: 10),
            const Text('Delete Branch'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$name"?\n\nThis will remove the branch configuration. Users and data linked to this branch will be retained but unlinked.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            icon: const Icon(Icons.delete_forever_rounded, size: 18),
            label: const Text('Delete'),
            onPressed: () {
              context.read<PanchayatBloc>().add(DeletePanchayat(id));
              if (_selected?.id == id) {
                setState(() => _selected = null);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

// ── Branch Card ─────────────────────────────────────────────────────────────

class _BranchCard extends StatelessWidget {
  final dynamic panchayat;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _BranchCard({
    required this.panchayat,
    required this.isActive,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = panchayat;
    final branchLabel =
        (p.branchType ?? 'VILLAGE_PANCHAYAT').replaceAll('_', ' ');
    final softName =
        p.softwareNameTa ?? p.softwareNameEn ?? 'ஊராட்சி குரல்';

    Color? primaryColor;
    final rawColor = p.primaryColor as String?;
    if (rawColor != null && rawColor.startsWith('#')) {
      final clean = rawColor.replaceAll('#', '');
      if (clean.length == 6) {
        final v = int.tryParse(clean, radix: 16);
        if (v != null) primaryColor = Color(0xFF000000 | v);
      }
    }
    primaryColor ??= AppTheme.primary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.primary.withValues(alpha: 0.06)
            : AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4)),
              ]
            : [],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Color indicator stripe
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _BranchLogo(logoUrl: p.logoUrl, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          softName,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert,
                        size: 18, color: AppTheme.textMuted),
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_note_rounded, size: 16),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline,
                                size: 16, color: AppTheme.error),
                            SizedBox(width: 8),
                            Text('Delete',
                                style: TextStyle(color: AppTheme.error)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _MiniChip(
                      icon: Icons.account_tree_rounded, label: branchLabel),
                  if (p.branchCode != null && p.branchCode.isNotEmpty)
                    _MiniChip(
                        icon: Icons.qr_code_rounded, label: p.branchCode),
                  if (p.ivrNumber != null && p.ivrNumber.isNotEmpty)
                    _MiniChip(
                        icon: Icons.phone_in_talk_rounded,
                        label: p.ivrNumber),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Branch Logo Widget ───────────────────────────────────────────────────────

class _BranchLogo extends StatelessWidget {
  final String? logoUrl;
  final double size;

  const _BranchLogo({this.logoUrl, required this.size});

  @override
  Widget build(BuildContext context) {
    final resolvedUrl =
        (logoUrl != null && logoUrl!.isNotEmpty)
            ? ApiConfig.fileUrl(logoUrl)
            : null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.primary.withValues(alpha: 0.1),
        child: resolvedUrl != null
            ? Image.network(
                resolvedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.account_balance_rounded,
                  color: AppTheme.primary,
                  size: size * 0.5,
                ),
              )
            : Icon(
                Icons.account_balance_rounded,
                color: AppTheme.primary,
                size: size * 0.5,
              ),
      ),
    );
  }
}

// ── Mini chip for card info ──────────────────────────────────────────────────

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SectionLabel({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppTheme.primary),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ── Detail Tabs ──────────────────────────────────────────────────────────────

class _BranchDetailsTab extends StatelessWidget {
  final dynamic panchayat;

  const _BranchDetailsTab({required this.panchayat});

  @override
  Widget build(BuildContext context) {
    final p = panchayat;
    final rows = <_DetailRow>[
      _DetailRow(
          icon: Icons.account_tree_rounded,
          label: 'Branch Type',
          value: (p.branchType ?? 'VILLAGE_PANCHAYAT').replaceAll('_', ' ')),
      _DetailRow(
          icon: Icons.qr_code_rounded,
          label: 'Branch Code',
          value: p.branchCode ?? '—'),
      _DetailRow(
          icon: Icons.phone_in_talk_rounded,
          label: 'IVR Hotline',
          value: p.ivrNumber ?? '—'),
      _DetailRow(
          icon: Icons.electrical_services_rounded,
          label: 'Poles',
          value: '${p.polesCount ?? 0}'),
      _DetailRow(
          icon: Icons.report_problem_rounded,
          label: 'Complaints',
          value: '${p.complaintsCount ?? 0}'),
      _DetailRow(
          icon: Icons.people_rounded,
          label: 'Users',
          value: '${p.usersCount ?? 0}'),
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ...rows.map((r) => _buildDetailRow(r)),
        const SizedBox(height: 16),
        _buildStatsGrid(p),
      ],
    );
  }

  Widget _buildDetailRow(_DetailRow r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(r.icon, size: 16, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(r.label,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textMuted)),
              Text(r.value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(dynamic p) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        _StatCard(
            label: 'Poles', value: '${p.polesCount ?? 0}',
            icon: Icons.electrical_services_rounded,
            color: Colors.blue),
        _StatCard(
            label: 'Complaints',
            value: '${p.complaintsCount ?? 0}',
            icon: Icons.report_problem_rounded,
            color: Colors.orange),
        _StatCard(
            label: 'Users', value: '${p.usersCount ?? 0}',
            icon: Icons.people_rounded,
            color: Colors.green),
      ],
    );
  }
}

class _DetailRow {
  final IconData icon;
  final String label;
  final String value;
  _DetailRow({required this.icon, required this.label, required this.value});
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary)),
          Text(label,
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        ],
      ),
    );
  }
}

// ── Branding Tab (read-only preview in detail panel) ────────────────────────

class _BrandingTab extends StatelessWidget {
  final dynamic panchayat;
  final Map<String, Map<String, String>> namePresets;

  const _BrandingTab(
      {required this.panchayat, required this.namePresets});

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return null;
    final v = int.tryParse(clean, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final p = panchayat;
    final primary = _parseColor(p.primaryColor) ?? AppTheme.primary;
    final secondary = _parseColor(p.secondaryColor) ?? AppTheme.accent;
    final nameTa = p.softwareNameTa ?? '—';
    final nameEn = p.softwareNameEn ?? '—';
    final taglineTa = p.softwareTaglineTa ?? '—';
    final taglineEn = p.softwareTaglineEn ?? '—';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Preview header banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              _BranchLogo(logoUrl: p.logoUrl, size: 48),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nameTa,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        )),
                    Text(nameEn,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                        )),
                    const SizedBox(height: 4),
                    Text(taglineTa,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.65),
                          fontSize: 11,
                        )),
                    Text(taglineEn,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 10,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Color swatches
        Row(
          children: [
            _ColorSwatch(
                label: 'Primary', color: primary, hex: p.primaryColor),
            const SizedBox(width: 16),
            _ColorSwatch(
                label: 'Secondary',
                color: secondary,
                hex: p.secondaryColor),
          ],
        ),
        const SizedBox(height: 20),

        // IVR greeting preview
        if (p.welcomeAudioUrl != null && p.welcomeAudioUrl.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.record_voice_over_rounded,
                    color: Colors.amber.shade700, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IVR Greeting Audio',
                          style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.amber.shade700,
                              fontSize: 12)),
                      Text(p.welcomeAudioUrl,
                          style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Edit branding CTA
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.edit_note_rounded),
            label: const Text('Edit Software Branding',
                style: TextStyle(fontWeight: FontWeight.w700)),
            onPressed: () {
              // Find the parent state to open the edit dialog
              final blocState = context.read<PanchayatBloc>().state;
              final panchayatList = blocState is PanchayatLoaded
                  ? blocState.panchayats
                  : <dynamic>[];
              final fresh =
                  panchayatList.where((x) => x.id == p.id);
              _openEditFromTab(context, fresh.isNotEmpty ? fresh.first : p);
            },
          ),
        ),
      ],
    );
  }

  void _openEditFromTab(BuildContext context, dynamic p) {
    // Navigate to edit dialog; reuse the parent screen's dialog logic
    showDialog(
      context: context,
      builder: (_) => BlocProvider.value(
        value: context.read<PanchayatBloc>(),
        child: _BrandingEditDialog(panchayat: p),
      ),
    );
  }
}

// ── Standalone Branding Edit Dialog ─────────────────────────────────────────

class _BrandingEditDialog extends StatefulWidget {
  final dynamic panchayat;
  const _BrandingEditDialog({required this.panchayat});

  @override
  State<_BrandingEditDialog> createState() => _BrandingEditDialogState();
}

class _BrandingEditDialogState extends State<_BrandingEditDialog> {
  late TextEditingController softTaC;
  late TextEditingController softEnC;
  late TextEditingController taglineTaC;
  late TextEditingController taglineEnC;
  late TextEditingController logoUrlC;
  late TextEditingController primaryColorC;
  late TextEditingController secondaryColorC;
  late TextEditingController welcomeAudioC;
  final _formKey = GlobalKey<FormState>();

  static const Map<String, Map<String, String>> _namePresets = {
    'VILLAGE_PANCHAYAT': {'ta': 'கிராம ஊராட்சி குரல்', 'en': 'Grama Ooratchi Kural'},
    'PANCHAYAT_UNION': {'ta': 'ஊராட்சி ஒன்றிய குரல்', 'en': 'Ooratchi Union Kural'},
    'DISTRICT_PANCHAYAT': {'ta': 'மாவட்ட ஊராட்சி குரல்', 'en': 'District Ooratchi Kural'},
    'TOWN_PANCHAYAT': {'ta': 'பேரூராட்சி குரல்', 'en': 'Peeraatchi Kural'},
    'MUNICIPALITY': {'ta': 'நகராட்சி குரல்', 'en': 'Nagaraatchi Kural'},
    'MUNICIPAL_CORPORATION': {'ta': 'மாநகராட்சி குரல்', 'en': 'Maanagaraatchi Kural'},
  };

  @override
  void initState() {
    super.initState();
    final p = widget.panchayat;
    softTaC = TextEditingController(text: p.softwareNameTa ?? '');
    softEnC = TextEditingController(text: p.softwareNameEn ?? '');
    taglineTaC = TextEditingController(text: p.softwareTaglineTa ?? '');
    taglineEnC = TextEditingController(text: p.softwareTaglineEn ?? '');
    logoUrlC = TextEditingController(text: p.logoUrl ?? '');
    primaryColorC =
        TextEditingController(text: p.primaryColor ?? '#1E3A8A');
    secondaryColorC =
        TextEditingController(text: p.secondaryColor ?? '#0EA5E9');
    welcomeAudioC =
        TextEditingController(text: p.welcomeAudioUrl ?? '');
  }

  @override
  void dispose() {
    softTaC.dispose();
    softEnC.dispose();
    taglineTaC.dispose();
    taglineEnC.dispose();
    logoUrlC.dispose();
    primaryColorC.dispose();
    secondaryColorC.dispose();
    welcomeAudioC.dispose();
    super.dispose();
  }

  Color? _parseColor(String hex) {
    final clean = hex.replaceAll('#', '').trim();
    if (clean.length != 6) return null;
    final v = int.tryParse(clean, radix: 16);
    return v == null ? null : Color(0xFF000000 | v);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.panchayat;
    final previewPrimary =
        _parseColor(primaryColorC.text) ?? AppTheme.primary;
    final previewNameTa =
        softTaC.text.isNotEmpty ? softTaC.text : 'ஊராட்சி குரல்';
    final previewNameEn =
        softEnC.text.isNotEmpty ? softEnC.text : 'Ooratchi Kural';
    final previewTagline = taglineTaC.text.isNotEmpty
        ? taglineTaC.text
        : 'குடிமக்கள் சேவை மையம்';

    return StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        backgroundColor: AppTheme.bgCard,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.palette_rounded, color: AppTheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Software Branding',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary)),
                  Text(p.name,
                      style: TextStyle(
                          fontSize: 12, color: AppTheme.textMuted)),
                ],
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 540,
          height: 480,
          child: Form(
            key: _formKey,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form fields
                Expanded(
                  flex: 3,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Preset chips
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: _namePresets.keys.map((type) {
                            return ActionChip(
                              label: Text(
                                type.replaceAll('_', ' '),
                                style: const TextStyle(fontSize: 10),
                              ),
                              onPressed: () {
                                setState(() {
                                  softTaC.text =
                                      _namePresets[type]?['ta'] ?? '';
                                  softEnC.text =
                                      _namePresets[type]?['en'] ?? '';
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: softTaC,
                          decoration: InputDecoration(
                            labelText: 'Software Name (Tamil) *',
                            hintText: 'நகராட்சி குரல்',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: softEnC,
                          decoration: InputDecoration(
                            labelText: 'Software Name (English) *',
                            hintText: 'Nagaraatchi Kural',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: taglineTaC,
                          decoration: InputDecoration(
                            labelText: 'Tagline (Tamil)',
                            hintText: 'குடிமக்கள் சேவை மையம்',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: taglineEnC,
                          decoration: InputDecoration(
                            labelText: 'Tagline (English)',
                            hintText: 'Citizen Service Portal',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: logoUrlC,
                          decoration: InputDecoration(
                            labelText: 'Logo URL',
                            hintText: 'https://...',
                            prefixIcon:
                                const Icon(Icons.image_outlined, size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: primaryColorC,
                                decoration: InputDecoration(
                                  labelText: 'Primary Color',
                                  hintText: '#1E3A8A',
                                  prefixIcon: Icon(Icons.circle,
                                      color: _parseColor(
                                              primaryColorC.text) ??
                                          AppTheme.primary,
                                      size: 16),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: secondaryColorC,
                                decoration: InputDecoration(
                                  labelText: 'Secondary',
                                  hintText: '#0EA5E9',
                                  prefixIcon: Icon(Icons.circle_outlined,
                                      color: _parseColor(
                                              secondaryColorC.text) ??
                                          AppTheme.accent,
                                      size: 16),
                                  border: OutlineInputBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                  isDense: true,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: welcomeAudioC,
                          decoration: InputDecoration(
                            labelText: 'Welcome Audio URL',
                            hintText: 'https://…/welcome.mp3',
                            prefixIcon: const Icon(
                                Icons.audio_file_outlined,
                                size: 18),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            isDense: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Live Preview
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Live Preview',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          )),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: previewPrimary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: logoUrlC.text.trim().isNotEmpty
                                      ? ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(6),
                                          child: Image.network(
                                            ApiConfig.fileUrl(
                                                logoUrlC.text.trim()),
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const Icon(
                                              Icons.location_city,
                                              color: Colors.white70,
                                              size: 16,
                                            ),
                                          ),
                                        )
                                      : const Icon(Icons.location_city,
                                          color: Colors.white70,
                                          size: 16),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(previewNameTa,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 12),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                      Text(previewNameEn,
                                          style: TextStyle(
                                              color: Colors.white
                                                  .withValues(alpha: 0.75),
                                              fontSize: 10),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 8),
                              decoration: BoxDecoration(
                                color: Colors.white
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                previewTagline,
                                style: TextStyle(
                                    color: Colors.white
                                        .withValues(alpha: 0.85),
                                    fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '🗣️ "$previewNameTa சேவைக்கு வரவேற்கிறோம்…"',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                            fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '🗣️ "Welcome to $previewNameEn service…"',
                        style: TextStyle(
                            fontSize: 10,
                            color: AppTheme.textMuted,
                            fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            icon: const Icon(Icons.save_rounded, size: 18),
            label: const Text('Save Branding'),
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              context.read<PanchayatBloc>().add(UpdateBranding(
                p.id,
                {
                  'software_name_ta': softTaC.text.trim(),
                  'software_name_en': softEnC.text.trim(),
                  'software_tagline_ta': taglineTaC.text.trim(),
                  'software_tagline_en': taglineEnC.text.trim(),
                  'logo_url': logoUrlC.text.trim(),
                  'primary_color': primaryColorC.text.trim(),
                  'secondary_color': secondaryColorC.text.trim(),
                  'welcome_audio_url': welcomeAudioC.text.trim(),
                },
              ));
              Navigator.pop(context);
            },
          ),
        ],
      );
    });
  }
}

// ── Admin Info Tab ───────────────────────────────────────────────────────────

class _AdminInfoTab extends StatelessWidget {
  final dynamic panchayat;

  const _AdminInfoTab({required this.panchayat});

  @override
  Widget build(BuildContext context) {
    final p = panchayat;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.admin_panel_settings_rounded,
                      color: AppTheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Admin Users for ${p.name}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${p.usersCount ?? 0} user(s) are linked to this branch.',
                style:
                    TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pushNamed('/users'),
                icon: const Icon(Icons.people_rounded, size: 16),
                label: const Text('Manage Users'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: Colors.amber.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade700, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Adding Admin Users',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.amber.shade700,
                        fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'To create a new admin user for this panchayat, go to "User Management" from the sidebar and create a user with panchayat_admin role assigned to this branch.',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Color Swatch ─────────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final String label;
  final Color color;
  final String? hex;

  const _ColorSwatch(
      {required this.label, required this.color, this.hex});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.textMuted)),
              Text(hex ?? color.toString(),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }
}