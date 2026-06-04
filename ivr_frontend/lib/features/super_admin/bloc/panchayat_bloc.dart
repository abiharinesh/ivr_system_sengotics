import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/panchayat_model.dart';
import '../data/super_admin_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────
abstract class PanchayatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPanchayats extends PanchayatEvent {}

class CreatePanchayat extends PanchayatEvent {
  final Map<String, dynamic> data;
  CreatePanchayat(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdatePanchayat extends PanchayatEvent {
  final int id;
  final Map<String, dynamic> data;
  UpdatePanchayat(this.id, this.data);
  @override
  List<Object?> get props => [id, data];
}

class DeletePanchayat extends PanchayatEvent {
  final int id;
  DeletePanchayat(this.id);
  @override
  List<Object?> get props => [id];
}

// ── States ────────────────────────────────────────────────────────────────
abstract class PanchayatState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PanchayatInitial extends PanchayatState {}

class PanchayatLoading extends PanchayatState {}

class PanchayatLoaded extends PanchayatState {
  final List<PanchayatModel> panchayats;
  PanchayatLoaded(this.panchayats);
  @override
  List<Object?> get props => [panchayats];
}

class PanchayatActionSuccess extends PanchayatState {
  final String message;
  PanchayatActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class PanchayatError extends PanchayatState {
  final String message;
  PanchayatError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────
class PanchayatBloc extends Bloc<PanchayatEvent, PanchayatState> {
  final SuperAdminRepository _repo;

  PanchayatBloc({SuperAdminRepository? repo})
    : _repo = repo ?? SuperAdminRepository(),
      super(PanchayatInitial()) {
    on<LoadPanchayats>(_onLoad);
    on<CreatePanchayat>(_onCreate);
    on<UpdatePanchayat>(_onUpdate);
    on<DeletePanchayat>(_onDelete);
  }

  Future<void> _onLoad(
    LoadPanchayats event,
    Emitter<PanchayatState> emit,
  ) async {
    emit(PanchayatLoading());
    try {
      final data = await _repo.listPanchayats();
      emit(PanchayatLoaded(data));
    } on ApiException catch (e) {
      emit(PanchayatError(e.message));
    }
  }

  Future<void> _onCreate(
    CreatePanchayat event,
    Emitter<PanchayatState> emit,
  ) async {
    try {
      await _repo.createPanchayat(event.data);
      emit(PanchayatActionSuccess('Panchayat created successfully'));
      add(LoadPanchayats());
    } on ApiException catch (e) {
      emit(PanchayatError(e.message));
    }
  }

  Future<void> _onUpdate(
    UpdatePanchayat event,
    Emitter<PanchayatState> emit,
  ) async {
    try {
      await _repo.updatePanchayat(event.id, event.data);
      emit(PanchayatActionSuccess('Panchayat updated successfully'));
      add(LoadPanchayats());
    } on ApiException catch (e) {
      emit(PanchayatError(e.message));
    }
  }

  Future<void> _onDelete(
    DeletePanchayat event,
    Emitter<PanchayatState> emit,
  ) async {
    try {
      await _repo.deletePanchayat(event.id);
      emit(PanchayatActionSuccess('Panchayat deleted successfully'));
      add(LoadPanchayats());
    } on ApiException catch (e) {
      emit(PanchayatError(e.message));
    }
  }
}
