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

import '../features/panchayat_admin/bloc/pa_dashboard_bloc.dart';
import '../features/panchayat_admin/bloc/pole_bloc.dart';
import '../features/panchayat_admin/bloc/pa_complaint_bloc.dart';
import '../features/panchayat_admin/presentation/pa_dashboard.dart';
import '../features/panchayat_admin/presentation/pole_management.dart';
import '../features/panchayat_admin/presentation/pa_complaint_management.dart';

import '../core/widgets/app_scaffold.dart';
import '../features/auth/bloc/auth_event.dart';

GoRouter createRouter(AuthBloc authBloc) {
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(authBloc.stream),
    redirect: (context, state) {
      final authState = authBloc.state;
      final isLoggedIn = authState is Authenticated;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
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
            builder: (context, state) => BlocProvider(
              create: (_) => PanchayatBloc()..add(LoadPanchayats()),
              child: const PanchayatManagement(),
            ),
          ),
          GoRoute(
            path: '/users',
            builder: (context, state) => MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => UserMgmtBloc()..add(LoadUsers())),
                BlocProvider(create: (_) => PanchayatBloc()..add(LoadPanchayats())),
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
                  create: (_) =>
                      SAComplaintBloc()..add(LoadSAComplaints()),
                  child: const ComplaintManagement(),
                );
              }
              return BlocProvider(
                create: (_) =>
                    PAComplaintBloc()..add(LoadPAComplaints()),
                child: const PAComplaintManagement(),
              );
            },
          ),
          GoRoute(
            path: '/ai-settings',
            builder: (context, state) => BlocProvider(
              create: (_) => SettingsBloc()..add(LoadAiProvider()),
              child: const AiSettingsScreen(),
            ),
          ),

          // Panchayat Admin Routes
          GoRoute(
            path: '/poles',
            builder: (context, state) => BlocProvider(
              create: (_) => PoleBloc()..add(LoadPoles()),
              child: const PoleManagement(),
            ),
          ),
        ],
      ),
    ],
  );
}

String _getTitle(String location) {
  switch (location) {
    case '/dashboard':
      return 'Dashboard';
    case '/panchayats':
      return 'Panchayat Management';
    case '/users':
      return 'User Management';
    case '/complaints':
      return 'Complaint Management';
    case '/ai-settings':
      return 'AI Settings';
    case '/poles':
      return 'Pole Management';
    default:
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
