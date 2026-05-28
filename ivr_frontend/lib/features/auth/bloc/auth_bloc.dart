import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../models/user_model.dart';
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
    final role = await SecureStorageService.getRole();
    final email = await SecureStorageService.getEmail();
    final userId = await SecureStorageService.getUserId();
    final panchayatId = await SecureStorageService.getPanchayatId();

    if (token != null && role != null && email != null && userId != null) {
      emit(
        Authenticated(
          user: UserModel(
            id: userId,
            email: email,
            role: role,
            panchayatId: panchayatId,
          ),
          token: token,
        ),
      );
    } else {
      emit(Unauthenticated());
    }
  }
}
