/**
 * Platform-wide event definitions.
 * Each event carries enough context for handlers to operate independently.
 * Handlers subscribe via @OnEvent decorator.
 */

// ── Complaint Events ──
export class ComplaintCreatedEvent {
  constructor(
    public readonly tenantId: string,
    public readonly branchId: number,
    public readonly complaintId: number,
    public readonly assetId?: number,
    public readonly assignedTo?: number,
    public readonly userId?: number,
  ) {}
}

export class ComplaintAssignedEvent {
  constructor(
    public readonly tenantId: string,
    public readonly branchId: number,
    public readonly complaintId: number,
    public readonly assignedTo: number,
    public readonly assignedBy?: number,
  ) {}
}

export class ComplaintClosedEvent {
  constructor(
    public readonly tenantId: string,
    public readonly branchId: number,
    public readonly complaintId: number,
    public readonly resolvedBy?: number,
    public readonly assetId?: number,
  ) {}
}

// ── Asset Events ──
export class AssetCreatedEvent {
  constructor(
    public readonly tenantId: string,
    public readonly branchId: number,
    public readonly assetId: number,
    public readonly assetTypeCode: string,
  ) {}
}

export class AssetInspectedEvent {
  constructor(
    public readonly tenantId: string,
    public readonly branchId: number,
    public readonly assetId: number,
    public readonly inspectionId: number,
    public readonly score?: number,
  ) {}
}

// ── Workflow Events ──
export class WorkflowStepCompletedEvent {
  constructor(
    public readonly tenantId: string,
    public readonly instanceId: number,
    public readonly stepId: number,
    public readonly action: string,
    public readonly actorUserId?: number,
  ) {}
}

// ── SLA Events ──
export class SlaWarningEvent {
  constructor(
    public readonly tenantId: string,
    public readonly entityType: string,
    public readonly entityId: number,
    public readonly targetAt: Date,
  ) {}
}

export class SlaBreachedEvent {
  constructor(
    public readonly tenantId: string,
    public readonly entityType: string,
    public readonly entityId: number,
    public readonly breachAt: Date,
  ) {}
}

// ── Branch Events ──
export class BranchStatusChangedEvent {
  constructor(
    public readonly tenantId: string,
    public readonly branchId: number,
    public readonly fromStatus: string,
    public readonly toStatus: string,
  ) {}
}

// ── User Events ──
export class UserLoginEvent {
  constructor(
    public readonly tenantId: string,
    public readonly userId: number,
    public readonly ipAddress?: string,
    public readonly deviceInfo?: string,
  ) {}
}

/**
 * Event name constants for @OnEvent() decorators.
 */
export const PLATFORM_EVENTS = {
  COMPLAINT_CREATED: 'complaint.created',
  COMPLAINT_ASSIGNED: 'complaint.assigned',
  COMPLAINT_CLOSED: 'complaint.closed',
  ASSET_CREATED: 'asset.created',
  ASSET_INSPECTED: 'asset.inspected',
  WORKFLOW_STEP_COMPLETED: 'workflow.step_completed',
  SLA_WARNING: 'sla.warning',
  SLA_BREACHED: 'sla.breached',
  BRANCH_STATUS_CHANGED: 'branch.status_changed',
  USER_LOGIN: 'user.login',
} as const;
