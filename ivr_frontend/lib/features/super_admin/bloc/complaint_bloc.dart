import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../data/models/complaint_model.dart';
import '../data/super_admin_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────
abstract class SAComplaintEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadSAComplaints extends SAComplaintEvent {
  final String? status;
  final int? panchayatId;
  LoadSAComplaints({this.status, this.panchayatId});
  @override
  List<Object?> get props => [status, panchayatId];
}

class UpdateSAComplaintStatus extends SAComplaintEvent {
  final int id;
  final String status;
  UpdateSAComplaintStatus(this.id, this.status);
  @override
  List<Object?> get props => [id, status];
}

class ResolveSAComplaint extends SAComplaintEvent {
  final int id;
  final int poleId;
  ResolveSAComplaint(this.id, this.poleId);
  @override
  List<Object?> get props => [id, poleId];
}

class AssignSAComplaintElectrician extends SAComplaintEvent {
  final int complaintId;
  final int electricianUserId;
  AssignSAComplaintElectrician(this.complaintId, this.electricianUserId);
  @override
  List<Object?> get props => [complaintId, electricianUserId];
}

// ── States ────────────────────────────────────────────────────────────────
abstract class SAComplaintState extends Equatable {
  @override
  List<Object?> get props => [];
}

class SAComplaintInitial extends SAComplaintState {}

class SAComplaintLoading extends SAComplaintState {}

class SAComplaintLoaded extends SAComplaintState {
  final List<ComplaintModel> complaints;
  SAComplaintLoaded(this.complaints);
  @override
  List<Object?> get props => [complaints];
}

class SAComplaintActionSuccess extends SAComplaintState {
  final String message;
  SAComplaintActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class SAComplaintError extends SAComplaintState {
  final String message;
  SAComplaintError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────
class SAComplaintBloc extends Bloc<SAComplaintEvent, SAComplaintState> {
  final SuperAdminRepository _repo;
  String? _currentFilter;
  int? _currentPanchayatFilter;

  SAComplaintBloc({SuperAdminRepository? repo})
    : _repo = repo ?? SuperAdminRepository(),
      super(SAComplaintInitial()) {
    on<LoadSAComplaints>(_onLoad);
    on<UpdateSAComplaintStatus>(_onUpdateStatus);
    on<ResolveSAComplaint>(_onResolve);
    on<AssignSAComplaintElectrician>(_onAssignElectrician);
  }

  Future<void> _onLoad(
    LoadSAComplaints event,
    Emitter<SAComplaintState> emit,
  ) async {
    _currentFilter = event.status;
    _currentPanchayatFilter = event.panchayatId;
    final cached = _repo.getCachedComplaints(
      status: event.status,
      panchayatId: event.panchayatId,
    );
    if (cached != null) {
      emit(SAComplaintLoaded(cached));
    } else {
      emit(SAComplaintLoading());
    }
    try {
      final data = await _repo.listComplaints(
        status: event.status,
        panchayatId: event.panchayatId,
        forceRefresh: cached == null,
      );
      emit(SAComplaintLoaded(data));
    } on ApiException catch (e) {
      if (cached == null) {
        emit(SAComplaintError(e.message));
      }
    }
  }

  Future<void> _onUpdateStatus(
    UpdateSAComplaintStatus event,
    Emitter<SAComplaintState> emit,
  ) async {
    try {
      await _repo.updateComplaintStatus(event.id, event.status);
      emit(SAComplaintActionSuccess('Status updated'));
      add(
        LoadSAComplaints(
          status: _currentFilter,
          panchayatId: _currentPanchayatFilter,
        ),
      );
    } on ApiException catch (e) {
      emit(SAComplaintError(e.message));
    }
  }

  Future<void> _onResolve(
    ResolveSAComplaint event,
    Emitter<SAComplaintState> emit,
  ) async {
    try {
      await _repo.resolveComplaint(event.id, event.poleId);
      emit(SAComplaintActionSuccess('Complaint resolved'));
      add(
        LoadSAComplaints(
          status: _currentFilter,
          panchayatId: _currentPanchayatFilter,
        ),
      );
    } on ApiException catch (e) {
      emit(SAComplaintError(e.message));
    }
  }

  Future<void> _onAssignElectrician(
    AssignSAComplaintElectrician event,
    Emitter<SAComplaintState> emit,
  ) async {
    try {
      await _repo.assignElectrician(event.complaintId, event.electricianUserId);
      emit(SAComplaintActionSuccess('Electrician assigned'));
      add(
        LoadSAComplaints(
          status: _currentFilter,
          panchayatId: _currentPanchayatFilter,
        ),
      );
    } on ApiException catch (e) {
      emit(SAComplaintError(e.message));
    }
  }
}
