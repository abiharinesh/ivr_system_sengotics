/**
 * Core Platform Module — exports all foundational services.
 * Import this single module in AppModule to get tenant isolation,
 * audit trail, number generation, comments, and workflows.
 */
export { TenantModule } from './tenant/tenant.module';
export { TenantService } from './tenant/tenant.service';
export { BranchHierarchyService } from './tenant/branch-hierarchy.service';

export { AuditModule } from './audit/audit.module';
export { AuditService } from './audit/audit.service';

export { NumberGenModule } from './number-gen/number-gen.module';
export { NumberGenService } from './number-gen/number-gen.service';

export { CommentModule } from './comment/comment.module';
export { CommentService } from './comment/comment.service';

export { WorkflowModule } from './workflow/workflow.module';
export { WorkflowService } from './workflow/workflow.service';

export { NotificationModule } from './notification/notification.module';
export { NotificationService } from './notification/notification.service';

export { SlaModule } from './sla/sla.module';
export { SlaService } from './sla/sla.service';

export { DocumentModule } from './document/document.module';
export { DocumentService, StorageAdapter } from './document/document.service';

export * from './events/platform-events';
