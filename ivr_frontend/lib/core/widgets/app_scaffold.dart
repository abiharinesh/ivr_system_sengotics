import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app.dart';
import '../../config/app_theme.dart';
import '../../features/panchayat_admin/data/panchayat_admin_repository.dart';
import '../../features/super_admin/data/super_admin_repository.dart';
import '../../models/dashboard_insights_model.dart';
import '../../models/pole_model.dart';
import 'nav_guard.dart';
import 'pole_picker_dialog.dart';

class AppScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final String currentRoute;
  final String userRole;
  final String userEmail;
  final VoidCallback onLogout;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentRoute,
    required this.userRole,
    required this.userEmail,
    required this.onLogout,
    this.floatingActionButton,
  });

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  late final TextEditingController _topSearchController;
  final GlobalKey _notificationIconKey = GlobalKey();
  final GlobalKey _mailIconKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _topSearchController = TextEditingController();
  }

  @override
  void dispose() {
    _topSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;
    final customization = context.adminCustomizationProvider;

    return ListenableBuilder(
      listenable: customization,
      builder: (context, _) {
        if (isMobile) {
          return Scaffold(
            appBar: AppBar(
              title: Text(widget.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  onPressed: widget.onLogout,
                  tooltip: 'Logout',
                ),
              ],
            ),
            drawer: _buildDrawer(context),
            body: widget.body,
            floatingActionButton: widget.floatingActionButton,
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.bgDark,
          body: Row(
            children: [
              _buildSidebar(context),
              Expanded(
                child: Column(
                  children: [_buildTopBar(context), Expanded(child: widget.body)],
                ),
              ),
            ],
          ),
          floatingActionButton: widget.floatingActionButton,
        );
      },
    );
  }

  /// Pick the nav route that is the longest prefix of [currentRoute].
  /// Returns null if no candidate matches.
  String? _activeRouteFor(Iterable<String?> routes, String currentRoute) {
    String? best;
    for (final r in routes) {
      if (r == null) continue;
      if (currentRoute == r || currentRoute.startsWith('$r/')) {
        if (best == null || r.length > best.length) best = r;
      }
    }
    return best;
  }

  /// Convenience: all primary + secondary nav routes for the current role.
  Iterable<String?> _allNavRoutes() sync* {
    for (final s in _primaryNavSpecs()) {
      yield s.route;
    }
    for (final s in _waterSupplyNavSpecs()) {
      yield s.route;
    }
    for (final s in _secondaryNavSpecs()) {
      yield s.route;
    }
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border:       Border(right: BorderSide(color: AppTheme.stroke)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                      Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'GramPanchayat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        'Operations Console',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          _navLabel('MAIN MENU'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ..._getPrimaryNavItems(),
                const SizedBox(height: 12),
                _navLabel('WATER SUPPLY'),
                ..._getWaterSupplyNavItems(),
                const SizedBox(height: 12),
                _navLabel('REPORTS & SYSTEM'),
                ..._getSecondaryNavItems(),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    widget.userEmail.isNotEmpty
                        ? widget.userEmail[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.userEmail,
                        style:       TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.userRole == 'super_admin'
                            ? 'Super Admin'
                            : widget.userRole == 'panchayat_admin'
                                ? 'Panchayat Admin'
                                : widget.userRole == 'agent'
                                    ? 'Field agent'
                                    : widget.userRole == 'electrician'
                                        ? 'Electrician'
                                        : widget.userRole,
                        style:       TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon:       Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: widget.onLogout,
                  tooltip: 'Logout',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border:       Border(bottom: BorderSide(color: AppTheme.stroke)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.bgSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _topSearchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _handleTopSearch(context),
                decoration:       InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search complaints, poles or users...',
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            height: 42,
            child: ElevatedButton.icon(
              onPressed: () => _handleNewComplaint(context),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Complaint'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            key: _notificationIconKey,
            onPressed:
                () => _openActivityCenter(
                  context,
                  initialTab: 0,
                  anchorKey: _notificationIconKey,
                ),
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppTheme.textMuted,
            tooltip: 'Notifications',
          ),
          IconButton(
            key: _mailIconKey,
            onPressed:
                () => _openActivityCenter(
                  context,
                  initialTab: 1,
                  anchorKey: _mailIconKey,
                ),
            icon: const Icon(Icons.mail_outline_rounded),
            color: AppTheme.textMuted,
            tooltip: 'Mail',
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(
                  Icons.phone_in_talk_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                const SizedBox(height: 8),
                const Text(
                  'GramPanchayat',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  widget.userEmail,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              children: [
                ..._getPrimaryNavItems(),
                const SizedBox(height: 12),
                _navLabel('WATER SUPPLY'),
                ..._getWaterSupplyNavItems(),
                const SizedBox(height: 12),
                _navLabel('REPORTS & SYSTEM'),
                ..._getSecondaryNavItems(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_NavSpec> _primaryNavSpecs() {
    if (widget.userRole == 'agent') {
      return const [
        _NavSpec(icon: Icons.dashboard_rounded, label: 'Home', route: '/agent'),
        _NavSpec(icon: Icons.list_alt_rounded, label: 'Poles', route: '/agent/poles'),
        _NavSpec(icon: Icons.add_location_alt_rounded, label: 'New pole', route: '/agent/poles/add'),
      ];
    }
    if (widget.userRole == 'electrician') {
      return const [
        _NavSpec(icon: Icons.dashboard_rounded, label: 'Home', route: '/electrician'),
        _NavSpec(icon: Icons.electrical_services_rounded, label: 'My jobs', route: '/electrician/jobs'),
      ];
    }
    if (widget.userRole == 'super_admin') {
      return const [
        _NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
        _NavSpec(icon: Icons.report_problem_rounded, label: 'Complaints', route: '/complaints'),
        _NavSpec(icon: Icons.map_rounded, label: 'Zone Management', route: '/zone-management'),
        _NavSpec(icon: Icons.engineering_rounded, label: 'Electricians', route: '/superadmin/electricians'),
        _NavSpec(icon: Icons.plumbing_rounded, label: 'Plumbers', route: '/superadmin/plumbers'),
        _NavSpec(icon: Icons.group_rounded, label: 'Agents', route: '/fieldops/agents'),
        _NavSpec(icon: Icons.alt_route_rounded, label: 'Pole Management', route: '/poles'),
        _NavSpec(icon: Icons.call_rounded, label: 'Voice Calls', route: '/voice-calls'),
        _NavSpec(icon: Icons.receipt_long_rounded, label: 'IVR Logs', route: '/ivr-logs'),
        _NavSpec(icon: Icons.account_tree_rounded, label: 'Panchayat Mgmt', route: '/panchayats'),
        _NavSpec(icon: Icons.people_rounded, label: 'User Management', route: '/users'),
        _NavSpec(icon: Icons.assignment_rounded, label: 'Tenders', route: '/superadmin/tenders'),
        _NavSpec(icon: Icons.store_mall_directory_rounded, label: 'Vendors', route: '/superadmin/vendors'),
        _NavSpec(icon: Icons.gavel_rounded, label: 'Vendor Bidding Portal', route: '/tenders/vendor-portal'),
      ];
    }
    return const [
      _NavSpec(icon: Icons.dashboard_rounded, label: 'Dashboard', route: '/dashboard'),
      _NavSpec(icon: Icons.report_problem_rounded, label: 'Complaints', route: '/complaints'),
      _NavSpec(icon: Icons.map_rounded, label: 'Zone Management', route: '/zone-management'),
      _NavSpec(icon: Icons.electrical_services_rounded, label: 'Poles', route: '/poles'),
      _NavSpec(icon: Icons.call_rounded, label: 'Voice Calls', route: '/voice-calls'),
      _NavSpec(icon: Icons.receipt_long_rounded, label: 'IVR Logs', route: '/ivr-logs'),
      _NavSpec(icon: Icons.engineering_rounded, label: 'Electricians', route: '/admin/electricians'),
      _NavSpec(icon: Icons.plumbing_rounded, label: 'Plumbers', route: '/admin/plumbers'),
      _NavSpec(icon: Icons.assignment_rounded, label: 'Tenders', route: '/tenders'),
      _NavSpec(icon: Icons.store_mall_directory_rounded, label: 'Vendors', route: '/vendors'),
      _NavSpec(icon: Icons.gavel_rounded, label: 'Vendor Bidding Portal', route: '/tenders/vendor-portal'),
    ];
  }

  List<_NavSpec> _secondaryNavSpecs() {
    if (widget.userRole == 'agent' || widget.userRole == 'electrician') {
      return const [];
    }
    return const [
      _NavSpec(
        icon: Icons.document_scanner_rounded,
        label: 'Report Generation',
        route: '/report-generation',
      ),
      _NavSpec(icon: Icons.insights_rounded, label: 'Analytics', route: '/analytics'),
      _NavSpec(icon: Icons.palette_rounded, label: 'Customization', route: '/settings/customization'),
      _NavSpec(
        icon: Icons.description_outlined,
        label: 'Document templates',
        route: '/settings/document-templates',
      ),
      _NavSpec(icon: Icons.settings_rounded, label: 'AI Settings', route: '/ai-settings'),
    ];
  }

  List<Widget> _getPrimaryNavItems() {
    final active = _activeRouteFor(_allNavRoutes(), widget.currentRoute);
    return _primaryNavSpecs()
        .map((s) => _NavItem(
              icon: s.icon,
              label: s.label,
              route: s.route,
              isActive: s.route != null && s.route == active,
              currentRoute: widget.currentRoute,
            ))
        .toList();
  }

  List<Widget> _getSecondaryNavItems() {
    final active = _activeRouteFor(_allNavRoutes(), widget.currentRoute);
    return _secondaryNavSpecs()
        .map((s) => _NavItem(
              icon: s.icon,
              label: s.label,
              route: s.route,
              isActive: s.route != null && s.route == active,
              currentRoute: widget.currentRoute,
            ))
        .toList();
  }

  List<_NavSpec> _waterSupplyNavSpecs() {
    if (widget.userRole == 'agent' || widget.userRole == 'electrician') {
      return const [];
    }
    return const [
      _NavSpec(icon: Icons.grid_on_rounded, label: 'Pipeline Grid', route: '/water/pipeline-grid'),
      _NavSpec(icon: Icons.opacity_rounded, label: 'Tanks & Borewells', route: '/water/tanks'),
      _NavSpec(icon: Icons.history_edu_rounded, label: 'Water Flow Logs', route: '/water/flow-logs'),
    ];
  }

  List<Widget> _getWaterSupplyNavItems() {
    final active = _activeRouteFor(_allNavRoutes(), widget.currentRoute);
    return _waterSupplyNavSpecs()
        .map((s) => _NavItem(
              icon: s.icon,
              label: s.label,
              route: s.route,
              isActive: s.route != null && s.route == active,
              currentRoute: widget.currentRoute,
            ))
        .toList();
  }

  Widget _navLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style:       TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }

  void _handleTopSearch(BuildContext context) {
    final term = _topSearchController.text.trim();
    if (widget.userRole == 'agent') {
      final route =
          term.isEmpty ? '/agent/poles' : '/agent/poles?q=${Uri.encodeComponent(term)}';
      context.go(route);
      return;
    }
    if (widget.userRole == 'electrician') {
      final route = term.isEmpty
          ? '/electrician/jobs'
          : '/electrician/jobs?q=${Uri.encodeComponent(term)}';
      context.go(route);
      return;
    }
    final route =
        term.isEmpty ? '/complaints' : '/complaints?q=${Uri.encodeComponent(term)}';
    context.go(route);
  }

  void _handleNewComplaint(BuildContext context) {
    if (widget.userRole == 'super_admin' || widget.userRole == 'panchayat_admin') {
      _openNewComplaintFlow(context);
      return;
    }
    if (widget.userRole == 'agent') {
      context.go('/agent/poles/add');
      return;
    }
    context.go('/electrician/jobs');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('New complaint creation is managed by admins.')),
    );
  }

  Future<void> _openNewComplaintFlow(BuildContext context) async {
    try {
      final poles = await _loadPolesForRole();
      if (!context.mounted) return;
      final selectedPole = await showPolePickerDialog(
        context: context,
        poles: poles,
        title: 'Select Pole for New Complaint',
        confirmLabel: 'Continue',
      );
      if (!context.mounted || selectedPole == null) return;

      final payload = await showDialog<_ManualComplaintPayload>(
        context: context,
        builder: (_) => const _ManualComplaintFormDialog(),
      );
      if (!context.mounted || payload == null) return;

      await _createComplaintForRole(
        poleId: selectedPole.id,
        complaintType: payload.complaintType,
        description: payload.description,
        urgencyLevel: payload.urgencyLevel,
      );
      if (!context.mounted) return;
      context.go('/complaints');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint created successfully.')),
      );
    } catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create complaint: $err')),
      );
    }
  }

  Future<List<PoleModel>> _loadPolesForRole() async {
    if (widget.userRole == 'super_admin') {
      final raw = await SuperAdminRepository().listPoles();
      return raw
          .whereType<Map>()
          .map((j) => PoleModel.fromJson(Map<String, dynamic>.from(j)))
          .toList();
    }
    return PanchayatAdminRepository().listPoles();
  }

  Future<void> _createComplaintForRole({
    required int poleId,
    required String complaintType,
    required String description,
    String? urgencyLevel,
  }) async {
    if (widget.userRole == 'super_admin') {
      await SuperAdminRepository().createComplaint(
        poleId: poleId,
        complaintType: complaintType,
        description: description,
        urgencyLevel: urgencyLevel,
      );
      return;
    }
    await PanchayatAdminRepository().createComplaint(
      poleId: poleId,
      complaintType: complaintType,
      description: description,
      urgencyLevel: urgencyLevel,
    );
  }

  Future<void> _openActivityCenter(
    BuildContext context, {
    required int initialTab,
    required GlobalKey anchorKey,
  }) async {
    final dataFuture = _loadActivityData();

    final anchorCtx = anchorKey.currentContext;
    if (anchorCtx == null) {
      return;
    }

    final renderObject = anchorCtx.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    final overlay = Overlay.of(context).context.findRenderObject();
    if (overlay is! RenderBox) {
      return;
    }

    const popupWidth = 420.0;
    const horizontalMargin = 12.0;
    const verticalGap = 8.0;
    final anchorTopLeft = renderObject.localToGlobal(Offset.zero, ancestor: overlay);
    final anchorBottomLeft = renderObject.localToGlobal(
      Offset(0, renderObject.size.height),
      ancestor: overlay,
    );

    final maxPopupWidth = overlay.size.width - (horizontalMargin * 2);
    final resolvedPopupWidth =
        maxPopupWidth < popupWidth ? maxPopupWidth.clamp(280.0, popupWidth) : popupWidth;
    final desiredLeft = anchorTopLeft.dx + renderObject.size.width - resolvedPopupWidth;
    final clampedLeft = desiredLeft.clamp(
      horizontalMargin,
      overlay.size.width - resolvedPopupWidth - horizontalMargin,
    );

    final maxPopupHeight = overlay.size.height * 0.72;
    final desiredTop = anchorBottomLeft.dy + verticalGap;
    final clampedTop = desiredTop.clamp(
      horizontalMargin,
      overlay.size.height - maxPopupHeight - horizontalMargin,
    );

    await showGeneralDialog<void>(
      context: context,
      barrierLabel: 'Close',
      barrierDismissible: true,
      barrierColor: Colors.black26,
      transitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (dialogContext, _, __) {
        return Stack(
          children: [
            Positioned(
              left: clampedLeft.toDouble(),
              top: clampedTop.toDouble(),
              width: resolvedPopupWidth.toDouble(),
              height: maxPopupHeight,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(14),
                clipBehavior: Clip.antiAlias,
                color: AppTheme.bgCard,
                child: FutureBuilder<_TopBarActivityData>(
                  future: dataFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load activity right now.',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      );
                    }
                    final data = snapshot.data ?? const _TopBarActivityData.empty();
                    return DefaultTabController(
                      length: 2,
                      initialIndex: initialTab,
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          const TabBar(
                            tabs: [
                              Tab(
                                icon: Icon(Icons.notifications_none_rounded),
                                text: 'Activity',
                              ),
                              Tab(
                                icon: Icon(Icons.mail_outline_rounded),
                                text: 'Messages',
                              ),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                _ActivityList(
                                  items: data.recentActivity,
                                  emptyMessage: data.emptyMessage,
                                ),
                                _CategoryList(
                                  items: data.byCategory,
                                  emptyMessage: data.emptyMessage,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<_TopBarActivityData> _loadActivityData() async {
    if (widget.userRole == 'super_admin') {
      final insights = await SuperAdminRepository().getDashboardInsights();
      return _TopBarActivityData.fromInsights(insights);
    }
    if (widget.userRole == 'panchayat_admin') {
      final insights = await PanchayatAdminRepository().getDashboardInsights();
      return _TopBarActivityData.fromInsights(insights);
    }
    return const _TopBarActivityData(
      recentActivity: [],
      byCategory: [],
      emptyMessage: 'Notifications and inbox are not enabled for this role yet.',
    );
  }
}

class _ManualComplaintPayload {
  final String complaintType;
  final String description;
  final String? urgencyLevel;

  const _ManualComplaintPayload({
    required this.complaintType,
    required this.description,
    this.urgencyLevel,
  });
}

class _ManualComplaintFormDialog extends StatefulWidget {
  const _ManualComplaintFormDialog();

  @override
  State<_ManualComplaintFormDialog> createState() =>
      _ManualComplaintFormDialogState();
}

class _ManualComplaintFormDialogState extends State<_ManualComplaintFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _complaintType = 'street_light';
  String _urgency = 'medium';

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Complaint Details'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: _complaintType,
                items: const [
                  DropdownMenuItem(
                    value: 'street_light',
                    child: Text('Street light issue'),
                  ),
                  DropdownMenuItem(
                    value: 'power_outage',
                    child: Text('Power outage'),
                  ),
                  DropdownMenuItem(
                    value: 'wire_damage',
                    child: Text('Wire damage'),
                  ),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged:
                    (v) => setState(() => _complaintType = v ?? 'street_light'),
                decoration: const InputDecoration(labelText: 'Complaint type'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _urgency,
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'medium', child: Text('Medium')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                ],
                onChanged: (v) => setState(() => _urgency = v ?? 'medium'),
                decoration: const InputDecoration(labelText: 'Urgency'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Issue description',
                  hintText: 'Describe the complaint',
                ),
                validator:
                    (v) =>
                        (v == null || v.trim().isEmpty)
                            ? 'Description is required'
                            : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(
              _ManualComplaintPayload(
                complaintType: _complaintType,
                description: _descriptionController.text.trim(),
                urgencyLevel: _urgency,
              ),
            );
          },
          child: const Text('Create Complaint'),
        ),
      ],
    );
  }
}

class _TopBarActivityData {
  final List<RecentActivityItem> recentActivity;
  final List<CategoryCount> byCategory;
  final String emptyMessage;

  const _TopBarActivityData({
    required this.recentActivity,
    required this.byCategory,
    required this.emptyMessage,
  });

  const _TopBarActivityData.empty()
      : recentActivity = const [],
        byCategory = const [],
        emptyMessage = 'No recent updates.';

  factory _TopBarActivityData.fromInsights(DashboardInsights insights) {
    return _TopBarActivityData(
      recentActivity: insights.recentActivity,
      byCategory: insights.byCategory,
      emptyMessage: 'No recent updates available.',
    );
  }
}

class _ActivityList extends StatelessWidget {
  final List<RecentActivityItem> items;
  final String emptyMessage;

  const _ActivityList({required this.items, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(Icons.circle_notifications_rounded),
          title: Text(item.title),
          subtitle: Text('${item.subtitle}\n${item.at}'),
          isThreeLine: true,
          onTap: () => context.go(
            '/complaints?q=${Uri.encodeComponent(item.complaintId.toString())}',
          ),
        );
      },
    );
  }
}

class _CategoryList extends StatelessWidget {
  final List<CategoryCount> items;
  final String emptyMessage;

  const _CategoryList({required this.items, required this.emptyMessage});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyMessage));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(Icons.mark_email_read_outlined),
          title: Text(item.label),
          trailing: Text(item.count.toString()),
          subtitle: const Text('Category summary from recent operations'),
        );
      },
    );
  }
}

class _NavSpec {
  final IconData icon;
  final String label;
  final String? route;
  const _NavSpec({required this.icon, required this.label, required this.route});
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? route;
  final bool isActive;
  final String currentRoute;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.isActive,
    required this.currentRoute,
  });

  bool get isEnabled => route != null;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            if (!isEnabled) {
              return;
            }
            // Tapping the sidebar always returns to that section's root.
            // No-op only when already on the exact root route.
            if (currentRoute == route) {
              if (Scaffold.of(context).isDrawerOpen) {
                Navigator.of(context).pop();
              }
              return;
            }
            // Prompt the user to confirm leaving if any screen has unsaved work.
            final canLeave = await NavGuard.instance.confirmLeave(context);
            if (!canLeave) return;
            if (!context.mounted) return;
            if (Scaffold.of(context).isDrawerOpen) {
              Navigator.of(context).pop();
            }
            context.go(route!);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? AppTheme.primary.withValues(alpha: 0.1)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border:
                  isActive
                      ? Border.all(
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      )
                      : null,
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color:
                      isActive
                          ? AppTheme.primaryLight
                          : isEnabled
                          ? AppTheme.textMuted
                          : AppTheme.textMuted.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    color:
                        isActive
                            ? AppTheme.textPrimary
                            : isEnabled
                            ? AppTheme.textSecondary
                            : AppTheme.textMuted.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}