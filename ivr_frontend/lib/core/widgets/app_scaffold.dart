import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ivr_frontend/app.dart';
import 'package:ivr_frontend/config/app_theme.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/data/panchayat_admin_repository.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/core/models/dashboard_insights_model.dart';
import 'package:ivr_frontend/core/models/pole_model.dart';
import 'package:ivr_frontend/core/navigation/role_navigation_config.dart';
import 'nav_guard.dart';
import 'pole_picker_dialog.dart';

class AppScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final String currentRoute;
  final UserModel user;
  final VoidCallback onLogout;
  final Widget? floatingActionButton;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentRoute,
    required this.user,
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
        final themeKey = ValueKey(
          '${customization.settings.themeMode}_'
          '${customization.settings.primaryColorValue}_'
          '${customization.settings.accentColorValue}',
        );

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
            body: KeyedSubtree(
              key: themeKey,
              child: widget.body,
            ),
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
                  children: [
                    _buildTopBar(context),
                    Expanded(
                      child: KeyedSubtree(
                        key: themeKey,
                        child: widget.body,
                      ),
                    ),
                  ],
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

  /// The signed-in user, when the auth bloc has one.
  ///
  /// Read via `read` rather than `watch` in the route helpers below, which run
  /// during layout rather than build and must not register a dependency.
  UserModel? get _user {
    final state = context.read<AuthBloc>().state;
    return state is Authenticated ? state.user : null;
  }

  /// Convenience: all nav routes reachable from the current sidebar.
  Iterable<String?> _allNavRoutes() =>
      RoleNavigationConfig.routesFrom(_user?.nav ?? const []);

  Widget _buildSidebar(BuildContext context) {
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    final softwareName = user?.dynamicSoftwareName ?? 'ஊராட்சி குரல்';
    final tagline = user?.softwareTaglineTa ?? 'GIS & Citizen Portal';

    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border:       Border(right: BorderSide(color: AppTheme.stroke)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                if (user?.logoUrl != null && user!.logoUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      ApiConfig.fileUrl(user.logoUrl),
                      height: 38,
                      width: 38,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.account_balance_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.account_balance_rounded,
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
                        softwareName,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        user?.orgUnitName ?? tagline,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                ..._buildDynamicSections(),
              ],
            ),
          ),
          const Divider(height: 1),
          InkWell(
            onTap: () => context.go('/profile'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary,
                    child: Text(
                      widget.user.email.isNotEmpty
                          ? widget.user.email[0].toUpperCase()
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
                          widget.user.email,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.user.displayRoleName,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.account_circle_outlined,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                    onPressed: () => context.go('/profile'),
                    tooltip: 'View Profile',
                  ),
                  IconButton(
                    icon: Icon(
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
              onPressed: widget.user.hasPermission('complaints.write')
                  ? () => _handleNewComplaint(context)
                  : null,
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
    final authState = context.watch<AuthBloc>().state;
    final user = authState is Authenticated ? authState.user : null;
    final softwareName = user?.dynamicSoftwareName ?? 'ஊராட்சி குரல்';

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (user?.logoUrl != null && user!.logoUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      ApiConfig.fileUrl(user.logoUrl),
                      height: 40,
                      width: 40,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.phone_in_talk_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  )
                else
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                const SizedBox(height: 8),
                Text(
                  softwareName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  user?.orgUnitName ?? widget.user.email,
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
                ..._buildDynamicSections(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRoleName(String role) {
    switch (role) {
      case 'super_admin': return 'Super Admin';
      case 'panchayat_admin': return 'Panchayat Admin';
      case 'municipal_commissioner': return 'Municipal Commissioner';
      case 'municipal_engineer': return 'Municipal Engineer';
      case 'revenue_officer': return 'Revenue Officer';
      case 'assistant_engineer': return 'Assistant Engineer';
      case 'health_officer': return 'Health Officer';
      case 'revenue_inspector': return 'Revenue Inspector';
      case 'junior_engineer': return 'Junior Engineer';
      case 'i3c_staff': return 'I3C Command Center';
      case 'contractor': return 'Contractor / Vendor';
      case 'citizen': return 'Citizen';
      case 'agent': return 'Field Agent';
      case 'electrician': return 'Electrician';
      case 'plumber': return 'Plumber';
      default: return role;
    }
  }

  List<Widget> _navItemsFor(List<NavSpec> specs) {
    final active = _activeRouteFor(_allNavRoutes(), widget.currentRoute);
    return specs
        .map((s) => _NavItem(
              icon: s.icon,
              label: s.label,
              route: s.route,
              isActive: s.route != null && s.route == active,
              currentRoute: widget.currentRoute,
            ))
        .toList();
  }

  /// The sidebar is fully grouped now — there is no separate ungrouped
  /// "primary" list above the sections, which is what used to let the two
  /// drift apart and show the same destination twice.
  List<Widget> _getPrimaryNavItems() => const [];

  /// Every group this role can reach, in catalogue order. A header only
  /// renders when it has items, so a role never sees an empty heading.
  List<Widget> _buildDynamicSections() {
    final widgets = <Widget>[];
    // The server decides, entirely. There are no role-based defaults left to
    // fall back to — a menu assembled from a hardcoded map is a second opinion
    // about a question `role_screen_access` already answers, and for the three
    // field roles that second opinion used to win.
    final sections = RoleNavigationConfig.sectionsFrom(_user?.nav ?? const []);
    for (final section in sections) {
      widgets.add(_navLabel(section.title));
      widgets.addAll(_navItemsFor(section.items));
      widgets.add(const SizedBox(height: 12));
    }
    return widgets;
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
    const searchableRoutes = [
      '/search',
      '/complaints',
      '/agent/poles',
      '/electrician/jobs',
      '/plumber/jobs',
    ];
    final available = _allNavRoutes().whereType<String>().toSet();
    final route = searchableRoutes.firstWhere(
      (candidate) => available.any(
        (allowed) => candidate == allowed || candidate.startsWith('$allowed/'),
      ),
      orElse: () => RoleNavigationConfig.homeRouteFrom(widget.user.nav),
    );
    context.go(term.isEmpty ? route : '$route?q=${Uri.encodeComponent(term)}');
  }

  void _handleNewComplaint(BuildContext context) {
    if (widget.user.hasPermission('complaints.write')) {
      _openNewComplaintFlow(context);
      return;
    }
    if (widget.user.hasPermission('street_lights.write') &&
        _allNavRoutes().contains('/agent/poles')) {
      context.go('/agent/poles/add');
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Your current permissions do not allow this action.')),
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
    if (widget.user.hasPermission('tenants.read')) {
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
    if (widget.user.hasPermission('tenants.read')) {
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
    if (widget.user.hasPermission('tenants.read')) {
      final insights = await SuperAdminRepository().getDashboardInsights();
      return _TopBarActivityData.fromInsights(insights);
    }
    if (widget.user.hasPermission('dashboard.read')) {
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
