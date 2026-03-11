import 'dotenv/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const BASE_URL = 'http://localhost:3000'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function run() {
    const ivrNumber = '04440115434' // User requested IVR

    // Find the panchayat for this IVR number
    const panchayat = await prisma.panchayat.findFirst({ where: { ivr_number: ivrNumber } })

    if (!panchayat) {
        console.log(`No panchayat found for IVR number: ${ivrNumber}. Exiting.`)
        process.exit(1)
    }

    const callSid = `TEST-VOICE-IVR-${Date.now()}`

    console.log(`Sending webhook for village: ${panchayat.name} (IVR: ${ivrNumber})`)

    const payloadAttempt1 = {
        CallSid: callSid,
        CallFrom: '+919876543210',
        CallTo: ivrNumber,
        RecordingUrl: 'https://recordings.exotel.com/exotelrecordings/nexerawe1/1773159742.4564145_0.mp3',
        ProcessStatus: 'ready'
    }

    const payloadAttempt2 = {
        ...payloadAttempt1,
        RecordingUrl: 'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772744617.3352439_0.mp3'
    }

    // ── ATTEMPT 1 ──────────────────────────────────────────────
    console.log('\n--- ATTEMPT 1 ---')
    console.time('Attempt 1 Duration')
    try {
        const res1 = await fetch(`${BASE_URL}/api/ivr/voice-complaint`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payloadAttempt1)
        })
        console.timeEnd('Attempt 1 Duration')
        console.log(`Status: ${res1.status}`)
        console.log(`Body: ${await res1.text()}`)

        await new Promise(r => setTimeout(r, 2000))
        const firstRows = await prisma.voiceCall.findMany({
            where: { call_sid: callSid },
            orderBy: { created_at: 'asc' }
        })
        const latestAfterFirst = firstRows.length ? firstRows[firstRows.length - 1] : null
        console.log(`Voice rows after attempt 1: ${firstRows.length}`)
        console.log(`Latest row attempt_number: ${latestAfterFirst?.attempt_number}, status: ${latestAfterFirst?.processing_status}`)

        // ── DUPLICATE REPLAY: same CallSid + same RecordingUrl ──────────
        console.log('\n--- DUPLICATE CALLBACK (SAME URL) ---')
        const duplicateRes = await fetch(`${BASE_URL}/api/ivr/voice-complaint`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payloadAttempt1)
        })
        console.log(`Duplicate status: ${duplicateRes.status}`)
        console.log(`Duplicate body: ${await duplicateRes.text()}`)

        await new Promise(r => setTimeout(r, 2000))
        const rowsAfterDuplicate = await prisma.voiceCall.findMany({
            where: { call_sid: callSid },
            orderBy: { created_at: 'asc' }
        })
        console.log(`Voice rows after duplicate: ${rowsAfterDuplicate.length} (should stay same as after attempt 1)`)

        if (res1.status === 404) {
            // ── ATTEMPT 2 (Simulating Retry) ─────────────────────────
            console.log('\n--- ATTEMPT 2 ---')
            console.time('Attempt 2 Duration')
            const res2 = await fetch(`${BASE_URL}/api/ivr/voice-complaint`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payloadAttempt2)
            })
            console.timeEnd('Attempt 2 Duration')
            console.log(`Status: ${res2.status}`)
            console.log(`Body: ${await res2.text()}`)

            console.log('Waiting 15 seconds to allow background Phase 2 to complete...')
            await new Promise(r => setTimeout(r, 15000))
            const voiceRows = await prisma.voiceCall.findMany({
                where: { call_sid: callSid },
                orderBy: { attempt_number: 'asc' }
            })
            console.log(`Voice rows after attempt 2: ${voiceRows.length}`)
            console.log('Attempt numbers:', voiceRows.map(v => v.attempt_number))
        }

        const finalVoiceRows = await prisma.voiceCall.findMany({
            where: { call_sid: callSid },
            orderBy: { created_at: 'asc' }
        })
        const complaint = await prisma.complaint.findFirst({
            where: {
                voice_call: { is: { call_sid: callSid } }
            },
            include: { pole: true }
        })

        console.log('\n--- LATEST COMPLAINT ---')
        console.log(complaint)
        console.log(`\nMatched Pole: ${complaint?.pole?.pole_number ?? 'None'}`)
        console.log(`Final voice row count for CallSid: ${finalVoiceRows.length}`)
    } catch (e: any) {
        console.error('Fetch failed. Is the NestJS server running on port 3000?', e.message)
    }

    await prisma.$disconnect()
    await pool.end()
}

run().catch(console.error)
