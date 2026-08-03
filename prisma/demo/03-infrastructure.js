/**
 * Physical infrastructure: street-light poles, the water network, the generic
 * asset register, and the field inspections carried out against them.
 *
 * These feed the GIS map layers, so coordinates matter more here than
 * elsewhere — a map with everything stacked on one pin is worse than no map.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, dayAgo, recentBiased,
  personName, scatter, step, heading, bulk, STREETS, LANDMARKS, BASE_LAT, BASE_LNG,
} = require('./lib');

/** A LineString wandering away from a start point — a plausible pipeline run. */
function lineFrom(lat, lng, segments = 5, step_ = 0.004) {
  const coords = [[lng, lat]];
  let [cl, cn] = [lng, lat];
  for (let i = 0; i < segments; i++) {
    cl += (Math.random() - 0.5) * step_ * 2;
    cn += (Math.random() - 0.5) * step_ * 2;
    coords.push([Number(cl.toFixed(6)), Number(cn.toFixed(6))]);
  }
  return { type: 'LineString', coordinates: coords };
}

async function seedInfrastructure(ctx) {
  heading('Infrastructure');
  const { all } = ctx;

  // ── Street-light poles ────────────────────────────────────────────────────
  const existingPoles = await prisma.electricPole.count();
  if (existingPoles < 120) {
    let p = 0;
    for (let i = existingPoles; i < 120; i++) {
      const org = pick(all);
      const loc = scatter(0.09);
      await prisma.electricPole.create({
        data: {
          pole_number: `SL-${org.branch_code ?? 'GEN'}-${String(i + 1).padStart(4, '0')}`,
          keypad_id: String(100000 + i),
          org_unit_id: org.id,
          latitude: loc.latitude,
          longitude: loc.longitude,
          landmarks: [pick(STREETS), pick(LANDMARKS)],
          image_url: chance(0.55) ? `/uploads/poles/pole-${i}.jpg` : null,
          image_latitude: loc.latitude,
          image_longitude: loc.longitude,
          image_captured_at: chance(0.55) ? daysAgo(recentBiased(200)) : null,
        },
      });
      p++;
    }
    step('street-light poles', p);
  } else {
    step(`street-light poles (already ${existingPoles})`);
  }

  // ── Water network ─────────────────────────────────────────────────────────
  if ((await prisma.waterPipeline.count()) === 0) {
    const MATERIALS = ['PVC', 'HDPE', 'Cast Iron', 'DI'];
    let n = 0;
    for (const org of all) {
      for (let i = 0; i < 6; i++) {
        const start = scatter(0.07);
        await prisma.waterPipeline.create({
          data: {
            name: `${pick(['Main', 'Branch', 'Distribution', 'Feeder'])} line — ${pick(STREETS)}`,
            org_unit_id: org.id,
            path_geojson: lineFrom(start.latitude, start.longitude, int(4, 9)),
            diameter_mm: pick([90, 110, 160, 200, 250, 315]),
            material: pick(MATERIALS),
            status: pick(['active', 'active', 'active', 'active', 'leak_alert', 'maintenance']),
          },
        });
        n++;
      }
    }
    step('water pipelines', n);

    let t = 0;
    for (const org of all) {
      for (let i = 0; i < 4; i++) {
        const loc = scatter(0.07);
        const cap = pick([50000, 75000, 100000, 150000, 200000, 300000]);
        await prisma.waterTankBorewell.create({
          data: {
            org_unit_id: org.id,
            name: `${pick(['OHT', 'Sump', 'Borewell', 'GLR'])} — ${pick(STREETS).split(' ')[0]} ${pick(['North', 'South', 'East', 'West'])}`,
            type: pick(['overhead_tank', 'sump', 'borewell']),
            capacity_liters: cap,
            current_level_pct: int(15, 100),
            latitude: loc.latitude,
            longitude: loc.longitude,
            status: pick(['active', 'active', 'active', 'maintenance']),
          },
        }).catch(() => {});
        t++;
      }
    }
    step('tanks & borewells', await prisma.waterTankBorewell.count());

    let v = 0;
    for (const org of all) {
      for (let i = 0; i < 5; i++) {
        const loc = scatter(0.07);
        await prisma.waterValve.create({
          data: {
            org_unit_id: org.id,
            valve_number: `V-${String.fromCharCode(65 + i)}${int(10, 99)}`,
            latitude: loc.latitude,
            longitude: loc.longitude,
            status: pick(['open', 'closed', 'open', 'open']),
          },
        }).catch(() => {});
        v++;
      }
    }
    step('water valves', await prisma.waterValve.count());
  } else {
    step('water network (already present)');
  }

  // ── Flow logs, so the water charts have a series ──────────────────────────
  if ((await prisma.waterFlowLog.count()) === 0) {
    const tanks = await prisma.waterTankBorewell.findMany({ take: 20 });
    let f = 0;
    for (const tank of tanks) {
      for (let d = 60; d >= 0; d -= 2) {
        await prisma.waterFlowLog.create({
          data: {
            tank_id: tank.id,
            flow_rate_lps: dec(2, 15, 2),
            pressure_bar: dec(0.8, 4.5, 2),
            logged_at: daysAgo(d),
          },
        }).catch(() => {});
        f++;
      }
    }
    step('water flow logs', await prisma.waterFlowLog.count());
  } else {
    step('water flow logs (already present)');
  }

  // ── Generic asset register ────────────────────────────────────────────────
  if ((await prisma.asset.count()) === 0) {
    const TYPES = [
      { code: 'park', names: ['VOC Park', 'Gandhi Park', 'Children\'s Play Area', 'Corporation Garden'] },
      { code: 'community_hall', names: ['Ward Community Hall', 'Kalyana Mandapam', 'Panchayat Hall'] },
      { code: 'vehicle', names: ['Garbage Compactor', 'Water Tanker', 'Tipper Lorry', 'JCB'] },
      { code: 'transformer', names: ['Distribution Transformer'] },
      { code: 'bus_shelter', names: ['Bus Shelter'] },
      { code: 'public_toilet', names: ['Public Convenience'] },
    ];
    const zones = await prisma.zone.findMany();
    let a = 0;
    for (const org of all) {
      for (let i = 0; i < 9; i++) {
        const t = pick(TYPES);
        const loc = scatter(0.07);
        await prisma.asset.create({
          data: {
            tenant_id: 'default',
            org_unit_id: org.id,
            asset_type_code: t.code,
            asset_code: `AST-${t.code.slice(0, 3).toUpperCase()}-${String(a + 1).padStart(4, '0')}`,
            name: `${pick(t.names)} — ${pick(STREETS).split(' ')[0]}`,
            latitude: loc.latitude,
            longitude: loc.longitude,
            zone_id: zones.length && chance(0.7) ? pick(zones).id : null,
            address: `${pick(STREETS)}, Ward ${int(1, 60)}`,
            landmarks: [pick(LANDMARKS)],
            installed_at: daysAgo(int(200, 3500)),
            manufacturer: pick(['Kirloskar', 'Ashok Leyland', 'Tata', 'Local Fabrication', 'Bajaj']),
            condition_rating: int(2, 5),
            is_operational: chance(0.88),
            custom_data: { ward: int(1, 60), last_audit: daysAgo(int(30, 400)).toISOString() },
          },
        });
        a++;
      }
    }
    step('assets', a);
  } else {
    step('assets (already present)');
  }

  // ── Inspection templates and field inspections ────────────────────────────
  if ((await prisma.inspectionTemplate.count()) === 0) {
    const templates = [
      { name: 'Street light routine check', asset_type_code: 'electric_pole',
        checklist_items: [
          { item: 'Fitting intact', type: 'yes_no' },
          { item: 'Wiring insulated', type: 'yes_no' },
          { item: 'Pole upright and stable', type: 'yes_no' },
          { item: 'Illumination adequate', type: 'rating' },
        ] },
      { name: 'Park safety audit', asset_type_code: 'park',
        checklist_items: [
          { item: 'Play equipment safe', type: 'yes_no' },
          { item: 'Fencing intact', type: 'yes_no' },
          { item: 'Lighting working', type: 'yes_no' },
          { item: 'Waste bins present', type: 'yes_no' },
        ] },
      { name: 'Vehicle fitness check', asset_type_code: 'vehicle',
        checklist_items: [
          { item: 'Brakes tested', type: 'yes_no' },
          { item: 'Tyres within tread limit', type: 'yes_no' },
          { item: 'Hydraulics functional', type: 'yes_no' },
          { item: 'Overall condition', type: 'rating' },
        ] },
      { name: 'Water tank hygiene inspection', asset_type_code: null,
        checklist_items: [
          { item: 'Tank cleaned in last quarter', type: 'yes_no' },
          { item: 'Chlorination done', type: 'yes_no' },
          { item: 'Lid secured', type: 'yes_no' },
        ] },
    ];
    for (const t of templates) {
      await prisma.inspectionTemplate.create({
        data: { tenant_id: 'default', ...t, is_active: true },
      });
    }
    step('inspection templates', templates.length);
  } else {
    step('inspection templates (already present)');
  }

  if ((await prisma.fieldInspection.count()) === 0) {
    const templates = await prisma.inspectionTemplate.findMany();
    const assets = await prisma.asset.findMany({ take: 60 });
    const inspectors = await prisma.user.findMany({
      where: { role: { in: ['junior_engineer', 'assistant_engineer', 'sanitary_inspector', 'agent'] } },
    });
    let n = 0;
    for (let i = 0; i < 150; i++) {
      const org = pick(all);
      const loc = scatter(0.07);
      const tpl = pick(templates);
      const score = int(45, 100);
      await prisma.fieldInspection.create({
        data: {
          tenant_id: 'default',
          org_unit_id: org.id,
          template_id: tpl.id,
          inspector_user_id: inspectors.length ? pick(inspectors).id : 1,
          asset_id: assets.length && chance(0.7) ? pick(assets).id : null,
          location_lat: loc.latitude,
          location_lng: loc.longitude,
          gps_locked: chance(0.85),
          gps_accuracy_m: dec(3, 22, 1),
          checklist_results: (tpl.checklist_items || []).map((c) => ({
            item: c.item,
            result: c.type === 'rating' ? int(2, 5) : chance(0.8) ? 'yes' : 'no',
          })),
          overall_score: score,
          photos: [`/uploads/inspections/insp-${i}-1.jpg`],
          remarks: score < 60
            ? pick(['Needs urgent attention.', 'Multiple defects noted, work order raised.', 'Below standard — re-inspection scheduled.'])
            : pick(['Satisfactory.', 'Minor wear, no action needed.', 'In good condition.', 'Routine check completed.']),
          status: 'completed',
          inspected_at: daysAgo(recentBiased(150)),
        },
      });
      n++;
    }
    step('field inspections', n);
  } else {
    step('field inspections (already present)');
  }
}

module.exports = { seedInfrastructure };
