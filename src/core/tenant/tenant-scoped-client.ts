import { Prisma, PrismaClient } from '@prisma/client';

/**
 * Every model that carries a `tenant_id` column. Read-only reference for
 * `scopedToTenant()` below — keep in sync with schema.prisma.
 */
const TENANT_SCOPED_MODELS = new Set([
  'Announcement', 'AppConfig', 'Asset', 'AssetInspection', 'AssetMaintenanceLog',
  'AuditLog', 'BranchLifecycleEvent', 'CallsMaster', 'CitizenFeedback', 'CitizenProfile',
  'Comment', 'Contractor', 'DashboardWidget', 'DataRetentionPolicy', 'Department',
  'Document', 'DocumentFolder', 'Employee', 'FieldInspection', 'FinancialYear',
  'FormSubmission', 'FormTemplate', 'Holiday', 'InspectionTemplate', 'IntegrationConfig',
  'LocalizationKey', 'MasterCategory', 'Notification', 'NotificationTemplate',
  'OrgUnit', 'PermissionGroup', 'Role', 'RoleDashboard', 'SavedReport',
  'ScheduledJob', 'SequenceConfig', 'SlaPolicy', 'SlaTracker', 'TenantFeatureConfig',
  'User', 'WorkOrder', 'WorkflowInstance', 'WorkflowTemplate', 'WorkingCalendar',
]);

/**
 * Returns a tenant-scoped Prisma client that auto-injects `tenant_id`
 * equality into `where` for read operations (`findMany`, `findFirst`,
 * `count`, `aggregate`, `groupBy`) on every tenant-owned model.
 *
 * Deliberately does NOT touch `findUnique` (its `where` is restricted to
 * unique-key combinations — adding an unrelated field would either be
 * rejected by Prisma or silently ignored, so it isn't a safe place for this)
 * or write operations (`create`/`update`/`delete`/`upsert` — those already
 * take `tenant_id` explicitly at each call site throughout the app, and
 * auto-rewriting write payloads is exactly the kind of blast-radius change
 * that needs its own dedicated, carefully-tested rollout rather than a
 * blanket retrofit).
 *
 * This is opt-in — call `prismaService.scopedToTenant(tenantId)` where you
 * want the extra safety net (e.g. a new tenant-facing service). Existing
 * services keep using the unscoped `PrismaService` unchanged.
 */
export function createTenantScopedClient(base: PrismaClient, tenantId: string) {
  return base.$extends({
    name: 'tenant-scoping',
    query: {
      $allModels: {
        async findMany({ model, args, query }) {
          return query(TENANT_SCOPED_MODELS.has(model) ? withTenantWhere(args, tenantId) : args);
        },
        async findFirst({ model, args, query }) {
          return query(TENANT_SCOPED_MODELS.has(model) ? withTenantWhere(args, tenantId) : args);
        },
        async count({ model, args, query }) {
          return query(TENANT_SCOPED_MODELS.has(model) ? withTenantWhere(args, tenantId) : args);
        },
        async aggregate({ model, args, query }) {
          return query(TENANT_SCOPED_MODELS.has(model) ? withTenantWhere(args, tenantId) : args);
        },
        async groupBy({ model, args, query }) {
          return query(TENANT_SCOPED_MODELS.has(model) ? withTenantWhere(args, tenantId) : args);
        },
      },
    },
  });
}

function withTenantWhere(args: any, tenantId: string) {
  return {
    ...args,
    where: { ...(args?.where ?? {}), tenant_id: tenantId },
  };
}

export type TenantScopedPrismaClient = ReturnType<typeof createTenantScopedClient>;
