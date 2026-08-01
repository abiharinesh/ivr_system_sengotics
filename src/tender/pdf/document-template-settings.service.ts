import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import {
  DOCUMENT_TEMPLATE_IDS,
  DocumentTemplateId,
  validateTemplateId,
} from '../tender-status';
import { MilestoneService } from '../milestone.service';
import {
  DOCUMENT_TEMPLATE_DEFAULTS_KEY,
  TemplateLayoutConfig,
  TemplateSettingsMap,
  builtinDefaultsMap,
  deepMergeConfig,
  getMergedLayout,
  mergeFieldOverrides,
  parsePanchayatSettingsJson,
  parseSettingsJson,
  sanitizeSettingsMap,
  TEMPLATE_LABELS,
} from './document-template-config';
import { renderTemplate, TemplateContext } from './templates';
import {
  sanitizeFabricScene,
  sanitizeOverlaySvg,
  sanitizeTemplateDefaults,
} from './overlay-sanitize';

@Injectable()
export class DocumentTemplateSettingsService {
  private readonly logger = new Logger(DocumentTemplateSettingsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly milestones: MilestoneService,
  ) {}

  private async loadGlobalMap(): Promise<TemplateSettingsMap> {
    const row = await this.prisma.systemSettings.findUnique({
      where: { key: DOCUMENT_TEMPLATE_DEFAULTS_KEY },
    });
    return parseSettingsJson(row?.value ?? null);
  }

  private async loadPanchayatMap(
    orgUnitId: number,
  ): Promise<TemplateSettingsMap> {
    const p = await this.prisma.orgUnit.findUnique({
      where: { id: orgUnitId },
      select: { document_template_settings: true },
    });
    if (!p) throw new NotFoundException(`Panchayat #${orgUnitId} not found`);
    return parsePanchayatSettingsJson(p.document_template_settings);
  }

  async getGlobalSettings() {
    const stored = await this.loadGlobalMap();
    const templates = this.packAllTemplates(stored, {});
    return {
      scope: 'global' as const,
      templates,
      updated_at: await this.globalUpdatedAt(),
    };
  }

  async updateGlobalSettings(patch: { templates?: unknown }) {
    if (!patch?.templates) {
      throw new BadRequestException('templates object is required');
    }
    const sanitized = sanitizeSettingsMap(patch.templates);
    const existing = await this.loadGlobalMap();
    const merged = this.mergeSettingsMaps(existing, sanitized);
    const row = await this.prisma.systemSettings.upsert({
      where: { key: DOCUMENT_TEMPLATE_DEFAULTS_KEY },
      update: { value: JSON.stringify(merged) },
      create: {
        key: DOCUMENT_TEMPLATE_DEFAULTS_KEY,
        value: JSON.stringify(merged),
      },
    });
    this.logger.log('Document template global defaults updated');
    return {
      scope: 'global' as const,
      templates: this.packAllTemplates(merged, {}),
      updated_at: row.updated_at,
    };
  }

  async getPanchayatSettings(orgUnitId: number) {
    const global = await this.loadGlobalMap();
    const org_unit = await this.loadPanchayatMap(orgUnitId);
    return {
      scope: 'panchayat' as const,
      org_unit_id: orgUnitId,
      templates: this.packAllTemplates(global, org_unit),
      global_templates: global,
      org_unit_overrides: org_unit,
      updated_at: await this.panchayatUpdatedAt(orgUnitId),
    };
  }

  async updatePanchayatSettings(
    orgUnitId: number,
    patch: { templates?: unknown },
  ) {
    if (!patch?.templates) {
      throw new BadRequestException('templates object is required');
    }
    const sanitized = sanitizeSettingsMap(patch.templates);
    const existing = await this.loadPanchayatMap(orgUnitId);
    const merged = this.mergeSettingsMaps(existing, sanitized);
    const p = await this.prisma.orgUnit.update({
      where: { id: orgUnitId },
      data: { document_template_settings: merged as any },
      select: { id: true, document_template_settings: true },
    });
    const global = await this.loadGlobalMap();
    return {
      scope: 'panchayat' as const,
      org_unit_id: orgUnitId,
      templates: this.packAllTemplates(
        global,
        parsePanchayatSettingsJson(p.document_template_settings),
      ),
      updated_at: null,
    };
  }

  async saveGlobalDesign(
    templateId: string,
    body: { fabric_scene?: unknown; overlay_svg?: unknown },
  ) {
    const tpl = validateTemplateId(templateId);
    const existing = await this.loadGlobalMap();
    const patch = this.designPatchForTemplate(existing[tpl], body);
    const merged = this.mergeSettingsMaps(existing, { [tpl]: patch });
    const row = await this.prisma.systemSettings.upsert({
      where: { key: DOCUMENT_TEMPLATE_DEFAULTS_KEY },
      update: { value: JSON.stringify(merged) },
      create: {
        key: DOCUMENT_TEMPLATE_DEFAULTS_KEY,
        value: JSON.stringify(merged),
      },
    });
    this.logger.log(`Document template design updated (global): ${tpl}`);
    return {
      scope: 'global' as const,
      template_id: tpl,
      templates: this.packAllTemplates(merged, {}),
      updated_at: row.updated_at,
    };
  }

  async savePanchayatDesign(
    orgUnitId: number,
    templateId: string,
    body: { fabric_scene?: unknown; overlay_svg?: unknown },
  ) {
    const tpl = validateTemplateId(templateId);
    const existing = await this.loadPanchayatMap(orgUnitId);
    const patch = this.designPatchForTemplate(existing[tpl], body);
    const merged = this.mergeSettingsMaps(existing, { [tpl]: patch });
    const p = await this.prisma.orgUnit.update({
      where: { id: orgUnitId },
      data: { document_template_settings: merged as any },
      select: { id: true, document_template_settings: true },
    });
    const global = await this.loadGlobalMap();
    this.logger.log(
      `Document template design updated (panchayat ${orgUnitId}): ${tpl}`,
    );
    return {
      scope: 'panchayat' as const,
      org_unit_id: orgUnitId,
      template_id: tpl,
      templates: this.packAllTemplates(
        global,
        parsePanchayatSettingsJson(p.document_template_settings),
      ),
      updated_at: null,
    };
  }

  private designPatchForTemplate(
    current: TemplateLayoutConfig | undefined,
    body: { fabric_scene?: unknown; overlay_svg?: unknown },
  ): TemplateLayoutConfig {
    const baseDefaults = {
      ...(current?.defaults ?? {}),
    };
    if (body.fabric_scene !== undefined) {
      const fabric = sanitizeFabricScene(body.fabric_scene);
      if (fabric) baseDefaults.fabric_scene = fabric;
      else delete baseDefaults.fabric_scene;
    }
    if (body.overlay_svg !== undefined) {
      const svg = sanitizeOverlaySvg(body.overlay_svg);
      if (svg) baseDefaults.overlay_svg = svg;
      else delete baseDefaults.overlay_svg;
    }
    const defaults = sanitizeTemplateDefaults(baseDefaults);
    return deepMergeConfig(current ?? {}, {
      defaults: defaults ?? {},
    });
  }

  async resetPanchayatTemplate(orgUnitId: number, templateId: string) {
    const tpl = validateTemplateId(templateId);
    const existing = await this.loadPanchayatMap(orgUnitId);
    delete existing[tpl];
    await this.prisma.orgUnit.update({
      where: { id: orgUnitId },
      data: {
        document_template_settings: Object.keys(existing).length
          ? (existing as any)
          : null,
      },
    });
    return this.getPanchayatSettings(orgUnitId);
  }

  async resolveMergedLayout(
    orgUnitId: number,
    templateId: DocumentTemplateId,
  ): Promise<TemplateLayoutConfig> {
    const [global, org_unit] = await Promise.all([
      this.loadGlobalMap(),
      this.loadPanchayatMap(orgUnitId),
    ]);
    return getMergedLayout(templateId, global, org_unit);
  }

  async resolveMergedFieldOverrides(
    orgUnitId: number,
    templateId: DocumentTemplateId,
    documentOverrides: Record<string, unknown> | null,
  ): Promise<Record<string, unknown>> {
    const layout = await this.resolveMergedLayout(orgUnitId, templateId);
    const defaults = layout.defaults ?? {};
    const { defaults: _d, ...layoutWithoutDefaults } = layout;
    void _d;
    void layoutWithoutDefaults;
    return mergeFieldOverrides(defaults, documentOverrides ?? {});
  }

  async buildPreviewHtml(
    orgUnitId: number,
    templateId: string,
    options?: { tender_id?: number; vendor_id?: number },
  ): Promise<string> {
    const tpl = validateTemplateId(templateId);
    const ctx =
      options?.tender_id != null
        ? await this.buildContextFromTender(
            options.tender_id,
            orgUnitId,
            tpl,
            options.vendor_id ?? null,
          )
        : await this.buildSampleContext(
            orgUnitId,
            tpl,
            options?.vendor_id ?? null,
          );
    return renderTemplate(tpl, ctx);
  }

  private mergeSettingsMaps(
    base: TemplateSettingsMap,
    patch: TemplateSettingsMap,
  ): TemplateSettingsMap {
    const out: TemplateSettingsMap = { ...base };
    for (const id of DOCUMENT_TEMPLATE_IDS) {
      if (patch[id]) {
        out[id] = deepMergeConfig(out[id], patch[id]);
      }
    }
    return out;
  }

  private packAllTemplates(
    global: TemplateSettingsMap,
    org_unit: TemplateSettingsMap,
  ) {
    return DOCUMENT_TEMPLATE_IDS.map((id) => {
      const effective = getMergedLayout(id, global, org_unit);
      const hasPanchayatOverride = Boolean(
        org_unit[id] && Object.keys(org_unit[id]).length,
      );
      const hasGlobalOverride = Boolean(
        global[id] && Object.keys(global[id]).length,
      );
      return {
        template_id: id,
        label: TEMPLATE_LABELS[id],
        effective,
        global: global[id] ?? null,
        org_unit_override: org_unit[id] ?? null,
        builtin: builtinDefaultsMap()[id],
        sources: {
          builtin: true,
          global: hasGlobalOverride,
          org_unit: hasPanchayatOverride,
        },
      };
    });
  }

  private async globalUpdatedAt() {
    const row = await this.prisma.systemSettings.findUnique({
      where: { key: DOCUMENT_TEMPLATE_DEFAULTS_KEY },
    });
    return row?.updated_at ?? null;
  }

  private async panchayatUpdatedAt(_panchayatId: number) {
    return null;
  }

  private async buildSampleContext(
    orgUnitId: number,
    templateId: DocumentTemplateId,
    vendorId: number | null,
  ): Promise<TemplateContext> {
    const panchayat = await this.prisma.orgUnit.findUnique({
      where: { id: orgUnitId },
    });
    if (!panchayat)
      throw new NotFoundException(`Panchayat #${orgUnitId} not found`);

    const layout = await this.resolveMergedLayout(orgUnitId, templateId);
    const fieldOverrides = mergeFieldOverrides(layout.defaults ?? {});

    return {
      org_unit: { id: panchayat.id, name: panchayat.name },
      tender: {
        id: 0,
        title_ta: 'மாதிரி பணி — தண்ணீர் குழாய் போடுதல்',
        title_en: 'Sample work — water pipeline',
        narrative_ta: 'இது முன்னோட்டத்திற்கான மாதிரி ஆவணம்.',
        narrative_en: 'This is a sample document for template preview.',
        anchor_date: new Date(),
        work_order_date: new Date(),
        work_completed_at: null,
        public_token: 'preview-sample',
        status: 'published',
      },
      timeline: {
        quotation_deadline: '2099-12-31',
        completion_deadline: '2099-12-31',
      },
      line_items: [
        {
          id: 1,
          seq: 1,
          description_ta: 'மாதிரி வரி உருப்படி',
          description_en: 'Sample line item',
          quantity: '1',
          unit: 'job',
        },
      ],
      invited_vendors: [
        {
          id: 1,
          name: 'Sample Vendor',
          phone_e164: '+919876543210',
          place: 'Town',
        },
      ],
      quotations: [
        {
          id: 1,
          vendor_id: vendorId ?? 1,
          submitter_name: 'Sample Vendor',
          submitter_phone_e164: '+919876543210',
          amount: '50000.00',
          remarks: 'Preview only',
          screening_outcome: 'approved',
          superseded_by_id: null,
        },
      ],
      awarded_quotation_id: 1,
      payment_meta: {
        payment_amount: 50000,
        expense_head: 'Sample head',
        nk_number: 'NK-000',
        so_proceedings_date: '2099-01-01',
        voucher_serial: 'V-001',
        voucher_date: '2099-01-01',
      },
      document: {
        template_id: templateId,
        version: 1,
        vendor_id: templateId === 'quotation' ? (vendorId ?? 1) : null,
        field_overrides: fieldOverrides,
      },
      generated_at: new Date(),
      layout,
    };
  }

  private async buildContextFromTender(
    tenderId: number,
    orgUnitId: number,
    templateId: DocumentTemplateId,
    vendorId: number | null,
  ): Promise<TemplateContext> {
    const tender = await this.prisma.tender.findUnique({
      where: { id: tenderId },
      include: { org_unit: true },
    });
    if (!tender || !tender.org_unit)
      throw new NotFoundException(`Tender #${tenderId} not found`);
    if (tender.org_unit_id !== orgUnitId) {
      throw new BadRequestException('Tender belongs to another panchayat');
    }

    const [lineItems, invites, quotations] = await Promise.all([
      this.prisma.tenderLineItem.findMany({
        where: { tender_id: tenderId },
        orderBy: { seq: 'asc' },
      }),
      this.prisma.tenderVendorInvite.findMany({
        where: { tender_id: tenderId },
        include: { vendor: true },
      }),
      this.prisma.tenderQuotation.findMany({
        where: { tender_id: tenderId },
        orderBy: { submitted_at: 'asc' },
      }),
    ]);
    const timeline = await this.milestones.resolveForTender(tenderId);
    const layout = await this.resolveMergedLayout(orgUnitId, templateId);
    const fieldOverrides = mergeFieldOverrides(layout.defaults ?? {});

    return {
      org_unit: { id: tender.org_unit.id, name: tender.org_unit.name },
      tender: {
        id: tender.id,
        title_ta: tender.title_ta,
        title_en: tender.title_en,
        narrative_ta: tender.narrative_ta,
        narrative_en: tender.narrative_en,
        anchor_date: tender.anchor_date,
        work_order_date: tender.work_order_date,
        work_completed_at: tender.work_completed_at,
        public_token: tender.public_token,
        status: tender.status,
      },
      timeline: timeline.dates,
      line_items: lineItems.map((li) => ({
        id: li.id,
        seq: li.seq,
        description_ta: li.description_ta,
        description_en: li.description_en,
        quantity: li.quantity != null ? String(li.quantity) : null,
        unit: li.unit,
      })),
      invited_vendors: invites.map((inv) => ({
        id: inv.vendor.id,
        name: inv.vendor.name,
        phone_e164: inv.vendor.phone_e164,
        place: inv.vendor.place,
      })),
      quotations: quotations.map((q) => ({
        id: q.id,
        vendor_id: q.vendor_id,
        submitter_name: q.submitter_name,
        submitter_phone_e164: q.submitter_phone_e164,
        amount: String(q.amount),
        remarks: q.remarks,
        screening_outcome: q.screening_outcome,
        superseded_by_id: q.superseded_by_id,
      })),
      awarded_quotation_id: tender.awarded_quotation_id,
      payment_meta:
        (tender.payment_meta as Record<string, unknown> | null) ?? null,
      document: {
        template_id: templateId,
        version: 1,
        vendor_id: templateId === 'quotation' ? vendorId : null,
        field_overrides: fieldOverrides,
      },
      generated_at: new Date(),
      layout,
    };
  }
}
