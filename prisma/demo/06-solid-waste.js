/**
 * Solid waste: public bins with a fill history, door-to-door collection routes,
 * the daily trips run against them, and sanitation worker attendance.
 *
 * Fill levels are deliberately spread across all five bands so the GIS map has
 * green, yellow *and* red pins — a map where everything is green demonstrates
 * nothing, and the red list is the screen a sanitary inspector actually works
 * from.
 */

const {
  prisma, pick, pickN, int, dec, chance, daysAgo, dayAgo, recentBiased,
  personName, phone, scatter, step, heading, bulk, STREETS, LANDMARKS,
} = require('./lib');

/** Mirrors `bin-fill.ts` — the band a percentage falls into. */
function bandFor(pct) {
  if (pct >= 100) return 'OVERFLOWING';
  if (pct >= 75) return 'HIGH';
  if (pct >= 40) return 'MEDIUM';
  if (pct >= 10) return 'LOW';
  return 'EMPTY';
}

async function seedSolidWaste(ctx) {
  heading('Solid waste');
  const { all } = ctx;
  const zones = await prisma.zone.findMany({ select: { id: true, org_unit_id: true } });
  const crew = await prisma.user.findMany({
    where: { role: { in: ['sanitary_inspector', 'health_officer', 'agent'] } },
    select: { id: true },
  });
  const anyUser = crew[0]?.id ?? 1;

  // ── Bins ──────────────────────────────────────────────────────────────────
  if ((await prisma.wasteBin.count()) === 0) {
    const TYPES = ['community', 'community', 'community', 'litter', 'segregated_wet', 'segregated_dry', 'compactor'];
    const rows = [];
    let idx = 0;
    for (const org of all) {
      const count = org.branch_type === 'MUNICIPAL_CORPORATION' ? 34 : 16;
      for (let i = 0; i < count; i++) {
        // A believable spread: most bins are part-full, a meaningful minority
        // are red, and a few have just been emptied.
        const pct = pick([
          0, 5, 15, 22, 30, 35, 45, 52, 58, 65, 70,
          78, 82, 88, 92, 96, 100, 100, 45, 60, 72,
        ]);
        const zoneOptions = zones.filter((z) => z.org_unit_id === org.id);
        const loc = scatter(0.085);
        rows.push({
          tenant_id: 'default',
          org_unit_id: org.id,
          bin_code: `BIN-${String(++idx).padStart(6, '0')}`,
          bin_type: pick(TYPES),
          capacity_litres: pick([240, 660, 660, 1100, 1100, 4500]),
          fill_level: bandFor(pct),
          fill_pct: pct,
          status: chance(0.93) ? 'ACTIVE' : pick(['DAMAGED', 'RELOCATED']),
          latitude: loc.latitude,
          longitude: loc.longitude,
          zone_id: zoneOptions.length && chance(0.7) ? pick(zoneOptions).id : null,
          ward_number: String(int(1, 60)),
          landmark: `${pick(STREETS)} — ${pick(LANDMARKS)}`,
          installed_at: daysAgo(int(90, 1600)),
          last_emptied_at: pct < 40 ? daysAgo(int(0, 2)) : daysAgo(int(2, 9)),
          last_read_at: daysAgo(int(0, 3)),
          created_by: anyUser,
        });
      }
    }
    step('waste bins', await bulk(prisma.wasteBin, rows));

    // Two weeks of readings per bin, so the fill history chart has a series.
    const bins = await prisma.wasteBin.findMany({
      select: { id: true, fill_pct: true, fill_level: true },
    });
    const readings = [];
    for (const bin of bins) {
      for (let d = 14; d >= 0; d--) {
        // Sawtooth: fills up, gets emptied, fills again.
        const emptied = d % pick([3, 4, 5]) === 0;
        const pct = emptied ? 0 : Math.min(100, int(10, 100));
        readings.push({
          bin_id: bin.id,
          fill_level: bandFor(pct),
          fill_pct: pct,
          emptied,
          remarks: emptied ? 'Cleared by the morning round.' : null,
          recorded_by: anyUser,
          recorded_at: daysAgo(d),
        });
      }
    }
    step('bin readings', await bulk(prisma.wasteBinReading, readings));
  } else {
    step('waste bins (already present)');
  }

  // ── Collection routes and their stops ─────────────────────────────────────
  if ((await prisma.collectionRoute.count()) === 0) {
    let r = 0;
    for (const org of all) {
      const routeCount = org.branch_type === 'MUNICIPAL_CORPORATION' ? 6 : 3;
      for (let i = 0; i < routeCount; i++) {
        const zoneOptions = zones.filter((z) => z.org_unit_id === org.id);
        const shift = pick(['morning', 'morning', 'morning', 'afternoon']);
        const route = await prisma.collectionRoute.create({
          data: {
            tenant_id: 'default',
            org_unit_id: org.id,
            route_code: `RTE-${String(++r).padStart(4, '0')}`,
            name: `${pick(STREETS).split(' ')[0]} ${pick(['circuit', 'round', 'beat'])} — ${shift}`,
            zone_id: zoneOptions.length ? pick(zoneOptions).id : null,
            ward_number: String(int(1, 60)),
            service_days: chance(0.6) ? [1, 2, 3, 4, 5, 6] : [1, 3, 5],
            shift,
            household_count: int(180, 900),
            distance_km: dec(3, 18, 1),
            is_active: chance(0.94),
          },
        });

        // Stops: some are public bins, some are plain door-to-door points.
        const binsHere = await prisma.wasteBin.findMany({
          where: { org_unit_id: org.id, status: 'ACTIVE' },
          select: { id: true }, take: 30,
        });
        const stopCount = int(8, 16);
        const chosenBins = pickN(binsHere, Math.min(binsHere.length, Math.floor(stopCount / 2)));
        const stops = [];
        for (let s = 1; s <= stopCount; s++) {
          const bin = chosenBins[s - 1];
          const loc = scatter(0.05);
          stops.push({
            route_id: route.id,
            seq: s,
            bin_id: bin?.id ?? null,
            label: `${pick(STREETS)} — ${pick(['north end', 'south end', 'junction', 'middle', 'bus stop', 'temple side'])}`,
            latitude: loc.latitude,
            longitude: loc.longitude,
            household_count: int(15, 70),
          });
        }
        await bulk(prisma.collectionRouteStop, stops);
      }
    }
    step('collection routes', r);
    step('  route stops', await prisma.collectionRouteStop.count());
  } else {
    step('collection routes (already present)');
  }

  // ── Trips: three weeks of daily rounds ────────────────────────────────────
  if ((await prisma.collectionTrip.count()) === 0) {
    const routes = await prisma.collectionRoute.findMany({
      where: { is_active: true },
      include: { stops: { select: { id: true, seq: true } } },
    });
    const drivers = await prisma.user.findMany({
      where: { role: { in: ['agent', 'electrician', 'plumber'] } }, select: { id: true },
    });
    let t = 0;
    for (const route of routes) {
      if (route.stops.length === 0) continue;
      for (let d = 20; d >= 0; d--) {
        const date = dayAgo(d);
        // Respect the route's service days rather than inventing a round on a
        // day the crew does not work.
        const dow = date.getUTCDay() === 0 ? 7 : date.getUTCDay();
        if (!route.service_days.includes(dow)) continue;

        const isToday = d === 0;
        const status = isToday
          ? pick(['IN_PROGRESS', 'IN_PROGRESS', 'COMPLETED'])
          : pick(['COMPLETED', 'COMPLETED', 'COMPLETED', 'COMPLETED', 'ABANDONED']);
        const total = route.stops.length;
        const done = status === 'COMPLETED' ? total
          : status === 'ABANDONED' ? int(1, Math.max(1, total - 3))
          : int(1, total - 1);
        const wetKg = status === 'COMPLETED' ? int(180, 900) : null;
        const dryKg = status === 'COMPLETED' ? int(90, 500) : null;
        const odoStart = int(12000, 90000);

        const trip = await prisma.collectionTrip.create({
          data: {
            tenant_id: 'default',
            org_unit_id: route.org_unit_id,
            route_id: route.id,
            trip_number: `TRIP-2026-27-${String(++t).padStart(6, '0')}`,
            trip_date: date,
            shift: route.shift,
            status,
            vehicle_number: `TN ${int(33, 43)} ${pick(['AB', 'BZ', 'CK', 'DL'])} ${int(1000, 9999)}`,
            driver_user_id: drivers.length ? pick(drivers).id : null,
            crew_size: int(2, 6),
            started_at: new Date(date.getTime() + 6 * 3600000),
            ended_at: status === 'IN_PROGRESS' ? null : new Date(date.getTime() + int(9, 13) * 3600000),
            waste_collected_kg: wetKg && dryKg ? wetKg + dryKg : null,
            segregated_wet_kg: wetKg,
            segregated_dry_kg: dryKg,
            odometer_start_km: odoStart,
            odometer_end_km: status === 'IN_PROGRESS' ? null : odoStart + int(5, 30),
            stops_total: total,
            stops_completed: done,
            abandon_reason: status === 'ABANDONED'
              ? pick(['Vehicle breakdown mid-route.', 'Heavy rain; round suspended.', 'Crew shortage — two absent.']) : null,
            created_by: anyUser,
          },
        });

        await bulk(prisma.collectionTripStop, route.stops.map((s, i) => ({
          trip_id: trip.id,
          route_stop_id: s.id,
          seq: s.seq,
          completed: i < done,
          skipped: false,
          completed_at: i < done ? new Date(date.getTime() + (6 + i * 0.25) * 3600000) : null,
        })));
      }
    }
    step('collection trips', t);
    step('  trip stops', await prisma.collectionTripStop.count());
  } else {
    step('collection trips (already present)');
  }

  // ── Sanitation attendance ─────────────────────────────────────────────────
  if ((await prisma.sanitationAttendance.count()) === 0) {
    const routes = await prisma.collectionRoute.findMany({ select: { id: true, org_unit_id: true } });
    const rows = [];
    for (const org of all) {
      // A stable roster per branch, marked over the last three weeks.
      const workers = Array.from(
        { length: org.branch_type === 'MUNICIPAL_CORPORATION' ? 26 : 12 },
        () => ({ name: personName(), phone: phone(), contract: chance(0.55) }),
      );
      const orgRoutes = routes.filter((r) => r.org_unit_id === org.id);
      for (let d = 20; d >= 0; d--) {
        const date = dayAgo(d);
        if (date.getUTCDay() === 0) continue; // Sunday off
        for (const w of workers) {
          const status = pick([
            'PRESENT', 'PRESENT', 'PRESENT', 'PRESENT', 'PRESENT',
            'PRESENT', 'PRESENT', 'ABSENT', 'LEAVE', 'HALF_DAY',
          ]);
          const present = status === 'PRESENT' || status === 'HALF_DAY';
          const loc = scatter(0.04);
          rows.push({
            tenant_id: 'default',
            org_unit_id: org.id,
            worker_name: w.name,
            worker_phone: w.phone,
            is_contract: w.contract,
            attendance_date: date,
            shift: 'morning',
            status,
            route_id: orgRoutes.length ? pick(orgRoutes).id : null,
            check_in_at: present ? new Date(date.getTime() + 6 * 3600000 + int(0, 40) * 60000) : null,
            check_out_at: status === 'PRESENT'
              ? new Date(date.getTime() + 13 * 3600000)
              : status === 'HALF_DAY' ? new Date(date.getTime() + 10 * 3600000) : null,
            check_in_lat: present ? loc.latitude : null,
            check_in_lng: present ? loc.longitude : null,
            remarks: status === 'LEAVE' ? pick(['Casual leave', 'Medical leave', 'Sanctioned leave']) : null,
            recorded_by: anyUser,
          });
        }
      }
    }
    step('sanitation attendance', await bulk(prisma.sanitationAttendance, rows));
  } else {
    step('sanitation attendance (already present)');
  }
}

module.exports = { seedSolidWaste };
