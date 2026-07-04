import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/bloc/auth_bloc.dart';
import '../features/zone_management/bloc/zone_bloc.dart';
import '../features/zone_management/presentation/zone_management_screen.dart';
import '../features/customization/presentation/screens/admin_customization_screen.dart';
import '../features/auth/bloc/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/citizen/presentation/screens/citizen_register_screen.dart';
import '../features/citizen/presentation/screens/citizen_dashboard_screen.dart';

import '../features/super_admin/bloc/dashboard_bloc.dart';
import '../features/super_admin/bloc/panchayat_bloc.dart';
import '../features/super_admin/bloc/user_bloc.dart';
import '../features/super_admin/bloc/complaint_bloc.dart';
import '../features/super_admin/bloc/settings_bloc.dart';
import '../features/super_admin/presentation/screens/super_admin_dashboard.dart';
import '../features/super_admin/presentation/screens/panchayat_management.dart';
import '../features/super_admin/presentation/screens/user_management.dart';
import '../features/super_admin/presentation/screens/complaint_management.dart';
import '../features/super_admin/presentation/screens/ai_settings_screen.dart';
import '../features/document_templates/presentation/document_templates_settings_screen.dart';
import '../features/super_admin/presentation/screens/voice_calls_screen.dart';
import '../features/super_admin/presentation/screens/ivr_logs_screen.dart';
import '../features/super_admin/presentation/screens/analytics_screen.dart';
import '../features/reports/presentation/report_generation_screen.dart';
import '../features/super_admin/presentation/screens/super_admin_pole_management.dart';
import '../features/super_admin/presentation/screens/agent_management.dart';
import '../features/super_admin/presentation/screens/electrician_management.dart';
import '../features/super_admin/presentation/screens/plumber_management.dart';

import '../features/panchayat_admin/bloc/pa_dashboard_bloc.dart';
import '../features/panchayat_admin/bloc/pole_bloc.dart';
import '../features/panchayat_admin/bloc/pa_complaint_bloc.dart';
import '../features/panchayat_admin/presentation/screens/pa_dashboard.dart';
import '../features/panchayat_admin/presentation/screens/pole_management.dart';
import '../features/panchayat_admin/presentation/screens/pa_complaint_management.dart';
import '../features/panchayat_admin/presentation/screens/electrician_management.dart';
import '../features/panchayat_admin/presentation/screens/plumber_management.dart';
import '../features/panchayat_admin/presentation/screens/pa_complaint_detail.dart';

import '../features/agent/presentation/screens/agent_dashboard_screen.dart';
import '../features/agent/presentation/screens/agent_pole_list_screen.dart';
import '../features/agent/presentation/screens/agent_pole_detail_screen.dart';
import '../features/agent/presentation/screens/agent_add_pole_screen.dart';
import '../features/electrician/presentation/screens/electrician_dashboard_screen.dart';
import '../features/electrician/presentation/screens/electrician_jobs_screen.dart';
import '../features/electrician/presentation/screens/electrician_complaint_detail_screen.dart';
import '../features/plumber/presentation/screens/plumber_dashboard_screen.dart';
import '../features/plumber/presentation/screens/plumber_jobs_screen.dart';
import '../features/plumber/presentation/screens/plumber_complaint_detail_screen.dart';

import '../features/tenders/presentation/screens/tender_list_screen.dart';
import '../features/tenders/presentation/screens/tender_create_screen.dart';
import '../features/tenders/presentation/screens/tender_detail_screen.dart';
import '../features/tenders/presentation/screens/vendor_directory_screen.dart';
import '../features/tenders/presentation/screens/public_tender_screen.dart';
import '../features/tenders/presentation/screens/invite_tender_screen.dart';
import '../features/tenders/presentation/screens/public_field_upload_screen.dart';
import '../features/tenders/presentation/screens/vendor_bidding_portal_screen.dart';

import '../features/water_supply/presentation/screens/pipeline_grid_screen.dart';
import '../features/water_supply/presentation/screens/tanks_borewells_screen.dart';
import '../features/water_supply/presentation/screens/water_flow_logs_screen.dart';
import '../features/agent/presentation/screens/agent_pipeline_tap_capture_screen.dart';
import '../features/water_supply/presentation/screens/infrastructure_approval_screen.dart';

import '../core/widgets/app_scaffold.dart';
import '../features/auth/bloc/auth_event.dart';

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
      if (isLoginRoute) return _homeForRole(authed);

      final u = authed.user;
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
          // Dashboard
          GoRoute(
            path: '/dashboard',
            builder: (context, state) {
              final authState = authBloc.state;
              if (authState is Authenticated && authState.user.isSuperAdmin) {
                return BlocProvider(
                  create: (_) => SADashBloc()..add(LoadSADashboard()),
                  child: const SuperAdminDashboard(),
                );
              }
              return BlocProvider(
                create: (_) => PADashBloc()..add(LoadPADashboard()),
                child: const PADashboard(),
              );
            },
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
    default:
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
