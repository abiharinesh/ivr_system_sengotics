import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../../super_admin/data/models/complaint_model.dart';
import '../data/panchayat_admin_repository.dart';

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
  }

  Future<void> _onLoad(
    LoadPAComplaints event,
    Emitter<PAComplaintState> emit,
  ) async {
    emit(PAComplaintLoading());
    _currentFilter = event.status;
    try {
      final data = await _repo.listComplaints(status: event.status);
      emit(PAComplaintLoaded(data));
    } on ApiException catch (e) {
      emit(PAComplaintError(e.message));
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
}
