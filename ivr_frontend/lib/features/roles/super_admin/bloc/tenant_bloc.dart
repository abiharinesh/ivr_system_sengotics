import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ivr_frontend/core/api/api_exceptions.dart';
import 'package:ivr_frontend/core/models/tenant_model.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';

// ── Events ────────────────────────────────────────────────────────────────
abstract class TenantEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadTenants extends TenantEvent {}

class ProvisionTenant extends TenantEvent {
  final Map<String, dynamic> data;
  ProvisionTenant(this.data);
  @override
  List<Object?> get props => [data];
}

class UpdateTenant extends TenantEvent {
  final String id;
  final Map<String, dynamic> data;
  UpdateTenant(this.id, this.data);
  @override
  List<Object?> get props => [id, data];
}

class DeactivateTenant extends TenantEvent {
  final String id;
  DeactivateTenant(this.id);
  @override
  List<Object?> get props => [id];
}

// ── States ────────────────────────────────────────────────────────────────
abstract class TenantState extends Equatable {
  @override
  List<Object?> get props => [];
}

class TenantInitial extends TenantState {}

class TenantLoading extends TenantState {}

class TenantLoaded extends TenantState {
  final List<TenantModel> tenants;
  TenantLoaded(this.tenants);
  @override
  List<Object?> get props => [tenants];
}

class TenantActionSuccess extends TenantState {
  final String message;
  final TenantProvisionResult? provisioned;
  TenantActionSuccess(this.message, {this.provisioned});
  @override
  List<Object?> get props => [message, provisioned];
}

class TenantError extends TenantState {
  final String message;
  TenantError(this.message);
  @override
  List<Object?> get props => [message];
}

// ── BLoC ──────────────────────────────────────────────────────────────────
class TenantBloc extends Bloc<TenantEvent, TenantState> {
  final SuperAdminRepository _repo;

  TenantBloc({SuperAdminRepository? repo})
      : _repo = repo ?? SuperAdminRepository(),
        super(TenantInitial()) {
    on<LoadTenants>(_onLoad);
    on<ProvisionTenant>(_onProvision);
    on<UpdateTenant>(_onUpdate);
    on<DeactivateTenant>(_onDeactivate);
  }

  Future<void> _onLoad(LoadTenants event, Emitter<TenantState> emit) async {
    final cached = _repo.getCachedTenants();
    if (cached != null) {
      emit(TenantLoaded(cached));
    } else {
      emit(TenantLoading());
    }
    try {
      final data = await _repo.listTenants(forceRefresh: cached == null);
      emit(TenantLoaded(data));
    } on ApiException catch (e) {
      if (cached == null) emit(TenantError(e.message));
    } catch (e) {
      if (cached == null) emit(TenantError(e.toString()));
    }
  }

  Future<void> _onProvision(ProvisionTenant event, Emitter<TenantState> emit) async {
    try {
      final result = await _repo.provisionTenant(event.data);
      emit(TenantActionSuccess(
        'Tenant "${result.tenant.name}" provisioned — admin login: ${result.adminEmail}',
        provisioned: result,
      ));
      add(LoadTenants());
    } on ApiException catch (e) {
      emit(TenantError(e.message));
    } catch (e) {
      emit(TenantError(e.toString()));
    }
  }

  Future<void> _onUpdate(UpdateTenant event, Emitter<TenantState> emit) async {
    try {
      await _repo.updateTenant(event.id, event.data);
      emit(TenantActionSuccess('Tenant updated successfully'));
      add(LoadTenants());
    } on ApiException catch (e) {
      emit(TenantError(e.message));
    }
  }

  Future<void> _onDeactivate(DeactivateTenant event, Emitter<TenantState> emit) async {
    try {
      await _repo.deactivateTenant(event.id);
      emit(TenantActionSuccess('Tenant deactivated'));
      add(LoadTenants());
    } on ApiException catch (e) {
      emit(TenantError(e.message));
    }
  }
}
