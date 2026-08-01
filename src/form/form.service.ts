import { Injectable, NotFoundException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { FormField } from '@prisma/client';

export class CreateFieldDto {
  field_key: string;
  field_type: string;
  label: string;
  label_ta?: string;
  placeholder?: string;
  options?: any;
  validation?: any;
  display_order: number;
  section?: string;
  visible_when?: any;
  is_required?: boolean;
}

export class CreateTemplateDto {
  code: string;
  name: string;
  name_ta?: string;
  module: string;
  version?: number;
  fields: CreateFieldDto[];
}

@Injectable()
export class FormService {
  private readonly logger = new Logger(FormService.name);

  constructor(private prisma: PrismaService) {}

  /**
   * Create a dynamic form template with its fields.
   */
  async createTemplate(tenantId: string, dto: CreateTemplateDto) {
    // Check if version code unique
    const existing = await this.prisma.formTemplate.findFirst({
      where: {
        tenant_id: tenantId,
        code: dto.code,
        version: dto.version ?? 1,
      },
    });

    if (existing) {
      throw new BadRequestException(`Form template with code "${dto.code}" version ${dto.version ?? 1} already exists.`);
    }

    const template = await this.prisma.formTemplate.create({
      data: {
        tenant_id: tenantId,
        code: dto.code,
        name: dto.name,
        name_ta: dto.name_ta ?? null,
        module: dto.module,
        version: dto.version ?? 1,
        is_active: true,
      },
    });

    // Create fields in batch
    if (dto.fields && dto.fields.length > 0) {
      await this.prisma.formField.createMany({
        data: dto.fields.map((f) => ({
          template_id: template.id,
          field_key: f.field_key,
          field_type: f.field_type,
          label: f.label,
          label_ta: f.label_ta ?? null,
          placeholder: f.placeholder ?? null,
          options: f.options ?? null,
          validation: f.validation ?? null,
          display_order: f.display_order,
          section: f.section ?? null,
          visible_when: f.visible_when ?? null,
          is_required: f.is_required ?? false,
        })),
      });
    }

    return this.getTemplate(tenantId, template.id);
  }

  async getTemplates(tenantId: string) {
    return this.prisma.formTemplate.findMany({
      where: { tenant_id: tenantId, is_active: true },
      include: { fields: { orderBy: { display_order: 'asc' } } },
    });
  }

  async getTemplate(tenantId: string, id: number) {
    const template = await this.prisma.formTemplate.findFirst({
      where: { id, tenant_id: tenantId, is_active: true },
      include: { fields: { orderBy: { display_order: 'asc' } } },
    });
    if (!template) throw new NotFoundException(`Form template #${id} not found.`);
    return template;
  }

  /**
   * Evaluate if a field is visible based on conditional values.
   */
  evaluateVisibility(field: FormField, data: Record<string, any>): boolean {
    const rules = field.visible_when as any;
    if (!rules || Object.keys(rules).length === 0) return true;

    const conditionField = rules.field;
    const expectedValue = rules.value;
    const op = rules.op ?? 'eq';

    const actualValue = data[conditionField];
    if (actualValue === undefined) return false;

    switch (op) {
      case 'eq':
        return actualValue === expectedValue;
      case 'gt':
        return Number(actualValue) > Number(expectedValue);
      case 'lt':
        return Number(actualValue) < Number(expectedValue);
      default:
        return false;
    }
  }

  /**
   * Run schema validations on the submitted JSON.
   */
  validateSubmission(fields: FormField[], data: Record<string, any>) {
    for (const field of fields) {
      // 1. Evaluate Visibility
      const isVisible = this.evaluateVisibility(field, data);
      if (!isVisible) {
        continue; // Skip validations for fields that are conditionally hidden
      }

      const value = data[field.field_key];

      // 2. Required Check
      if (field.is_required && (value === undefined || value === null || value === '')) {
        throw new BadRequestException(`Field "${field.label}" (${field.field_key}) is required`);
      }

      if (value === undefined || value === null || value === '') {
        continue;
      }

      // 3. Number Type Check
      if (field.field_type === 'number') {
        const num = Number(value);
        if (isNaN(num)) {
          throw new BadRequestException(`Field "${field.label}" must be a number`);
        }

        const valRules = field.validation as any;
        if (valRules) {
          if (valRules.min !== undefined && num < Number(valRules.min)) {
            throw new BadRequestException(`Field "${field.label}" must be at least ${valRules.min}`);
          }
          if (valRules.max !== undefined && num > Number(valRules.max)) {
            throw new BadRequestException(`Field "${field.label}" must not exceed ${valRules.max}`);
          }
        }
      }

      // 4. Date Type Check
      if (field.field_type === 'date') {
        const date = Date.parse(value as string);
        if (isNaN(date)) {
          throw new BadRequestException(`Field "${field.label}" must be a valid date`);
        }
      }

      // 5. Pattern Validation
      const valRules = field.validation as any;
      if (valRules?.pattern) {
        const regex = new RegExp(valRules.pattern);
        if (!regex.test(String(value))) {
          throw new BadRequestException(`Field "${field.label}" does not match required layout format`);
        }
      }
    }
  }

  /**
   * Submit form payload.
   */
  async submitForm(
    tenantId: string,
    orgUnitId: number,
    templateId: number,
    submittedBy: number | null,
    data: Record<string, any>,
    entityType?: string,
    entityId?: number,
  ) {
    const template = await this.getTemplate(tenantId, templateId);

    // Validate using the schema definitions
    this.validateSubmission(template.fields, data);

    // Create FormSubmission
    const submission = await this.prisma.formSubmission.create({
      data: {
        tenant_id: tenantId,
        org_unit_id: orgUnitId,
        template_id: templateId,
        submitted_by: submittedBy,
        data: data as any,
        status: 'submitted',
        entity_type: entityType ?? null,
        entity_id: entityId ?? null,
      },
    });

    return submission;
  }
}
