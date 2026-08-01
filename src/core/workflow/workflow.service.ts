import { Injectable, Logger, NotFoundException, BadRequestException } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { PrismaService } from '../../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import {
  WorkflowStepCompletedEvent,
  PLATFORM_EVENTS,
} from '../events/platform-events';

@Injectable()
export class WorkflowService {
  private readonly logger = new Logger(WorkflowService.name);

  constructor(
    private prisma: PrismaService,
    private audit: AuditService,
    private events: EventEmitter2,
  ) {}

  /**
   * Evaluates if a WorkflowRule condition matches the entity context.
   */
  private evaluateRule(rule: any, context: Record<string, any>): boolean {
    const value = context[rule.condition_field];
    if (value === undefined) return false;

    const target = rule.condition_value;

    switch (rule.condition_op) {
      case 'eq':
        return value === target;
      case 'gt':
        return Number(value) > Number(target);
      case 'lt':
        return Number(value) < Number(target);
      case 'in':
        return Array.isArray(target) && target.includes(value);
      case 'between':
        return (
          Array.isArray(target) &&
          target.length === 2 &&
          Number(value) >= Number(target[0]) &&
          Number(value) <= Number(target[1])
        );
      default:
        return false;
    }
  }

  /**
   * Fetch complete field context of any database entity.
   */
  async getEntityContext(entityType: string, entityId: number): Promise<Record<string, any>> {
    let entity: any = null;
    const modelName = entityType.toLowerCase();

    try {
      if (modelName === 'complaint') {
        entity = await this.prisma.complaint.findUnique({ where: { id: entityId } });
      } else if (modelName === 'tender') {
        entity = await this.prisma.tender.findUnique({ where: { id: entityId } });
      } else if (modelName === 'asset') {
        entity = await this.prisma.asset.findUnique({ where: { id: entityId } });
      } else {
        // Fallback for dynamic models
        entity = await (this.prisma as any)[entityType].findUnique({ where: { id: entityId } });
      }
    } catch (err) {
      this.logger.warn(`Could not extract context fields for ${entityType}#${entityId}: ${err.message}`);
    }

    return entity ? { ...entity } : {};
  }

  /**
   * Start a new workflow instance for an entity.
   * Evaluates first step skip rules recursively.
   */
  async startWorkflow(
    tenantId: string,
    orgUnitId: number,
    templateName: string,
    entityType: string,
    entityId: number,
  ) {
    const template = await this.prisma.workflowTemplate.findFirst({
      where: {
        org_unit_id: orgUnitId,
        name: templateName,
        status: 'published',
        is_active: true,
      },
      orderBy: { version: 'desc' },
      include: { steps: { orderBy: { step_order: 'asc' } } },
    });

    if (!template) {
      this.logger.warn(`No published workflow template "${templateName}" for branch ${orgUnitId}`);
      return null;
    }

    if (template.steps.length === 0) {
      this.logger.warn(`Template "${templateName}" has no steps`);
      return null;
    }

    const context = await this.getEntityContext(entityType, entityId);
    let startStepOrder = template.steps[0].step_order;
    let currentCheckOrder = 0;

    while (true) {
      const stepToCheck = template.steps.find((s) => s.step_order > currentCheckOrder);
      if (!stepToCheck) {
        // All steps skipped! Create as completed
        return this.prisma.workflowInstance.create({
          data: {
            tenant_id: tenantId,
            template_id: template.id,
            entity_type: entityType,
            entity_id: entityId,
            current_step_order: 1,
            status: 'completed',
            completed_at: new Date(),
          },
        });
      }

      const stepRules = await this.prisma.workflowRule.findMany({
        where: { template_id: template.id, step_id: stepToCheck.id },
        orderBy: { priority: 'asc' },
      });

      let skipThisStep = false;
      for (const rule of stepRules) {
        if (this.evaluateRule(rule, context)) {
          if (rule.then_action === 'skip_step') {
            skipThisStep = true;
            break;
          }
        }
      }

      if (skipThisStep) {
        currentCheckOrder = stepToCheck.step_order;
        continue;
      } else {
        startStepOrder = stepToCheck.step_order;
        break;
      }
    }

    const instance = await this.prisma.workflowInstance.create({
      data: {
        tenant_id: tenantId,
        template_id: template.id,
        entity_type: entityType,
        entity_id: entityId,
        current_step_order: startStepOrder,
        status: 'in_progress',
      },
    });

    this.logger.log(
      `Started workflow instance ${instance.id} (template: ${templateName} v${template.version}) starting at step order ${startStepOrder}`,
    );

    return instance;
  }

  /**
   * Process approval actions. Evaluates next step skip rules recursively.
   */
  async processAction(
    tenantId: string,
    instanceId: number,
    actorUserId: number,
    action: 'approved' | 'rejected' | 'returned' | 'escalated' | 'executed',
    comments?: string,
  ) {
    const instance = await this.prisma.workflowInstance.findUnique({
      where: { id: instanceId },
      include: {
        template: {
          include: {
            steps: { orderBy: { step_order: 'asc' } },
            rules: true,
          },
        },
      },
    });

    if (!instance) throw new NotFoundException('Workflow instance not found');
    if (instance.status !== 'in_progress') {
      throw new BadRequestException(`Workflow is ${instance.status}, cannot process action`);
    }

    const currentStep = instance.template.steps.find(
      (s) => s.step_order === instance.current_step_order,
    );
    if (!currentStep) {
      throw new BadRequestException('Current step not found in template');
    }

    await this.prisma.workflowStepAction.create({
      data: {
        instance_id: instanceId,
        step_id: currentStep.id,
        actor_user_id: actorUserId,
        action,
        comments: comments ?? null,
      },
    });

    await this.audit.log({
      tenantId,
      userId: actorUserId,
      module: 'workflow',
      entityType: instance.entity_type,
      entityId: instance.entity_id.toString(),
      action: `workflow_${action}`,
      afterValue: {
        instanceId,
        stepOrder: currentStep.step_order,
        roleName: currentStep.role_name,
        comments,
      },
    });

    if (action === 'rejected') {
      await this.prisma.workflowInstance.update({
        where: { id: instanceId },
        data: { status: 'rejected', completed_at: new Date() },
      });
    } else if (action === 'returned') {
      const prevStepOrder = currentStep.step_order - 1;
      if (prevStepOrder < 1) {
        throw new BadRequestException('Cannot return from first step');
      }
      await this.prisma.workflowInstance.update({
        where: { id: instanceId },
        data: { current_step_order: prevStepOrder },
      });
    } else if (action === 'approved' || action === 'executed') {
      const context = await this.getEntityContext(instance.entity_type, instance.entity_id);
      let nextStepOrder: number | null = null;
      let currentCheckOrder = currentStep.step_order;
      let workflowStatus = 'in_progress';

      while (true) {
        const nextStep = instance.template.steps.find((s) => s.step_order > currentCheckOrder);
        if (!nextStep) {
          nextStepOrder = null;
          workflowStatus = 'completed';
          break;
        }

        const stepRules = await this.prisma.workflowRule.findMany({
          where: { template_id: instance.template_id, step_id: nextStep.id },
          orderBy: { priority: 'asc' },
        });

        let skipThisStep = false;
        for (const rule of stepRules) {
          if (this.evaluateRule(rule, context)) {
            if (rule.then_action === 'skip_step') {
              skipThisStep = true;
              break;
            }
          }
        }

        if (skipThisStep) {
          currentCheckOrder = nextStep.step_order;
          continue;
        } else {
          nextStepOrder = nextStep.step_order;
          break;
        }
      }

      if (nextStepOrder !== null) {
        await this.prisma.workflowInstance.update({
          where: { id: instanceId },
          data: { current_step_order: nextStepOrder },
        });
      } else {
        await this.prisma.workflowInstance.update({
          where: { id: instanceId },
          data: { status: workflowStatus as any, completed_at: new Date() },
        });
      }
    } else if (action === 'escalated') {
      await this.prisma.workflowInstance.update({
        where: { id: instanceId },
        data: { status: 'escalated' },
      });
    }

    this.events.emit(
      PLATFORM_EVENTS.WORKFLOW_STEP_COMPLETED,
      new WorkflowStepCompletedEvent(
        tenantId,
        instanceId,
        currentStep.id,
        action,
        actorUserId,
      ),
    );

    return this.prisma.workflowInstance.findUnique({
      where: { id: instanceId },
      include: {
        template: { include: { steps: { orderBy: { step_order: 'asc' } } } },
        actions: { orderBy: { acted_at: 'desc' } },
      },
    });
  }

  async getTimeline(tenantId: string, entityType: string, entityId: number) {
    return this.prisma.workflowInstance.findFirst({
      where: {
        tenant_id: tenantId,
        entity_type: entityType,
        entity_id: entityId,
      },
      orderBy: { started_at: 'desc' },
      include: {
        template: {
          include: {
            steps: { orderBy: { step_order: 'asc' } },
          },
        },
        actions: {
          orderBy: { acted_at: 'asc' },
        },
      },
    });
  }

  async getPendingForRole(tenantId: string, orgUnitId: number, roleName: string) {
    const steps = await this.prisma.workflowStep.findMany({
      where: { role_name: roleName },
      select: { id: true, step_order: true, template_id: true },
    });

    if (steps.length === 0) return [];

    return this.prisma.workflowInstance.findMany({
      where: {
        tenant_id: tenantId,
        status: 'in_progress',
        OR: steps.map((s) => ({
          template_id: s.template_id,
          current_step_order: s.step_order,
        })),
      },
      include: {
        template: true,
      },
      orderBy: { started_at: 'asc' },
    });
  }

  // ── Template, Step & Rule management (CRUD) ────────────────────────────────

  async createTemplate(tenantId: string, data: any) {
    return this.prisma.workflowTemplate.create({
      data: {
        ...data,
        tenant_id: tenantId,
      },
    });
  }

  async createStep(data: any) {
    return this.prisma.workflowStep.create({
      data,
    });
  }

  async createRule(data: any) {
    return this.prisma.workflowRule.create({
      data: {
        template_id: data.template_id,
        step_id: data.step_id,
        condition_field: data.condition_field,
        condition_op: data.condition_op,
        condition_value: data.condition_value,
        then_action: data.then_action,
        then_value: data.then_value ?? null,
        priority: data.priority ?? 1,
      },
    });
  }
}
