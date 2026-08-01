import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../config/api_config.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/models/user_model.dart';
import '../data/auth_repository.dart';
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
        panchayatId: response.user.panchayatId,
      );
      await SecureStorageService.saveUserJson(jsonEncode(response.user.toJson()));
      emit(Authenticated(user: response.user, token: response.accessToken));
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
        panchayatId: response.user.panchayatId,
      );
      await SecureStorageService.saveUserJson(jsonEncode(response.user.toJson()));
      emit(Authenticated(user: response.user, token: response.accessToken));
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
        final panchayatId = await SecureStorageService.getPanchayatId();
        if (role != null && email != null && userId != null) {
          initialUser = UserModel(
            id: userId,
            email: email,
            role: role,
            panchayatId: panchayatId,
          );
        }
      }

      if (initialUser != null) {
        emit(Authenticated(user: initialUser, token: token));

        // Re-sync fresh profile and dynamic branding from database
        try {
          final freshData = await ApiClient.instance.get(ApiConfig.paMe);
          if (freshData is Map<String, dynamic>) {
            final freshUser = UserModel.fromJson(freshData);
            await SecureStorageService.saveUserJson(jsonEncode(freshUser.toJson()));
            emit(Authenticated(user: freshUser, token: token));
          }
        } catch (_) {
          // Keep cached initial user if server fetch is unavailable
        }
        return;
      }
    }

    emit(Unauthenticated());
  }
}
