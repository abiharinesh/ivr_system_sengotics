/**
 * IVR End-to-End Local Test Script
 * Run: npx ts-node test-ivr.ts
 *
 * Tests:
 *  1. Show all panchayats + their IVR numbers
 *  2. Show all electric poles + keypad_ids
 *  3. Simulate EP1 → service selection (street light = "1")
 *  4. Simulate EP2 → pole number entry
 *  5. Verify complaint was created in DB
 */

import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const BASE_URL = 'http://localhost:3000'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function run() {
    console.log('\n══════════════════════════════════════════════')
    console.log('  IVR LOCAL TEST')
    console.log('══════════════════════════════════════════════\n')

    // ── 1. Show Panchayats ────────────────────────────────────────────────────
    console.log('📋 PANCHAYATS IN DB:')
    const panchayats = await prisma.panchayat.findMany()
    if (panchayats.length === 0) {
        console.log('  ❌ No panchayats found! Please seed the DB first.')
        process.exit(1)
    }
    panchayats.forEach(p => console.log(`  [${p.id}] ${p.name} — IVR: ${p.ivr_number ?? '⚠️  NO IVR NUMBER'}`))

    const testPanchayat = panchayats.find(p => p.ivr_number) ?? panchayats[0]
    console.log(`\n  ✅ Using panchayat: "${testPanchayat.name}" (IVR: ${testPanchayat.ivr_number})`)

    // ── 2. Show Electric Poles ────────────────────────────────────────────────
    console.log('\n📋 ELECTRIC POLES IN DB:')
    const poles = await prisma.electricPole.findMany({ where: { panchayat_id: testPanchayat.id } })
    if (poles.length === 0) {
        console.log('  ❌ No poles found for this panchayat! Please seed poles.')
        process.exit(1)
    }
    poles.forEach(p => console.log(`  [${p.id}] Pole: ${p.pole_number} — keypad_id: ${p.keypad_id ?? '⚠️  NONE'}`))

    const testPole = poles.find(p => p.keypad_id) ?? poles[0]
    console.log(`\n  ✅ Using pole: ${testPole.pole_number} (keypad_id: "${testPole.keypad_id}")`)

    const callSid = `TEST-${Date.now()}`
    const ivrNumber = testPanchayat.ivr_number ?? '0000000000'
    const callerNumber = '+919876543210'

    // ── 3. EP1 — Service Selection (press "1" for street light) ───────────────
    console.log('\n──────────────────────────────────────────────')
    console.log('📞 EP1: User presses "1" (street light)')
    console.log(`   CallSid: ${callSid}`)
    console.log(`   CallTo:  ${ivrNumber}`)

    const ep1Res = await fetch(`${BASE_URL}/api/ivr/service`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            CallSid: callSid,
            CallFrom: callerNumber,
            CallTo: ivrNumber,
            digits: '1',
        })
    })
    const ep1Body = await ep1Res.text()
    console.log(`   Response [${ep1Res.status}]: ${ep1Body.slice(0, 80)}`)
    console.log(ep1Res.ok ? '   ✅ EP1 OK' : '   ❌ EP1 FAILED')

    // ── 4. EP2 — Poll Input (user enters pole keypad_id) ─────────────────────
    console.log('\n──────────────────────────────────────────────')
    console.log(`📞 EP2: User enters pole keypad_id "${testPole.keypad_id}"`)

    const ep2Res = await fetch(`${BASE_URL}/api/ivr/poll`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            CallSid: callSid,
            CallFrom: callerNumber,
            CallTo: ivrNumber,
            digits: testPole.keypad_id,
        })
    })
    const ep2Body = await ep2Res.text()
    console.log(`   Response [${ep2Res.status}]: ${ep2Body.slice(0, 80)}`)
    console.log(ep2Res.ok ? '   ✅ EP2 OK' : '   ❌ EP2 FAILED')

    // ── 5. Verify Complaint was Created ──────────────────────────────────────
    console.log('\n──────────────────────────────────────────────')
    console.log('🔍 VERIFYING COMPLAINT IN DB...')

    await new Promise(r => setTimeout(r, 500)) // small wait for async writes

    const complaint = await prisma.complaint.findFirst({
        where: { panchayat_id: testPanchayat.id },
        orderBy: { created_at: 'desc' },
        include: { pole: true }
    })

    if (!complaint) {
        console.log('  ❌ No complaint found in DB!')
    } else {
        console.log(`  ✅ Complaint created!`)
        console.log(`     ID:     #${complaint.id}`)
        console.log(`     Type:   ${complaint.complaint_type}`)
        console.log(`     Status: ${complaint.status}`)
        console.log(`     Pole:   ${complaint.pole?.pole_number ?? 'none (unlinked)'}`)
        console.log(`     Desc:   ${complaint.description}`)
    }

    // ── Also test water service ───────────────────────────────────────────────
    console.log('\n──────────────────────────────────────────────')
    console.log('💧 BONUS: Testing water service (digit "2")')
    const callSid2 = `TEST-WATER-${Date.now()}`

    await fetch(`${BASE_URL}/api/ivr/service`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ CallSid: callSid2, CallFrom: callerNumber, CallTo: ivrNumber, digits: '2' })
    })

    await fetch(`${BASE_URL}/api/ivr/poll`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ CallSid: callSid2, CallFrom: callerNumber, CallTo: ivrNumber, digits: '5' })
    })

    const waterComplaint = await prisma.complaint.findFirst({
        where: { panchayat_id: testPanchayat.id, complaint_type: 'water' },
        orderBy: { created_at: 'desc' }
    })

    console.log(waterComplaint
        ? `  ✅ Water complaint #${waterComplaint.id} created`
        : '  ❌ Water complaint NOT created')

    console.log('\n══════════════════════════════════════════════')
    console.log('  TEST COMPLETE')
    console.log('══════════════════════════════════════════════\n')

    await prisma.$disconnect()
    await pool.end()
}

run().catch(async (e) => {
    console.error('❌ Test error:', e.message)
    await prisma.$disconnect()
    await pool.end()
    process.exit(1)
})
