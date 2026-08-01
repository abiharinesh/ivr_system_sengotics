import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/models/complaint_model.dart';
import 'package:ivr_frontend/features/roles/panchayat_admin/data/panchayat_admin_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────
abstract class PAComplaintEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadPAComplaints extends PAComplaintEvent {
  final String? status;
  LoadPAComplaints({this.status});
  @override
  List<Object?> get props => [status];
}

class UpdatePAComplaintStatus extends PAComplaintEvent {
  final int id;
  final String status;
  UpdatePAComplaintStatus(this.id, this.status);
  @override
  List<Object?> get props => [id, status];
}

class ResolvePAComplaint extends PAComplaintEvent {
  final int id;
  final int poleId;
  ResolvePAComplaint(this.id, this.poleId);
  @override
  List<Object?> get props => [id, poleId];
}

class AssignPAComplaintElectrician extends PAComplaintEvent {
  final int complaintId;
  final int electricianUserId;
  AssignPAComplaintElectrician(this.complaintId, this.electricianUserId);
  @override
  List<Object?> get props => [complaintId, electricianUserId];
}

class AssignPAComplaintPlumber extends PAComplaintEvent {
  final int complaintId;
  final int plumberUserId;
  AssignPAComplaintPlumber(this.complaintId, this.plumberUserId);
  @override
  List<Object?> get props => [complaintId, plumberUserId];
}

// ── States ────────────────────────────────────────────────────────────────
abstract class PAComplaintState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PAComplaintInitial extends PAComplaintState {}

class PAComplaintLoading extends PAComplaintState {}

class PAComplaintLoaded extends PAComplaintState {
  final List<ComplaintModel> complaints;
  PAComplaintLoaded(this.complaints);
  @override
  List<Object?> get props => [complaints];
}

class PAComplaintActionSuccess extends PAComplaintState {
  final String message;
  PAComplaintActionSuccess(this.message);
  @override
  List<Object?> get props => [message];
}

class PAComplaintError extends PAComplaintState {
  final String message;
  PAComplaintError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────
class PAComplaintBloc extends Bloc<PAComplaintEvent, PAComplaintState> {
  final PanchayatAdminRepository _repo;
  String? _currentFilter;

  PAComplaintBloc({PanchayatAdminRepository? repo})
    : _repo = repo ?? PanchayatAdminRepository(),
      super(PAComplaintInitial()) {
    on<LoadPAComplaints>(_onLoad);
    on<UpdatePAComplaintStatus>(_onUpdateStatus);
    on<ResolvePAComplaint>(_onResolve);
    on<AssignPAComplaintElectrician>(_onAssignElectrician);
    on<AssignPAComplaintPlumber>(_onAssignPlumber);
  }

  Future<void> _onLoad(
    LoadPAComplaints event,
    Emitter<PAComplaintState> emit,
  ) async {
    _currentFilter = event.status;
    final cached = _repo.getCachedComplaints(status: event.status);
    if (cached != null) {
      emit(PAComplaintLoaded(cached));
    } else {
      emit(PAComplaintLoading());
    }
    try {
      final data = await _repo.listComplaints(status: event.status, forceRefresh: cached == null);
      emit(PAComplaintLoaded(data));
    } on ApiException catch (e) {
      if (cached == null) {
        emit(PAComplaintError(e.message));
      }
    }
  }

  Future<void> _onUpdateStatus(
    UpdatePAComplaintStatus event,
    Emitter<PAComplaintState> emit,
  ) async {
    try {
      await _repo.updateComplaintStatus(event.id, event.status);
      emit(PAComplaintActionSuccess('Status updated'));
      add(LoadPAComplaints(status: _currentFilter));
    } on ApiException catch (e) {
      emit(PAComplaintError(e.message));
    }
  }

  Future<void> _onResolve(
    ResolvePAComplaint event,
    Emitter<PAComplaintState> emit,
  ) async {
    try {
      await _repo.resolveComplaint(event.id, event.poleId);
      emit(PAComplaintActionSuccess('Complaint resolved'));
      add(LoadPAComplaints(status: _currentFilter));
    } on ApiException catch (e) {
      emit(PAComplaintError(e.message));
    }
  }

  Future<void> _onAssignElectrician(
    AssignPAComplaintElectrician event,
    Emitter<PAComplaintState> emit,
  ) async {
    try {
      await _repo.assignElectrician(event.complaintId, event.electricianUserId);
      emit(PAComplaintActionSuccess('Electrician assigned'));
      add(LoadPAComplaints(status: _currentFilter));
    } on ApiException catch (e) {
      emit(PAComplaintError(e.message));
    }
  }

  Future<void> _onAssignPlumber(
    AssignPAComplaintPlumber event,
    Emitter<PAComplaintState> emit,
  ) async {
    try {
      // Mock plumber assignment response
      await Future<void>.delayed(const Duration(milliseconds: 300));
      emit(PAComplaintActionSuccess('Plumber assigned'));
      add(LoadPAComplaints(status: _currentFilter));
    } catch (e) {
      emit(PAComplaintError(e.toString()));
    }
  }
}
