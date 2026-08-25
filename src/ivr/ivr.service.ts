import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { IvrCallbackDto } from './dto/ivr-callback.dto';
import { WardIdentificationResult } from '../voice-processing/ward-identification.service';

// ── Service Map ────────────────────────────────────────────────────────────────
// Maps the digit the user presses in the main IVR menu to a complaint type.
const SERVICE_MAP: Record<string, string> = {
  '1': 'street_light',
  '2': 'water',
  '3': 'garbage',
};

export interface PollInputResult {
  found: boolean;
  complaintId?: number;
}

@Injectable()
export class IvrService {
  private readonly logger = new Logger(IvrService.name);

  constructor(private prisma: PrismaService) {}

  // ── EP1: Service Selection ────────────────────────────────────────────────
  async handleServiceSelection(
    data: IvrCallbackDto,
  ): Promise<{ success: boolean }> {
    const callSid = data.CallSid || `UNKNOWN_${Date.now()}`;
    this.logger.log(`[EP1] Service selection for CallSid: ${callSid}`);

    const cleanDigits = this.cleanDigits(data.digits);
    const serviceName = cleanDigits
      ? (SERVICE_MAP[cleanDigits] ?? `unknown_${cleanDigits}`)
      : null;

    this.logger.log(
      `[EP1] User selected digit="${cleanDigits}" → service="${serviceName}"`,
    );

    try {
      // Upsert calls_master
      await this.prisma.ivrCall.upsert({
        where: { call_sid: callSid },
        create: {
          call_sid: callSid,
          caller_number: data.CallFrom ?? data.From,
          call_to: data.CallTo ?? data.To,
          flow_id: data.flow_id,
          tenant_id: data.tenant_id,
          call_start_time: data.StartTime ? new Date(data.StartTime) : null,
          call_end_time: data.EndTime ? new Date(data.EndTime) : null,
          service_selected: !!cleanDigits,
        },
        update: {
          service_selected: !!cleanDigits,
          updated_at: new Date(),
        },
      });

      // Record the service selection
      await this.prisma.ivrServiceSelection.create({
        data: {
          call_sid: callSid,
          caller_number: data.CallFrom ?? data.From,
          service_option: cleanDigits,
          raw_payload: { ...(data as any), resolved_service: serviceName },
        },
      });

      this.logger.log(`[EP1] ✅ Saved service selection.`);
    } catch (err) {
      this.logger.error(
        `[EP1] DB error (non-fatal): ${(err as Error).message}`,
      );
      // Don't re-throw — EP1 must never fail the response
    }

    return { success: true };
  }

  // ── EP2: Poll / Detail Input ─────────────────────────────────────────────
  async handlePollInput(data: IvrCallbackDto): Promise<PollInputResult> {
    const callSid = data.CallSid || `UNKNOWN_${Date.now()}`;
    this.logger.log(`[EP2] Poll input for CallSid: ${callSid}`);

    const cleanDigits = this.cleanDigits(data.digits);

    try {
      // Upsert calls_master
      await this.prisma.ivrCall.upsert({
        where: { call_sid: callSid },
        create: {
          call_sid: callSid,
          caller_number: data.CallFrom ?? data.From,
          call_to: data.CallTo ?? data.To,
          flow_id: data.flow_id,
          tenant_id: data.tenant_id,
          call_start_time: data.StartTime ? new Date(data.StartTime) : null,
          poll_entered: !!cleanDigits,
        },
        update: {
          poll_entered: !!cleanDigits,
          updated_at: new Date(),
        },
      });

      // Save the raw poll input
      await this.prisma.ivrPollInput.create({
        data: {
          call_sid: callSid,
          caller_number: data.CallFrom ?? data.From,
          poll_id: cleanDigits,
          raw_payload: data as any,
        },
      });
    } catch (err) {
      this.logger.error(
        `[EP2] DB recording error (non-fatal): ${(err as Error).message}`,
      );
      // Continue — we still try to create the complaint
    }

    const callTo = data.CallTo ?? data.To;
    if (!cleanDigits || !callTo) {
      this.logger.warn(
        `[EP2] Missing digits or CallTo — skipping complaint creation`,
      );
      return { found: false };
    }

    // ── Lookup which service was selected in EP1 ──────────────────────────
    let serviceSelection: { service_option: string | null } | null = null;
    try {
      serviceSelection = await this.prisma.ivrServiceSelection.findFirst({
        where: { call_sid: callSid },
        orderBy: { received_at: 'desc' },
      });
    } catch (err) {
      this.logger.error(
        `[EP2] Service lookup failed: ${(err as Error).message}`,
      );
    }

    if (!serviceSelection?.service_option) {
      this.logger.warn(
        `[EP2] No service selection found for CallSid=${callSid}`,
      );
      return { found: false };
    }

    const serviceDigit = serviceSelection.service_option;
    const serviceType = SERVICE_MAP[serviceDigit] ?? `unknown_${serviceDigit}`;

    this.logger.log(
      `[EP2] Service="${serviceType}", detail digit="${cleanDigits}"`,
    );

    // ── Lookup Panchayat by the IVR number dialed ─────────────────────────
    const panchayat = await this.prisma.orgUnit.findFirst({
      where: { ivr_number: callTo },
    });

    if (!panchayat) {
      this.logger.warn(`[EP2] No panchayat found for IVR number: ${callTo}`);
      return { found: false };
    }

    // ── Check if ward was identified in Step 2 ───────────────────────────
    let wardId: number | null = null;
    try {
      const callState = await this.prisma.ivrCallState.findUnique({
        where: { call_sid: callSid },
        select: { ward_id: true },
      });
      wardId = callState?.ward_id ?? null;
    } catch (err) {
      this.logger.warn(`[EP2] Failed to check ward state: ${(err as Error).message}`);
    }

    // ── Create complaint based on service type ────────────────────────────
    try {
      const complaint = await this.createServiceComplaint(
        serviceType,
        cleanDigits,
        panchayat.id,
        data.CallFrom ?? data.From ?? 'unknown',
        wardId,
      );

      // Update call state with complaint info
      await this.prisma.ivrCallState.updateMany({
        where: { call_sid: callSid },
        data: {
          complaint_created: true,
          complaint_id: complaint.id,
          finalized_at: new Date(),
        },
      });

      return { found: true, complaintId: complaint.id };
    } catch (err) {
      this.logger.error(
        `[EP2] Failed to create complaint: ${(err as Error).message}`,
      );
      return { found: false };
    }
  }

  // ── EP-WARD: Ward Identification ─────────────────────────────────────────
  async handleWardIdentification(
    callSid: string,
    result: WardIdentificationResult,
    data: IvrCallbackDto,
  ): Promise<{ success: boolean }> {
    this.logger.log(
      `[EP-WARD] Saving ward identification for CallSid=${callSid}: ward=${result.wardNumber}`,
    );

    try {
      // Upsert calls_master
      await this.prisma.ivrCall.upsert({
        where: { call_sid: callSid },
        create: {
          call_sid: callSid,
          caller_number: data.CallFrom ?? data.From,
          call_to: data.CallTo ?? data.To,
          flow_id: data.flow_id,
          tenant_id: data.tenant_id,
          call_start_time: data.StartTime ? new Date(data.StartTime) : null,
        },
        update: {
          updated_at: new Date(),
        },
      });

      // Update IvrCallState with ward identification result
      await this.prisma.ivrCallState.upsert({
        where: { call_sid: callSid },
        create: {
          call_sid: callSid,
          ward_id: result.wardId,
          ward_status: result.wardId ? 'identified' : 'not_found',
        },
        update: {
          ward_id: result.wardId,
          ward_status: result.wardId ? 'identified' : 'not_found',
        },
      });

      this.logger.log(`[EP-WARD] ✅ Ward state saved.`);
    } catch (err) {
      this.logger.error(
        `[EP-WARD] DB error (non-fatal): ${(err as Error).message}`,
      );
    }

    return { success: true };
  }

  // ── EP-METHOD: Complaint Method Selection ────────────────────────────────
  async handleComplaintMethod(
    data: IvrCallbackDto,
  ): Promise<{ success: boolean }> {
    const callSid = data.CallSid || `UNKNOWN_${Date.now()}`;
    this.logger.log(`[EP-METHOD] Complaint method for CallSid: ${callSid}`);

    const cleanDigits = this.cleanDigits(data.digits);
    // 1 = keypad (pole ID), 2 = voice complaint
    const method = cleanDigits === '1' ? 'keypad' : cleanDigits === '2' ? 'voice' : null;

    this.logger.log(
      `[EP-METHOD] User selected digit="${cleanDigits}" → method="${method}"`,
    );

    try {
      // Update IvrCallState with complaint method
      await this.prisma.ivrCallState.upsert({
        where: { call_sid: callSid },
        create: {
          call_sid: callSid,
          complaint_method: method,
        },
        update: {
          complaint_method: method,
        },
      });

      this.logger.log(`[EP-METHOD] ✅ Complaint method saved.`);
    } catch (err) {
      this.logger.error(
        `[EP-METHOD] DB error (non-fatal): ${(err as Error).message}`,
      );
    }

    return { success: true };
  }

  // ── BOT AGENT TOOL: Direct Complaint Registration ────────────────────────
  async createBotComplaint(data: {
    service_type?: string;
    ward_number?: number | string;
    pole_id?: string;
    issue_description?: string;
    caller_phone?: string;
  }): Promise<{
    success: boolean;
    complaint_id: string;
    service: string;
    ward: number | null;
    message: string;
  }> {
    this.logger.log(`[BOT-TOOL] Received complaint from AI bot: ${JSON.stringify(data)}`);

    // 1. Find Mettupalayam Municipality OrgUnit (or first available org unit)
    let orgUnit = await this.prisma.orgUnit.findFirst({
      where: {
        name: { contains: 'Mettupalayam', mode: 'insensitive' },
      },
    });

    if (!orgUnit) {
      orgUnit = await this.prisma.orgUnit.findFirst();
    }

    const orgUnitId = orgUnit?.id ?? 1;

    // 2. Resolve Ward ID if ward_number provided
    let wardId: number | null = null;
    let resolvedWardNumber: number | null = null;

    if (data.ward_number) {
      const wardNum = parseInt(String(data.ward_number).replace(/\D/g, ''), 10);
      if (!isNaN(wardNum)) {
        resolvedWardNumber = wardNum;
        const ward = await this.prisma.ward.findFirst({
          where: {
            org_unit_id: orgUnitId,
            ward_number: wardNum,
          },
        });
        if (ward) {
          wardId = ward.id;
        }
      }
    }

    // 3. Normalize service type
    const rawService = (data.service_type || 'general').toLowerCase();
    let serviceType = 'general';
    if (rawService.includes('light') || rawService.includes('street') || rawService.includes('விளக்கு')) {
      serviceType = 'street_light';
    } else if (rawService.includes('water') || rawService.includes('தண்ணீர்') || rawService.includes('குடிநீர்')) {
      serviceType = 'water';
    } else if (rawService.includes('garb') || rawService.includes('waste') || rawService.includes('குப்பை')) {
      serviceType = 'garbage';
    } else if (rawService.includes('drain') || rawService.includes('சாக்கடை')) {
      serviceType = 'drainage';
    }

    // 4. Resolve Pole ID if given for street_light
    let poleId: number | null = null;
    if (data.pole_id && serviceType === 'street_light') {
      const cleanPole = String(data.pole_id).trim();
      const pole = await this.prisma.electricPole.findFirst({
        where: {
          org_unit_id: orgUnitId,
          OR: [
            { keypad_id: cleanPole },
            { pole_number: { contains: cleanPole, mode: 'insensitive' } },
          ],
        },
      });
      if (pole) {
        poleId = pole.id;
        if (!wardId && pole.ward_id) {
          wardId = pole.ward_id;
        }
      }
    }

    // 5. Detect Urgency
    const desc = data.issue_description || '';
    const isCritical =
      desc.toLowerCase().includes('wire') ||
      desc.toLowerCase().includes('spark') ||
      desc.toLowerCase().includes('shock') ||
      desc.toLowerCase().includes('கம்பி') ||
      desc.toLowerCase().includes('அறுந்து') ||
      desc.toLowerCase().includes('burst');

    // 6. Create Complaint Record in Prisma
    const complaint = await this.prisma.complaint.create({
      data: {
        org_unit_id: orgUnitId,
        ward_id: wardId,
        pole_id: poleId,
        complaint_type: serviceType,
        description: desc || `AI Voicebot ${serviceType} complaint from ${data.caller_phone || 'citizen'}`,
        status: 'pending',
        urgency_level: isCritical ? 'critical' : 'medium',
      },
    });

    const formattedId = `MTP-${complaint.id}`;
    this.logger.log(`[BOT-TOOL] ✅ Created complaint #${complaint.id} (${formattedId})`);

    return {
      success: true,
      complaint_id: formattedId,
      service: serviceType,
      ward: resolvedWardNumber,
      message: `Complaint #${formattedId} successfully registered in Mettupalayam Municipality system.`,
    };
  }

  // ── BOT AGENT TOOL: Fetch Existing Complaints ────────────────────────────
  async fetchBotComplaints(data: {
    caller_phone?: string;
    complaint_id?: string | number;
    service_type?: string;
  }): Promise<{
    success: boolean;
    total_complaints: number;
    complaints: Array<{
      complaint_id: string;
      service_type: string;
      status: string;
      ward_number: string | number | null;
      description: string;
      created_date: string;
      is_resolved: boolean;
    }>;
    message: string;
    tracking_info: string;
  }> {
    this.logger.log(`[BOT-TOOL] Fetching complaints for: ${JSON.stringify(data)}`);

    try {
      const whereConditions: any[] = [];

      // 1. If complaint_id is provided, search by ID
      if (data.complaint_id) {
        const cleanId = parseInt(
          String(data.complaint_id).replace(/\D/g, ''),
          10,
        );
        if (!isNaN(cleanId)) {
          whereConditions.push({ id: cleanId });
        }
      }

      // 2. If caller_phone is provided, search by guest_phone or description containing phone
      if (data.caller_phone) {
        const phone = String(data.caller_phone).trim();
        const digitsOnly = phone.replace(/\D/g, '');
        const last10Digits = digitsOnly.slice(-10);

        whereConditions.push({
          OR: [
            { guest_phone: { contains: last10Digits || phone } },
            { description: { contains: last10Digits || phone } },
          ],
        });
      }

      // 3. Optional service type filter
      if (data.service_type) {
        const rawService = data.service_type.toLowerCase();
        let serviceType = rawService;
        if (rawService.includes('light') || rawService.includes('street') || rawService.includes('விளக்கு')) {
          serviceType = 'street_light';
        } else if (rawService.includes('water') || rawService.includes('தண்ணீர்') || rawService.includes('குடிநீர்')) {
          serviceType = 'water';
        } else if (rawService.includes('garb') || rawService.includes('waste') || rawService.includes('குப்பை')) {
          serviceType = 'garbage';
        } else if (rawService.includes('drain') || rawService.includes('சாக்கடை')) {
          serviceType = 'drainage';
        }
        whereConditions.push({
          complaint_type: { contains: serviceType, mode: 'insensitive' },
        });
      }

      // Query database
      const records = await this.prisma.complaint.findMany({
        where: whereConditions.length > 0 ? { OR: whereConditions } : {},
        orderBy: { created_at: 'desc' },
        take: 5,
        include: {
          ward: {
            select: { ward_number: true, name_en: true, name_ta: true },
          },
        },
      });

      const complaintsList = records.map((c) => ({
        complaint_id: `MTP-${c.id}`,
        service_type: c.complaint_type || 'general',
        status: c.status || 'pending',
        ward_number: c.ward?.ward_number ?? c.ward_number ?? null,
        description: c.description || 'No description provided',
        created_date: c.created_at.toISOString().split('T')[0],
        is_resolved: c.status?.toLowerCase() === 'resolved' || c.status?.toLowerCase() === 'closed',
      }));

      const count = complaintsList.length;

      let message = '';
      if (count > 0) {
        const activeComplaints = complaintsList.filter((c) => !c.is_resolved);
        if (activeComplaints.length > 0) {
          const latest = activeComplaints[0];
          message = `Found ${count} existing complaint(s). Most recent active complaint is #${latest.complaint_id} for ${latest.service_type} in Ward ${latest.ward_number ?? 'N/A'}, currently with status: ${latest.status}.`;
        } else {
          message = `Found ${count} existing complaint(s), all of which are already resolved.`;
        }
      } else {
        message = 'No existing complaints found for this caller/ID.';
      }

      return {
        success: true,
        total_complaints: count,
        complaints: complaintsList,
        message,
        tracking_info:
          'Citizens can also track live progress and submit feedback via the Sengotics Citizen Portal / App.',
      };
    } catch (err) {
      this.logger.error(`[BOT-TOOL] Error fetching complaints: ${(err as Error).message}`);
      return {
        success: true,
        total_complaints: 0,
        complaints: [],
        message: 'No existing complaints found.',
        tracking_info:
          'Citizens can track complaints on the Sengotics Citizen Mobile App.',
      };
    }
  }

  // ── Private Helpers ─────────────────────────────────────────────────────────

  /** Clean and normalize digits from Exotel (strip quotes and whitespace). */
  private cleanDigits(raw?: string): string | null {
    if (!raw) return null;
    const cleaned = raw.replace(/"/g, '').trim();
    return cleaned || null;
  }

  /** Create a complaint for the given service type. */
  private async createServiceComplaint(
    serviceType: string,
    detail: string,
    orgUnitId: number,
    callerNumber: string,
    wardId?: number | null,
  ): Promise<{ id: number }> {
    // For street_light, look up the specific pole
    if (serviceType === 'street_light') {
      // If ward is known, scope the pole search to that ward
      const whereClause: any = { org_unit_id: orgUnitId, keypad_id: detail };
      if (wardId) {
        whereClause.ward_id = wardId;
      }

      const pole = await this.prisma.electricPole.findFirst({
        where: whereClause,
      });

      if (!pole) {
        this.logger.warn(
          `[EP2] No pole found with keypad_id="${detail}" in panchayat ${orgUnitId}${wardId ? ` ward ${wardId}` : ''}`,
        );
        throw new Error(`Pole with keypad_id="${detail}" not found`);
      }

      const complaint = await this.prisma.complaint.create({
        data: {
          pole_id: pole.id,
          org_unit_id: orgUnitId,
          ward_id: wardId ?? null,
          complaint_type: 'street_light',
          description: `IVR street light complaint for pole ${pole.pole_number} (keypad: ${detail}) from ${callerNumber}`,
          status: 'pending',
        },
      });
      this.logger.log(
        `[EP2] ✅ Street light complaint #${complaint.id} created for pole ${pole.pole_number}`,
      );
      return complaint;
    }

    // For all other services, create a generic complaint
    const complaint = await this.prisma.complaint.create({
      data: {
        org_unit_id: orgUnitId,
        ward_id: wardId ?? null,
        complaint_type: serviceType,
        description: `IVR ${serviceType} complaint from ${callerNumber} (input: ${detail})`,
        status: 'pending',
      },
    });
    this.logger.log(
      `[EP2] ✅ ${serviceType} complaint #${complaint.id} created`,
    );
    return complaint;
  }
}

