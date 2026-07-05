import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/api_exceptions.dart';
import '../../../core/models/pole_model.dart';
import '../../super_admin/data/models/complaint_model.dart';
import '../data/citizen_repository.dart';

// --- Events ---
abstract class CitizenEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadCitizenDashboard extends CitizenEvent {}

class SubmitComplaint extends CitizenEvent {
  final int poleId;
  final String complaintType;
  final String description;
  final String urgencyLevel;

  SubmitComplaint({
    required this.poleId,
    required this.complaintType,
    required this.description,
    required this.urgencyLevel,
  });

  @override
  List<Object?> get props => [poleId, complaintType, description, urgencyLevel];
}

// --- States ---
abstract class CitizenState extends Equatable {
  @override
  List<Object?> get props => [];
}

class CitizenInitial extends CitizenState {}

class CitizenLoading extends CitizenState {}

class CitizenDashboardLoaded extends CitizenState {
  final List<PoleModel> poles;
  final List<ComplaintModel> complaints;
  final Map<String, dynamic> ivrHistory;

  CitizenDashboardLoaded({
    required this.poles,
    required this.complaints,
    this.ivrHistory = const {},
  });

  @override
  List<Object?> get props => [poles, complaints, ivrHistory];
}

class CitizenComplaintSubmitting extends CitizenState {}

class CitizenComplaintSubmitSuccess extends CitizenState {
  final String message;
  CitizenComplaintSubmitSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class CitizenError extends CitizenState {
  final String message;
  CitizenError(this.message);

  @override
  List<Object?> get props => [message];
}

// --- BLoC ---
class CitizenBloc extends Bloc<CitizenEvent, CitizenState> {
  final CitizenRepository _repo;

  CitizenBloc({CitizenRepository? repo})
      : _repo = repo ?? CitizenRepository(),
        super(CitizenInitial()) {
    on<LoadCitizenDashboard>(_onLoadDashboard);
    on<SubmitComplaint>(_onSubmitComplaint);
  }

  Future<void> _onLoadDashboard(
    LoadCitizenDashboard event,
    Emitter<CitizenState> emit,
  ) async {
    emit(CitizenLoading());
    try {
      final poles = await _repo.listPoles();
      final complaints = await _repo.listComplaints();
      Map<String, dynamic> ivrHistory = {};
      try {
        ivrHistory = await _repo.getIvrHistory();
      } catch (_) {
        // Fallback for issues fetching history or no phone linked
      }
      emit(CitizenDashboardLoaded(
        poles: poles,
        complaints: complaints,
        ivrHistory: ivrHistory,
      ));
    } on ApiException catch (e) {
      emit(CitizenError(e.message));
    } catch (e) {
      emit(CitizenError('Failed to load dashboard: ${e.toString()}'));
    }
  }

  Future<void> _onSubmitComplaint(
    SubmitComplaint event,
    Emitter<CitizenState> emit,
  ) async {
    emit(CitizenComplaintSubmitting());
    try {
      await _repo.raiseComplaint(
        poleId: event.poleId,
        complaintType: event.complaintType,
        description: event.description,
        urgencyLevel: event.urgencyLevel,
      );
      emit(CitizenComplaintSubmitSuccess('Complaint raised successfully.'));
      add(LoadCitizenDashboard());
    } on ApiException catch (e) {
      emit(CitizenError(e.message));
    } catch (e) {
      emit(CitizenError('Failed to raise complaint: ${e.toString()}'));
    }
  }
}
