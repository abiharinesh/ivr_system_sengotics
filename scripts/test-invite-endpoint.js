#!/usr/bin/env node
/* eslint-disable */
require('dotenv').config();
const { Client } = require('pg');

(async () => {
  const c = new Client({ connectionString: process.env.DATABASE_URL });
  await c.connect();
  const r = await c.query(
    "SELECT invite_token FROM tender_vendor_invites WHERE tender_id = 9 LIMIT 1",
  );
  const tok = r.rows[0].invite_token;
  console.log('Full token:', tok);
  await c.end();

  const url = `http://127.0.0.1:3000/public/invite/${tok}`;
  console.log('GET', url);
  const res = await fetch(url);
  console.log('Status:', res.status);
  const body = await res.text();
  try {
    const json = JSON.parse(body);
    console.log('Body:', JSON.stringify(json, null, 2).slice(0, 1200));
  } catch {
    console.log('Body (raw):', body.slice(0, 600));
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
