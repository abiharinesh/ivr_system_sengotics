import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/api/revenue_service.dart';

// =============================================================================
//  SHARED STATE & EVENTS
// =============================================================================
class RevenueEvent extends Equatable {
  const RevenueEvent();
  @override
  List<Object?> get props => [];
}

class RevenueState extends Equatable {
  const RevenueState();
  @override
  List<Object?> get props => [];
}

class RevenueInitial extends RevenueState {}
class RevenueLoading extends RevenueState {}
class RevenueSuccess extends RevenueState {
  final String message;
  const RevenueSuccess(this.message);
  @override
  List<Object?> get props => [message];
}
class RevenueError extends RevenueState {
  final String error;
  const RevenueError(this.error);
  @override
  List<Object?> get props => [error];
}

// =============================================================================
//  1. PROPERTY TAX BLOC
// =============================================================================
class LoadPropertyTaxData extends RevenueEvent {
  final int panchayatId;
  final String? financialYear;
  const LoadPropertyTaxData(this.panchayatId, {this.financialYear});
}

class CreatePropertyEvent extends RevenueEvent {
  final int panchayatId;
  final Map<String, dynamic> data;
  const CreatePropertyEvent(this.panchayatId, this.data);
}

class GenerateDemandsEvent extends RevenueEvent {
  final int panchayatId;
  final String financialYear;
  final String dueDate;
  const GenerateDemandsEvent({required this.panchayatId, required this.financialYear, required this.dueDate});
}

class RecordPaymentEvent extends RevenueEvent {
  final int panchayatId;
  final int paymentId;
  final Map<String, dynamic> data;
  const RecordPaymentEvent({required this.panchayatId, required this.paymentId, required this.data});
}

class PropertyTaxLoaded extends RevenueState {
  final List<dynamic> properties;
  final List<dynamic> defaulters;
  final Map<String, dynamic> summary;
  const PropertyTaxLoaded({required this.properties, required this.defaulters, required this.summary});
  @override
  List<Object?> get props => [properties, defaulters, summary];
}

class PropertyTaxBloc extends Bloc<RevenueEvent, RevenueState> {
  final RevenueService _service = RevenueService();
  PropertyTaxBloc() : super(RevenueInitial()) {
    on<LoadPropertyTaxData>((event, emit) async {
      emit(RevenueLoading());
      try {
        final props = await _service.getProperties(event.panchayatId);
        final defs = await _service.getTaxDefaulters(event.panchayatId, financialYear: event.financialYear);
        final sum = await _service.getTaxSummary(event.panchayatId, financialYear: event.financialYear);
        emit(PropertyTaxLoaded(properties: props, defaulters: defs, summary: sum));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<CreatePropertyEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.createProperty(event.data);
        add(LoadPropertyTaxData(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<GenerateDemandsEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.generateTaxDemands({
          'panchayat_id': event.panchayatId,
          'financial_year': event.financialYear,
          'due_date': event.dueDate,
        });
        add(LoadPropertyTaxData(event.panchayatId, financialYear: event.financialYear));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<RecordPaymentEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.recordTaxPayment(event.paymentId, event.data);
        add(LoadPropertyTaxData(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });
  }
}

// =============================================================================
//  2. AD CAMPAIGN BLOC
// =============================================================================
class LoadAdCampaigns extends RevenueEvent {
  final int panchayatId;
  const LoadAdCampaigns(this.panchayatId);
}

class CreateCampaignEvent extends RevenueEvent {
  final int panchayatId;
  final Map<String, dynamic> data;
  const CreateCampaignEvent(this.panchayatId, this.data);
}

class UpdateCampaignEvent extends RevenueEvent {
  final int panchayatId;
  final int id;
  final Map<String, dynamic> data;
  const UpdateCampaignEvent(this.panchayatId, this.id, this.data);
}

class DeleteCampaignEvent extends RevenueEvent {
  final int panchayatId;
  final int id;
  const DeleteCampaignEvent(this.panchayatId, this.id);
}

class AdCampaignsLoaded extends RevenueState {
  final List<dynamic> campaigns;
  const AdCampaignsLoaded(this.campaigns);
  @override
  List<Object?> get props => [campaigns];
}

class AdCampaignBloc extends Bloc<RevenueEvent, RevenueState> {
  final RevenueService _service = RevenueService();
  AdCampaignBloc() : super(RevenueInitial()) {
    on<LoadAdCampaigns>((event, emit) async {
      emit(RevenueLoading());
      try {
        final campaigns = await _service.getCampaigns(event.panchayatId);
        emit(AdCampaignsLoaded(campaigns));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<CreateCampaignEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.createCampaign(event.data);
        add(LoadAdCampaigns(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<UpdateCampaignEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.updateCampaign(event.id, event.data);
        add(LoadAdCampaigns(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<DeleteCampaignEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.deleteCampaign(event.id);
        add(LoadAdCampaigns(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });
  }
}

// =============================================================================
//  3. PENALTY BLOC
// =============================================================================
class LoadPenaltyData extends RevenueEvent {
  final int panchayatId;
  const LoadPenaltyData(this.panchayatId);
}

class UpsertRuleEvent extends RevenueEvent {
  final int panchayatId;
  final Map<String, dynamic> data;
  const UpsertRuleEvent(this.panchayatId, this.data);
}

class WaivePenaltyEvent extends RevenueEvent {
  final int panchayatId;
  final int penaltyId;
  final String reason;
  const WaivePenaltyEvent({required this.panchayatId, required this.penaltyId, required this.reason});
}

class DeductPenaltyEvent extends RevenueEvent {
  final int panchayatId;
  final int penaltyId;
  const DeductPenaltyEvent({required this.panchayatId, required this.penaltyId});
}

class PenaltyDataLoaded extends RevenueState {
  final List<dynamic> rules;
  final List<dynamic> penalties;
  final Map<String, dynamic> summary;
  const PenaltyDataLoaded({required this.rules, required this.penalties, required this.summary});
  @override
  List<Object?> get props => [rules, penalties, summary];
}

class PenaltyBloc extends Bloc<RevenueEvent, RevenueState> {
  final RevenueService _service = RevenueService();
  PenaltyBloc() : super(RevenueInitial()) {
    on<LoadPenaltyData>((event, emit) async {
      emit(RevenueLoading());
      try {
        final rules = await _service.getRules(event.panchayatId);
        final penalties = await _service.getPenalties(event.panchayatId);
        final summary = await _service.getPenaltySummary(event.panchayatId);
        emit(PenaltyDataLoaded(rules: rules, penalties: penalties, summary: summary));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<UpsertRuleEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.upsertRule(event.data);
        add(LoadPenaltyData(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<WaivePenaltyEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.waivePenalty(event.penaltyId, event.reason);
        add(LoadPenaltyData(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<DeductPenaltyEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.deductPenalty(event.penaltyId);
        add(LoadPenaltyData(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });
  }
}

// =============================================================================
//  4. CERTIFICATE BLOC
// =============================================================================
class LoadCertificates extends RevenueEvent {
  final int panchayatId;
  final String? type;
  const LoadCertificates(this.panchayatId, {this.type});
}

class ApproveCertificateEvent extends RevenueEvent {
  final int panchayatId;
  final int id;
  final Map<String, dynamic> data;
  const ApproveCertificateEvent({required this.panchayatId, required this.id, required this.data});
}

class RejectCertificateEvent extends RevenueEvent {
  final int panchayatId;
  final int id;
  final String notes;
  const RejectCertificateEvent({required this.panchayatId, required this.id, required this.notes});
}

class CertificatesLoaded extends RevenueState {
  final List<dynamic> requests;
  const CertificatesLoaded(this.requests);
  @override
  List<Object?> get props => [requests];
}

class CertificateBloc extends Bloc<RevenueEvent, RevenueState> {
  final RevenueService _service = RevenueService();
  CertificateBloc() : super(RevenueInitial()) {
    on<LoadCertificates>((event, emit) async {
      emit(RevenueLoading());
      try {
        final requests = await _service.getCertificateRequests(event.panchayatId, type: event.type);
        emit(CertificatesLoaded(requests));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<ApproveCertificateEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.approveCertificate(event.id, event.data);
        add(LoadCertificates(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<RejectCertificateEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.rejectCertificate(event.id, event.notes);
        add(LoadCertificates(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });
  }
}

// =============================================================================
//  5. ASSET BOOKING BLOC
// =============================================================================
class LoadAssetBookings extends RevenueEvent {
  final int panchayatId;
  const LoadAssetBookings(this.panchayatId);
}

class CreateAssetEvent extends RevenueEvent {
  final int panchayatId;
  final Map<String, dynamic> data;
  const CreateAssetEvent(this.panchayatId, this.data);
}

class CreateBookingEvent extends RevenueEvent {
  final int panchayatId;
  final Map<String, dynamic> data;
  const CreateBookingEvent(this.panchayatId, this.data);
}

class ConfirmBookingEvent extends RevenueEvent {
  final int panchayatId;
  final int bookingId;
  final String paymentRef;
  const ConfirmBookingEvent({required this.panchayatId, required this.bookingId, required this.paymentRef});
}

class PayBalanceEvent extends RevenueEvent {
  final int panchayatId;
  final int bookingId;
  const PayBalanceEvent(this.panchayatId, this.bookingId);
}

class CancelBookingEvent extends RevenueEvent {
  final int panchayatId;
  final int bookingId;
  final double fee;
  const CancelBookingEvent({required this.panchayatId, required this.bookingId, required this.fee});
}

class AssetBookingsLoaded extends RevenueState {
  final List<dynamic> assets;
  final List<dynamic> bookings;
  const AssetBookingsLoaded({required this.assets, required this.bookings});
  @override
  List<Object?> get props => [assets, bookings];
}

class AssetBookingBloc extends Bloc<RevenueEvent, RevenueState> {
  final RevenueService _service = RevenueService();
  AssetBookingBloc() : super(RevenueInitial()) {
    on<LoadAssetBookings>((event, emit) async {
      emit(RevenueLoading());
      try {
        final assets = await _service.getAssets(event.panchayatId);
        final bookings = await _service.getBookings(event.panchayatId);
        emit(AssetBookingsLoaded(assets: assets, bookings: bookings));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<CreateAssetEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.createAsset(event.data);
        add(LoadAssetBookings(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<CreateBookingEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.createBooking(event.data);
        add(LoadAssetBookings(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<ConfirmBookingEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.confirmBooking(event.bookingId, event.paymentRef);
        add(LoadAssetBookings(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<PayBalanceEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.payBookingBalance(event.bookingId);
        add(LoadAssetBookings(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<CancelBookingEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.cancelBooking(event.bookingId, event.fee);
        add(LoadAssetBookings(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });
  }
}

// =============================================================================
//  6. SHANDY MARKET VENDORS BLOC
// =============================================================================
class LoadMarketData extends RevenueEvent {
  final int panchayatId;
  const LoadMarketData(this.panchayatId);
}

class CreateMarketDayEvent extends RevenueEvent {
  final int panchayatId;
  final Map<String, dynamic> data;
  const CreateMarketDayEvent(this.panchayatId, this.data);
}

class CreateVendorEvent extends RevenueEvent {
  final int panchayatId;
  final Map<String, dynamic> data;
  const CreateVendorEvent(this.panchayatId, this.data);
}

class RecordMarketFeeEvent extends RevenueEvent {
  final int panchayatId;
  final Map<String, dynamic> data;
  const RecordMarketFeeEvent(this.panchayatId, this.data);
}

class MarketDataLoaded extends RevenueState {
  final List<dynamic> marketDays;
  final List<dynamic> vendors;
  final List<dynamic> payments;
  const MarketDataLoaded({required this.marketDays, required this.vendors, required this.payments});
  @override
  List<Object?> get props => [marketDays, vendors, payments];
}

class MarketBloc extends Bloc<RevenueEvent, RevenueState> {
  final RevenueService _service = RevenueService();
  MarketBloc() : super(RevenueInitial()) {
    on<LoadMarketData>((event, emit) async {
      emit(RevenueLoading());
      try {
        final days = await _service.getMarketDays(event.panchayatId);
        final vendors = await _service.getMarketVendors(event.panchayatId);
        final payments = await _service.getMarketPayments(event.panchayatId);
        emit(MarketDataLoaded(marketDays: days, vendors: vendors, payments: payments));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<CreateMarketDayEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.createMarketDay(event.data);
        add(LoadMarketData(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<CreateVendorEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.createMarketVendor(event.data);
        add(LoadMarketData(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });

    on<RecordMarketFeeEvent>((event, emit) async {
      emit(RevenueLoading());
      try {
        await _service.recordMarketFee(event.data);
        add(LoadMarketData(event.panchayatId));
      } catch (e) {
        emit(RevenueError(e.toString()));
      }
    });
  }
}
