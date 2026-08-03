/**
 * The operational long tail — every remaining table that backs a screen but
 * had no rows: running workflow instances, comments, asset photos, field
 * verification, dynamic forms, saved reports, export jobs, IVR call state and
 * the tenant/branch configuration records.
 *
 * These are the tables that make a screen render an empty state rather than a
 * list, which is exactly what this dataset exists to prevent.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, daysAhead, recentBiased,
  personName, phone, scatter, step, heading, bulk, STREETS, LANDMARKS,
} = require('./lib');

const crypto = require('crypto');

async function seedOperations(ctx) {
  heading('Operations');
  const { all, primary } = ctx;
  const staff = await prisma.user.findMany({
    where: { user_type: 'employee' },
    select: { id: true, role: true, primary_org_unit_id: true },
  });
  const anyUser = staff[0]?.id ?? 1;
  const pickStaff = (role) => {
    const m = staff.filter((s) => s.role === role);
    return (m.length ? pick(m) : pick(staff))?.id ?? anyUser;
  };

  // ── Tenant feature ceiling ────────────────────────────────────────────────
  if ((await prisma.tenantFeatureConfig.count()) === 0) {
    const tenants = await prisma.tenant.findMany({ select: { id: true } });
    for (const t of tenants) {
      await prisma.tenantFeatureConfig.create({
        data: {
          tenant_id: t.id,
          // The ceiling is deliberately generous; the per-branch config is
          // where a module actually gets switched off.
          cemetery_mgmt: false,
          vehicle_fleet_mgmt: t.id === 'default',
        },
      });
    }
    step('tenant feature configs', tenants.length);
  } else {
    step('tenant feature configs (already present)');
  }

  // ── Branch lifecycle history ──────────────────────────────────────────────
  if ((await prisma.branchLifecycleEvent.count()) === 0) {
    const rows = [];
    for (const org of all) {
      const created = daysAgo(int(500, 1400));
      rows.push({
        tenant_id: 'default', org_unit_id: org.id,
        event_type: 'created', from_status: null, to_status: 'active',
        details: { note: `${org.name} onboarded onto the platform.` },
        effective_date: created, performed_by: anyUser, created_at: created,
      });
      rows.push({
        tenant_id: 'default', org_unit_id: org.id,
        event_type: 'activated', from_status: 'provisioning', to_status: 'active',
        details: { modules_enabled: int(8, 16) },
        effective_date: new Date(created.getTime() + 7 * 86400000),
        performed_by: anyUser, created_at: new Date(created.getTime() + 7 * 86400000),
      });
      if (chance(0.35)) {
        const upgraded = daysAgo(int(60, 400));
        rows.push({
          tenant_id: 'default', org_unit_id: org.id,
          event_type: 'upgraded', from_status: 'active', to_status: 'active',
          details: { reason: 'Additional modules sanctioned by the council.' },
          effective_date: upgraded, performed_by: anyUser, created_at: upgraded,
        });
      }
    }
    step('branch lifecycle events', await bulk(prisma.branchLifecycleEvent, rows));
  } else {
    step('branch lifecycle events (already present)');
  }

  // ── Sequence configs ──────────────────────────────────────────────────────
  //
  // NumberGenService creates these lazily on first use, which means the number
  // settings screen is blank until someone files a record. Pre-creating them
  // also documents the numbering scheme.
  if ((await prisma.sequenceConfig.count()) === 0) {
    const SPEC = [
      ['complaint', 'CMP', '{prefix}-{fy}-{seq:6}', 'financial_year'],
      ['work_order', 'WO', '{prefix}-{fy}-{seq:4}', 'financial_year'],
      ['building_permit', 'BP', '{prefix}-{fy}-{seq:5}', 'financial_year'],
      ['trade_licence', 'TL', '{prefix}-{fy}-{seq:5}', 'financial_year'],
      ['birth_registration', 'BR', '{prefix}-{cy}-{seq:6}', 'calendar_year'],
      ['death_registration', 'DR', '{prefix}-{cy}-{seq:6}', 'calendar_year'],
      ['collection_trip', 'TRIP', '{prefix}-{fy}-{seq:6}', 'financial_year'],
      ['tender', 'TND', '{prefix}-{fy}-{seq:4}', 'financial_year'],
      ['certificate', 'CERT', '{prefix}-{fy}-{seq:6}', 'financial_year'],
      ['tax_demand', 'TAX', '{prefix}-{fy}-{seq:6}', 'financial_year'],
      ['asset', 'AST', '{prefix}-{seq:6}', 'never'],
      ['waste_bin', 'BIN', '{prefix}-{seq:6}', 'never'],
    ];
    const rows = [];
    for (const org of all) {
      for (const [entity, prefix, format, cycle] of SPEC) {
        rows.push({
          tenant_id: 'default', org_unit_id: org.id,
          entity_type: entity, prefix, format,
          current_seq: int(20, 900),
          reset_cycle: cycle,
          last_reset_at: new Date(`${new Date().getFullYear()}-04-01T00:00:00.000Z`),
        });
      }
    }
    step('sequence configs', await bulk(prisma.sequenceConfig, rows));
  } else {
    step('sequence configs (already present)');
  }

  // ── Running workflow instances ────────────────────────────────────────────
  //
  // This is what the "pending approvals" inbox reads. Without it every
  // officer's approval queue is empty regardless of how many permits exist.
  if ((await prisma.workflowInstance.count()) === 0) {
    const templates = await prisma.workflowTemplate.findMany({
      include: { steps: { orderBy: { step_order: 'asc' } } },
    });
    const ENTITY_FOR = {
      building_permit_approval: 'building_permit',
      vital_event_registration: 'vital_event',
      trade_licence_approval: 'trade_licence',
      work_order_approval: 'work_order',
    };
    const pools = {
      building_permit: await prisma.buildingPermit.findMany({ select: { id: true, org_unit_id: true } }),
      vital_event: await prisma.vitalEvent.findMany({ select: { id: true, org_unit_id: true } }),
      trade_licence: await prisma.tradeLicence.findMany({ select: { id: true, org_unit_id: true } }),
      work_order: await prisma.workOrder.findMany({ select: { id: true, org_unit_id: true } }),
    };
    let inst = 0;
    const actions = [];
    for (const tpl of templates) {
      const entityType = ENTITY_FOR[tpl.name];
      const candidates = (pools[entityType] ?? []).filter((e) => e.org_unit_id === tpl.org_unit_id);
      if (!candidates.length || !tpl.steps.length) continue;
      for (const entity of pickN(candidates, Math.min(candidates.length, int(2, 5)))) {
        const total = tpl.steps.length;
        // Spread instances across the chain so the inbox has work at every level.
        const status = pick(['in_progress', 'in_progress', 'completed', 'completed', 'rejected', 'escalated']);
        const current = status === 'completed' ? total
          : status === 'rejected' ? int(1, total)
          : int(1, total);
        const started = daysAgo(recentBiased(90));
        const instance = await prisma.workflowInstance.create({
          data: {
            tenant_id: 'default',
            template_id: tpl.id,
            entity_type: entityType,
            entity_id: entity.id,
            current_step_order: current,
            status,
            started_at: started,
            completed_at: status === 'completed'
              ? new Date(started.getTime() + int(3, 25) * 86400000) : null,
          },
        });
        // Every step already passed gets an action row.
        const passed = status === 'completed' ? total : current - 1;
        for (let i = 0; i < passed; i++) {
          const s = tpl.steps[i];
          actions.push({
            instance_id: instance.id,
            step_id: s.id,
            actor_user_id: pickStaff(s.role_name),
            action: 'approved',
            comments: chance(0.5) ? pick([
              'Verified against the submitted documents.',
              'Recommended for the next level.',
              'Site details found in order.',
              'Fee receipt enclosed.',
            ]) : null,
            acted_at: new Date(started.getTime() + (i + 1) * int(1, 5) * 86400000),
          });
        }
        if (status === 'rejected') {
          const s = tpl.steps[Math.max(0, current - 1)];
          actions.push({
            instance_id: instance.id, step_id: s.id,
            actor_user_id: pickStaff(s.role_name),
            action: 'rejected',
            comments: pick([
              'Setback does not meet the prescribed norms.',
              'Ownership document not produced.',
              'Application incomplete — returned to the applicant.',
            ]),
            acted_at: new Date(started.getTime() + int(4, 20) * 86400000),
          });
        }
        if (status === 'escalated') {
          const s = tpl.steps[Math.max(0, current - 1)];
          actions.push({
            instance_id: instance.id, step_id: s.id,
            actor_user_id: pickStaff(s.role_name),
            action: 'escalated',
            comments: 'No action within the SLA. Escalated to the next authority.',
            acted_at: new Date(started.getTime() + int(6, 30) * 86400000),
          });
        }
        inst++;
      }
    }
    step('workflow instances', inst);
    step('  step actions', await bulk(prisma.workflowStepAction, actions));
  } else {
    step('workflow instances (already present)');
  }

  // ── Comments across entities ──────────────────────────────────────────────
  if ((await prisma.comment.count()) === 0) {
    const complaints = await prisma.complaint.findMany({ select: { id: true }, take: 120 });
    const tenders = await prisma.tender.findMany({ select: { id: true } });
    const orders = await prisma.workOrder.findMany({ select: { id: true } });
    const permits = await prisma.buildingPermit.findMany({ select: { id: true }, take: 60 });
    const INTERNAL = [
      'Assigned to the ward technician for a site visit.',
      'Materials indented from the central store.',
      'Discussed in the weekly review; to be taken up next week.',
      'Duplicate of an earlier ticket from the same street.',
      'Contractor informed over phone.',
      'Photograph attached from the field inspection.',
      'Escalating — no response from the section office.',
    ];
    const PUBLIC = [
      'Our team will attend to this within two working days.',
      'The work has been completed. Kindly confirm.',
      'This falls under the EB jurisdiction; forwarded to them.',
      'Thank you for reporting. A crew is on the way.',
    ];
    const rows = [];
    const add = (type, list, n) => {
      for (let i = 0; i < n; i++) {
        if (!list.length) return;
        const internal = chance(0.7);
        rows.push({
          tenant_id: 'default',
          entity_type: type,
          entity_id: pick(list).id,
          user_id: staff.length ? pick(staff).id : anyUser,
          body: internal ? pick(INTERNAL) : pick(PUBLIC),
          is_internal: internal,
          created_at: daysAgo(recentBiased(80)),
        });
      }
    };
    add('complaint', complaints, 180);
    add('tender', tenders, 60);
    add('work_order', orders, 50);
    add('building_permit', permits, 60);
    step('comments', await bulk(prisma.comment, rows));
  } else {
    step('comments (already present)');
  }

  // ── Document folders, and filing the existing documents into them ─────────
  if ((await prisma.documentFolder.count()) === 0) {
    const TREE = {
      'Building Permits': ['Site Plans', 'Sanctioned Drawings', 'NOC Letters'],
      'Trade Licences': ['Applications', 'Renewals'],
      'Tenders & Works': ['Tender Notices', 'Agreements', 'Measurement Books'],
      'Vital Records': ['Birth', 'Death'],
      'Council & Administration': ['Resolutions', 'Circulars'],
    };
    let folders = 0;
    const byOrgTop = new Map();
    for (const org of all) {
      for (const [top, kids] of Object.entries(TREE)) {
        const parent = await prisma.documentFolder.create({
          data: { tenant_id: 'default', org_unit_id: org.id, name: top },
        });
        folders++;
        byOrgTop.set(`${org.id}:${top}`, parent.id);
        await bulk(prisma.documentFolder, kids.map((name) => ({
          tenant_id: 'default', org_unit_id: org.id, name, parent_id: parent.id,
        })));
        folders += kids.length;
      }
    }
    step('document folders', folders);

    // Documents seeded earlier have no folder — file them so the tree is not
    // a set of empty folders next to a flat list.
    const unfiled = await prisma.document.findMany({
      where: { folder_id: null },
      select: { id: true, org_unit_id: true, module: true },
    });
    let filed = 0;
    for (const d of unfiled) {
      const top = d.module === 'building_permits' ? 'Building Permits'
        : d.module === 'trade_licences' ? 'Trade Licences' : 'Council & Administration';
      const fid = byOrgTop.get(`${d.org_unit_id}:${top}`);
      if (!fid) continue;
      await prisma.document.update({ where: { id: d.id }, data: { folder_id: fid } });
      filed++;
    }
    step('  documents filed', filed);
  } else {
    step('document folders (already present)');
  }

  // ── Asset photographs ─────────────────────────────────────────────────────
  if ((await prisma.assetImage.count()) === 0) {
    const assets = await prisma.asset.findMany({
      select: { id: true, asset_type_code: true, latitude: true, longitude: true },
    });
    const rows = [];
    for (const a of assets) {
      for (const type of pickN(['installation', 'current', 'damage', 'repair'], int(1, 3))) {
        const captured = daysAgo(int(1, 700));
        rows.push({
          asset_id: a.id,
          storage_key: `default/assets/${a.id}/${type}-${int(1000, 9999)}.jpg`,
          image_url: `/uploads/default/assets/${a.id}/${type}.jpg`,
          image_type: type,
          caption: {
            installation: 'Taken at the time of commissioning.',
            current: 'Latest condition photograph from the routine round.',
            damage: 'Damage reported by the ward technician.',
            repair: 'After the repair work was carried out.',
          }[type],
          file_size_bytes: int(180000, 5200000),
          resolution: pick(['1920x1080', '3024x4032', '1280x960', '4000x3000']),
          captured_device: pick(['Redmi Note 12', 'Samsung Galaxy M14', 'Moto G84', 'realme narzo 60']),
          exif_data: { iso: pick([100, 200, 400]), fnum: pick(['1.8', '2.2']), orientation: 1 },
          gps_lat: a.latitude,
          gps_lng: a.longitude,
          gps_accuracy_m: dec(3, 18, 1),
          captured_at: captured,
          uploaded_by: anyUser,
          uploaded_at: captured,
        });
      }
    }
    step('asset images', await bulk(prisma.assetImage, rows));
  } else {
    step('asset images (already present)');
  }

  // ── Field-captured assets awaiting approval ───────────────────────────────
  if ((await prisma.assetFieldCapture.count()) === 0) {
    const rows = [];
    for (const org of all) {
      const n = org.branch_type === 'MUNICIPAL_CORPORATION' ? 22 : 10;
      for (let i = 0; i < n; i++) {
        const loc = scatter(0.07);
        const status = pick(['pending_approval', 'pending_approval', 'approved', 'approved', 'approved', 'rejected']);
        rows.push({
          tenant_id: 'default',
          org_unit_id: org.id,
          type: pick(['household_tap', 'household_tap', 'public_tap', 'main_pipeline', 'valve_chamber']),
          material: pick(['PVC', 'HDPE', 'Cast Iron', 'GI', 'DI']),
          diameter_mm: pick([15, 20, 25, 40, 63, 90, 110, 160, 200]),
          latitude: loc.latitude,
          longitude: loc.longitude,
          photo_url: `/uploads/default/captures/${org.id}-${i}.jpg`,
          status,
          comment: status === 'rejected'
            ? pick(['Photograph unclear.', 'Coordinates fall outside the ward boundary.', 'Duplicate of an existing entry.'])
            : chance(0.3) ? 'Captured during the door-to-door survey.' : null,
          agent_name: personName(),
          captured_by: anyUser,
          device_model: pick(['Redmi Note 12', 'Samsung Galaxy M14', 'Moto G84']),
          altitude: dec(380, 460, 1),
          precision: dec(3, 14, 1),
          submitted_at: daysAgo(recentBiased(120)),
        });
      }
    }
    step('asset field captures', await bulk(prisma.assetFieldCapture, rows));
  } else {
    step('asset field captures (already present)');
  }

  // ── Tender invites, document jobs, field verification ─────────────────────
  if ((await prisma.tenderInvite.count()) === 0) {
    const tenders = await prisma.tender.findMany({
      select: { id: true, org_unit_id: true, created_at: true, status: true },
    });
    const contractors = await prisma.contractor.findMany({
      select: { id: true, org_unit_id: true },
    });
    const invites = [];
    for (const t of tenders) {
      const here = contractors.filter((c) => c.org_unit_id === t.org_unit_id);
      const chosen = pickN(here.length ? here : contractors, int(2, 4));
      const seen = new Set();
      for (const c of chosen) {
        if (seen.has(c.id)) continue;
        seen.add(c.id);
        const opened = chance(0.75);
        const submitted = opened && chance(0.7);
        const sent = new Date(t.created_at.getTime() + int(1, 6) * 86400000);
        invites.push({
          tender_id: t.id,
          contractor_id: c.id,
          invite_token: crypto.randomBytes(16).toString('hex'),
          invite_expires_at: new Date(sent.getTime() + 21 * 86400000),
          invite_revoked_at: !opened && chance(0.15) ? new Date(sent.getTime() + 10 * 86400000) : null,
          invite_opened_at: opened ? new Date(sent.getTime() + int(1, 5) * 86400000) : null,
          invite_submitted_at: submitted ? new Date(sent.getTime() + int(5, 15) * 86400000) : null,
          created_at: sent,
        });
      }
    }
    step('tender invites', await bulk(prisma.tenderInvite, invites));

    // Generated document chain per tender.
    const TEMPLATES = ['tender_notice', 'comparative_statement', 'work_order', 'agreement', 'completion_certificate'];
    const jobs = [];
    for (const t of tenders) {
      const upto = ['closed', 'work_in_progress', 'field_verification'].includes(t.status) ? 5
        : t.status === 'awarded' ? 4
        : t.status === 'published' ? 2 : 1;
      for (let i = 0; i < upto; i++) {
        const generated = chance(0.85);
        jobs.push({
          tender_id: t.id,
          template_id: TEMPLATES[i],
          contractor_id: null,
          version: 1,
          storage_path: generated ? `default/tenders/${t.id}/${TEMPLATES[i]}-v1.pdf` : null,
          generated_at: generated ? new Date(t.created_at.getTime() + (i + 1) * int(2, 8) * 86400000) : null,
          generated_by_user_id: generated ? anyUser : null,
          status: generated ? 'generated' : pick(['pending', 'failed']),
          error_message: generated ? null : chance(0.4) ? 'Template placeholder {{contractor_name}} unresolved.' : null,
          created_at: new Date(t.created_at.getTime() + (i + 1) * 86400000),
        });
      }
    }
    step('tender document jobs', await bulk(prisma.tenderDocumentJob, jobs));

    // Field verification sessions on tenders that reached verification.
    const verifiable = tenders.filter((t) => ['field_verification', 'closed', 'work_in_progress'].includes(t.status));
    const poles = await prisma.electricPole.findMany({ select: { id: true, org_unit_id: true, latitude: true, longitude: true } });
    let sessions = 0;
    const photos = [];
    for (const t of verifiable) {
      const here = poles.filter((p) => p.org_unit_id === t.org_unit_id);
      const subset = pickN(here, Math.min(here.length, int(3, 8)));
      const s = await prisma.fieldVerificationSession.create({
        data: {
          tender_id: t.id,
          token: crypto.randomBytes(20).toString('hex'),
          label: `Field verification — ${pick(['round 1', 'round 2', 'post-completion'])}`,
          expires_at: daysAhead(int(5, 40)),
          pole_subset_ids: subset.map((p) => p.id),
          created_by_user_id: anyUser,
          confirmed_at: chance(0.6) ? daysAgo(int(1, 40)) : null,
        },
      });
      sessions++;
      for (const p of subset) {
        const jitter = () => (Math.random() - 0.5) * 0.0004;
        const lat = (p.latitude ?? 11.0168) + jitter();
        const lng = (p.longitude ?? 76.9558) + jitter();
        const distance = dec(1, 60, 1);
        const conf = distance < 10 ? 'exact' : distance < 25 ? 'near' : 'ambiguous';
        photos.push({
          session_id: s.id,
          image_url: `/uploads/default/field/${s.id}/${p.id}.jpg`,
          exif_lat: lat, exif_lng: lng,
          captured_at: daysAgo(int(1, 45)),
          ocr_lat: chance(0.7) ? lat : null,
          ocr_lng: chance(0.7) ? lng : null,
          ocr_address: chance(0.6) ? `${pick(STREETS)}, near ${pick(LANDMARKS)}` : null,
          ocr_pole_number: chance(0.6) ? `P-${int(1000, 9999)}` : null,
          ocr_match_confidence: pick(['exact', 'near', 'skipped']),
          coord_source: pick(['exif', 'exif', 'ocr']),
          matched_lat: lat, matched_lng: lng,
          matched_pole_id: p.id,
          distance_meters: distance,
          match_confidence: conf,
          notes: chance(0.25) ? 'Fitting replaced and glowing at the time of the visit.' : null,
          uploaded_at: daysAgo(int(1, 45)),
        });
      }
    }
    step('field verification sessions', sessions);
    step('  verification photos', await bulk(prisma.fieldVerificationPhoto, photos));

    // Officer checklist rows tied to the verified photos.
    const uploaded = await prisma.fieldVerificationPhoto.findMany({
      select: { id: true, matched_pole_id: true, session: { select: { tender_id: true } } },
    });
    step('tender checklist items', await bulk(prisma.tenderFieldChecklistItem, uploaded.map((u) => ({
      tender_id: u.session.tender_id,
      pole_id: u.matched_pole_id,
      is_done: chance(0.72),
      verified_upload_id: chance(0.72) ? u.id : null,
      notes: chance(0.2) ? 'Verified against the geo-tagged photograph.' : null,
    }))));
  } else {
    step('tender invites (already present)');
  }

  // ── IVR call state machine and poll inputs ────────────────────────────────
  if ((await prisma.ivrCallState.count()) === 0) {
    const calls = await prisma.ivrCall.findMany({
      select: { call_sid: true, caller_number: true, created_at: true },
    });
    const states = [];
    const polls = [];
    for (const c of calls) {
      const p1 = pick(['completed', 'completed', 'completed', 'completed', 'failed', 'pending']);
      const p2 = p1 === 'completed'
        ? pick(['completed', 'completed', 'completed', 'pending', 'failed'])
        : 'pending';
      const made = p1 === 'completed' && p2 === 'completed' && chance(0.7);
      states.push({
        call_sid: c.call_sid,
        phase1_status: p1,
        phase2_status: p2,
        complaint_created: made,
        complaint_id: null,
        finalized_at: p2 === 'completed' ? new Date(c.created_at.getTime() + int(2, 9) * 60000) : null,
        last_error: p1 === 'failed' ? 'Recording download timed out after 30s.'
          : p2 === 'failed' ? 'Transcription service returned an empty result.' : null,
        created_at: c.created_at,
      });
      if (chance(0.4)) {
        polls.push({
          call_sid: c.call_sid,
          caller_number: c.caller_number,
          poll_id: pick(['satisfaction_1', 'service_quality', 'callback_optin']),
          received_at: new Date(c.created_at.getTime() + int(1, 8) * 60000),
          raw_payload: { digit: String(int(1, 5)), attempts: int(1, 2) },
        });
      }
    }
    step('IVR call states', await bulk(prisma.ivrCallState, states));
    step('IVR poll inputs', await bulk(prisma.ivrPollInput, polls));

    // Point the ones that produced a ticket at a real complaint.
    const created = await prisma.ivrCallState.findMany({
      where: { complaint_created: true }, select: { id: true },
    });
    const complaintIds = (await prisma.complaint.findMany({
      select: { id: true }, take: created.length || 1,
    })).map((r) => r.id);
    let linked = 0;
    for (let i = 0; i < created.length && i < complaintIds.length; i++) {
      await prisma.ivrCallState.update({
        where: { id: created[i].id }, data: { complaint_id: complaintIds[i] },
      });
      linked++;
    }
    step('  linked to complaints', linked);
  } else {
    step('IVR call states (already present)');
  }

  // ── Dynamic forms ─────────────────────────────────────────────────────────
  if ((await prisma.formTemplate.count()) === 0) {
    const FORMS = [
      ['water_connection_request', 'New water connection request', 'water_supply', [
        ['applicant_name', 'text', 'Applicant name', true],
        ['door_number', 'text', 'Door number', true],
        ['ward', 'select', 'Ward', true, Array.from({ length: 20 }, (_, i) => `Ward ${i + 1}`)],
        ['connection_type', 'select', 'Connection type', true, ['Domestic', 'Commercial', 'Industrial']],
        ['pipe_size_mm', 'number', 'Pipe size (mm)', true],
        ['location', 'gps', 'Location', true],
        ['site_photo', 'photo', 'Site photograph', false],
        ['ownership_proof', 'file', 'Ownership proof', true],
      ]],
      ['grievance_intake', 'Grievance intake form', 'complaints', [
        ['complainant_name', 'text', 'Complainant name', true],
        ['phone', 'text', 'Mobile number', true],
        ['category', 'select', 'Category', true, ['Street light', 'Water supply', 'Garbage', 'Drainage', 'Road', 'Other']],
        ['urgency', 'select', 'Urgency', true, ['Low', 'Medium', 'High', 'Critical']],
        ['description', 'text', 'Describe the issue', true],
        ['location', 'gps', 'Location', false],
        ['photo', 'photo', 'Photograph', false],
      ]],
      ['trade_licence_inspection', 'Trade licence inspection checklist', 'trade_licences', [
        ['premises_clean', 'select', 'Premises clean', true, ['Yes', 'No']],
        ['waste_segregated', 'select', 'Waste segregated', true, ['Yes', 'No']],
        ['fire_extinguisher', 'select', 'Fire extinguisher present', true, ['Yes', 'No', 'Not applicable']],
        ['staff_health_cards', 'select', 'Staff health cards produced', true, ['Yes', 'No']],
        ['observations', 'text', 'Observations', false],
        ['inspector_signature', 'signature', 'Inspector signature', true],
      ]],
      ['property_assessment', 'Property tax assessment', 'property_tax', [
        ['owner_name', 'text', 'Owner name', true],
        ['plinth_area_sqft', 'number', 'Plinth area (sq ft)', true],
        ['building_type', 'select', 'Building type', true, ['RCC', 'Tiled', 'Sheet', 'Thatched']],
        ['floors', 'number', 'Number of floors', true],
        ['usage', 'select', 'Usage', true, ['Residential', 'Commercial', 'Mixed', 'Vacant land']],
        ['occupancy_date', 'date', 'Date of occupancy', false],
      ]],
      ['bin_condition_survey', 'Bin condition survey', 'solid_waste', [
        ['bin_code', 'text', 'Bin code', true],
        ['condition', 'select', 'Condition', true, ['Good', 'Damaged', 'Missing lid', 'Needs replacement']],
        ['fill_pct', 'number', 'Fill percentage', true],
        ['location', 'gps', 'Location', true],
        ['photo', 'photo', 'Photograph', true],
      ]],
    ];
    let t = 0, f = 0;
    for (const [code, name, module, fields] of FORMS) {
      const tpl = await prisma.formTemplate.create({
        data: { tenant_id: 'default', code, name, module, version: 1, is_active: true },
      });
      t++;
      await bulk(prisma.formField, fields.map(([key, type, label, required, options], i) => ({
        template_id: tpl.id,
        field_key: key,
        field_type: type,
        label,
        options: options ? { choices: options } : null,
        validation: { required, ...(type === 'number' ? { min: 0 } : {}) },
        display_order: i + 1,
        is_required: required,
      })));
      f += fields.length;
    }
    step('form templates', t);
    step('  form fields', f);

    const templates = await prisma.formTemplate.findMany({ select: { id: true, code: true } });
    const subs = [];
    for (const tpl of templates) {
      for (let i = 0; i < int(14, 30); i++) {
        subs.push({
          tenant_id: 'default',
          org_unit_id: pick(all).id,
          template_id: tpl.id,
          submitted_by: staff.length ? pick(staff).id : anyUser,
          data: {
            applicant_name: personName(),
            phone: phone(),
            ward: `Ward ${int(1, 20)}`,
            remarks: 'Submitted from the field application.',
          },
          status: pick(['submitted', 'submitted', 'under_review', 'approved', 'approved', 'rejected']),
          submitted_at: daysAgo(recentBiased(100)),
        });
      }
    }
    step('form submissions', await bulk(prisma.formSubmission, subs));
  } else {
    step('form templates (already present)');
  }

  // ── Saved reports ─────────────────────────────────────────────────────────
  if ((await prisma.savedReport.count()) === 0) {
    const SPEC = [
      ['Monthly complaint summary', 'complaint_summary', 'pdf', '0 6 1 * *'],
      ['Ward-wise SLA compliance', 'sla_compliance', 'excel', '0 7 * * 1'],
      ['Property tax collection register', 'tax_collection', 'excel', '0 6 * * *'],
      ['Trade licences expiring in 30 days', 'licence_expiry', 'excel', '0 8 * * 1'],
      ['Daily solid waste collection', 'waste_collection', 'pdf', '0 20 * * *'],
      ['Building permits pending beyond 30 days', 'permit_ageing', 'pdf', null],
      ['Birth and death register extract', 'vital_register', 'excel', '0 6 1 * *'],
      ['Tender award summary', 'tender_award', 'pdf', null],
      ['Street light fault report', 'pole_faults', 'csv', '0 9 * * *'],
      ['Contractor performance', 'contractor_performance', 'excel', null],
    ];
    const rows = [];
    for (const org of all) {
      for (const [name, type, format, cron] of pickN(SPEC, int(5, 9))) {
        rows.push({
          tenant_id: 'default',
          org_unit_id: org.id,
          name, report_type: type, format,
          filters: { org_unit_id: org.id, range: 'last_30_days' },
          schedule_cron: cron,
          email_to: cron ? [`commissioner.${org.id}@example.gov.in`] : [],
          last_generated: cron ? daysAgo(int(0, 5)) : null,
          created_by: anyUser,
          created_at: daysAgo(int(30, 300)),
        });
      }
    }
    step('saved reports', await bulk(prisma.savedReport, rows));
  } else {
    step('saved reports (already present)');
  }

  // ── Export jobs ───────────────────────────────────────────────────────────
  if ((await prisma.exportJob.count()) === 0) {
    const electricians = staff.filter((s) => ['electrician', 'agent', 'plumber'].includes(s.role));
    const pool = electricians.length ? electricians : staff;
    const rows = [];
    for (let i = 0; i < 40; i++) {
      const e = pick(pool);
      const from = daysAgo(int(30, 150));
      const status = pick(['completed', 'completed', 'completed', 'completed', 'pending', 'failed']);
      const created = daysAgo(recentBiased(60));
      rows.push({
        created_by_user_id: anyUser,
        org_unit_id: e.primary_org_unit_id ?? primary.id,
        electrician_user_id: e.id,
        range_from: from,
        range_to: new Date(from.getTime() + 30 * 86400000),
        status,
        result_relative_path: status === 'completed' ? `exports/work-${i}-${int(10000, 99999)}.xlsx` : null,
        error_message: status === 'failed' ? 'No records found in the selected range.' : null,
        row_count: status === 'completed' ? int(12, 480) : null,
        created_at: created,
        completed_at: status === 'completed' ? new Date(created.getTime() + int(5, 90) * 1000) : null,
      });
    }
    step('export jobs', await bulk(prisma.exportJob, rows));
  } else {
    step('export jobs (already present)');
  }
}

module.exports = { seedOperations };
