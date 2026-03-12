import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../models/user_model.dart';
import '../data/super_admin_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────
abstract class UserMgmtEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadUsers extends UserMgmtEvent {}

class CreateUser extends UserMgmtEvent {
  final Map<String, dynamic> data;
  CreateUser(this.data);
  @override
  List<Object?> get props => [data];
}

class DeleteUser extends UserMgmtEvent {
  final int id;
  DeleteUser(this.id);
  @override
  List<Object?> get props => [id];
}

// ── States ────────────────────────────────────────────────────────────────
abstract class UserMgmtState extends Equatable {
  @override
  List<Object?> get props => [];
}

class UserMgmtInitial extends UserMgmtState {}

class UserMgmtLoading extends UserMgmtState {}

class UserMgmtLoaded extends UserMgmtState {
  final List<UserModel> users;
  UserMgmtLoaded(this.users);
  @override
  List<Object?> get props => [users];
}

class UserMgmtActionSuccess extends UserMgmtState {
  final String message;
  UserMgmtActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class UserMgmtError extends UserMgmtState {
  final String message;
  UserMgmtError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────
class UserMgmtBloc extends Bloc<UserMgmtEvent, UserMgmtState> {
  final SuperAdminRepository _repo;

  UserMgmtBloc({SuperAdminRepository? repo})
    : _repo = repo ?? SuperAdminRepository(),
      super(UserMgmtInitial()) {
    on<LoadUsers>(_onLoad);
    on<CreateUser>(_onCreate);
    on<DeleteUser>(_onDelete);
  }

  Future<void> _onLoad(LoadUsers event, Emitter<UserMgmtState> emit) async {
    emit(UserMgmtLoading());
    try {
      final data = await _repo.listUsers();
      emit(UserMgmtLoaded(data));
    } on ApiException catch (e) {
      emit(UserMgmtError(e.message));
    }
  }

  Future<void> _onCreate(CreateUser event, Emitter<UserMgmtState> emit) async {
    try {
      await _repo.createUser(event.data);
      emit(UserMgmtActionSuccess('Admin user created successfully'));
      add(LoadUsers());
    } on ApiException catch (e) {
      emit(UserMgmtError(e.message));
    }
  }

  Future<void> _onDelete(DeleteUser event, Emitter<UserMgmtState> emit) async {
    try {
      await _repo.deleteUser(event.id);
      emit(UserMgmtActionSuccess('User deleted'));
      add(LoadUsers());
    } on ApiException catch (e) {
      emit(UserMgmtError(e.message));
    }
  }
}
