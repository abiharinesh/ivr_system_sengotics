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

    const payload = {
        CallSid: callSid,
        CallFrom: '+919876543210',
        CallTo: ivrNumber,
        RecordingUrl: 'https://recordings.exotel.com/exotelrecordings/nexerawe1/1773159742.4564145_0.mp3',
        ProcessStatus: 'ready'
    }

    // ── ATTEMPT 1 ──────────────────────────────────────────────
    console.log('\n--- ATTEMPT 1 ---')
    console.time('Attempt 1 Duration')
    try {
        const res1 = await fetch(`${BASE_URL}/api/ivr/voice-complaint`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        })
        console.timeEnd('Attempt 1 Duration')
        console.log(`Status: ${res1.status}`)
        console.log(`Body: ${await res1.text()}`)

        await new Promise(r => setTimeout(r, 2000))
        const voiceCall1 = await prisma.voiceCall.findFirst({ where: { call_sid: callSid }, orderBy: { created_at: 'desc' } })
        console.log(`DB attempt_number: ${voiceCall1?.attempt_number}, status: ${voiceCall1?.processing_status}`)

        if (res1.status === 404) {
            // ── ATTEMPT 2 (Simulating Retry) ─────────────────────────
            console.log('\n--- ATTEMPT 2 ---')
            console.time('Attempt 2 Duration')
            const res2 = await fetch(`${BASE_URL}/api/ivr/voice-complaint`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            })
            console.timeEnd('Attempt 2 Duration')
            console.log(`Status: ${res2.status}`)
            console.log(`Body: ${await res2.text()}`)

            console.log('Waiting 15 seconds to allow background Phase 2 to complete...')
            await new Promise(r => setTimeout(r, 15000))
            const voiceCall2 = await prisma.voiceCall.findFirst({ where: { call_sid: callSid }, orderBy: { created_at: 'desc' } })
            console.log(`DB attempt_number: ${voiceCall2?.attempt_number}, status: ${voiceCall2?.processing_status}`)
        }

        const complaint = await prisma.complaint.findFirst({ where: { voice_call_id: voiceCall1?.id }, include: { pole: true } })

        console.log('\n--- LATEST COMPLAINT ---')
        console.log(complaint)
        console.log(`\nMatched Pole: ${complaint?.pole?.pole_number ?? 'None'}`)
    } catch (e: any) {
        console.error('Fetch failed. Is the NestJS server running on port 3000?', e.message)
    }

    await prisma.$disconnect()
    await pool.end()
}

run().catch(console.error)
