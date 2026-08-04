import 'package:equatable/equatable.dart';
import 'package:ivr_frontend/core/models/user_model.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class Authenticated extends AuthState {
  final UserModel user;
  final String token;

  const Authenticated({required this.user, required this.token});

  @override
  List<Object?> get props => [user, token];
}

/// Emitted once immediately before the [Authenticated] state that follows a
/// successful password change, so the screen can acknowledge it. A transient
/// signal, not a state anything rests in.
class PasswordChanged extends AuthState {
  final UserModel user;
  final String token;

  const PasswordChanged({required this.user, required this.token});

  @override
  List<Object?> get props => [user, token];
}

class Unauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  const AuthError(this.message);

  @override
  List<Object?> get props => [message];
}
