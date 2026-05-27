#!/usr/bin/env node
/* eslint-disable */
require('dotenv').config();
const { Client } = require('pg');

(async () => {
  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();
  try {
    const tendersRes = await client.query(`
      SELECT id, status, quotation_access_mode, public_token
      FROM tenders ORDER BY id DESC LIMIT 5
    `);
    console.log('--- Recent tenders ---');
    console.table(tendersRes.rows.map((r) => ({
      ...r,
      public_token: r.public_token ? r.public_token.slice(0, 12) + '…' : null,
    })));

    const invitesRes = await client.query(`
      SELECT i.id, i.tender_id, i.vendor_id, v.name AS vendor_name,
             i.invite_token IS NOT NULL AS has_token,
             LEFT(i.invite_token, 12) AS token_preview,
             i.invite_revoked_at, i.invite_opened_at, i.invite_submitted_at
      FROM tender_vendor_invites i
      JOIN vendors v ON v.id = i.vendor_id
      ORDER BY i.id DESC LIMIT 20
    `);
    console.log('--- Recent invites ---');
    console.table(invitesRes.rows);
  } finally {
    await client.end();
  }
})().catch((err) => {
  console.error('check-invites error:', err);
  process.exit(1);
});
