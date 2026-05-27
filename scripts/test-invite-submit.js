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
  await c.end();

  const url = `http://127.0.0.1:3000/public/invite/${tok}/quotation`;
  const form = new FormData();
  form.set('name', 'Nivedha Electronics');
  form.set('amount', '12500');
  form.set('remarks', 'Automated test bid');

  console.log('POST', url);
  const res = await fetch(url, { method: 'POST', body: form });
  console.log('Status:', res.status);
  console.log('Body:', await res.text());
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
