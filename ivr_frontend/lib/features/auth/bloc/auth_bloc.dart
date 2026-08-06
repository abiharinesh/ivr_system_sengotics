import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ivr_frontend/core/api/api_client.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/config/api_config.dart';
import 'package:ivr_frontend/core/storage/secure_storage.dart';
import 'package:ivr_frontend/core/models/user_model.dart';
import 'package:ivr_frontend/core/navigation/role_navigation_config.dart'
    show NavScreen;
import 'package:ivr_frontend/features/auth/data/auth_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;

  AuthBloc({AuthRepository? authRepository})
    : _authRepository = authRepository ?? AuthRepository(),
      super(AuthInitial()) {
    on<LoginRequested>(_onLogin);
    on<LogoutRequested>(_onLogout);
    on<AuthCheckRequested>(_onAuthCheck);
    on<UpdateAuthUser>(_onUpdateUser);
    on<SwitchContextRequested>(_onSwitchContext);
    on<PasswordChangeRequested>(_onPasswordChange);
  }

  /// Fill in what the sidebar needs to draw itself.
  ///
  /// The token carries screen *keys*, which is enough for the guards and small
  /// enough not to grow the token every time a module ships. Drawing a menu
  /// needs the route, label, icon and group as well, and those come from
  /// `/api/rbac/me/entitlements` — the one place that resolves the tenant's
  /// plan, the branch's provisioning and the role's grants together.
  ///
  /// Non-throwing on purpose. A user whose entitlements request fails keeps
  /// whatever was cached from last time; signing them out of their own menu
  /// because one request timed out would be worse than a slightly stale one.
  Future<UserModel> _withEntitlements(UserModel user) async {
    try {
      final data = await ApiClient.instance.get(ApiConfig.myEntitlements);
      if (data is! Map<String, dynamic>) return user;

      final nav = (data['nav'] as List<dynamic>?)
          ?.map((e) => NavScreen.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      final screens = (data['screens'] as List<dynamic>?)?.cast<String>();
      if (nav == null && screens == null) return user;

      return user.copyWith(nav: nav, screens: screens);
    } catch (_) {
      return user;
    }
  }

  /// Persist and emit, with the sidebar's data attached.
  Future<void> _settle(
    UserModel user,
    String token,
    Emitter<AuthState> emit,
  ) async {
    final resolved = await _withEntitlements(user);
    await SecureStorageService.saveUserJson(jsonEncode(resolved.toJson()));
    emit(Authenticated(user: resolved, token: token));
  }

  Future<void> _onPasswordChange(
    PasswordChangeRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! Authenticated) return;

    emit(AuthLoading());
    try {
      final token = await _authRepository.changePassword(
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );
      // The reissued token was minted after the flag cleared; keeping the old
      // one would have the client asserting a state the server has left.
      await SecureStorageService.saveToken(token);

      final user = currentState.user.copyWith(mustChangePassword: false);
      await SecureStorageService.saveUserJson(jsonEncode(user.toJson()));
      emit(PasswordChanged(user: user, token: token));
      emit(Authenticated(user: user, token: token));
    } on ApiException catch (e) {
      emit(AuthError(e.message));
      // Return to the authenticated state so the screen stays usable and the
      // user can correct the password rather than being thrown out.
      emit(currentState);
    } catch (_) {
      emit(const AuthError('Could not change your password. Please try again.'));
      emit(currentState);
    }
  }

  Future<void> _onSwitchContext(
    SwitchContextRequested event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! Authenticated) return;
    try {
      final response = await _authRepository.switchContext(event.userRoleId);
      await SecureStorageService.saveToken(response.accessToken);
      await SecureStorageService.saveUserInfo(
        role: response.user.role,
        email: response.user.email,
        userId: response.user.id,
        orgUnitId: response.user.orgUnitId,
      );
      await _settle(response.user, response.accessToken, emit);
    } on ApiException catch (e) {
      emit(AuthError(e.message));
      emit(currentState);
    }
  }

  Future<void> _onUpdateUser(UpdateAuthUser event, Emitter<AuthState> emit) async {
    final currentState = state;
    if (currentState is Authenticated) {
      await SecureStorageService.saveUserJson(jsonEncode(event.user.toJson()));
      emit(Authenticated(user: event.user, token: currentState.token));
    }
  }

  UserModel? get currentUser {
    final s = state;
    if (s is Authenticated) return s.user;
    return null;
  }

  Future<void> _onLogin(LoginRequested event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await _authRepository.login(event.email, event.password);
      await SecureStorageService.saveToken(response.accessToken);
      await SecureStorageService.saveUserInfo(
        role: response.user.role,
        email: response.user.email,
        userId: response.user.id,
        orgUnitId: response.user.orgUnitId,
      );
      await _settle(response.user, response.accessToken, emit);
    } on ApiException catch (e) {
      emit(AuthError(e.message));
    } catch (e) {
      emit(const AuthError('Login failed. Please try again.'));
    }
  }

  Future<void> _onLogout(LogoutRequested event, Emitter<AuthState> emit) async {
    await SecureStorageService.clearAll();
    emit(Unauthenticated());
  }

  Future<void> _onAuthCheck(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    final token = await SecureStorageService.getToken();
    final userJsonStr = await SecureStorageService.getUserJson();

    if (token != null) {
      UserModel? initialUser;
      if (userJsonStr != null) {
        try {
          final userMap = jsonDecode(userJsonStr) as Map<String, dynamic>;
          initialUser = UserModel.fromJson(userMap);
        } catch (_) {}
      }

      if (initialUser == null) {
        final role = await SecureStorageService.getRole();
        final email = await SecureStorageService.getEmail();
        final userId = await SecureStorageService.getUserId();
        final orgUnitId = await SecureStorageService.getPanchayatId();
        if (role != null && email != null && userId != null) {
          initialUser = UserModel(
            id: userId,
            email: email,
            role: role,
            orgUnitId: orgUnitId,
          );
        }
      }

      if (initialUser != null) {
        // The cached user carries the sidebar it had last time, so the menu
        // paints on the first frame instead of appearing a request later.
        emit(Authenticated(user: initialUser, token: token));

        // Re-sync fresh profile and dynamic branding from database.
        try {
          final freshData = await ApiClient.instance.get(ApiConfig.paMe);
          if (freshData is Map<String, dynamic>) {
            // Through `_settle`, because this endpoint returns the profile and
            // branding but not the resolved menu — emitting its result
            // directly would replace a user who has a sidebar with one who
            // has none, and blank the rail on every reload.
            await _settle(UserModel.fromJson(freshData), token, emit);
          }
        } catch (_) {
          // Keep the cached user if the server is unavailable.
        }
        return;
      }
    }

    emit(Unauthenticated());
  }
}
