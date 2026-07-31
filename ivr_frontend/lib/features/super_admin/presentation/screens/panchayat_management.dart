import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../config/app_theme.dart';
import '../../../../config/api_config.dart';
import '../../../../core/widgets/app_loading_state.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/list_screen_shell.dart';
import '../../bloc/panchayat_bloc.dart';

class PanchayatManagement extends StatefulWidget {
  const PanchayatManagement({super.key});

  @override
  State<PanchayatManagement> createState() => _PanchayatManagementState();
}

class _PanchayatManagementState extends State<PanchayatManagement> {
  List<dynamic> _cachedPanchayats = [];

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
              content: Text(state.message),
              backgroundColor: AppTheme.accent,
            ),
          );
          context.read<PanchayatBloc>().add(LoadPanchayats());
        }
        if (state is PanchayatError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: AppTheme.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is PanchayatLoading || (state is PanchayatInitial && _cachedPanchayats.isEmpty);
        if (state is PanchayatLoaded) {
          _cachedPanchayats = state.panchayats;
        }
        return _buildList(context, _cachedPanchayats, isLoading: isLoading);
      },
    );
  }

  Widget _buildList(BuildContext context, List<dynamic> panchayats, {bool isLoading = false}) {
    return ListScreenShell(
      title: 'Unified Panchayat & Branding Hub',
      subtitle: 'Create, brand, and assign admin credentials in one place',
      countLabel: isLoading ? 'Loading...' : '${panchayats.length} panchayat branch(es)',
      action: ElevatedButton.icon(
        onPressed: isLoading ? null : () => _showUnifiedSetupDialog(context),
        icon: const Icon(Icons.add_location_alt_rounded, size: 18),
        label: const Text('New Panchayat & Branding'),
      ),
      child: isLoading
          ? const AppLoadingState(
              message: 'Loading panchayat records...',
              style: AppLoadingStyle.list,
            )
          : (panchayats.isEmpty
              ? EmptyState(
                  icon: Icons.location_city_rounded,
                  title: 'No Panchayats Found',
                  subtitle: 'Create your first panchayat branch to initialize branding and admin access',
                  action: ElevatedButton.icon(
                    onPressed: () => _showUnifiedSetupDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Panchayat'),
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final hPad = constraints.maxWidth < 400 ? 12.0 : 24.0;
                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: hPad),
                      itemCount: panchayats.length,
                      itemBuilder: (context, index) {
                        final p = panchayats[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        color: AppTheme.primary.withValues(alpha: 0.1),
                                        child: (p.logoUrl != null && p.logoUrl.toString().isNotEmpty)
                                            ? Image.network(
                                                ApiConfig.fileUrl(p.logoUrl),
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => const Icon(
                                                  Icons.account_balance_rounded,
                                                  color: Colors.teal,
                                                  size: 26,
                                                ),
                                              )
                                            : const Icon(
                                                Icons.account_balance_rounded,
                                                color: Colors.teal,
                                                size: 26,
                                              ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  p.name,
                                                  style: const TextStyle(
                                                    fontSize: 17,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accent.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  p.branchCode ?? 'PANCHAYAT',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppTheme.accent,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            p.softwareNameTa ?? p.softwareNameEn ?? 'ஊராட்சி சேவை',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (action) {
                                        if (action == 'edit') {
                                          _showEditDialog(context, p);
                                        } else if (action == 'delete') {
                                          _showDeleteDialog(context, p.id, p.name);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        const PopupMenuItem(
                                          value: 'edit',
                                          child: Row(
                                            children: [
                                              Icon(Icons.edit_note_rounded, size: 18),
                                              SizedBox(width: 8),
                                              Text('Edit Panchayat & Branding'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_forever_rounded, size: 18, color: AppTheme.error),
                                              SizedBox(width: 8),
                                              Text('Delete', style: TextStyle(color: AppTheme.error)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                const Divider(height: 1),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 16,
                                  runSpacing: 8,
                                  children: [
                                    if (p.ivrNumber != null)
                                      _InfoChip(
                                        icon: Icons.phone_in_talk_rounded,
                                        label: 'IVR Hotline: ${p.ivrNumber}',
                                      ),
                                    if (p.contactEmail != null)
                                      _InfoChip(
                                        icon: Icons.mark_email_read_rounded,
                                        label: '${p.contactEmail}',
                                      ),
                                    _InfoChip(
                                      icon: Icons.shield_outlined,
                                      label: '${p.district ?? 'Coimbatore'} District',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                )),
    );
  }

  void _showUnifiedSetupDialog(BuildContext context) {
    final nameC = TextEditingController();
    final codeC = TextEditingController();
    final districtC = TextEditingController();
    final ivrC = TextEditingController();
    
    final softTaC = TextEditingController();
    final softEnC = TextEditingController();
    final taglineTaC = TextEditingController();
    final logoUrlC = TextEditingController();

    final adminNameC = TextEditingController();
    final adminEmailC = TextEditingController();
    final adminPassC = TextEditingController();
    final adminPhoneC = TextEditingController();

    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => DefaultTabController(
        length: 3,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Unified Panchayat & Branding Setup', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text('Create Panchayat, configure software branding, and assign admin credentials', style: TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              const SizedBox(height: 12),
              TabBar(
                labelColor: AppTheme.primary,
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppTheme.primary,
                tabs: const [
                  Tab(icon: Icon(Icons.business_rounded, size: 18), text: 'Branch'),
                  Tab(icon: Icon(Icons.palette_rounded, size: 18), text: 'Branding'),
                  Tab(icon: Icon(Icons.person_add_rounded, size: 18), text: 'Admin User'),
                ],
              ),
            ],
          ),
          content: SizedBox(
            width: 520,
            height: 380,
            child: Form(
              key: formKey,
              child: TabBarView(
                children: [
                  // Tab 1: Branch Details
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: nameC,
                          decoration: const InputDecoration(labelText: 'Panchayat / Branch Name *', prefixIcon: Icon(Icons.location_city_rounded)),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: codeC,
                                decoration: const InputDecoration(labelText: 'Branch Code (e.g. TN-PNC-02)', prefixIcon: Icon(Icons.qr_code_rounded)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: districtC,
                                decoration: const InputDecoration(labelText: 'District', prefixIcon: Icon(Icons.map_rounded)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: ivrC,
                          decoration: const InputDecoration(labelText: 'IVR Hotline Number', prefixIcon: Icon(Icons.phone_in_talk_rounded)),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Dynamic Branding
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: softTaC,
                          decoration: const InputDecoration(labelText: 'Software Name (Tamil)', prefixIcon: Icon(Icons.translate_rounded)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: softEnC,
                          decoration: const InputDecoration(labelText: 'Software Name (English)', prefixIcon: Icon(Icons.text_fields_rounded)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: taglineTaC,
                          decoration: const InputDecoration(labelText: 'Software Tagline (Tamil)', prefixIcon: Icon(Icons.subtitles_rounded)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: logoUrlC,
                          decoration: const InputDecoration(labelText: 'Emblem / Logo URL', prefixIcon: Icon(Icons.image_outlined)),
                        ),
                      ],
                    ),
                  ),

                  // Tab 3: Admin Credentials
                  SingleChildScrollView(
                    child: Column(
                      children: [
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: adminNameC,
                          decoration: const InputDecoration(labelText: 'Panchayat Officer Name', prefixIcon: Icon(Icons.badge_rounded)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: adminEmailC,
                          decoration: const InputDecoration(labelText: 'Admin Email Address *', prefixIcon: Icon(Icons.email_outlined)),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: adminPassC,
                          obscureText: true,
                          decoration: const InputDecoration(labelText: 'Initial Password (Default: Password@123)', prefixIcon: Icon(Icons.lock_outline)),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: adminPhoneC,
                          decoration: const InputDecoration(labelText: 'Admin Mobile Phone', prefixIcon: Icon(Icons.smartphone_rounded)),
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
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Save & Initialize'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final data = <String, dynamic>{
                    'name': nameC.text.trim(),
                  };
                  if (codeC.text.isNotEmpty) data['branch_code'] = codeC.text.trim();
                  if (districtC.text.isNotEmpty) data['district'] = districtC.text.trim();
                  if (ivrC.text.isNotEmpty) data['ivr_number'] = ivrC.text.trim();
                  if (softTaC.text.isNotEmpty) data['software_name_ta'] = softTaC.text.trim();
                  if (softEnC.text.isNotEmpty) data['software_name_en'] = softEnC.text.trim();
                  if (taglineTaC.text.isNotEmpty) data['software_tagline_ta'] = taglineTaC.text.trim();
                  if (logoUrlC.text.isNotEmpty) data['logo_url'] = logoUrlC.text.trim();

                  if (adminEmailC.text.isNotEmpty) {
                    data['admin_email'] = adminEmailC.text.trim();
                    if (adminNameC.text.isNotEmpty) data['admin_name'] = adminNameC.text.trim();
                    if (adminPassC.text.isNotEmpty) data['admin_password'] = adminPassC.text.trim();
                    if (adminPhoneC.text.isNotEmpty) data['admin_phone'] = adminPhoneC.text.trim();
                  }

                  context.read<PanchayatBloc>().add(CreateUnifiedPanchayat(data));
                  Navigator.pop(ctx);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, dynamic panchayat) {
    final nameC = TextEditingController(text: panchayat.name);
    final ivrC = TextEditingController(text: panchayat.ivrNumber ?? '');
    final softTaC = TextEditingController(text: panchayat.softwareNameTa ?? '');
    final softEnC = TextEditingController(text: panchayat.softwareNameEn ?? '');
    final logoUrlC = TextEditingController(text: panchayat.logoUrl ?? '');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Panchayat & Branding', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameC,
                  decoration: const InputDecoration(labelText: 'Panchayat Name *'),
                  validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: ivrC,
                  decoration: const InputDecoration(labelText: 'IVR Hotline Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: softTaC,
                  decoration: const InputDecoration(labelText: 'Software Name (Tamil)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: softEnC,
                  decoration: const InputDecoration(labelText: 'Software Name (English)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: logoUrlC,
                  decoration: const InputDecoration(labelText: 'Logo / Emblem URL'),
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
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final data = <String, dynamic>{
                  'name': nameC.text.trim(),
                  'ivr_number': ivrC.text.trim(),
                  'software_name_ta': softTaC.text.trim(),
                  'software_name_en': softEnC.text.trim(),
                  'logo_url': logoUrlC.text.trim(),
                };
                context.read<PanchayatBloc>().add(UpdatePanchayat(panchayat.id, data));
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, int id, String name) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Panchayat Branch'),
        content: Text('Are you sure you want to delete "$name"? This action will remove branch configuration.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () {
              context.read<PanchayatBloc>().add(DeletePanchayat(id));
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}