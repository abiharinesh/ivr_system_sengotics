import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../config/app_theme.dart';

class AppScaffold extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 800;

    if (isMobile) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: onLogout,
              tooltip: 'Logout',
            ),
          ],
        ),
        drawer: _buildDrawer(context),
        body: body,
        floatingActionButton: floatingActionButton,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: Column(
              children: [_buildTopBar(context), Expanded(child: body)],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 270,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppTheme.stroke)),
      ),
      child: Column(
        children: [
          // Logo / Brand
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
                const Expanded(
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

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                ..._getPrimaryNavItems(),
                const SizedBox(height: 12),
                _navLabel('REPORTS & SYSTEM'),
                ..._getSecondaryNavItems(),
              ],
            ),
          ),

          // User section
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppTheme.primary,
                  child: Text(
                    userEmail.isNotEmpty ? userEmail[0].toUpperCase() : '?',
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
                        userEmail,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        userRole == 'super_admin'
                            ? 'Super Admin'
                            : 'Panchayat Admin',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.logout_rounded,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  onPressed: onLogout,
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
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.stroke)),
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
              child: const TextField(
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search complaints, poles or users...',
                  hintStyle: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                  prefixIcon: Icon(
                    Icons.search,
                    size: 18,
                    color: AppTheme.textMuted,
                  ),
                  contentPadding: EdgeInsets.symmetric(
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
              onPressed: () {},
              icon: const Icon(Icons.add, size: 16),
              label: const Text('New Complaint'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none_rounded),
            color: AppTheme.textMuted,
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.mail_outline_rounded),
            color: AppTheme.textMuted,
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
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient),
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
                  userEmail,
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
                _navLabel('REPORTS & SYSTEM'),
                ..._getSecondaryNavItems(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _getPrimaryNavItems() {
    if (userRole == 'super_admin') {
      return [
        _NavItem(
          icon: Icons.dashboard_rounded,
          label: 'Dashboard',
          route: '/dashboard',
          currentRoute: currentRoute,
        ),
        _NavItem(
          icon: Icons.report_problem_rounded,
          label: 'Complaints',
          route: '/complaints',
          currentRoute: currentRoute,
        ),
        _NavItem(
          icon: Icons.alt_route_rounded,
          label: 'Pole Management',
		  route: '/poles',
          currentRoute: currentRoute,
        ),
        _NavItem(
          icon: Icons.call_rounded,
          label: 'Voice Calls',
		  route: '/voice-calls',
          currentRoute: currentRoute,
        ),
        _NavItem(
          icon: Icons.receipt_long_rounded,
          label: 'IVR Logs',
		  route: '/ivr-logs',
          currentRoute: currentRoute,
        ),
        _NavItem(
          icon: Icons.account_tree_rounded,
          label: 'Panchayat Mgmt',
          route: '/panchayats',
          currentRoute: currentRoute,
        ),
        _NavItem(
          icon: Icons.people_rounded,
          label: 'User Management',
          route: '/users',
          currentRoute: currentRoute,
        ),
      ];
    }
    return [
      _NavItem(
        icon: Icons.dashboard_rounded,
        label: 'Dashboard',
        route: '/dashboard',
        currentRoute: currentRoute,
      ),
      _NavItem(
        icon: Icons.electrical_services_rounded,
        label: 'Poles',
        route: '/poles',
        currentRoute: currentRoute,
      ),
      _NavItem(
        icon: Icons.call_rounded,
        label: 'Voice Calls',
	  route: '/voice-calls',
        currentRoute: currentRoute,
      ),
      _NavItem(
        icon: Icons.receipt_long_rounded,
        label: 'IVR Logs',
	  route: '/ivr-logs',
        currentRoute: currentRoute,
      ),
      _NavItem(
        icon: Icons.account_tree_rounded,
        label: 'Panchayat Mgmt',
	  route: '/panchayats',
        currentRoute: currentRoute,
      ),
      _NavItem(
        icon: Icons.people_rounded,
        label: 'User Management',
	  route: '/users',
        currentRoute: currentRoute,
      ),
      _NavItem(
        icon: Icons.report_problem_rounded,
        label: 'Complaints',
        route: '/complaints',
        currentRoute: currentRoute,
      ),
    ];
  }

  List<Widget> _getSecondaryNavItems() {
    return [
      _NavItem(
        icon: Icons.insights_rounded,
        label: 'Analytics',
		  route: '/analytics',
        currentRoute: currentRoute,
      ),
      _NavItem(
        icon: Icons.settings_rounded,
        label: 'Settings',
        route: '/ai-settings',
        currentRoute: currentRoute,
      ),
    ];
  }

  Widget _navLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
            color: AppTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? route;
  final String currentRoute;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    required this.currentRoute,
  });

  bool get isActive => route != null && currentRoute == route;
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
          onTap: () {
            if (!isEnabled) {
              return;
            }
            if (!isActive) {
              if (Scaffold.of(context).isDrawerOpen) {
                Navigator.of(context).pop();
              }
              context.go(route!);
            }
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
