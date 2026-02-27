/**
 * IVR Callback DTO — deliberately lenient.
 *
 * Exotel sends variable payloads depending on the callback type.
 * We intentionally avoid strict validation here because a validation
 * failure produces a 400 error that Exotel cannot handle, causing
 * the call to disconnect. Every field is optional; the service layer
 * handles missing data gracefully.
 */
export class IvrCallbackDto {
    CallSid?: string
    CallFrom?: string
    CallTo?: string
    From?: string
    To?: string
    Direction?: string
    Created?: string
    StartTime?: string
    EndTime?: string
    CallType?: string
    DialCallDuration?: string
    DialWhomNumber?: string
    flow_id?: string
    tenant_id?: string
    CurrentTime?: string
    digits?: string
    RecordingUrl?: string
    RecordingAvailableBy?: string
    ProcessStatus?: string

    // Exotel may send additional fields not listed above.
    // We capture them via the catch-all index signature.
    [key: string]: any
}
