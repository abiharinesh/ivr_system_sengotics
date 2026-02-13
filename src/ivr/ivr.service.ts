import { Injectable, Logger } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'
import { IvrCallbackDto } from './dto/ivr-callback.dto'

@Injectable()
export class IvrService {
    private readonly logger = new Logger(IvrService.name)

    constructor(private prisma: PrismaService) { }

    async handleServiceSelection(data: IvrCallbackDto) {
        this.logger.log(`Processing service selection for CallSid: ${data.CallSid}`)

        // Upsert calls_master
        await this.prisma.callsMaster.upsert({
            where: { call_sid: data.CallSid },
            create: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                call_to: data.CallTo,
                flow_id: data.flow_id,
                tenant_id: data.tenant_id,
                call_start_time: data.StartTime ? new Date(data.StartTime) : null,
                call_end_time: data.EndTime ? new Date(data.EndTime) : null,
                service_selected: !!data.digits
            },
            update: {
                service_selected: !!data.digits,
                updated_at: new Date()
            }
        })

        // Insert service selection record
        await this.prisma.ivrServiceSelection.create({
            data: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                service_option: data.digits,
                raw_payload: data as any
            }
        })

        return { success: true }
    }

    async handlePollInput(data: IvrCallbackDto) {
        this.logger.log(`Processing poll input for CallSid: ${data.CallSid}`)

        // Upsert calls_master
        await this.prisma.callsMaster.upsert({
            where: { call_sid: data.CallSid },
            create: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                call_to: data.CallTo,
                flow_id: data.flow_id,
                tenant_id: data.tenant_id,
                call_start_time: data.StartTime ? new Date(data.StartTime) : null,
                call_end_time: data.EndTime ? new Date(data.EndTime) : null,
                poll_entered: !!data.digits
            },
            update: {
                poll_entered: !!data.digits,
                updated_at: new Date()
            }
        })

        // Insert poll input record
        await this.prisma.ivrPollInput.create({
            data: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                poll_id: data.digits,
                raw_payload: data as any
            }
        })

        return { success: true }
    }

    async handleVoicemail(data: IvrCallbackDto) {
        this.logger.log(`Processing voicemail for CallSid: ${data.CallSid}`)

        // Upsert calls_master
        await this.prisma.callsMaster.upsert({
            where: { call_sid: data.CallSid },
            create: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                call_to: data.CallTo,
                flow_id: data.flow_id,
                tenant_id: data.tenant_id,
                call_start_time: data.StartTime ? new Date(data.StartTime) : null,
                call_end_time: data.EndTime ? new Date(data.EndTime) : null,
                voicemail_left: !!data.RecordingUrl
            },
            update: {
                voicemail_left: !!data.RecordingUrl,
                updated_at: new Date()
            }
        })

        // Insert voicemail record
        await this.prisma.ivrVoicemail.create({
            data: {
                call_sid: data.CallSid,
                caller_number: data.CallFrom,
                recording_url: data.RecordingUrl,
                recording_available_by: data.RecordingAvailableBy ? new Date(data.RecordingAvailableBy) : null,
                raw_payload: data as any
            }
        })

        return { success: true }
    }
}
