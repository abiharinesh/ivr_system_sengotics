import 'package:equatable/equatable.dart';
import 'package:ivr_frontend/core/models/user_model.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;

  const LoginRequested({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

/// Set a new password for the signed-in user.
///
/// On success the reissued token replaces the stored one and the
/// `must_change_password` flag clears, which is what releases the router's
/// hold on the change-password screen.
class PasswordChangeRequested extends AuthEvent {
  final String currentPassword;
  final String newPassword;

  const PasswordChangeRequested({
    required this.currentPassword,
    required this.newPassword,
  });

  @override
  List<Object?> get props => [currentPassword, newPassword];
}

class LogoutRequested extends AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class UpdateAuthUser extends AuthEvent {
  final UserModel user;
  const UpdateAuthUser(this.user);

  @override
  List<Object?> get props => [user];
}

/// Switch the active role/org-unit context to one of the user's other
/// UserRole assignments (see [UserModel.roleAssignments]).
class SwitchContextRequested extends AuthEvent {
  final int userRoleId;
  const SwitchContextRequested(this.userRoleId);

  @override
  List<Object?> get props => [userRoleId];
}
