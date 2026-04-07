import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/bloc/auth_bloc.dart';
import '../features/auth/bloc/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';

import '../features/super_admin/bloc/dashboard_bloc.dart';
import '../features/super_admin/bloc/panchayat_bloc.dart';
import '../features/super_admin/bloc/user_bloc.dart';
import '../features/super_admin/bloc/complaint_bloc.dart';
import '../features/super_admin/bloc/settings_bloc.dart';
import '../features/super_admin/presentation/super_admin_dashboard.dart';
import '../features/super_admin/presentation/panchayat_management.dart';
import '../features/super_admin/presentation/user_management.dart';
import '../features/super_admin/presentation/complaint_management.dart';
import '../features/super_admin/presentation/ai_settings_screen.dart';
import '../features/super_admin/presentation/voice_calls_screen.dart';
import '../features/super_admin/presentation/ivr_logs_screen.dart';
import '../features/super_admin/presentation/analytics_screen.dart';
import '../features/super_admin/presentation/super_admin_pole_management.dart';
import '../features/super_admin/presentation/agent_management.dart';
import '../features/super_admin/presentation/electrician_management.dart';

import '../features/panchayat_admin/bloc/pa_dashboard_bloc.dart';
import '../features/panchayat_admin/bloc/pole_bloc.dart';
import '../features/panchayat_admin/bloc/pa_complaint_bloc.dart';
import '../features/panchayat_admin/presentation/pa_dashboard.dart';
import '../features/panchayat_admin/presentation/pole_management.dart';
import '../features/panchayat_admin/presentation/pa_complaint_management.dart';
import '../features/panchayat_admin/presentation/electrician_management.dart';

import '../features/agent/presentation/agent_dashboard_screen.dart';
import '../features/agent/presentation/agent_pole_list_screen.dart';
import '../features/agent/presentation/agent_pole_detail_screen.dart';
import '../features/agent/presentation/agent_add_pole_screen.dart';
import '../features/electrician/presentation/electrician_dashboard_screen.dart';
import '../features/electrician/presentation/electrician_jobs_screen.dart';
import '../features/electrician/presentation/electrician_complaint_detail_screen.dart';

import '../core/widgets/app_scaffold.dart';
import '../features/auth/bloc/auth_event.dart';

String _homeForRole(Authenticated auth) {
  final u = auth.user;
  if (u.isSuperAdmin || u.isPanchayatAdmin) return '/dashboard';
  if (u.isAgent) return '/agent';
  if (u.isElectrician) return '/electrician';
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

      if (authState is! Authenticated) {
        return isLoginRoute ? null : '/login';
      }

      final authed = authState;
      if (isLoginRoute) return _homeForRole(authed);

      final u = authed.user;
      if (u.isAgent || u.isElectrician) {
        if (u.isAgent && !loc.startsWith('/agent')) return '/agent';
        if (u.isElectrician && !loc.startsWith('/electrician')) return '/electrician';
      }

      if ((u.isSuperAdmin || u.isPanchayatAdmin) && (loc.startsWith('/agent') || loc.startsWith('/electrician'))) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
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
            builder: (context, state) => const AgentPoleListScreen(),
          ),
          GoRoute(
            path: '/agent/poles/add',
            builder: (context, state) => const AgentAddPoleScreen(),
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
            builder: (context, state) => const ElectricianJobsScreen(),
          ),
          GoRoute(
            path: '/electrician/jobs/:id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              return ElectricianComplaintDetailScreen(complaintId: id);
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
              final authState = authBloc.state;
              if (authState is Authenticated && authState.user.isSuperAdmin) {
                return BlocProvider(
                  create: (_) => SAComplaintBloc()..add(LoadSAComplaints()),
                  child: const ComplaintManagement(),
                );
              }
              return BlocProvider(
                create: (_) => PAComplaintBloc()..add(LoadPAComplaints()),
                child: const PAComplaintManagement(),
              );
            },
          ),
          GoRoute(
            path: '/superadmin/electricians',
            builder: (context, state) => const SuperAdminElectricianManagement(),
          ),
          GoRoute(
            path: '/admin/electricians',
            builder: (context, state) => const PanchayatElectricianManagement(),
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
    case '/fieldops/agents':
      return 'Field agents';
    case '/ai-settings':
      return 'AI Settings';
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
    default:
      if (location.startsWith('/agent/poles/')) return 'Pole detail';
      if (location.startsWith('/electrician/jobs/')) return 'Complaint';
      return 'IVR System';
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
