/**
 * Shared helpers and reference data for the demo seed.
 *
 * The seed exists so no screen in the product renders an empty state during a
 * demonstration. That means the data has to look like a real Tamil Nadu local
 * body's records, not `Lorem ipsum #4` — real ward names, plausible fee
 * amounts, Tamil names in the proportions you would actually see, and history
 * spread across months so every chart has a shape rather than a single spike.
 */

require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');

// Supabase's pooler drops a connection that is held too long, and a seed that
// inserts row-by-row holds one for minutes. Generous timeouts plus batched
// writes below keep the whole run inside one healthy connection.
const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 5,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 20000,
  keepAlive: true,
});
const prisma = new PrismaClient({ adapter: new PrismaPg(pool) });

/**
 * Insert rows in batches via `createMany`.
 *
 * Seeding thousands of rows one `create` at a time is both slow (a round trip
 * each) and fragile — the pooled connection times out mid-run. One statement
 * per chunk turns minutes into seconds.
 *
 * Returns the number of rows written. Use only where the generated ids are not
 * needed immediately; query them back afterwards if they are.
 */
async function bulk(model, rows, chunkSize = 500) {
  let written = 0;
  for (let i = 0; i < rows.length; i += chunkSize) {
    const chunk = rows.slice(i, i + chunkSize);
    const res = await model.createMany({ data: chunk, skipDuplicates: true });
    written += res.count;
  }
  return written;
}

// ── Deterministic randomness ────────────────────────────────────────────────
//
// Seeded so re-running produces the same database. A demo that looks different
// every time is impossible to talk through, and impossible to screenshot.

let _seed = 20260803;
function rnd() {
  _seed = (_seed * 1664525 + 1013904223) % 4294967296;
  return _seed / 4294967296;
}
const pick = (arr) => arr[Math.floor(rnd() * arr.length)];
const pickN = (arr, n) => {
  const copy = [...arr];
  const out = [];
  for (let i = 0; i < n && copy.length; i++) {
    out.push(copy.splice(Math.floor(rnd() * copy.length), 1)[0]);
  }
  return out;
};
const int = (min, max) => Math.floor(rnd() * (max - min + 1)) + min;
const dec = (min, max, places = 2) =>
  Number((rnd() * (max - min) + min).toFixed(places));
const chance = (p) => rnd() < p;

/** A date N days ago, with a random time of day. */
const daysAgo = (n) => {
  const d = new Date(Date.now() - n * 86400000);
  d.setHours(int(8, 18), int(0, 59), int(0, 59), 0);
  return d;
};
/** Midnight UTC N days ago — for `@db.Date` columns. */
const dayAgo = (n) => {
  const d = new Date(Date.now() - n * 86400000);
  return new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
};
const daysAhead = (n) => new Date(Date.now() + n * 86400000);

/**
 * Weighted date in the recent past.
 *
 * Real caseloads are heavier close to today — a register that is perfectly
 * uniform over two years looks synthetic the moment you plot it.
 */
const recentBiased = (maxDays) => Math.floor(Math.pow(rnd(), 1.7) * maxDays);

// ── Tamil Nadu reference data ───────────────────────────────────────────────

const TAMIL_MALE = [
  'Murugan', 'Karthik', 'Selvam', 'Rajendran', 'Arumugam', 'Senthil', 'Dinesh',
  'Manikandan', 'Prabhu', 'Saravanan', 'Vignesh', 'Anbarasu', 'Balaji',
  'Chandran', 'Ezhilarasan', 'Gopal', 'Hariharan', 'Iniyan', 'Jeyakumar',
  'Kannan', 'Lingam', 'Mohanraj', 'Natarajan', 'Palanisamy', 'Ramesh',
  'Sathish', 'Thangaraj', 'Udhayakumar', 'Velmurugan', 'Yuvaraj',
];
const TAMIL_FEMALE = [
  'Lakshmi', 'Meena', 'Kavitha', 'Revathi', 'Anitha', 'Bhuvana', 'Chitra',
  'Devi', 'Gayathri', 'Hemalatha', 'Indira', 'Jayanthi', 'Kalaiselvi',
  'Malathi', 'Nithya', 'Pushpa', 'Radha', 'Saraswathi', 'Tamilselvi',
  'Uma', 'Vasanthi', 'Yamuna', 'Amudha', 'Bhavani', 'Ezhilarasi',
];
const INITIALS = ['R', 'K', 'S', 'M', 'P', 'V', 'A', 'T', 'N', 'G', 'D', 'C'];

const maleName = () => `${pick(INITIALS)}. ${pick(TAMIL_MALE)}`;
const femaleName = () => `${pick(INITIALS)}. ${pick(TAMIL_FEMALE)}`;
const personName = () => (chance(0.55) ? maleName() : femaleName());

const STREETS = [
  'Anna Nagar 3rd Street', 'Gandhi Road', 'Kamarajar Salai', 'Bharathi Street',
  'Nehru Street', 'Periyar Nagar Main Road', 'Sastri Road', 'Thiruvalluvar Street',
  'Mettupalayam Road', 'Avinashi Road', 'Trichy Road', 'Sathy Road',
  'Race Course Road', 'Big Bazaar Street', 'Oppanakara Street', 'Raja Street',
  'Cross Cut Road', 'DB Road', 'TV Swamy Road', 'Bharathiyar Road',
  'Kovai Main Road', 'Sungam Bypass', 'Ukkadam Main Road', 'Singanallur Road',
];

const LANDMARKS = [
  'near the Amman temple', 'opposite the bus stand', 'behind the ration shop',
  'next to the primary school', 'near the water tank', 'at the market entrance',
  'opposite the PHC', 'near the panchayat office', 'beside the community hall',
  'at the burial ground road', 'near the overhead tank', 'by the canal bridge',
];

/** Coimbatore city centre — everything scatters around this. */
const BASE_LAT = 11.0168;
const BASE_LNG = 76.9558;
const scatter = (spread = 0.06) => ({
  latitude: Number((BASE_LAT + (rnd() - 0.5) * spread).toFixed(6)),
  longitude: Number((BASE_LNG + (rnd() - 0.5) * spread).toFixed(6)),
});

const phone = () =>
  `+91${pick(['9', '8', '7', '6'])}${String(int(100000000, 999999999)).slice(0, 9)}`;

const doorNo = () =>
  chance(0.3)
    ? `${int(1, 180)}${pick(['A', 'B', 'C', '/1', '/2'])}`
    : `${int(1, 220)}`;

const address = () =>
  `${doorNo()}, ${pick(STREETS)}, Ward ${int(1, 60)}, Coimbatore`;

// ── Progress output ─────────────────────────────────────────────────────────

const t0 = Date.now();
function step(label, count) {
  const secs = ((Date.now() - t0) / 1000).toFixed(1);
  const n = count === undefined ? '' : String(count).padStart(6);
  console.log(`  ${n}  ${label.padEnd(34)} ${secs}s`);
}
function heading(text) {
  console.log(`\n── ${text} ${'─'.repeat(Math.max(0, 56 - text.length))}`);
}

/**
 * Insert rows only when the table is empty.
 *
 * Keeps the seed re-runnable without stacking duplicate history on every run,
 * which would quietly skew every chart it feeds.
 */
async function seedIfEmpty(model, label, builder) {
  const existing = await model.count();
  if (existing > 0) {
    step(`${label} (already has ${existing})`);
    return false;
  }
  await builder();
  step(label, await model.count());
  return true;
}

module.exports = {
  prisma,
  pool,
  rnd, pick, pickN, int, dec, chance,
  daysAgo, dayAgo, daysAhead, recentBiased,
  TAMIL_MALE, TAMIL_FEMALE,
  maleName, femaleName, personName,
  STREETS, LANDMARKS, scatter, phone, doorNo, address,
  BASE_LAT, BASE_LNG,
  step, heading, seedIfEmpty, bulk,
};
