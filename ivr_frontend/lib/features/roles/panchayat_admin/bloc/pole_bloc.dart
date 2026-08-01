import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/models/pole_model.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/data/panchayat_admin_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────
abstract class PoleEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPoles extends PoleEvent {}

class CreatePole extends PoleEvent {
  final Map<String, dynamic> data;
  CreatePole(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdatePole extends PoleEvent {
  final int id;
  final Map<String, dynamic> data;
  UpdatePole(this.id, this.data);
  @override
  List<Object?> get props => [id, data];
}

class DeletePole extends PoleEvent {
  final int id;
  DeletePole(this.id);
  @override
  List<Object?> get props => [id];
}

// ── States ────────────────────────────────────────────────────────────────
abstract class PoleState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PoleInitial extends PoleState {}

class PoleLoading extends PoleState {}

class PoleLoaded extends PoleState {
  final List<PoleModel> poles;
  PoleLoaded(this.poles);
  @override
  List<Object?> get props => [poles];
}

class PoleActionSuccess extends PoleState {
  final String message;
  PoleActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class PoleError extends PoleState {
  final String message;
  PoleError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────
class PoleBloc extends Bloc<PoleEvent, PoleState> {
  final PanchayatAdminRepository _repo;

  PoleBloc({PanchayatAdminRepository? repo})
    : _repo = repo ?? PanchayatAdminRepository(),
      super(PoleInitial()) {
    on<LoadPoles>(_onLoad);
    on<CreatePole>(_onCreate);
    on<UpdatePole>(_onUpdate);
    on<DeletePole>(_onDelete);
  }

  Future<void> _onLoad(LoadPoles event, Emitter<PoleState> emit) async {
    final cached = _repo.getCachedPoles();
    if (cached != null) {
      emit(PoleLoaded(cached));
    } else {
      emit(PoleLoading());
    }
    try {
      final data = await _repo.listPoles(forceRefresh: cached == null);
      emit(PoleLoaded(data));
    } on ApiException catch (e) {
      if (cached == null) {
        emit(PoleError(e.message));
      }
    }
  }

  Future<void> _onCreate(CreatePole event, Emitter<PoleState> emit) async {
    try {
      await _repo.createPole(event.data);
      emit(PoleActionSuccess('Pole created successfully'));
      add(LoadPoles());
    } on ApiException catch (e) {
      emit(PoleError(e.message));
    }
  }

  Future<void> _onUpdate(UpdatePole event, Emitter<PoleState> emit) async {
    try {
      await _repo.updatePole(event.id, event.data);
      emit(PoleActionSuccess('Pole updated successfully'));
      add(LoadPoles());
    } on ApiException catch (e) {
      emit(PoleError(e.message));
    }
  }

  Future<void> _onDelete(DeletePole event, Emitter<PoleState> emit) async {
    try {
      await _repo.deletePole(event.id);
      emit(PoleActionSuccess('Pole deleted'));
      add(LoadPoles());
    } on ApiException catch (e) {
      emit(PoleError(e.message));
    }
  }
}
