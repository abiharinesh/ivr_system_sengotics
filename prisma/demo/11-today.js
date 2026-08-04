/**
 * Keeps the demo current.
 *
 * The other sections lay down history relative to the day they ran. Shown a
 * week later, "today's collection progress" is 0%, nobody is on duty, and no
 * licence is due for renewal — every operational panel reads as a dead system
 * rather than a working one.
 *
 * This section is idempotent and rolls the live edge of the data forward to
 * whatever today is. Re-run it before a demo; running it twice on the same day
 * changes nothing.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, dayAgo, daysAhead,
  step, heading, bulk,
} = require('./lib');

/** Mirrors `bin-fill.ts` — the band a percentage falls into. */
function bandFor(pct) {
  if (pct >= 100) return 'OVERFLOWING';
  if (pct >= 75) return 'HIGH';
  if (pct >= 40) return 'MEDIUM';
  if (pct >= 10) return 'LOW';
  return 'EMPTY';
}

const startOfToday = () => {
  const d = new Date();
  d.setUTCHours(0, 0, 0, 0);
  return d;
};

async function seedToday(ctx) {
  heading('Today');
  const today = startOfToday();
  const anyUser =
    (await prisma.user.findFirst({ where: { user_type: 'employee' }, select: { id: true } }))?.id ??
    1;

  // ── Collection rounds for today ───────────────────────────────────────────
  const existingTrips = await prisma.collectionTrip.count({
    where: { trip_date: { gte: today } },
  });
  if (existingTrips === 0) {
    const routes = await prisma.collectionRoute.findMany({
      where: { is_active: true },
      include: { stops: { select: { id: true, seq: true } } },
    });
    const drivers = await prisma.user.findMany({
      where: { role: { in: ['agent', 'electrician', 'plumber'] } },
      select: { id: true },
    });
    const dow = today.getUTCDay() === 0 ? 7 : today.getUTCDay();
    const seq = await prisma.collectionTrip.count();
    let t = 0;

    for (const route of routes) {
      if (!route.stops.length || !route.service_days.includes(dow)) continue;

      // Mid-shift: some rounds finished, most are part-way. A day where every
      // round is already complete tells the supervisor nothing.
      const status = pick(['IN_PROGRESS', 'IN_PROGRESS', 'IN_PROGRESS', 'COMPLETED']);
      const total = route.stops.length;
      const done = status === 'COMPLETED' ? total : int(1, Math.max(1, total - 1));
      const odoStart = int(12000, 90000);

      const trip = await prisma.collectionTrip.create({
        data: {
          tenant_id: 'default',
          org_unit_id: route.org_unit_id,
          route_id: route.id,
          trip_number: `TRIP-2026-27-${String(seq + ++t).padStart(6, '0')}`,
          trip_date: today,
          shift: route.shift,
          status,
          vehicle_number: `TN ${int(33, 43)} ${pick(['AB', 'BZ', 'CK', 'DL'])} ${int(1000, 9999)}`,
          driver_user_id: drivers.length ? pick(drivers).id : null,
          crew_size: int(2, 6),
          started_at: new Date(today.getTime() + 6 * 3600000),
          ended_at: status === 'COMPLETED'
            ? new Date(today.getTime() + int(9, 12) * 3600000) : null,
          waste_collected_kg: status === 'COMPLETED' ? int(280, 1300) : null,
          segregated_wet_kg: status === 'COMPLETED' ? int(180, 800) : null,
          segregated_dry_kg: status === 'COMPLETED' ? int(90, 500) : null,
          odometer_start_km: odoStart,
          odometer_end_km: status === 'COMPLETED' ? odoStart + int(5, 30) : null,
          stops_total: total,
          stops_completed: done,
          created_by: anyUser,
        },
      });

      await bulk(prisma.collectionTripStop, route.stops.map((s, i) => ({
        trip_id: trip.id,
        route_stop_id: s.id,
        seq: s.seq,
        completed: i < done,
        skipped: false,
        completed_at: i < done
          ? new Date(today.getTime() + (6 + i * 0.25) * 3600000) : null,
      })));
    }
    step("today's collection rounds", t);
  } else {
    step("today's rounds (already marked)");
  }

  // ── Attendance for today ──────────────────────────────────────────────────
  const existingAttendance = await prisma.sanitationAttendance.count({
    where: { attendance_date: { gte: today } },
  });
  if (existingAttendance === 0) {
    // Reuse yesterday's roster so the same people appear day to day rather
    // than a fresh set of names each morning.
    const roster = await prisma.sanitationAttendance.findMany({
      where: { attendance_date: { lt: today } },
      distinct: ['worker_name'],
      select: {
        org_unit_id: true, worker_name: true, worker_phone: true,
        is_contract: true, route_id: true,
      },
    });
    const rows = roster.map((w) => {
      const status = pick([
        'PRESENT', 'PRESENT', 'PRESENT', 'PRESENT', 'PRESENT',
        'PRESENT', 'PRESENT', 'PRESENT', 'ABSENT', 'LEAVE', 'HALF_DAY',
      ]);
      const present = status === 'PRESENT' || status === 'HALF_DAY';
      return {
        tenant_id: 'default',
        org_unit_id: w.org_unit_id,
        worker_name: w.worker_name,
        worker_phone: w.worker_phone,
        is_contract: w.is_contract,
        attendance_date: today,
        shift: 'morning',
        status,
        route_id: w.route_id,
        check_in_at: present
          ? new Date(today.getTime() + 6 * 3600000 + int(0, 40) * 60000) : null,
        check_out_at: status === 'PRESENT'
          ? new Date(today.getTime() + 13 * 3600000) : null,
        remarks: status === 'LEAVE' ? pick(['Casual leave', 'Medical leave']) : null,
        recorded_by: anyUser,
      };
    });
    step("today's attendance", await bulk(prisma.sanitationAttendance, rows));
  } else {
    step("today's attendance (already marked)");
  }

  // ── Fresh bin readings ────────────────────────────────────────────────────
  const readToday = await prisma.wasteBinReading.count({
    where: { recorded_at: { gte: today } },
  });
  if (readToday === 0) {
    const bins = await prisma.wasteBin.findMany({
      where: { status: 'ACTIVE' },
      select: { id: true, fill_pct: true },
    });
    await bulk(prisma.wasteBinReading, bins.map((b) => {
      const emptied = chance(0.25);
      const pct = emptied ? int(0, 8) : Math.min(100, b.fill_pct + int(0, 25));
      return {
        bin_id: b.id,
        fill_level: bandFor(pct),
        fill_pct: pct,
        emptied,
        remarks: emptied ? 'Cleared by the morning round.' : null,
        recorded_by: anyUser,
        recorded_at: new Date(today.getTime() + int(6, 10) * 3600000),
      };
    }));
    // Carry the reading onto the bin, since the map reads the bin not the log.
    let moved = 0;
    for (const b of bins) {
      const latest = await prisma.wasteBinReading.findFirst({
        where: { bin_id: b.id },
        orderBy: { recorded_at: 'desc' },
      });
      if (!latest) continue;
      await prisma.wasteBin.update({
        where: { id: b.id },
        data: {
          fill_pct: latest.fill_pct,
          fill_level: latest.fill_level,
          last_read_at: latest.recorded_at,
          ...(latest.emptied ? { last_emptied_at: latest.recorded_at } : {}),
        },
      });
      moved++;
    }
    step("today's bin readings", moved);
  } else {
    step("today's bin readings (already taken)");
  }

  // ── Inspections still to do ───────────────────────────────────────────────
  //
  // Every seeded inspection was `completed`, so every "inspections due" panel
  // read zero and every inspector's work queue was empty.
  const scheduledField = await prisma.fieldInspection.count({
    where: { status: 'scheduled' },
  });
  if (scheduledField === 0) {
    const templates = await prisma.inspectionTemplate.findMany({ select: { id: true } });
    const inspectors = await prisma.user.findMany({
      where: { role: { in: ['field_inspector', 'sanitary_inspector', 'junior_engineer', 'agent'] } },
      select: { id: true, primary_org_unit_id: true },
    });
    const assets = await prisma.asset.findMany({
      select: { id: true, org_unit_id: true, latitude: true, longitude: true },
    });
    const rows = [];
    for (const org of ctx.all) {
      const here = inspectors.filter((i) => i.primary_org_unit_id === org.id);
      const orgAssets = assets.filter((a) => a.org_unit_id === org.id);
      for (let i = 0; i < int(3, 8); i++) {
        const asset = orgAssets.length ? pick(orgAssets) : null;
        rows.push({
          tenant_id: 'default',
          org_unit_id: org.id,
          template_id: templates.length ? pick(templates).id : null,
          inspector_user_id: (here.length ? pick(here) : inspectors[0])?.id ?? anyUser,
          asset_id: asset?.id ?? null,
          location_lat: asset?.latitude ?? null,
          location_lng: asset?.longitude ?? null,
          gps_locked: false,
          status: 'scheduled',
          remarks: pick([
            'Routine quarterly check.',
            'Follow-up after the last complaint.',
            'Pre-monsoon condition survey.',
          ]),
          inspected_at: daysAhead(int(1, 14)),
        });
      }
    }
    step('field inspections scheduled', await bulk(prisma.fieldInspection, rows));
  } else {
    step('field inspections (already scheduled)');
  }

  const scheduledLicence = await prisma.tradeLicenceInspection.count({
    where: { status: 'scheduled' },
  });
  if (scheduledLicence === 0) {
    const licences = await prisma.tradeLicence.findMany({
      where: { status: { in: ['APPROVED', 'INSPECTION', 'SUBMITTED'] } },
      select: { id: true, latitude: true, longitude: true },
      take: 30,
    });
    await bulk(prisma.tradeLicenceInspection, pickN(licences, Math.min(licences.length, 18)).map((l) => ({
      licence_id: l.id,
      inspection_type: pick(['routine', 'pre_licence', 'complaint_driven', 'renewal']),
      scheduled_for: daysAhead(int(1, 21)),
      inspector_user_id: anyUser,
      status: 'scheduled',
      violations: [],
      latitude: l.latitude,
      longitude: l.longitude,
    })));
    step('licence inspections scheduled', await prisma.tradeLicenceInspection.count({ where: { status: 'scheduled' } }));
  } else {
    step('licence inspections (already scheduled)');
  }

  const scheduledPermit = await prisma.buildingPermitInspection.count({
    where: { status: 'scheduled' },
  });
  if (scheduledPermit === 0) {
    const permits = await prisma.buildingPermit.findMany({
      where: { status: { in: ['INSPECTION', 'NOC_PENDING', 'SCRUTINY', 'APPROVED'] } },
      select: { id: true, latitude: true, longitude: true },
      take: 30,
    });
    await bulk(prisma.buildingPermitInspection, pickN(permits, Math.min(permits.length, 15)).map((p) => ({
      permit_id: p.id,
      inspection_type: pick(['site_verification', 'plinth_level', 'structural', 'completion']),
      scheduled_for: daysAhead(int(1, 21)),
      inspector_user_id: anyUser,
      status: 'scheduled',
      location_lat: p.latitude,
      location_lng: p.longitude,
    })));
    step('permit inspections scheduled', await prisma.buildingPermitInspection.count({ where: { status: 'scheduled' } }));
  } else {
    step('permit inspections (already scheduled)');
  }

  // ── Licences coming up for renewal ────────────────────────────────────────
  //
  // Nothing expired within the next 30 days, so the renewals queue — a screen
  // the licensing clerk works from daily — was permanently empty.
  const expiringSoon = await prisma.tradeLicence.count({
    where: {
      status: 'APPROVED',
      valid_until: { gte: new Date(), lte: daysAhead(30) },
    },
  });
  if (expiringSoon === 0) {
    const candidates = await prisma.tradeLicence.findMany({
      where: { status: 'APPROVED' },
      select: { id: true },
      take: 40,
    });
    const chosen = pickN(candidates, Math.min(candidates.length, 14));
    for (const l of chosen) {
      await prisma.tradeLicence.update({
        where: { id: l.id },
        data: { valid_until: daysAhead(int(2, 29)) },
      });
    }
    step('licences brought into the renewal window', chosen.length);
  } else {
    step('renewal window (already populated)');
  }

  // ── Give every complaint a location ───────────────────────────────────────
  //
  // `latitude`/`longitude` are new on the complaint itself. Backfill them from
  // the referenced asset where there is one, and scatter the rest around the
  // branch centre, so the ward-density map plots the whole caseload rather
  // than the minority that happened to name a pole.
  const unplaced = await prisma.complaint.count({ where: { latitude: null } });
  if (unplaced > 0) {
    const poles = await prisma.electricPole.findMany({
      select: { id: true, latitude: true, longitude: true },
    });
    const poleById = new Map(poles.map((p) => [p.id, p]));
    const orgById = new Map(ctx.all.map((o) => [o.id, o]));

    let placed = 0;
    for (const org of ctx.all) {
      const rows = await prisma.complaint.findMany({
        where: { org_unit_id: org.id, latitude: null },
        select: { id: true, pole_id: true },
      });
      for (const c of rows) {
        const pole = c.pole_id == null ? null : poleById.get(c.pole_id);
        const centre = orgById.get(org.id);
        const lat = pole?.latitude ?? (centre?.center_lat ?? 11.0168) + dec(-0.05, 0.05, 5);
        const lng = pole?.longitude ?? (centre?.center_lng ?? 76.9558) + dec(-0.05, 0.05, 5);
        await prisma.complaint.update({
          where: { id: c.id },
          data: {
            latitude: lat,
            longitude: lng,
            ward_number: String(int(1, centre?.ward_count ?? 40)),
          },
        });
        placed++;
      }
    }
    step('complaints given a location', placed);
  } else {
    step('complaints already located');
  }

  // ── Complaints tied to the asset they concern ─────────────────────────────
  //
  // Only 26 of 260 complaints referenced a pole, so the street-light fault
  // count and the ward density map were both near-empty.
  const openUnlinked = await prisma.complaint.findMany({
    where: {
      pole_id: null,
      status: { in: ['pending', 'assigned', 'in_progress'] },
      category: { in: ['street_light', 'streetlight', 'electrical'] },
    },
    select: { id: true, org_unit_id: true },
    take: 120,
  });
  if (openUnlinked.length) {
    const poles = await prisma.electricPole.findMany({
      select: { id: true, org_unit_id: true },
    });
    let linked = 0;
    for (const c of openUnlinked) {
      const here = poles.filter((p) => p.org_unit_id === c.org_unit_id);
      if (!here.length) continue;
      await prisma.complaint.update({
        where: { id: c.id },
        data: { pole_id: pick(here).id },
      });
      linked++;
    }
    step('complaints linked to a pole', linked);
  } else {
    step('complaints already linked to assets');
  }

  // ── A handful of complaints logged today ──────────────────────────────────
  const loggedToday = await prisma.complaint.count({
    where: { created_at: { gte: today } },
  });
  if (loggedToday === 0) {
    const poles = await prisma.electricPole.findMany({
      select: { id: true, org_unit_id: true },
    });
    const rows = [];
    for (const org of ctx.all) {
      const here = poles.filter((p) => p.org_unit_id === org.id);
      for (let i = 0; i < int(1, 5); i++) {
        const category = pick(['street_light', 'water_supply', 'garbage', 'drainage', 'road']);
        rows.push({
          org_unit_id: org.id,
          pole_id: category === 'street_light' && here.length ? pick(here).id : null,
          category,
          complaint_type: category,
          description: pick([
            'Street light not glowing since last night.',
            'No water supply in the street for two days.',
            'Garbage not collected this week.',
            'Drain overflowing near the junction.',
            'Pothole causing accidents.',
          ]),
          caller_language: pick(['ta', 'ta', 'en']),
          urgency_level: pick(['low', 'medium', 'medium', 'high', 'critical']),
          status: 'pending',
          latitude: (org.center_lat ?? 11.0168) + dec(-0.04, 0.04, 5),
          longitude: (org.center_lng ?? 76.9558) + dec(-0.04, 0.04, 5),
          ward_number: String(int(1, org.ward_count ?? 40)),
          created_at: new Date(today.getTime() + int(6, 16) * 3600000),
        });
      }
    }
    step("today's complaints", await bulk(prisma.complaint, rows));
  } else {
    step("today's complaints (already logged)");
  }
}

module.exports = { seedToday };
