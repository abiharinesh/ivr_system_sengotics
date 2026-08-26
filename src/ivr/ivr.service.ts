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

    // 3. Normalize & Auto-Correct service type from both service_type and issue_description
    const rawService = (data.service_type || '').toLowerCase();
    const rawDesc = (data.issue_description || '').toLowerCase();
    const combinedText = `${rawService} ${rawDesc}`;

    let serviceType = 'general';

    // Priority 1: Street Light keywords (STRICT)
    if (
      combinedText.includes('light') ||
      combinedText.includes('street') ||
      combinedText.includes('விளக்கு') ||
      combinedText.includes('லைட்') ||
      combinedText.includes('bulb') ||
      combinedText.includes('பல்பு') ||
      combinedText.includes('pole') ||
      combinedText.includes('போஸ்ட்') ||
      combinedText.includes('கம்பம்') ||
      combinedText.includes('lamp') ||
      combinedText.includes('eriyala') ||
      combinedText.includes('எரியல') ||
      combinedText.includes('வெளிச்சம்') ||
      combinedText.includes('கரண்ட்')
    ) {
      serviceType = 'street_light';
    } 
    // Priority 2: Water Supply keywords
    else if (
      combinedText.includes('water') ||
      combinedText.includes('தண்ணீர்') ||
      combinedText.includes('தண்ணி') ||
      combinedText.includes('குடிநீர்') ||
      combinedText.includes('pipe') ||
      combinedText.includes('பைப்') ||
      combinedText.includes('leak') ||
      combinedText.includes('கசிவு') ||
      combinedText.includes('pressure') ||
      combinedText.includes('டேப்') ||
      combinedText.includes('குழாய்')
    ) {
      serviceType = 'water';
    } 
    // Priority 3: Garbage keywords
    else if (
      combinedText.includes('garb') ||
      combinedText.includes('waste') ||
      combinedText.includes('குப்பை') ||
      combinedText.includes('trash') ||
      combinedText.includes('dustbin') ||
      combinedText.includes('தொட்டி')
    ) {
      serviceType = 'garbage';
    } 
    // Priority 4: Drainage keywords
    else if (
      combinedText.includes('drain') ||
      combinedText.includes('சாக்கடை') ||
      combinedText.includes('கழிவுநீர்') ||
      combinedText.includes('அடைப்பு')
    ) {
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

  // ── BOT AGENT TOOL: Lookup Infrastructure (Poles, Wards, Areas) ──────────
  async lookupInfra(data: {
    pole_id?: string;
    ward_number?: number | string;
    area_name?: string;
  }): Promise<{
    success: boolean;
    found: boolean;
    pole_details?: {
      pole_number: string;
      keypad_id: string | null;
      ward_number: number | null;
      ward_name: string | null;
      location: string | null;
    } | null;
    ward_details?: {
      ward_number: number;
      name_en: string | null;
      name_ta: string | null;
    } | null;
    message: string;
  }> {
    this.logger.log(`[BOT-TOOL] Infrastructure lookup: ${JSON.stringify(data)}`);

    try {
      let poleResult: any = null;
      let wardResult: any = null;

      // 1. Find pole if pole_id provided
      if (data.pole_id) {
        const cleanPole = String(data.pole_id).trim();
        const pole = await this.prisma.electricPole.findFirst({
          where: {
            OR: [
              { keypad_id: cleanPole },
              { pole_number: { contains: cleanPole, mode: 'insensitive' } },
            ],
          },
          include: {
            ward: { select: { ward_number: true, name_en: true, name_ta: true } },
          },
        });

        if (pole) {
          poleResult = {
            pole_number: pole.pole_number,
            keypad_id: pole.keypad_id,
            ward_number: pole.ward?.ward_number ?? null,
            ward_name: pole.ward?.name_en ?? null,
            location: pole.pole_number,
          };
          if (!wardResult && pole.ward) {
            wardResult = {
              ward_number: pole.ward.ward_number,
              name_en: pole.ward.name_en,
              name_ta: pole.ward.name_ta,
            };
          }
        }
      }

      // 2. Find ward by number or area name
      if (!wardResult && data.ward_number) {
        const wardNum = parseInt(String(data.ward_number).replace(/\D/g, ''), 10);
        if (!isNaN(wardNum)) {
          const ward = await this.prisma.ward.findFirst({
            where: { ward_number: wardNum },
          });
          if (ward) {
            wardResult = {
              ward_number: ward.ward_number,
              name_en: ward.name_en,
              name_ta: ward.name_ta,
            };
          }
        }
      }

      if (!wardResult && data.area_name) {
        const area = String(data.area_name).trim();
        const ward = await this.prisma.ward.findFirst({
          where: {
            OR: [
              { name_en: { contains: area, mode: 'insensitive' } },
              { name_ta: { contains: area, mode: 'insensitive' } },
            ],
          },
        });
        if (ward) {
          wardResult = {
            ward_number: ward.ward_number,
            name_en: ward.name_en,
            name_ta: ward.name_ta,
          };
        }
      }

      const isFound = Boolean(poleResult || wardResult);

      let msg = '';
      if (poleResult) {
        msg = `Pole ${poleResult.pole_number} is verified in Ward ${poleResult.ward_number || 'N/A'} (${poleResult.ward_name || ''}).`;
      } else if (wardResult) {
        msg = `Ward ${wardResult.ward_number} (${wardResult.name_en || ''}) is verified in Mettupalayam Municipality.`;
      } else {
        msg = 'No matching pole or ward found in live database.';
      }

      return {
        success: true,
        found: isFound,
        pole_details: poleResult,
        ward_details: wardResult,
        message: msg,
      };
    } catch (err) {
      this.logger.error(`[BOT-TOOL] Lookup error: ${(err as Error).message}`);
      return {
        success: false,
        found: false,
        pole_details: null,
        ward_details: null,
        message: 'Database lookup error.',
      };
    }
  }

  // ── BOT WEBHOOK: Handle Session End (Save Recording & Transcript) ────────
  async handleBotSessionEnd(payload: any): Promise<{ success: boolean }> {
    this.logger.log(`[BOT-WEBHOOK] Session end payload: ${JSON.stringify(payload)}`);

    try {
      // 1. Recursive helper to extract any recording URL in the payload
      const findRecordingUrl = (obj: any): string | null => {
        if (!obj) return null;
        if (typeof obj === 'string') {
          if (obj.includes('recordings.exotel.com') || (obj.startsWith('http') && (obj.endsWith('.mp3') || obj.endsWith('.wav')))) {
            return obj;
          }
          return null;
        }
        if (typeof obj === 'object') {
          for (const key of Object.keys(obj)) {
            const val = obj[key];
            if (
              key.toLowerCase().includes('recording') ||
              key.toLowerCase().includes('audio') ||
              key.toLowerCase().includes('media') ||
              key.toLowerCase().includes('url')
            ) {
              if (typeof val === 'string' && val.startsWith('http')) {
                return val;
              }
            }
            const nested = findRecordingUrl(val);
            if (nested) return nested;
          }
        }
        return null;
      };

      // 2. Recursive helper to extract conversation transcripts
      const extractTranscript = (obj: any): string => {
        if (!obj) return '';
        if (typeof obj === 'string') return obj;

        // Check for array of messages / turns / dialogue at various paths
        const possibleArrays = [
          obj.conversation_transcript,
          obj.transcripts,
          obj.transcript,
          obj.messages,
          obj.dialogue,
          obj.turns,
          obj.chat_history,
          obj.history,
          obj.conversation,
          obj.conversation_history,
          obj.data?.messages,
          obj.data?.transcript,
          obj.data?.conversation,
          obj.data?.conversation_transcript,
          obj.session?.messages,
          obj.session?.transcript,
          obj.session?.conversation,
          obj.result?.transcript,
          obj.result?.messages,
          obj.recording_details?.transcript,
          obj.call_details?.transcript,
        ];

        for (const arr of possibleArrays) {
          if (Array.isArray(arr) && arr.length > 0) {
            return arr
              .map((item: any) => {
                if (typeof item === 'string') return item;
                const speaker = item.role || item.speaker || item.sender || item.from || (item.is_user ? 'Citizen' : 'AI Assistant');
                const text = item.content || item.message || item.text || item.transcript || item.utterance || '';
                return `${speaker}: ${text}`;
              })
              .join('\n');
          }
          // Also handle if the value is a string (e.g. a single transcript text)
          if (typeof arr === 'string' && arr.trim().length > 0) {
            return arr.trim();
          }
        }

        // Check for stringified JSON in transcript-like fields
        for (const key of ['transcript', 'conversation', 'text', 'summary', 'conversation_transcript']) {
          const val = obj[key];
          if (typeof val === 'string' && val.trim().length > 0) {
            // Try to parse as JSON array
            try {
              const parsed = JSON.parse(val);
              if (Array.isArray(parsed) && parsed.length > 0) {
                return parsed
                  .map((item: any) => {
                    if (typeof item === 'string') return item;
                    const speaker = item.role || item.speaker || 'Unknown';
                    const text = item.content || item.message || item.text || '';
                    return `${speaker}: ${text}`;
                  })
                  .join('\n');
              }
            } catch {
              // Not JSON, use as-is
            }
            return val.trim();
          }
        }

        // Deep search for any conversation-like arrays in nested objects
        for (const key of Object.keys(obj)) {
          const val = obj[key];
          if (Array.isArray(val) && val.length > 0 && typeof val[0] === 'object') {
            // Check if items look like dialogue turns
            const first = val[0];
            if (first.role || first.speaker || first.content || first.message || first.text) {
              return val
                .map((item: any) => {
                  const speaker = item.role || item.speaker || item.sender || 'Unknown';
                  const text = item.content || item.message || item.text || '';
                  return `${speaker}: ${text}`;
                })
                .join('\n');
            }
          }
          if (typeof val === 'object' && val !== null && !Array.isArray(val)) {
            const nested = extractTranscript(val);
            if (nested && nested.length > 10) return nested;
          }
        }

        return '';
      };

      // Build a structured summary from the payload when no transcript found
      const buildPayloadSummary = (obj: any): string => {
        const parts: string[] = [];
        const interesting = ['service_type', 'issue_description', 'ward_number', 'pole_id',
          'caller_phone', 'caller_number', 'call_status', 'status', 'duration', 'summary'];
        for (const key of interesting) {
          if (obj[key] != null && String(obj[key]).trim()) {
            parts.push(`${key}: ${String(obj[key]).trim()}`);
          }
        }
        return parts.length > 0
          ? `AI Voicebot Session:\n${parts.join('\n')}`
          : '';
      };

      const callSid =
        payload.call_sid ||
        payload.CallSid ||
        payload.session_id ||
        payload.sessionId ||
        payload.call_id ||
        payload.id ||
        `BOT-${Date.now()}`;

      const recordingUrl = findRecordingUrl(payload);
      const rawTranscript = extractTranscript(payload);
      const transcriptText = rawTranscript || buildPayloadSummary(payload) || 'Voicebot Call Completed';
      const callerPhone =
        payload.caller_phone ||
        payload.caller_number ||
        payload.phone ||
        payload.From ||
        payload.CallFrom ||
        payload.caller ||
        null;

      // 3. Create or update VoiceCall record in database
      const voiceCall = await this.prisma.voiceCall.create({
        data: {
          call_sid: String(callSid),
          audio_url: recordingUrl,
          transcript: transcriptText,
          transcript_english: payload.summary || payload.english_summary || null,
          ai_extracted_json: payload,
          processing_status: 'completed',
          confidence_score: 1.0,
        },
      });

      // 4. Upsert IvrCall record
      if (callSid) {
        await this.prisma.ivrCall.upsert({
          where: { call_sid: String(callSid) },
          create: {
            call_sid: String(callSid),
            caller_number: callerPhone ? String(callerPhone) : null,
            call_start_time: new Date(),
            call_end_time: new Date(),
            final_call_status: 'completed',
          },
          update: {
            caller_number: callerPhone ? String(callerPhone) : undefined,
            call_end_time: new Date(),
            final_call_status: 'completed',
          },
        }).catch(() => null);
      }

      // 5. Link recording to recent complaint if found
      if (recordingUrl && callerPhone) {
        const last10Digits = String(callerPhone).replace(/\D/g, '').slice(-10);
        if (last10Digits) {
          const recentComplaint = await this.prisma.complaint.findFirst({
            where: {
              guest_phone: { contains: last10Digits },
              audio_url: null,
            },
            orderBy: { id: 'desc' },
          });

          if (recentComplaint) {
            await this.prisma.complaint.update({
              where: { id: recentComplaint.id },
              data: {
                audio_url: recordingUrl,
                voice_call_id: voiceCall.id,
              },
            });
            this.logger.log(`[BOT-WEBHOOK] Linked recording to Complaint #${recentComplaint.id}`);
          }
        }
      }

      return { success: true };
    } catch (err) {
      this.logger.error(`[BOT-WEBHOOK] Error saving session end: ${(err as Error).message}`);
      return { success: false };
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

