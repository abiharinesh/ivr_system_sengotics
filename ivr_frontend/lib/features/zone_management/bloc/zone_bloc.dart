import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../models/zone_model.dart';
import '../data/zone_repository.dart';

// ── Events ───────────────────────────────────────────────────────────────────

abstract class ZoneEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadZones extends ZoneEvent {}

class CreateZone extends ZoneEvent {
  final String name;
  final Map<String, dynamic> boundaryGeojson;
  final String? color;
  final double? opacity;
  final List<String>? places;
  final int? panchayatId;

  CreateZone({
    required this.name,
    required this.boundaryGeojson,
    this.color,
    this.opacity,
    this.places,
    this.panchayatId,
  });

  @override
  List<Object?> get props => [name, boundaryGeojson, color, panchayatId];
}

class UpdateZone extends ZoneEvent {
  final int zoneId;
  final String? name;
  final Map<String, dynamic>? boundaryGeojson;
  final String? color;
  final double? opacity;
  final List<String>? places;
  final bool? isActive;
  final int? panchayatId;

  UpdateZone({
    required this.zoneId,
    this.name,
    this.boundaryGeojson,
    this.color,
    this.opacity,
    this.places,
    this.isActive,
    this.panchayatId,
  });

  @override
  List<Object?> get props => [zoneId, name, color, isActive];
}

class DeleteZone extends ZoneEvent {
  final int zoneId;
  final int? panchayatId;

  DeleteZone({required this.zoneId, this.panchayatId});

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

  ZonesLoaded({
    required this.zones,
    this.placeResults = const [],
    this.isSearching = false,
  });

  @override
  List<Object?> get props => [zones, placeResults, isSearching];

  ZonesLoaded copyWith({
    List<ZoneModel>? zones,
    List<PlaceBoundaryResult>? placeResults,
    bool? isSearching,
  }) {
    return ZonesLoaded(
      zones: zones ?? this.zones,
      placeResults: placeResults ?? this.placeResults,
      isSearching: isSearching ?? this.isSearching,
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

  ZoneBloc({bool isSuperAdmin = false})
      : _repository = ZoneRepository(isSuperAdmin: isSuperAdmin),
        super(ZoneInitial()) {
    on<LoadZones>(_onLoadZones);
    on<CreateZone>(_onCreateZone);
    on<UpdateZone>(_onUpdateZone);
    on<DeleteZone>(_onDeleteZone);
    on<LookupPlaceBoundary>(_onLookupPlace);
    on<ClearPlaceResults>(_onClearPlaceResults);
  }

  Future<void> _onLoadZones(LoadZones event, Emitter<ZoneState> emit) async {
    emit(ZoneLoading());
    try {
      final zones = await _repository.listZones();
      emit(ZonesLoaded(zones: zones));
    } catch (e) {
      emit(ZoneError(message: e.toString()));
    }
  }

  Future<void> _onCreateZone(CreateZone event, Emitter<ZoneState> emit) async {
    try {
      await _repository.createZone(
        name: event.name,
        boundaryGeojson: event.boundaryGeojson,
        color: event.color,
        opacity: event.opacity,
        places: event.places,
        panchayatId: event.panchayatId,
      );
      add(LoadZones());
    } catch (e) {
      emit(ZoneError(message: 'Failed to create zone: $e'));
    }
  }

  Future<void> _onUpdateZone(UpdateZone event, Emitter<ZoneState> emit) async {
    try {
      await _repository.updateZone(
        zoneId: event.zoneId,
        name: event.name,
        boundaryGeojson: event.boundaryGeojson,
        color: event.color,
        opacity: event.opacity,
        places: event.places,
        isActive: event.isActive,
        panchayatId: event.panchayatId,
      );
      add(LoadZones());
    } catch (e) {
      emit(ZoneError(message: 'Failed to update zone: $e'));
    }
  }

  Future<void> _onDeleteZone(DeleteZone event, Emitter<ZoneState> emit) async {
    try {
      await _repository.deleteZone(event.zoneId, panchayatId: event.panchayatId);
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
