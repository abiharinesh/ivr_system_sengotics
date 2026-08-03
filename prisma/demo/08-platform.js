/**
 * Platform layer: SLA policies and live trackers, workflow templates, the
 * audit trail, notifications, documents, and the role dashboard definitions.
 *
 * `dashboard_widgets` and `role_dashboards` were designed and never populated,
 * so every role dashboard has been rendering from hardcoded widgets. Seeding
 * them is what makes the per-role dashboard configurable from the super admin
 * console rather than from a redeploy.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, daysAhead, recentBiased,
  personName, phone, step, heading, bulk,
} = require('./lib');

/** Widget catalogue — the palette a super admin composes a dashboard from. */
const WIDGETS = [
  ['complaints_open', 'Open complaints', 'counter', 'complaints', 'small'],
  ['complaints_overdue', 'Overdue complaints', 'counter', 'complaints', 'small'],
  ['complaints_trend', 'Complaint volume trend', 'bar_chart', 'complaints', 'large'],
  ['complaints_by_category', 'Complaints by category', 'pie_chart', 'complaints', 'medium'],
  ['sla_compliance', 'SLA compliance', 'kpi', 'complaints', 'small'],
  ['resolution_time', 'Average resolution time', 'kpi', 'complaints', 'small'],
  ['tax_collected', 'Property tax collected', 'kpi', 'property_tax', 'medium'],
  ['tax_defaulters', 'Tax defaulters', 'counter', 'property_tax', 'small'],
  ['tax_collection_trend', 'Collection trend', 'bar_chart', 'property_tax', 'large'],
  ['revenue_mix', 'Revenue by source', 'pie_chart', 'reports', 'medium'],
  ['licences_expiring', 'Licences expiring in 30 days', 'counter', 'trade_licences', 'small'],
  ['licences_active', 'Active trade licences', 'counter', 'trade_licences', 'small'],
  ['permits_pending', 'Permits awaiting action', 'counter', 'building_permits', 'small'],
  ['permits_by_stage', 'Permits by stage', 'bar_chart', 'building_permits', 'medium'],
  ['births_registered', 'Births registered', 'counter', 'vital_events', 'small'],
  ['deaths_registered', 'Deaths registered', 'counter', 'vital_events', 'small'],
  ['vital_late_registrations', 'Late registrations', 'counter', 'vital_events', 'small'],
  ['bins_red', 'Bins needing clearing', 'counter', 'solid_waste', 'small'],
  ['bin_fill_map', 'Bin fill-level map', 'map', 'solid_waste', 'large'],
  ['collection_progress', "Today's collection progress", 'kpi', 'solid_waste', 'medium'],
  ['workers_on_duty', 'Sanitation workers on duty', 'counter', 'solid_waste', 'small'],
  ['water_tank_levels', 'Tank levels', 'bar_chart', 'water_supply', 'medium'],
  ['pipeline_alerts', 'Pipeline leak alerts', 'counter', 'water_supply', 'small'],
  ['poles_faulty', 'Faulty street lights', 'counter', 'street_lights', 'small'],
  ['pole_map', 'Street light map', 'map', 'street_lights', 'large'],
  ['tenders_open', 'Open tenders', 'counter', 'tenders', 'small'],
  ['work_orders_progress', 'Work orders in progress', 'counter', 'tenders', 'small'],
  ['contractor_ratings', 'Contractor ratings', 'table', 'contractors', 'medium'],
  ['inspections_due', 'Inspections due', 'counter', 'inspections', 'small'],
  ['recent_activity', 'Recent activity', 'table', 'core', 'large'],
  ['citizen_satisfaction', 'Citizen satisfaction', 'kpi', 'reports', 'medium'],
  ['ward_heatmap', 'Ward-wise complaint density', 'map', 'complaints', 'large'],
];

/** Which widgets each role lands on. This is what the console will edit. */
const ROLE_DASHBOARDS = {
  super_admin: ['complaints_open', 'tax_collected', 'licences_active', 'bins_red', 'complaints_trend', 'revenue_mix', 'recent_activity'],
  panchayat_admin: ['complaints_open', 'complaints_overdue', 'tax_collected', 'licences_expiring', 'complaints_trend', 'complaints_by_category', 'recent_activity'],
  municipal_commissioner: ['complaints_open', 'sla_compliance', 'tax_collected', 'permits_pending', 'complaints_trend', 'revenue_mix', 'citizen_satisfaction', 'ward_heatmap'],
  deputy_commissioner: ['complaints_open', 'complaints_overdue', 'bins_red', 'permits_pending', 'complaints_trend', 'ward_heatmap'],
  municipal_engineer: ['poles_faulty', 'pipeline_alerts', 'tenders_open', 'work_orders_progress', 'water_tank_levels', 'pole_map', 'inspections_due'],
  assistant_engineer: ['complaints_open', 'poles_faulty', 'pipeline_alerts', 'inspections_due', 'water_tank_levels'],
  junior_engineer: ['complaints_open', 'poles_faulty', 'inspections_due', 'pole_map'],
  health_officer: ['bins_red', 'workers_on_duty', 'collection_progress', 'births_registered', 'deaths_registered', 'bin_fill_map', 'licences_active'],
  sanitary_inspector: ['bins_red', 'workers_on_duty', 'collection_progress', 'bin_fill_map', 'complaints_open'],
  revenue_officer: ['tax_collected', 'tax_defaulters', 'licences_expiring', 'licences_active', 'tax_collection_trend', 'revenue_mix'],
  revenue_inspector: ['tax_defaulters', 'licences_expiring', 'tax_collection_trend'],
  town_planning_officer: ['permits_pending', 'permits_by_stage', 'inspections_due', 'recent_activity'],
  registrar: ['births_registered', 'deaths_registered', 'vital_late_registrations', 'recent_activity'],
  licensing_clerk: ['licences_active', 'licences_expiring', 'inspections_due', 'tax_collection_trend'],
  accounts_officer: ['tax_collected', 'revenue_mix', 'tax_collection_trend'],
  executive_officer: ['complaints_open', 'tax_collected', 'bins_red', 'licences_active', 'complaints_trend'],
  i3c_staff: ['complaints_open', 'complaints_overdue', 'complaints_by_category', 'ward_heatmap', 'recent_activity'],
  contractor: ['tenders_open', 'work_orders_progress'],
};

async function seedPlatform(ctx) {
  heading('Platform');
  const { all, primary } = ctx;
  const admin = await prisma.user.findFirst({ where: { role: 'super_admin' } });
  const adminId = admin?.id ?? 1;

  // ── SLA policies ──────────────────────────────────────────────────────────
  if ((await prisma.slaPolicy.count()) === 0) {
    const rows = [];
    const SPEC = [
      ['complaint', 'street_light', { critical: 4, high: 12, medium: 48, low: 96 }],
      ['complaint', 'water_supply', { critical: 4, high: 8, medium: 24, low: 72 }],
      ['complaint', 'garbage', { critical: 6, high: 12, medium: 24, low: 72 }],
      ['complaint', 'drainage', { critical: 4, high: 12, medium: 36, low: 96 }],
      ['building_permit', 'residential', { medium: 720 }],
      ['building_permit', 'commercial', { medium: 1080 }],
      ['vital_event', 'birth', { medium: 168 }],
      ['vital_event', 'death', { medium: 120 }],
      ['waste_bin', 'community', { critical: 8, high: 24 }],
      ['trade_licence', 'eatery', { medium: 360 }],
    ];
    for (const [entity, category, levels] of SPEC) {
      for (const [urgency, target] of Object.entries(levels)) {
        rows.push({
          tenant_id: 'default',
          org_unit_id: null, // tenant-wide default
          entity_type: entity,
          category,
          urgency_level: urgency,
          target_hours: target,
          warning_hours: Math.round(target * 0.6),
          escalation_hours: Math.round(target * 0.85),
          breach_hours: target,
          escalation_role: pick(['municipal_commissioner', 'municipal_engineer', 'health_officer']),
          is_24x7: urgency === 'critical',
          is_active: true,
        });
      }
    }
    step('SLA policies', await bulk(prisma.slaPolicy, rows));

    // Live trackers against open complaints, so the SLA board is populated.
    const policies = await prisma.slaPolicy.findMany({ where: { entity_type: 'complaint' } });
    const open = await prisma.complaint.findMany({
      where: { status: { in: ['pending', 'assigned', 'in_progress'] } },
      select: { id: true, created_at: true, urgency_level: true, category: true },
      take: 140,
    });
    const trackers = [];
    for (const c of open) {
      const policy = policies.find((p) => p.category === c.category && p.urgency_level === c.urgency_level)
        ?? pick(policies);
      if (!policy) continue;
      const started = c.created_at;
      const target = new Date(started.getTime() + policy.target_hours * 3600000);
      const now = Date.now();
      const status = now > target.getTime() ? 'breached'
        : now > started.getTime() + policy.escalation_hours * 3600000 ? 'escalated'
        : now > started.getTime() + policy.warning_hours * 3600000 ? 'warning'
        : 'on_track';
      trackers.push({
        tenant_id: 'default',
        entity_type: 'complaint',
        entity_id: c.id,
        sla_policy_id: policy.id,
        started_at: started,
        target_at: target,
        warning_at: new Date(started.getTime() + policy.warning_hours * 3600000),
        escalation_at: new Date(started.getTime() + policy.escalation_hours * 3600000),
        breach_at: new Date(started.getTime() + policy.breach_hours * 3600000),
        status,
        delay_reason: status === 'breached'
          ? pick(['Material not available in store.', 'Crew diverted to an emergency.', 'Awaiting contractor mobilisation.']) : null,
      });
    }
    step('SLA trackers', await bulk(prisma.slaTracker, trackers));
  } else {
    step('SLA policies (already present)');
  }

  // ── Workflow templates ────────────────────────────────────────────────────
  if ((await prisma.workflowTemplate.count()) === 0) {
    const SPEC = [
      ['building_permit_approval', 'Building permit approval', [
        ['licensing_clerk', 'review', 48],
        ['town_planning_officer', 'verify', 120],
        ['municipal_commissioner', 'approve', 72],
      ]],
      ['vital_event_registration', 'Late vital event registration', [
        ['registrar', 'review', 24],
        ['municipal_commissioner', 'approve', 72],
      ]],
      ['trade_licence_approval', 'Trade licence approval', [
        ['licensing_clerk', 'review', 24],
        ['sanitary_inspector', 'verify', 72],
        ['health_officer', 'approve', 48],
      ]],
      ['work_order_approval', 'Work order approval', [
        ['assistant_engineer', 'review', 24],
        ['municipal_engineer', 'verify', 48],
        ['municipal_commissioner', 'approve', 72],
      ]],
    ];
    let wf = 0, st = 0;
    for (const org of all) {
      for (const [name, description, steps] of SPEC) {
        const tpl = await prisma.workflowTemplate.create({
          data: {
            tenant_id: 'default',
            org_unit_id: org.id,
            name, description,
            version: 1,
            status: 'published',
            is_active: true,
          },
        });
        await bulk(prisma.workflowStep, steps.map(([role, action, sla], i) => ({
          template_id: tpl.id,
          step_order: i + 1,
          role_name: role,
          action_type: action,
          is_required: true,
          sla_hours: sla,
          auto_escalate_hours: Math.round(sla * 1.5),
        })));
        // Conditional routing: small-value permits skip the commissioner.
        if (name === 'building_permit_approval') {
          const last = await prisma.workflowStep.findFirst({
            where: { template_id: tpl.id, step_order: 3 },
          });
          if (last) {
            await prisma.workflowRule.create({
              data: {
                template_id: tpl.id,
                step_id: last.id,
                condition_field: 'estimated_cost',
                condition_op: 'lt',
                condition_value: 500000,
                then_action: 'skip_step',
                priority: 1,
              },
            });
          }
        }
        wf++; st += steps.length;
      }
    }
    step('workflow templates', wf);
    step('  workflow steps', st);
  } else {
    step('workflow templates (already present)');
  }

  // ── Notification templates and a delivery log ─────────────────────────────
  if ((await prisma.notificationTemplate.count()) === 0) {
    const T = [
      ['complaint_registered', 'Your complaint {{id}} has been registered. We will update you shortly.'],
      ['complaint_assigned', 'Complaint {{id}} has been assigned to a field technician.'],
      ['complaint_resolved', 'Complaint {{id}} has been resolved. Thank you for reporting it.'],
      ['tax_due_reminder', 'Property tax of Rs.{{amount}} is due on {{date}}. Pay to avoid penalty.'],
      ['licence_renewal_due', 'Trade licence {{number}} expires on {{date}}. Please renew.'],
      ['permit_approved', 'Building permit {{number}} has been sanctioned. Collect it from the office.'],
      ['certificate_ready', 'Your {{type}} certificate is ready for collection.'],
      ['water_interruption', 'Water supply will be interrupted on {{date}} from {{from}} to {{to}}.'],
    ];
    let n = 0;
    for (const [code, body] of T) {
      for (const channel of ['whatsapp', 'sms']) {
        await prisma.notificationTemplate.create({
          data: {
            tenant_id: 'default', code, channel,
            body_template: body, language: 'en', is_active: true,
          },
        });
        n++;
      }
    }
    step('notification templates', n);

    const citizens = await prisma.citizenProfile.findMany({ select: { user_id: true, phone: true } });
    const rows = [];
    for (let i = 0; i < 220; i++) {
      const [code, body] = pick(T);
      const c = citizens.length ? pick(citizens) : null;
      const status = pick(['sent', 'sent', 'sent', 'sent', 'read', 'read', 'queued', 'failed']);
      const created = daysAgo(recentBiased(90));
      rows.push({
        tenant_id: 'default',
        recipient_user_id: c?.user_id ?? null,
        recipient_phone: c?.phone ?? phone(),
        template_code: code,
        channel: pick(['whatsapp', 'whatsapp', 'sms']),
        variables: { id: int(1000, 9999), amount: int(500, 9000) },
        rendered_body: body.replace(/\{\{\w+\}\}/g, () => String(int(100, 9999))),
        status,
        retry_count: status === 'failed' ? int(1, 3) : 0,
        error_message: status === 'failed' ? 'Recipient number not on WhatsApp' : null,
        sent_at: ['sent', 'read'].includes(status) ? created : null,
        read_at: status === 'read' ? new Date(created.getTime() + int(1, 600) * 60000) : null,
        created_at: created,
      });
    }
    step('notifications', await bulk(prisma.notification, rows));
  } else {
    step('notifications (already present)');
  }

  // ── Audit trail ───────────────────────────────────────────────────────────
  if ((await prisma.auditLog.count()) === 0) {
    const users = await prisma.user.findMany({
      where: { user_type: 'employee' }, select: { id: true, primary_org_unit_id: true }, take: 40,
    });
    const SPEC = [
      ['complaints', 'complaint', ['create', 'assign', 'resolve', 'update']],
      ['building_permits', 'building_permit', ['create', 'submit', 'approve', 'noc_granted', 'payment_recorded']],
      ['vital_events', 'vital_event', ['report', 'verify', 'register', 'certificate_issued']],
      ['trade_licences', 'trade_licence', ['create', 'submit', 'approve', 'renew', 'payment_recorded']],
      ['solid_waste', 'waste_bin', ['bin_reading', 'bin_emptied', 'create']],
      ['tenders', 'tender', ['create', 'published', 'quotation_received', 'awarded']],
      ['rbac', 'role', ['role_screens_updated', 'role_permissions_updated', 'role_assigned']],
      ['property_tax', 'tax_property', ['create', 'payment_recorded', 'update']],
    ];
    const rows = [];
    for (let i = 0; i < 600; i++) {
      const [module, entity, actions] = pick(SPEC);
      const u = users.length ? pick(users) : null;
      rows.push({
        tenant_id: 'default',
        org_unit_id: u?.primary_org_unit_id ?? primary.id,
        user_id: u?.id ?? adminId,
        module,
        entity_type: entity,
        entity_id: String(int(1, 300)),
        action: pick(actions),
        after_value: { note: 'Demo activity record', ref: `REF-${int(1000, 9999)}` },
        changed_fields: pickN(['status', 'amount', 'assigned_to', 'remarks'], int(1, 2)),
        ip_address: `10.${int(0, 255)}.${int(0, 255)}.${int(1, 254)}`,
        created_at: daysAgo(recentBiased(120)),
      });
    }
    step('audit log entries', await bulk(prisma.auditLog, rows));
  } else {
    step('audit log (already present)');
  }

  // ── Dashboard widgets and per-role layouts ────────────────────────────────
  //
  // These two tables shipped with the schema and were never populated, so
  // every role dashboard has been rendering hardcoded widgets.
  if ((await prisma.dashboardWidget.count()) === 0) {
    await bulk(prisma.dashboardWidget, WIDGETS.map(([code, title, type, source, size]) => ({
      tenant_id: 'default',
      code, title,
      widget_type: type,
      data_source: source,
      query_config: { module: source, range: 'last_30_days' },
      default_size: size,
      is_active: true,
    })));
    step('dashboard widgets', await prisma.dashboardWidget.count());

    const widgets = await prisma.dashboardWidget.findMany({ select: { id: true, code: true } });
    const byCode = new Map(widgets.map((w) => [w.code, w.id]));
    let d = 0;
    for (const [role, codes] of Object.entries(ROLE_DASHBOARDS)) {
      const ids = codes.map((c) => byCode.get(c)).filter(Boolean);
      if (!ids.length) continue;
      await prisma.roleDashboard.upsert({
        where: { tenant_id_role_name: { tenant_id: 'default', role_name: role } },
        update: { widget_ids: ids },
        create: {
          tenant_id: 'default',
          role_name: role,
          widget_ids: ids,
          layout: { columns: 4, order: codes },
        },
      });
      d++;
    }
    step('role dashboards', d);
  } else {
    step('dashboard widgets (already present)');
  }

  // ── Documents ─────────────────────────────────────────────────────────────
  if ((await prisma.document.count()) === 0) {
    const permits = await prisma.buildingPermit.findMany({ select: { id: true, org_unit_id: true }, take: 40 });
    const licences = await prisma.tradeLicence.findMany({ select: { id: true, org_unit_id: true }, take: 40 });
    const rows = [];
    for (const p of permits) {
      for (const [title, file, mime] of [
        ['Site plan', 'site-plan.pdf', 'application/pdf'],
        ['Floor plan', 'floor-plan.pdf', 'application/pdf'],
        ['Patta copy', 'patta.jpg', 'image/jpeg'],
      ]) {
        rows.push({
          tenant_id: 'default', org_unit_id: p.org_unit_id,
          title, file_name: file,
          storage_key: `default/${p.org_unit_id}/permit-${p.id}-${file}`,
          file_url: `/uploads/default/${p.org_unit_id}/permit-${p.id}-${file}`,
          file_size_bytes: BigInt(int(80000, 4000000)),
          mime_type: mime, version: 1,
          module: 'building_permits', entity_type: 'building_permit', entity_id: p.id,
          uploaded_by: adminId, created_at: daysAgo(recentBiased(150)),
        });
      }
    }
    for (const l of licences) {
      for (const [title, file, mime] of [
        ['Rent agreement', 'rent-agreement.pdf', 'application/pdf'],
        ['Premises photo', 'premises.jpg', 'image/jpeg'],
      ]) {
        rows.push({
          tenant_id: 'default', org_unit_id: l.org_unit_id,
          title, file_name: file,
          storage_key: `default/${l.org_unit_id}/licence-${l.id}-${file}`,
          file_url: `/uploads/default/${l.org_unit_id}/licence-${l.id}-${file}`,
          file_size_bytes: BigInt(int(50000, 2500000)),
          mime_type: mime, version: 1,
          module: 'trade_licences', entity_type: 'trade_licence', entity_id: l.id,
          uploaded_by: adminId, created_at: daysAgo(recentBiased(150)),
        });
      }
    }
    step('documents', await bulk(prisma.document, rows));
  } else {
    step('documents (already present)');
  }

  // ── Working calendar and holidays, which the SLA engine reads ─────────────
  if ((await prisma.workingCalendar.count()) === 0) {
    await prisma.workingCalendar.create({
      data: {
        tenant_id: 'default', org_unit_id: null,
        name: 'Standard Government Calendar',
        working_days: [1, 2, 3, 4, 5, 6],
        working_hours_start: '09:30',
        working_hours_end: '17:45',
        half_day_hours_end: '13:00',
        is_default: true,
      },
    });
    await prisma.workingCalendar.create({
      data: {
        tenant_id: 'default', org_unit_id: null,
        name: 'Emergency 24x7',
        working_days: [1, 2, 3, 4, 5, 6, 0],
        working_hours_start: '00:00',
        working_hours_end: '23:59',
        is_default: false,
      },
    });
    step('working calendars', 2);

    const YEAR = new Date().getFullYear();
    const HOLIDAYS = [
      [`${YEAR}-01-01`, 'New Year\'s Day', 'national'],
      [`${YEAR}-01-14`, 'Pongal', 'state'],
      [`${YEAR}-01-15`, 'Thiruvalluvar Day', 'state'],
      [`${YEAR}-01-26`, 'Republic Day', 'national'],
      [`${YEAR}-04-14`, 'Tamil New Year', 'state'],
      [`${YEAR}-05-01`, 'May Day', 'national'],
      [`${YEAR}-08-15`, 'Independence Day', 'national'],
      [`${YEAR}-10-02`, 'Gandhi Jayanti', 'national'],
      [`${YEAR}-12-25`, 'Christmas', 'national'],
    ];
    await bulk(prisma.holiday, HOLIDAYS.map(([date, name, type]) => ({
      tenant_id: 'default', org_unit_id: null,
      date: new Date(`${date}T00:00:00.000Z`),
      name, holiday_type: type, is_active: true,
    })));
    step('holidays', await prisma.holiday.count());
  } else {
    step('calendars (already present)');
  }
}

module.exports = { seedPlatform, WIDGETS, ROLE_DASHBOARDS };
