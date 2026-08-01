import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ivr_frontend/core/models/panchayat_model.dart';
import 'package:ivr_frontend/features/roles/super_admin/data/super_admin_repository.dart';
import 'package:ivr_frontend/features/modules/zone_management/data/models/zone_model.dart';
import 'package:ivr_frontend/features/modules/zone_management/data/zone_repository.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class ZoneEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadZones extends ZoneEvent {}

class SelectPanchayat extends ZoneEvent {
  final int? orgUnitId;
  SelectPanchayat(this.orgUnitId);

  @override
  List<Object?> get props => [orgUnitId];
}

class CreateZone extends ZoneEvent {
  final String name;
  final Map<String, dynamic> boundaryGeojson;
  final String? color;
  final double? opacity;
  final List<String>? places;
  final int? orgUnitId;

  CreateZone({
    required this.name,
    required this.boundaryGeojson,
    this.color,
    this.opacity,
    this.places,
    this.orgUnitId,
  });

  @override
  List<Object?> get props => [name, boundaryGeojson, color, orgUnitId];
}

class UpdateZone extends ZoneEvent {
  final int zoneId;
  final String? name;
  final Map<String, dynamic>? boundaryGeojson;
  final String? color;
  final double? opacity;
  final List<String>? places;
  final bool? isActive;
  final int? orgUnitId;

  UpdateZone({
    required this.zoneId,
    this.name,
    this.boundaryGeojson,
    this.color,
    this.opacity,
    this.places,
    this.isActive,
    this.orgUnitId,
  });

  @override
  List<Object?> get props => [zoneId, name, color, isActive];
}

class DeleteZone extends ZoneEvent {
  final int zoneId;
  final int? orgUnitId;

  DeleteZone({required this.zoneId, this.orgUnitId});

  @override
  List<Object?> get props => [zoneId];
}

class LookupPlaceBoundary extends ZoneEvent {
  final String placeName;

  LookupPlaceBoundary({required this.placeName});

  @override
  List<Object?> get props => [placeName];
}

class ClearPlaceResults extends ZoneEvent {}

// ── States ───────────────────────────────────────────────────────────────────

abstract class ZoneState extends Equatable {
  @override
  List<Object?> get props => [];
}

class ZoneInitial extends ZoneState {}

class ZoneLoading extends ZoneState {}

class ZonesLoaded extends ZoneState {
  final List<ZoneModel> zones;
  final List<PlaceBoundaryResult> placeResults;
  final bool isSearching;
  final List<PanchayatModel> panchayats;
  final int? selectedPanchayatId;

  ZonesLoaded({
    required this.zones,
    this.placeResults = const [],
    this.isSearching = false,
    this.panchayats = const [],
    this.selectedPanchayatId,
  });

  @override
  List<Object?> get props => [
        zones,
        placeResults,
        isSearching,
        panchayats,
        selectedPanchayatId,
      ];

  ZonesLoaded copyWith({
    List<ZoneModel>? zones,
    List<PlaceBoundaryResult>? placeResults,
    bool? isSearching,
    List<PanchayatModel>? panchayats,
    int? selectedPanchayatId,
  }) {
    return ZonesLoaded(
      zones: zones ?? this.zones,
      placeResults: placeResults ?? this.placeResults,
      isSearching: isSearching ?? this.isSearching,
      panchayats: panchayats ?? this.panchayats,
      selectedPanchayatId: selectedPanchayatId ?? this.selectedPanchayatId,
    );
  }
}

class ZoneError extends ZoneState {
  final String message;

  ZoneError({required this.message});

  @override
  List<Object?> get props => [message];
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class ZoneBloc extends Bloc<ZoneEvent, ZoneState> {
  final ZoneRepository _repository;
  final bool isSuperAdmin;
  int? selectedPanchayatId;
  List<PanchayatModel> panchayats = [];

  ZoneBloc({this.isSuperAdmin = false})
      : _repository = ZoneRepository(isSuperAdmin: isSuperAdmin),
        super(ZoneInitial()) {
    on<LoadZones>(_onLoadZones);
    on<SelectPanchayat>(_onSelectPanchayat);
    on<CreateZone>(_onCreateZone);
    on<UpdateZone>(_onUpdateZone);
    on<DeleteZone>(_onDeleteZone);
    on<LookupPlaceBoundary>(_onLookupPlace);
    on<ClearPlaceResults>(_onClearPlaceResults);
  }

  Future<void> _onLoadZones(LoadZones event, Emitter<ZoneState> emit) async {
    final currentState = state;
    List<PlaceBoundaryResult> existingPlaceResults = const [];
    bool existingIsSearching = false;
    if (currentState is ZonesLoaded) {
      existingPlaceResults = currentState.placeResults;
      existingIsSearching = currentState.isSearching;
    }

    if (isSuperAdmin && panchayats.isEmpty) {
      try {
        panchayats = await SuperAdminRepository().listPanchayats();
      } catch (_) {}
    }

    final cached = _repository.getCachedZones(orgUnitId: selectedPanchayatId);
    if (cached != null) {
      emit(ZonesLoaded(
        zones: cached,
        panchayats: panchayats,
        selectedPanchayatId: selectedPanchayatId,
        placeResults: existingPlaceResults,
        isSearching: existingIsSearching,
      ));
    } else {
      emit(ZoneLoading());
    }

    try {
      final zones = await _repository.listZones(
        orgUnitId: selectedPanchayatId,
        forceRefresh: cached == null,
      );
      emit(ZonesLoaded(
        zones: zones,
        panchayats: panchayats,
        selectedPanchayatId: selectedPanchayatId,
        placeResults: existingPlaceResults,
        isSearching: existingIsSearching,
      ));
    } catch (e) {
      if (cached == null) {
        emit(ZoneError(message: e.toString()));
      }
    }
  }

  void _onSelectPanchayat(SelectPanchayat event, Emitter<ZoneState> emit) {
    selectedPanchayatId = event.orgUnitId;
    add(LoadZones());
  }

  Future<void> _onCreateZone(CreateZone event, Emitter<ZoneState> emit) async {
    try {
      final pId = event.orgUnitId ?? selectedPanchayatId;
      if (isSuperAdmin && pId == null) {
        emit(ZoneError(message: 'Please select a Panchayat before creating a zone.'));
        return;
      }
      await _repository.createZone(
        name: event.name,
        boundaryGeojson: event.boundaryGeojson,
        color: event.color,
        opacity: event.opacity,
        places: event.places,
        orgUnitId: pId,
      );
      add(LoadZones());
    } catch (e) {
      emit(ZoneError(message: 'Failed to create zone: $e'));
    }
  }

  Future<void> _onUpdateZone(UpdateZone event, Emitter<ZoneState> emit) async {
    try {
      int? pId = event.orgUnitId;
      if (isSuperAdmin && pId == null) {
        final currentState = state;
        if (currentState is ZonesLoaded) {
          final matched = currentState.zones.firstWhere((z) => z.id == event.zoneId);
          pId = matched.orgUnitId;
        }
      }
      await _repository.updateZone(
        zoneId: event.zoneId,
        name: event.name,
        boundaryGeojson: event.boundaryGeojson,
        color: event.color,
        opacity: event.opacity,
        places: event.places,
        isActive: event.isActive,
        orgUnitId: pId,
      );
      add(LoadZones());
    } catch (e) {
      emit(ZoneError(message: 'Failed to update zone: $e'));
    }
  }

  Future<void> _onDeleteZone(DeleteZone event, Emitter<ZoneState> emit) async {
    try {
      int? pId = event.orgUnitId;
      if (isSuperAdmin && pId == null) {
        final currentState = state;
        if (currentState is ZonesLoaded) {
          final matched = currentState.zones.firstWhere((z) => z.id == event.zoneId);
          pId = matched.orgUnitId;
        }
      }
      await _repository.deleteZone(event.zoneId, orgUnitId: pId);
      add(LoadZones());
    } catch (e) {
      emit(ZoneError(message: 'Failed to delete zone: $e'));
    }
  }

  Future<void> _onLookupPlace(LookupPlaceBoundary event, Emitter<ZoneState> emit) async {
    final current = state;
    if (current is ZonesLoaded) {
      emit(current.copyWith(isSearching: true));
      try {
        final results = await _repository.lookupPlaceBoundary(event.placeName);
        final updated = state is ZonesLoaded ? state as ZonesLoaded : current;
        emit(updated.copyWith(placeResults: results, isSearching: false));
      } catch (e) {
        emit(current.copyWith(placeResults: [], isSearching: false));
      }
    }
  }

  void _onClearPlaceResults(ClearPlaceResults event, Emitter<ZoneState> emit) {
    final current = state;
    if (current is ZonesLoaded) {
      emit(current.copyWith(placeResults: []));
    }
  }
}
