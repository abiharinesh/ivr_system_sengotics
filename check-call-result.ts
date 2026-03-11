import 'dotenv/config'
import { Client } from 'pg'

async function run() {
    const callSid = process.argv[2]
    if (!callSid) {
        console.error('Usage: npx ts-node check-call-result.ts <CallSid>')
        process.exit(1)
    }

    const client = new Client({ connectionString: process.env.DATABASE_URL })
    await client.connect()

    try {
        const attempts = await client.query(
            `SELECT id, call_sid, audio_url, attempt_number, processing_status, transcript, transcript_english, ai_extracted_json, confidence_score, created_at
             FROM voice_calls
             WHERE call_sid = $1
             ORDER BY attempt_number ASC, created_at ASC`,
            [callSid]
        )

        const complaints = await client.query(
            `SELECT c.id, c.voice_call_id, c.status, c.complaint_type, c.description, c.created_at
             FROM complaints c
             JOIN voice_calls v ON v.id = c.voice_call_id
             WHERE v.call_sid = $1
             ORDER BY c.created_at DESC`,
            [callSid]
        )

        console.log(`CallSid: ${callSid}`)
        console.log('Attempts:')
        console.log(JSON.stringify(attempts.rows, null, 2))
        console.log('Complaints:')
        console.log(JSON.stringify(complaints.rows, null, 2))

        const recentComplaints = await client.query(
            `SELECT id, pole_id, panchayat_id, status, created_at, description
             FROM complaints
             WHERE created_at > NOW() - INTERVAL '24 hours'
             ORDER BY created_at DESC
             LIMIT 30`
        )
        console.log('Recent complaints (24h):')
        console.log(JSON.stringify(recentComplaints.rows, null, 2))
    } finally {
        await client.end()
    }
}

run().catch((err) => {
    console.error(err)
    process.exit(1)
})
