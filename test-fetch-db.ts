import { Client } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

async function checkLatestCalls() {
    const client = new Client({
        connectionString: process.env.DATABASE_URL
    });

    try {
        await client.connect();

        console.log('Fetching the latest 3 voice calls from Supabase...\n');

        const { rows: calls } = await client.query(`
            SELECT * FROM voice_calls 
            ORDER BY created_at DESC 
            LIMIT 3
        `);

        for (const call of calls) {
            console.log(`--- Call SID: ${call.call_sid} ---`);
            console.log(`Time       : ${call.created_at}`);
            console.log(`Transcript : ${call.transcript}`);
            console.log(`Extraction :`, call.ai_extracted_json);
            console.log(`Status     : ${call.processing_status}`);
            console.log(`Confidence : ${call.confidence_score}\n`);

            // If it completed, let's see if a complaint was created
            if (call.processing_status === 'completed') {
                const { rows: complaints } = await client.query(`
                    SELECT c.id as complaint_id, c.pole_id, p.pole_number, p.landmarks, pan.name as panchayat_name
                    FROM complaints c
                    LEFT JOIN electric_poles p ON c.pole_id = p.id
                    LEFT JOIN panchayats pan ON c.panchayat_id = pan.id
                    WHERE c.description LIKE $1
                    LIMIT 1
                `, [`%${call.call_sid}%`]);

                if (complaints.length > 0) {
                    const complaint = complaints[0];
                    console.log(`>> Created Complaint #${complaint.complaint_id} for Pole: ${complaint.pole_number}`);
                    console.log(`>> Pole Landmarks :`, complaint.landmarks);
                    console.log(`>> Panchayat      : ${complaint.panchayat_name}\n`);
                }
            }
        }

    } catch (error) {
        console.error('Error fetching data:', error);
    } finally {
        await client.end();
    }
}

checkLatestCalls();
