import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import 'package:ivr_frontend/features/auth/bloc/auth_bloc.dart';
import 'package:ivr_frontend/features/modules/zone_management/bloc/zone_bloc.dart';
import 'package:ivr_frontend/features/modules/zone_management/presentation/zone_management_screen.dart';
import 'package:ivr_frontend/features/customization/presentation/screens/admin_customization_screen.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_state.dart';
import 'package:ivr_frontend/features/auth/presentation/change_password_screen.dart';
import 'package:ivr_frontend/features/auth/presentation/login_screen.dart';
import 'package:ivr_frontend/features/roles/citizen/presentation/screens/citizen_register_screen.dart';
import 'package:ivr_frontend/features/roles/citizen/presentation/screens/citizen_dashboard_screen.dart';
import 'package:ivr_frontend/features/roles/citizen/presentation/screens/public_pole_report_screen.dart';
import 'package:ivr_frontend/features/roles/citizen/presentation/screens/complaint_tracking_screen.dart';


import 'package:ivr_frontend/features/roles/super_admin/bloc/dashboard_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/panchayat_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/user_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/complaint_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/settings_bloc.dart';
import 'package:ivr_frontend/features/roles/super_admin/bloc/tenant_bloc.dart';
import 'package:ivr_frontend/features/dashboard/presentation/screens/role_dashboard_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/super_admin_dashboard.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/panchayat_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/user_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/complaint_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/ai_settings_screen.dart';
import 'package:ivr_frontend/features/modules/document_templates/presentation/document_templates_settings_screen.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/presentation/voice_calls_screen.dart';
import 'package:ivr_frontend/features/modules/ivr_operations/presentation/ivr_logs_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/analytics_screen.dart';
import 'package:ivr_frontend/features/modules/reports/presentation/report_generation_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/super_admin_pole_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/agent_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/electrician_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/plumber_management.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/role_management_console.dart';

import 'package:ivr_frontend/features/roles/panchayat_admin/bloc/pa_dashboard_bloc.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/bloc/pole_bloc.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/bloc/pa_complaint_bloc.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/pa_dashboard.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/pole_management.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/pa_complaint_management.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/electrician_management.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/plumber_management.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/pa_complaint_detail.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/qr_customizer_screen.dart';

import 'package:ivr_frontend/features/roles/agent/presentation/screens/agent_dashboard_screen.dart';
import 'package:ivr_frontend/features/roles/agent/presentation/screens/agent_pole_list_screen.dart';
import 'package:ivr_frontend/features/roles/agent/presentation/screens/agent_pole_detail_screen.dart';
import 'package:ivr_frontend/features/roles/agent/presentation/screens/agent_add_pole_screen.dart';
import 'package:ivr_frontend/features/roles/electrician/presentation/screens/electrician_dashboard_screen.dart';
import 'package:ivr_frontend/features/roles/electrician/presentation/screens/electrician_jobs_screen.dart';
import 'package:ivr_frontend/features/roles/electrician/presentation/screens/electrician_complaint_detail_screen.dart';
import 'package:ivr_frontend/features/roles/plumber/presentation/screens/plumber_dashboard_screen.dart';
import 'package:ivr_frontend/features/roles/plumber/presentation/screens/plumber_jobs_screen.dart';
import 'package:ivr_frontend/features/roles/plumber/presentation/screens/plumber_complaint_detail_screen.dart';

import 'package:ivr_frontend/features/modules/tenders/presentation/screens/tender_list_screen.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/screens/tender_create_screen.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/screens/tender_detail_screen.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/screens/vendor_directory_screen.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/screens/public_tender_screen.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/screens/invite_tender_screen.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/screens/public_field_upload_screen.dart';
import 'package:ivr_frontend/features/modules/tenders/presentation/screens/vendor_bidding_portal_screen.dart';

import 'package:ivr_frontend/features/modules/water_supply/presentation/screens/pipeline_grid_screen.dart';
import 'package:ivr_frontend/features/modules/water_supply/presentation/screens/tanks_borewells_screen.dart';
import 'package:ivr_frontend/features/modules/water_supply/presentation/screens/water_flow_logs_screen.dart';
import 'package:ivr_frontend/features/roles/agent/presentation/screens/agent_pipeline_tap_capture_screen.dart';
import 'package:ivr_frontend/features/modules/water_supply/presentation/screens/infrastructure_approval_screen.dart';

import 'package:ivr_frontend/features/modules/reports/presentation/ad_campaign_screen.dart';
import 'package:ivr_frontend/features/modules/reports/presentation/penalty_management_screen.dart';
import 'package:ivr_frontend/features/modules/reports/presentation/property_tax_screen.dart';
import 'package:ivr_frontend/features/modules/reports/presentation/certificate_review_screen.dart';
import 'package:ivr_frontend/features/modules/reports/presentation/asset_booking_screen.dart';
import 'package:ivr_frontend/features/modules/reports/presentation/market_fees_screen.dart';

import 'package:ivr_frontend/features/modules/contractor/presentation/contractor_list_screen.dart';
import 'package:ivr_frontend/features/modules/inspection/presentation/inspection_list_screen.dart';
import 'package:ivr_frontend/features/modules/search/presentation/universal_search_screen.dart';
import 'package:ivr_frontend/features/roles/citizen_portal/presentation/citizen_portal_screen.dart';
import 'package:ivr_frontend/features/modules/municipality/presentation/municipality_screen.dart';

// Screen Plan Modules
import 'package:ivr_frontend/features/roles/panchayat_admin/presentation/screens/panchayat_admin_profile_screen.dart';
import 'package:ivr_frontend/features/auth/presentation/context_selector_screen.dart';
import 'package:ivr_frontend/features/auth/presentation/employee_service_book_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/tenant_management_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/employee_directory_screen.dart';
import 'package:ivr_frontend/features/roles/super_admin/presentation/screens/designation_transfer_timeline_screen.dart';
import 'package:ivr_frontend/features/modules/complaints/presentation/sla_analytics_screen.dart';
import 'package:ivr_frontend/features/modules/dms/presentation/dms_explorer_screen.dart';
import 'package:ivr_frontend/features/modules/audit/presentation/audit_log_inspector_screen.dart';
import 'package:ivr_frontend/features/modules/solid_waste/presentation/screens/solid_waste_screen.dart';
import 'package:ivr_frontend/features/modules/municipality/presentation/public_health_screen.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/screens/building_permit_list_screen.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/screens/building_permit_detail_screen.dart';
import 'package:ivr_frontend/features/modules/building_permits/presentation/screens/building_permit_form_screen.dart';
import 'package:ivr_frontend/features/modules/vital_events/data/models/vital_event_models.dart';
import 'package:ivr_frontend/features/modules/vital_events/presentation/screens/vital_events_registry_screen.dart';
import 'package:ivr_frontend/features/modules/vital_events/presentation/screens/vital_event_detail_screen.dart';
import 'package:ivr_frontend/features/modules/vital_events/presentation/screens/vital_event_form_screen.dart';
import 'package:ivr_frontend/features/modules/vital_events/presentation/screens/certificate_verification_screen.dart';
import 'package:ivr_frontend/features/modules/trade_licences/presentation/screens/trade_licence_register_screen.dart';
import 'package:ivr_frontend/features/modules/trade_licences/presentation/screens/trade_licence_detail_screen.dart';
import 'package:ivr_frontend/features/modules/trade_licences/presentation/screens/trade_licence_form_screen.dart';
import 'package:ivr_frontend/features/modules/trade_licences/presentation/screens/licence_verification_screen.dart';
import 'package:ivr_frontend/features/hubs/presentation/field_workforce_hub.dart';
import 'package:ivr_frontend/features/hubs/presentation/ivr_operations_hub.dart';
import 'package:ivr_frontend/features/hubs/presentation/insights_hub.dart';
import 'package:ivr_frontend/features/hubs/presentation/system_settings_hub.dart';
import 'package:ivr_frontend/features/hubs/presentation/water_supply_hub.dart';

import 'package:ivr_frontend/core/widgets/app_scaffold.dart';
import 'package:ivr_frontend/features/auth/bloc/auth_event.dart';

String _homeForRole(Authenticated auth) {
  final u = auth.user;
  if (u.isSuperAdmin || u.isPanchayatAdmin) return '/dashboard';
  if (u.isAgent) return '/agent';
  if (u.isElectrician) return '/electrician';
  if (u.isPlumber) return '/plumber';
  if (u.isCitizen) return '/citizen';
  return '/dashboard';
}

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isLoginRoute = state.matchedLocation == '/login';
      final loc = state.matchedLocation;

      // Public no-auth routes (tender link + field session upload).
      if (loc.startsWith('/public/')) return null;
      if (loc == '/register-citizen') return null;

      if (authState is! Authenticated) {
        return isLoginRoute ? null : '/login';
      }

      final authed = authState;
      final u = authed.user;

      // An account still on the password it was issued goes nowhere else.
      // Checked before every other rule, including the per-role landing
      // redirects below, so a field worker cannot slip past it into their own
      // shell. The screen itself offers signing out as the only alternative.
      const changePasswordRoute = '/change-password';
      if (u.mustChangePassword) {
        return loc == changePasswordRoute ? null : changePasswordRoute;
      }
      if (loc == changePasswordRoute) {
        // Reached voluntarily from the profile menu — nothing to enforce.
        return null;
      }

      if (isLoginRoute) return _homeForRole(authed);

      if (u.isAgent || u.isElectrician || u.isPlumber) {
        if (u.isAgent && !loc.startsWith('/agent')) return '/agent';
        if (u.isElectrician && !loc.startsWith('/electrician')) return '/electrician';
        if (u.isPlumber && !loc.startsWith('/plumber')) return '/plumber';
      }

      if (u.isCitizen) {
        if (!loc.startsWith('/citizen')) return '/citizen';
      }

      if ((u.isSuperAdmin || u.isPanchayatAdmin) &&
          (loc.startsWith('/agent') ||
              loc.startsWith('/electrician') ||
              loc.startsWith('/plumber') ||
              loc.startsWith('/citizen'))) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      // Outside the app shell on purpose: a user held here has no sidebar to
      // navigate with, and showing one they cannot use invites them to try.
      GoRoute(
        path: '/change-password',
        builder: (context, state) {
          final authState = authBloc.state;
          return ChangePasswordScreen(
            forced: authState is Authenticated &&
                authState.user.mustChangePassword,
          );
        },
      ),
      GoRoute(
        path: '/register-citizen',
        builder: (context, state) => const CitizenRegisterScreen(),
      ),
      GoRoute(
        path: '/citizen',
        builder: (context, state) => const CitizenDashboardScreen(),
      ),
      // Public seller and field-staff routes (no auth shell).
      GoRoute(
        path: '/public/open/:token',
        builder: (context, state) =>
            PublicTenderScreen(token: state.pathParameters['token']!),
      ),
      GoRoute(
        path: '/public/invite/:token',
        builder: (context, state) =>
            InviteTenderScreen(token: state.pathParameters['token']!),
      ),
      // Backward-compatible legacy route.
      GoRoute(
        path: '/public/tenders/:token',
        builder: (context, state) => PublicTenderScreen(
          token: state.pathParameters['token']!,
          useLegacyEndpoint: true,
        ),
      ),
      GoRoute(
        path: '/public/field/:token',
        builder: (context, state) =>
            PublicFieldUploadScreen(token: state.pathParameters['token']!),
      ),
      // Public QR pole report (zero-auth citizen scan).
      GoRoute(
        path: '/public/report/:token',
        builder: (context, state) => PublicPoleReportScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      // Public complaint tracking (zero-auth).
      GoRoute(
        path: '/public/track/:token',
        builder: (context, state) => ComplaintTrackingScreen(
          trackingToken: state.pathParameters['token']!,
        ),
      ),
      // Public birth/death certificate verification — the target of the QR
      // code printed on every issued certificate.
      GoRoute(
        path: '/public/verify-certificate/:token',
        builder: (context, state) => CertificateVerificationScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      // Public trade licence verification — the QR displayed in the shop.
      GoRoute(
        path: '/public/verify-licence/:token',
        builder: (context, state) => LicenceVerificationScreen(
          token: state.pathParameters['token']!,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final authState = authBloc.state;
          if (authState is! Authenticated) return const LoginScreen();

          return AppScaffold(
            title: _getTitle(state.matchedLocation),
            body: child,
            currentRoute: state.matchedLocation,
            userRole: authState.user.role,
            userEmail: authState.user.email,
            onLogout: () => authBloc.add(LogoutRequested()),
          );
        },
        routes: [
          GoRoute(
            path: '/agent',
            builder: (context, state) => const AgentDashboardScreen(),
          ),
          GoRoute(
            path: '/agent/poles',
            builder: (context, state) => AgentPoleListScreen(
              initialSearch: state.uri.queryParameters['q'] ?? '',
            ),
          ),
          GoRoute(
            path: '/agent/poles/add',
            builder: (context, state) => const AgentAddPoleScreen(),
          ),
          GoRoute(
            path: '/agent/pipeline-tap-capture',
            builder: (context, state) => const AgentPipelineTapCaptureScreen(),
          ),
          GoRoute(
            path: '/agent/poles/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return AgentPoleDetailScreen(poleId: id);
            },
          ),
          GoRoute(
            path: '/electrician',
            builder: (context, state) => const ElectricianDashboardScreen(),
          ),
          GoRoute(
            path: '/electrician/jobs',
            builder: (context, state) => ElectricianJobsScreen(
              initialSearch: state.uri.queryParameters['q'] ?? '',
            ),
          ),
          GoRoute(
            path: '/electrician/jobs/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return ElectricianComplaintDetailScreen(complaintId: id);
            },
          ),
          GoRoute(
            path: '/plumber',
            builder: (context, state) => const PlumberDashboardScreen(),
          ),
          GoRoute(
            path: '/plumber/jobs',
            builder: (context, state) => PlumberJobsScreen(
              initialSearch: state.uri.queryParameters['q'] ?? '',
            ),
          ),
          GoRoute(
            path: '/plumber/jobs/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return PlumberComplaintDetailScreen(complaintId: id);
            },
          ),
          // Dashboard.
          //
          // Composed server-side from the caller's `role_dashboards` row, so
          // each designation lands on panels chosen for it. This route used to
          // serve exactly two screens — one for the super admin and one for
          // everyone else — which meant a Commissioner and a Sanitary
          // Inspector opened the same dashboard. Both of those screens are
          // still reachable below.
          GoRoute(
            path: '/dashboard',
            builder: (context, state) {
              final authState = authBloc.state;
              return RoleDashboardScreen(
                user: authState is Authenticated ? authState.user : null,
              );
            },
          ),
          GoRoute(
            path: '/dashboard/platform',
            builder: (context, state) => BlocProvider(
              create: (_) => SADashBloc()..add(LoadSADashboard()),
              child: const SuperAdminDashboard(),
            ),
          ),
          GoRoute(
            path: '/dashboard/branch',
            builder: (context, state) => BlocProvider(
              create: (_) => PADashBloc()..add(LoadPADashboard()),
              child: const PADashboard(),
            ),
          ),
          GoRoute(
            path: '/zone-management',
            builder: (context, state) {
              final authState = authBloc.state;
              final isSuperAdmin = authState is Authenticated && authState.user.isSuperAdmin;
              return BlocProvider(
                create: (_) => ZoneBloc(isSuperAdmin: isSuperAdmin)..add(LoadZones()),
                child: const ZoneManagementScreen(),
              );
            },
          ),
          GoRoute(
            path: '/settings/customization',
            builder: (context, state) => const AdminCustomizationScreen(),
          ),

          // Super Admin Routes
          GoRoute(
            path: '/superadmin/roles',
            builder: (context, state) {
              final userIdStr = state.uri.queryParameters['user_id'];
              final userId = userIdStr != null ? int.tryParse(userIdStr) : null;
              return RoleManagementConsole(initialUserId: userId);
            },
          ),
          // Both of these were separate screens the console now contains as
          // tabs. Kept as redirects so bookmarks and the old sidebar entries
          // land somewhere useful rather than on a blank route.
          GoRoute(
            path: '/superadmin/feature-toggles',
            redirect: (_, __) => '/superadmin/roles',
          ),
          GoRoute(
            path: '/superadmin/branding',
            redirect: (_, __) => '/panchayats',
          ),
          GoRoute(
            path: '/panchayats',
            builder:
                (context, state) => BlocProvider(
                  create: (_) => PanchayatBloc()..add(LoadPanchayats()),
                  child: const PanchayatManagement(),
                ),
          ),
          GoRoute(
            path: '/users',
            builder:
                (context, state) => MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) => UserMgmtBloc()..add(LoadUsers()),
                    ),
                    BlocProvider(
                      create: (_) => PanchayatBloc()..add(LoadPanchayats()),
                    ),
                  ],
                  child: const UserManagement(),
                ),
          ),
          GoRoute(
            path: '/complaints',
            builder: (context, state) {
              final query = state.uri.queryParameters['q'] ?? '';
              final openCreate = state.uri.queryParameters['action'] == 'new';
              final authState = authBloc.state;
              if (authState is Authenticated && authState.user.isSuperAdmin) {
                return BlocProvider(
                  create: (_) => SAComplaintBloc()..add(LoadSAComplaints()),
                  child: ComplaintManagement(
                    initialQuery: query,
                    openCreate: openCreate,
                  ),
                );
              }
              return BlocProvider(
                create: (_) => PAComplaintBloc()..add(LoadPAComplaints()),
                child: PAComplaintManagement(
                  initialQuery: query,
                  openCreate: openCreate,
                ),
              );
            },
          ),
          GoRoute(
            path: '/complaints/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return PAComplaintDetailScreen(complaintId: id);
            },
          ),
          GoRoute(
            path: '/superadmin/electricians',
            builder: (context, state) => const SuperAdminElectricianManagement(),
          ),
          GoRoute(
            path: '/superadmin/plumbers',
            builder: (context, state) => const SuperAdminPlumberManagement(),
          ),
          GoRoute(
            path: '/admin/electricians',
            builder: (context, state) => const PanchayatElectricianManagement(),
          ),
          GoRoute(
            path: '/admin/plumbers',
            builder: (context, state) => const PanchayatPlumberManagement(),
          ),
          GoRoute(
            path: '/fieldops/agents',
            builder:
                (context, state) => MultiBlocProvider(
                  providers: [
                    BlocProvider(
                      create: (_) => UserMgmtBloc()..add(LoadUsers()),
                    ),
                    BlocProvider(
                      create: (_) => PanchayatBloc()..add(LoadPanchayats()),
                    ),
                  ],
                  child: const AgentManagement(),
                ),
          ),
          GoRoute(
            path: '/ai-settings',
            builder:
                (context, state) => BlocProvider(
                  create: (_) => SettingsBloc()..add(LoadProviders()),
                  child: const AiSettingsScreen(),
                ),
          ),
          GoRoute(
            path: '/settings/document-templates',
            builder: (context, state) {
              final authState = authBloc.state;
              final isSuperAdmin =
                  authState is Authenticated && authState.user.isSuperAdmin;
              return DocumentTemplatesSettingsScreen(isSuperAdmin: isSuperAdmin);
            },
          ),

          // Voice & IVR
          GoRoute(
            path: '/voice-calls',
            builder: (context, state) => const VoiceCallsScreen(),
          ),
          GoRoute(
            path: '/ivr-logs',
            builder: (context, state) => const IvrLogsScreen(),
          ),
          GoRoute(
            path: '/analytics',
            builder: (context, state) => const AnalyticsScreen(),
          ),
          GoRoute(
            path: '/report-generation',
            builder: (context, state) => const ReportGenerationScreen(),
          ),

          // Panchayat Admin Routes
          GoRoute(
            path: '/poles',
            builder: (context, state) {
              final authState = authBloc.state;
              final isSuperAdmin =
                  authState is Authenticated && authState.user.isSuperAdmin;
              if (isSuperAdmin) {
                return const SuperAdminPoleManagement();
              }
              return BlocProvider(
                create: (_) => PoleBloc()..add(LoadPoles()),
                child: const PoleManagement(),
              );
            },
          ),
          GoRoute(
            path: '/pole-management',
            builder: (context, state) {
              final authState = authBloc.state;
              final isSuperAdmin =
                  authState is Authenticated && authState.user.isSuperAdmin;
              if (isSuperAdmin) {
                return const SuperAdminPoleManagement();
              }
              return BlocProvider(
                create: (_) => PoleBloc()..add(LoadPoles()),
                child: const PoleManagement(),
              );
            },
          ),
          GoRoute(
            path: '/poles/:id/qr-customizer',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return QrCustomizerScreen(poleId: id);
            },
          ),

          // Tender workflow (officer)
          GoRoute(
            path: '/tenders',
            builder: (context, state) => const TenderListScreen(),
          ),
          GoRoute(
            path: '/tenders/new',
            builder: (context, state) => const TenderCreateScreen(),
          ),
          GoRoute(
            path: '/tenders/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return TenderDetailScreen(tenderId: id);
            },
          ),
          GoRoute(
            path: '/vendors',
            builder: (context, state) => const VendorDirectoryScreen(),
          ),

          // Super Admin Tender workflow
          GoRoute(
            path: '/superadmin/tenders',
            builder: (context, state) => const TenderListScreen(isSuperAdmin: true),
          ),
          GoRoute(
            path: '/superadmin/tenders/new',
            builder: (context, state) => const TenderCreateScreen(isSuperAdmin: true),
          ),
          GoRoute(
            path: '/superadmin/tenders/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return TenderDetailScreen(tenderId: id, isSuperAdmin: true);
            },
          ),
          GoRoute(
            path: '/superadmin/vendors',
            builder: (context, state) => const VendorDirectoryScreen(isSuperAdmin: true),
          ),
          GoRoute(
            path: '/tenders/vendor-portal',
            builder: (context, state) => const VendorBiddingPortalScreen(),
          ),
          GoRoute(
            path: '/water/pipeline-grid',
            builder: (context, state) => const PipelineGridScreen(),
          ),
          GoRoute(
            path: '/water/tanks',
            builder: (context, state) => const TanksBorewellsScreen(),
          ),
          GoRoute(
            path: '/water/flow-logs',
            builder: (context, state) => const WaterFlowLogsScreen(),
          ),
          GoRoute(
            path: '/water/approvals',
            builder: (context, state) => const InfrastructureApprovalScreen(),
          ),
          
          // Revenue Generation Routes
          GoRoute(
            path: '/revenue/ads',
            builder: (context, state) => const AdCampaignScreen(),
          ),
          GoRoute(
            path: '/revenue/penalties',
            builder: (context, state) => const PenaltyManagementScreen(),
          ),
          GoRoute(
            path: '/revenue/property-tax',
            builder: (context, state) => const PropertyTaxScreen(),
          ),
          GoRoute(
            path: '/revenue/certificates',
            builder: (context, state) => const CertificateReviewScreen(),
          ),
          GoRoute(
            path: '/revenue/assets',
            builder: (context, state) => const AssetBookingScreen(),
          ),
          GoRoute(
            path: '/revenue/markets',
            builder: (context, state) => const MarketFeesScreen(),
          ),

          // Phase 6 — Contractor & Work Orders
          GoRoute(
            path: '/contractors',
            builder: (context, state) => const ContractorListScreen(),
          ),

          // Phase 7 — Field Inspections
          GoRoute(
            path: '/inspections',
            builder: (context, state) => const InspectionListScreen(),
          ),

          // Phase 9 — Universal Search
          GoRoute(
            path: '/search',
            builder: (context, state) => UniversalSearchScreen(
              initialQuery: state.uri.queryParameters['q'] ?? '',
            ),
          ),

          // Phase 9 — Citizen Portal
          GoRoute(
            path: '/citizen-portal',
            builder: (context, state) => const CitizenPortalScreen(),
          ),

          // Phase 11 — Municipality Modules
          GoRoute(
            path: '/municipality',
            builder: (context, state) => const MunicipalityScreen(),
          ),

          // ── Merged hubs ──
          //
          // Each of these replaces two to four sidebar entries that pointed at
          // views of the same job. The old routes still resolve so bookmarks
          // and deep links keep working; they simply open the hub on the right
          // tab.
          GoRoute(
            path: '/workforce',
            builder: (context, state) {
              final authState = authBloc.state;
              final isSuperAdmin =
                  authState is Authenticated && authState.user.isSuperAdmin;
              return FieldWorkforceHub(isSuperAdmin: isSuperAdmin);
            },
          ),
          GoRoute(
            path: '/voice-ivr',
            builder: (context, state) => const IvrOperationsHub(),
          ),
          GoRoute(
            path: '/water',
            builder: (context, state) => const WaterSupplyHub(),
          ),
          GoRoute(
            path: '/insights',
            builder: (context, state) => const InsightsHub(),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) {
              final authState = authBloc.state;
              final isSuperAdmin =
                  authState is Authenticated && authState.user.isSuperAdmin;
              return SystemSettingsHub(isSuperAdmin: isSuperAdmin);
            },
          ),

          // Screen Plan Specification Routes
          GoRoute(
            path: '/profile',
            builder: (context, state) => const PanchayatAdminProfileScreen(),
          ),
          GoRoute(
            path: '/panchayat-admin/profile',
            builder: (context, state) => const PanchayatAdminProfileScreen(),
          ),
          GoRoute(
            path: '/select-context',
            builder: (context, state) => const ContextSelectorScreen(),
          ),
          GoRoute(
            path: '/profile/employee',
            builder: (context, state) => const EmployeeServiceBookScreen(),
          ),
          GoRoute(
            path: '/admin/tenants',
            builder: (context, state) => BlocProvider(
              create: (_) => TenantBloc()..add(LoadTenants()),
              child: const TenantManagementScreen(),
            ),
          ),
          GoRoute(
            path: '/admin/employees',
            builder: (context, state) => const EmployeeDirectoryScreen(),
          ),
          GoRoute(
            path: '/admin/employees/:id/history',
            builder: (context, state) => DesignationTransferTimelineScreen(
              empId: state.pathParameters['id'] ?? 'EMP-00042',
            ),
          ),
          GoRoute(
            path: '/admin/rbac/user-assignments',
            redirect: (_, __) => '/superadmin/roles',
          ),
          GoRoute(
            path: '/analytics/sla',
            builder: (context, state) => const SlaAnalyticsScreen(),
          ),
          GoRoute(
            path: '/documents',
            builder: (context, state) => const DmsExplorerScreen(),
          ),
          GoRoute(
            path: '/admin/audit-logs',
            builder: (context, state) => const AuditLogInspectorScreen(),
          ),
          GoRoute(
            path: '/municipality/solid-waste',
            builder: (context, state) => const SolidWasteScreen(),
          ),
          GoRoute(
            path: '/municipality/health',
            builder: (context, state) => const PublicHealthScreen(),
          ),

          // Phase 11 — Building Permits & Plan Approval
          GoRoute(
            path: '/municipality/building-permits',
            builder: (context, state) => const BuildingPermitListScreen(),
          ),
          // Declared before the `:id` route so "new" isn't parsed as an id.
          GoRoute(
            path: '/municipality/building-permits/new',
            builder: (context, state) => const BuildingPermitFormScreen(),
          ),
          GoRoute(
            path: '/municipality/building-permits/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const BuildingPermitListScreen();
              return BuildingPermitDetailScreen(permitId: id);
            },
          ),
          GoRoute(
            path: '/municipality/building-permits/:id/edit',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const BuildingPermitListScreen();
              return BuildingPermitFormScreen(permitId: id);
            },
          ),

          // Phase 11 — Birth & Death Registration
          GoRoute(
            path: '/municipality/vital-events',
            builder: (context, state) => const VitalEventsRegistryScreen(),
          ),
          // Declared before the `:id` route so "new" isn't parsed as an id.
          GoRoute(
            path: '/municipality/vital-events/new',
            builder: (context, state) => VitalEventFormScreen(
              eventType: VitalEventType.parse(
                state.uri.queryParameters['type'],
              ),
            ),
          ),
          GoRoute(
            path: '/municipality/vital-events/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const VitalEventsRegistryScreen();
              return VitalEventDetailScreen(eventId: id);
            },
          ),

          // Phase 11 — Trade Licence & Renewal
          GoRoute(
            path: '/municipality/trade-licences',
            builder: (context, state) => const TradeLicenceRegisterScreen(),
          ),
          // The renewal board is the register filtered to the queue, so it
          // shares a screen rather than duplicating one.
          GoRoute(
            path: '/municipality/trade-licences/renewals',
            builder: (context, state) =>
                const TradeLicenceRegisterScreen(renewalMode: true),
          ),
          GoRoute(
            path: '/municipality/trade-licences/new',
            builder: (context, state) => const TradeLicenceFormScreen(),
          ),
          GoRoute(
            path: '/municipality/trade-licences/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const TradeLicenceRegisterScreen();
              return TradeLicenceDetailScreen(licenceId: id);
            },
          ),
          GoRoute(
            path: '/municipality/trade-licences/:id/edit',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              if (id == null) return const TradeLicenceRegisterScreen();
              return TradeLicenceFormScreen(licenceId: id);
            },
          ),
        ],
      ),
    ],
  );
}

String _getTitle(String location) {
  switch (location) {
    case '/agent':
      return 'Agent — Home';
    case '/agent/poles':
      return 'Agent — Poles';
    case '/agent/poles/add':
      return 'Agent — New pole';
    case '/electrician':
      return 'Electrician — Home';
    case '/electrician/jobs':
      return 'Electrician — Jobs';
    case '/plumber':
      return 'Plumber — Home';
    case '/plumber/jobs':
      return 'Plumber — Jobs';
    case '/dashboard':
      return 'Dashboard';
    case '/panchayats':
      return 'Panchayat Management';
    case '/users':
      return 'User Management';
    case '/complaints':
      return 'Complaint Management';
    case '/superadmin/electricians':
    case '/admin/electricians':
      return 'Field electricians';
    case '/superadmin/plumbers':
    case '/admin/plumbers':
      return 'Field plumbers';
    case '/fieldops/agents':
      return 'Field agents';
    case '/ai-settings':
      return 'AI Settings';
    case '/settings/document-templates':
      return 'Document templates';
    case '/poles':
      return 'Pole Management';
	case '/pole-management':
	  return 'Pole Management';
	case '/voice-calls':
	  return 'Voice Calls';
	case '/ivr-logs':
	  return 'IVR Logs';
	case '/analytics':
	  return 'Analytics';
    case '/report-generation':
      return 'Report Generation';
    case '/zone-management':
      return 'Zone Management';
    case '/settings/customization':
      return 'Customization';
    case '/tenders':
    case '/superadmin/tenders':
      return 'Tenders';
    case '/tenders/new':
    case '/superadmin/tenders/new':
      return 'New tender';
    case '/vendors':
    case '/superadmin/vendors':
      return 'Vendor directory';
    case '/tenders/vendor-portal':
      return 'Vendor Bidding Portal';
    case '/water/pipeline-grid':
      return 'Pipeline Grid';
    case '/water/tanks':
      return 'Tanks & Borewells';
    case '/water/flow-logs':
      return 'Water Flow Logs';
    case '/agent/pipeline-tap-capture':
      return 'Agent — Pipeline & Tap Capture';
    case '/water/approvals':
      return 'Infrastructure Approvals';
    case '/revenue/ads':
      return 'Ad Campaigns';
    case '/revenue/penalties':
      return 'Technician Penalties';
    case '/revenue/property-tax':
      return 'Property Tax Collection';
    case '/revenue/certificates':
      return 'Certificate Reviews';
    case '/revenue/assets':
      return 'Community Asset Rental';
    case '/revenue/markets':
      return 'Market Stall Fees';
    case '/contractors':
      return 'Contractor Management';
    case '/inspections':
      return 'Field Inspections';
    case '/search':
      return 'Universal Search';
    case '/citizen-portal':
      return 'Citizen Portal';
    case '/municipality':
      return 'Municipality Modules';
    case '/municipality/solid-waste':
      return 'Solid Waste Management';
    case '/municipality/health':
      return 'Public Health & Sanitation';
    case '/municipality/building-permits':
      return 'Building Permits';
    case '/municipality/building-permits/new':
      return 'New building permit';
    case '/municipality/vital-events':
      return 'Birth & Death Register';
    case '/municipality/vital-events/new':
      return 'Report a birth or death';
    case '/municipality/trade-licences':
      return 'Trade Licences';
    case '/municipality/trade-licences/renewals':
      return 'Licence Renewals';
    case '/municipality/trade-licences/new':
      return 'New trade licence';
    case '/workforce':
      return 'Field workforce';
    case '/voice-ivr':
      return 'Voice & IVR';
    case '/water':
      return 'Water Supply';
    case '/insights':
      return 'Reports & analytics';
    case '/settings':
      return 'Settings';
    default:
      if (location.startsWith('/municipality/trade-licences/')) {
        return location.endsWith('/edit')
            ? 'Edit trade licence'
            : 'Trade licence';
      }
      if (location.startsWith('/municipality/building-permits/')) {
        return location.endsWith('/edit')
            ? 'Edit building permit'
            : 'Building permit';
      }
      if (location.startsWith('/municipality/vital-events/')) {
        return 'Register entry';
      }
      if (location.startsWith('/tenders/') || location.startsWith('/superadmin/tenders/')) return 'Tender detail';
      if (location.startsWith('/agent/poles/')) return 'Pole detail';
      if (location.startsWith('/electrician/jobs/') || location.startsWith('/plumber/jobs/')) return 'Complaint';
      return 'Ooraatchi';
  }
}

// Go router refresh notifier from stream
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final dynamic _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
