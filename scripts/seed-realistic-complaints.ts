import { Client } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

// Helper to generate coordinates close to a center point
function shiftCoords(lat: number, lng: number) {
    const shiftLat = (Math.random() - 0.5) * 0.0002; // Roughly 10-20 meters
    const shiftLng = (Math.random() - 0.5) * 0.0002;
    return {
        lat: Number((lat + shiftLat).toFixed(6)),
        lng: Number((lng + shiftLng).toFixed(6)),
        distance: Number((5 + Math.random() * 10).toFixed(1)) // 5 to 15 meters
    };
}

async function main() {
    const client = new Client({
        connectionString: process.env.DATABASE_URL
    });

    try {
        await client.connect();
        console.log('⚡ Connected to database. Seeding realistic complaints...');

        // 1. Fetch Panchayats
        const { rows: panchayats } = await client.query('SELECT id, name, center_lat, center_lng FROM panchayats');
        const thayanur = panchayats.find(p => p.name === 'Thayanur');
        const tholampalay = panchayats.find(p => p.name === 'Tholampalay');

        if (!thayanur || !tholampalay) {
            console.error('❌ Thayanur or Tholampalay panchayat is missing! Please make sure seed.js has been run.');
            return;
        }

        console.log(`Found panchayats: Thayanur (ID: ${thayanur.id}), Tholampalay (ID: ${tholampalay.id})`);

        // 2. Fetch Electric Poles
        const { rows: poles } = await client.query('SELECT id, pole_number, latitude, longitude, panchayat_id FROM electric_poles');
        const thayanurPoles = poles.filter(p => p.panchayat_id === thayanur.id);
        const tholampalayPoles = poles.filter(p => p.panchayat_id === tholampalay.id);

        console.log(`Found electric poles: Thayanur (${thayanurPoles.length} poles), Tholampalay (${tholampalayPoles.length} poles)`);

        // 3. Fetch Water Pipelines
        const { rows: pipelines } = await client.query('SELECT id, name FROM water_pipelines WHERE panchayat_id = $1', [thayanur.id]);
        console.log(`Found water pipelines in Thayanur: ${pipelines.length}`);

        // 4. Fetch Water Tanks/Borewells
        const { rows: tanks } = await client.query('SELECT id, name, type, latitude, longitude FROM water_tank_borewells WHERE panchayat_id = $1', [thayanur.id]);
        console.log(`Found water tanks/borewells in Thayanur: ${tanks.length}`);

        // 5. Fetch Users
        const { rows: users } = await client.query('SELECT id, email, role FROM users');
        const electrician = users.find(u => u.role === 'electrician' || u.email.includes('electrician') || u.email.includes('test@gmail.com'));
        const plumber = users.find(u => u.role === 'plumber' || u.email.includes('plumber') || u.email.includes('plumber@gmail.com'));

        console.log(`Staff users: Electrician (ID: ${electrician?.id}), Plumber (ID: ${plumber?.id})`);

        // Clear existing complaints and voice calls first to avoid duplicates
        console.log('🧹 Cleaning existing complaints and voice calls...');
        await client.query('DELETE FROM complaints');
        await client.query('DELETE FROM voice_calls');
        await client.query('DELETE FROM call_state');

        // Voice calls & complaints specifications
        const voiceCalls = [
            // --- THAYANUR LIGHT POLES (Electrician domain) ---
            {
                call_sid: 'CALL-TY-LIGHT-001',
                transcript: 'வணக்கம், மாரியம்மன் கோவில் தெருவில் இருக்கும் கம்பத்தில் நேற்று இரவு முதல் விளக்கு எரியவில்லை. தயவுசெய்து சரிசெய்யவும்.',
                transcript_english: 'Hello, the light on the pole in Mariamman Temple Street has not been working since yesterday night. Please fix it.',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'மாரியம்மன் கோயில்',
                    complaint_type: 'light pole not working',
                    urgency_level: 'medium',
                    caller_emotion: 'calm',
                    caller_language: 'tamil'
                },
                confidence_score: 0.95,
                panchayat_id: thayanur.id,
                pole_key: 'TY-001',
                complaint: {
                    complaint_type: 'light pole not working',
                    description: 'Street light not working since last night near Mariamman Temple. Extremely dark and unsafe.',
                    urgency_level: 'medium',
                    caller_emotion: 'calm',
                    caller_language: 'tamil',
                    status: 'resolved',
                    category: 'electricity',
                    created_offset_days: 28, // days ago
                    assigned_to: electrician?.id,
                    resolution: {
                        note: 'Replaced the fused 40W LED bulb with a new one and cleaned the holder contacts.',
                        image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600',
                        offset_resolved_days: 26 // 2 days later
                    }
                }
            },
            {
                call_sid: 'CALL-TY-LIGHT-002',
                transcript: 'அரசு பள்ளிக்கு பக்கத்தில் இருக்கிற மின்சார கம்பத்திலிருந்து ஒயர்கள் கீழே தொங்குகின்றன. குழந்தைகள் நடமாடும் இடம் என்பதால் ஆபத்தாக உள்ளது. உடனே சரிசெய்ய வேண்டும்.',
                transcript_english: 'Wires are hanging down from the electric pole next to the government school. It is dangerous as children walk around. Please fix it immediately.',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'அரசு பள்ளி',
                    complaint_type: 'wire damage',
                    urgency_level: 'high',
                    caller_emotion: 'concerned',
                    caller_language: 'tamil'
                },
                confidence_score: 0.98,
                panchayat_id: thayanur.id,
                pole_key: 'TY-002',
                complaint: {
                    complaint_type: 'wire damage',
                    description: 'Loose overhead service lines hanging low near the government school boundary wall. Poses serious hazard to kids.',
                    urgency_level: 'high',
                    caller_emotion: 'concerned',
                    caller_language: 'tamil',
                    status: 'resolved',
                    category: 'electricity',
                    created_offset_days: 20,
                    assigned_to: electrician?.id,
                    resolution: {
                        note: 'Tightened and anchored the dangling overhead cables to the school compound wall support hook.',
                        image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600',
                        offset_resolved_days: 19 // 1 day later
                    }
                }
            },
            {
                call_sid: 'CALL-TY-LIGHT-003',
                transcript: 'தண்ணி டேங்க் ரோட்டில் இருக்கும் கம்பத்தில் லைட் எரியாமல் இருட்டாக இருக்கிறது. இரவு நேரத்தில் நடக்க பயமாக உள்ளது.',
                transcript_english: 'The light on the pole in Water Tank Road is not working and it is dark. It is scary to walk at night.',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'தண்ணி டேங்க்',
                    complaint_type: 'light pole not working',
                    urgency_level: 'low',
                    caller_emotion: 'anxious',
                    caller_language: 'tamil'
                },
                confidence_score: 0.92,
                panchayat_id: thayanur.id,
                pole_key: 'TY-005',
                complaint: {
                    complaint_type: 'light pole not working',
                    description: 'Street light near water tank is off. Pedestrians facing difficulty after 7 PM.',
                    urgency_level: 'low',
                    caller_emotion: 'anxious',
                    caller_language: 'tamil',
                    status: 'in_progress',
                    category: 'electricity',
                    created_offset_days: 2,
                    assigned_to: electrician?.id
                }
            },
            {
                call_sid: 'CALL-TY-LIGHT-004',
                transcript: 'ரேஷன் கடை கிட்ட இருக்கிற கம்பத்தில வயரிங்ல தீப்பொறி பறக்குதுங்க. பயமா இருக்கு, சீக்கிரம் யாரையாவது அனுப்பி பாருங்க.',
                transcript_english: 'Sparking observed in the wiring of the pole near the ration shop. We are scared, please send someone quickly.',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'ரேஷன் கடை',
                    complaint_type: 'sparking/fire hazard',
                    urgency_level: 'high',
                    caller_emotion: 'scared',
                    caller_language: 'tamil'
                },
                confidence_score: 0.97,
                panchayat_id: thayanur.id,
                pole_key: 'TY-004',
                complaint: {
                    complaint_type: 'wire damage',
                    description: 'Active sparking on the junctions of pole TY-004 near the ration shop. Urgent attention needed.',
                    urgency_level: 'high',
                    caller_emotion: 'scared',
                    caller_language: 'tamil',
                    status: 'pending',
                    category: 'electricity',
                    created_offset_days: 0 // today
                }
            },

            // --- THOLAMPALAY LIGHT POLES ---
            {
                call_sid: 'CALL-TH-LIGHT-001',
                transcript: 'தோலாம்பாளையம் மாரியம்மன் கோவில் பக்கத்தில் இருக்கும் மின் கம்பத்தில் விளக்கு தொடர்ந்து மின்னி மின்னி எரிகிறது. பல்பை மாற்ற வேண்டும்.',
                transcript_english: 'The light on the electric pole near Tholampalay Mariamman temple is flickering continuously. The bulb needs to be replaced.',
                ai_extracted_json: {
                    village: 'Tholampalay',
                    landmark: 'மாரியம்மன் கோயில்',
                    complaint_type: 'light pole flickering',
                    urgency_level: 'low',
                    caller_emotion: 'calm',
                    caller_language: 'tamil'
                },
                confidence_score: 0.91,
                panchayat_id: tholampalay.id,
                pole_key: 'TH-002',
                complaint: {
                    complaint_type: 'light pole not working',
                    description: 'Sodium vapor lamp flickering constantly near Mariamman Temple in Tholampalay. Disturbs neighbors.',
                    urgency_level: 'low',
                    caller_emotion: 'calm',
                    caller_language: 'tamil',
                    status: 'resolved',
                    category: 'electricity',
                    created_offset_days: 15,
                    resolution: {
                        note: 'Replaced faulty choke coil in the tubelight set on the pole.',
                        image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600',
                        offset_resolved_days: 13
                    }
                }
            },
            {
                call_sid: 'CALL-TH-LIGHT-002',
                transcript: 'டீ கடை பக்கத்துல கம்பத்துல லைட் எரியலங்க. சாயங்காலம் ஆனா ரொம்ப இருட்டா இருக்கு, கடைக்கு வர்றவங்களுக்கு கஷ்டமா இருக்கு.',
                transcript_english: 'The light on the pole near the tea shop is not working. It gets very dark in the evening, making it difficult for customers.',
                ai_extracted_json: {
                    village: 'Tholampalay',
                    landmark: 'டீ கடை',
                    complaint_type: 'light pole not working',
                    urgency_level: 'medium',
                    caller_emotion: 'concerned',
                    caller_language: 'tamil'
                },
                confidence_score: 0.94,
                panchayat_id: tholampalay.id,
                pole_key: 'TH-007',
                complaint: {
                    complaint_type: 'light pole not working',
                    description: 'No street lighting near the local tea stall. High footfall area is dark during night.',
                    urgency_level: 'medium',
                    caller_emotion: 'concerned',
                    caller_language: 'tamil',
                    status: 'pending',
                    category: 'electricity',
                    created_offset_days: 1
                }
            },

            // --- WATER COMPLAINTS (Plumber domain - Thayanur) ---
            {
                call_sid: 'CALL-TY-WATER-001',
                transcript: 'அண்ணூர் ரோடு மெயின் பைப்லைனில் இருந்து தண்ணீர் பெருக்கெடுத்து ஓடுகிறது. பெரிய அளவில் கசிவு ஏற்பட்டு வீணாகிறது.',
                transcript_english: 'Water is gushing out from the Annur Road main pipeline. There is a huge leak and water is being wasted.',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'அண்ணூர் ரோடு',
                    complaint_type: 'pipeline leak',
                    urgency_level: 'high',
                    caller_emotion: 'angry',
                    caller_language: 'tamil'
                },
                confidence_score: 0.96,
                panchayat_id: thayanur.id,
                pipeline_key: 'Annur-Coimbatore Main Trunk',
                complaint: {
                    complaint_type: 'water leak',
                    description: 'Major leak on the 250mm Cast Iron main pipeline on Annur Road. Thousands of liters of water being wasted.',
                    urgency_level: 'high',
                    caller_emotion: 'angry',
                    caller_language: 'tamil',
                    status: 'resolved',
                    category: 'water_supply',
                    created_offset_days: 12,
                    assigned_to: plumber?.id,
                    resolution: {
                        note: 'Excavated the site and installed a leak repair clamp on the pipe joint. Backfilled and leveled.',
                        image_url: 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600',
                        offset_resolved_days: 11 // resolved in 1 day
                    }
                }
            },
            {
                call_sid: 'CALL-TY-WATER-002',
                transcript: 'அண்ணூர் மேல்நிலை நீர்த்தேக்க தொட்டியில் இருந்து மோட்டார் ஓடும் போது தண்ணீர் பக்கவாட்டில் வழிகிறது. வால்வு ஒழுங்காக மூடவில்லை போலிருக்கிறது.',
                transcript_english: 'Water is overflowing from the side of the Annur elevated reservoir when the motor runs. It seems the valve is not closed properly.',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'மேல்நிலை நீர்த்தேக்க தொட்டி',
                    complaint_type: 'tank overflow',
                    urgency_level: 'medium',
                    caller_emotion: 'calm',
                    caller_language: 'tamil'
                },
                confidence_score: 0.93,
                panchayat_id: thayanur.id,
                tank_key: 'Annur Main Elevated Reservoir',
                complaint: {
                    complaint_type: 'tank overflow',
                    description: 'Water overflowing from the overhead reservoir due to valve blockage/malfunction during pumpset run.',
                    urgency_level: 'medium',
                    caller_emotion: 'calm',
                    caller_language: 'tamil',
                    status: 'resolved',
                    category: 'water_supply',
                    created_offset_days: 8,
                    assigned_to: plumber?.id,
                    resolution: {
                        note: 'Cleared plastic debris clogging the inlet control valve float. Verified overflow shutoff.',
                        image_url: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=600',
                        offset_resolved_days: 7
                    }
                }
            },
            {
                call_sid: 'CALL-TY-WATER-003',
                transcript: 'அலங்கால் தெருக்களில் உள்ள குழாய்களில் இன்று காலை சேறும் சகதியுமாக அழுக்கு தண்ணீர் வருகிறது. குடிக்க முடியவில்லை.',
                transcript_english: 'Muddy and dirty water is coming from the taps in Alngkhal streets this morning. We cannot drink it.',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'அலங்கால்',
                    complaint_type: 'dirty water',
                    urgency_level: 'high',
                    caller_emotion: 'angry',
                    caller_language: 'tamil'
                },
                confidence_score: 0.97,
                panchayat_id: thayanur.id,
                pipeline_key: 'Alngkhal Distribution Grid',
                complaint: {
                    complaint_type: 'dirty water',
                    description: 'Turbid muddy water coming out of household connections linked to the Alngkhal distribution grid.',
                    urgency_level: 'high',
                    caller_emotion: 'angry',
                    caller_language: 'tamil',
                    status: 'in_progress',
                    category: 'water_supply',
                    created_offset_days: 1,
                    assigned_to: plumber?.id
                }
            },
            {
                call_sid: 'CALL-TY-WATER-004',
                transcript: 'போர்வெல் பம்ப் மோட்டார் ஓடவில்லை. தண்ணி வரல. மக்கள் கஷ்டப்படுறாங்க. உடனே பாருங்க.',
                transcript_english: 'Borewell pump motor is not running. No water supply. People are suffering. Look into this immediately.',
                ai_extracted_json: {
                    village: 'Thayanur',
                    landmark: 'போர்வெல்',
                    complaint_type: 'borewell pump fault',
                    urgency_level: 'high',
                    caller_emotion: 'angry',
                    caller_language: 'tamil'
                },
                confidence_score: 0.94,
                panchayat_id: thayanur.id,
                tank_key: 'Alngkhal Deep Borewell Pump',
                complaint: {
                    complaint_type: 'pump issue',
                    description: 'Deep borewell pump failure. No water pumping to local households since morning.',
                    urgency_level: 'high',
                    caller_emotion: 'angry',
                    caller_language: 'tamil',
                    status: 'pending',
                    category: 'water_supply',
                    created_offset_days: 0
                }
            }
        ];

        // 6. Additional complaints without calls to enrich the database history (resolved / in-progress)
        const additionalComplaints = [
            {
                panchayat_id: thayanur.id,
                complaint_type: 'light pole not working',
                description: 'Flickering street light near Hospital (TY-009). Creating visibility issues for ambulance entry.',
                urgency_level: 'medium',
                caller_emotion: 'concerned',
                caller_language: 'tamil',
                status: 'resolved',
                category: 'electricity',
                created_offset_days: 25,
                pole_key: 'TY-009',
                assigned_to: electrician?.id,
                resolution: {
                    note: 'Fixed a loose wire connection inside the pole junction box and wrapped with insulated tape.',
                    image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600',
                    offset_resolved_days: 24
                }
            },
            {
                panchayat_id: thayanur.id,
                complaint_type: 'light pole not working',
                description: 'Street light bulb completely broken near Vinayagar Temple (TY-010). Heavy darkness during evening worship.',
                urgency_level: 'low',
                caller_emotion: 'calm',
                caller_language: 'tamil',
                status: 'resolved',
                category: 'electricity',
                created_offset_days: 18,
                pole_key: 'TY-010',
                assigned_to: electrician?.id,
                resolution: {
                    note: 'Installed a new energy-efficient LED lamp and verified its functionality.',
                    image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600',
                    offset_resolved_days: 17
                }
            },
            {
                panchayat_id: thayanur.id,
                complaint_type: 'light pole not working',
                description: 'Pole near Bus Stand (TY-003) is not glowing. High crowd area is very unsafe.',
                urgency_level: 'high',
                caller_emotion: 'concerned',
                caller_language: 'tamil',
                status: 'resolved',
                category: 'electricity',
                created_offset_days: 14,
                pole_key: 'TY-003',
                assigned_to: electrician?.id,
                resolution: {
                    note: 'Replaced damaged cutout fuse at the pole base. Power restored successfully.',
                    image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600',
                    offset_resolved_days: 13
                }
            },
            {
                panchayat_id: thayanur.id,
                complaint_type: 'water leak',
                description: 'Slow leakage on Annur-Tiruppur Secondary Conduit pipeline. Minor dampness spreading near road.',
                urgency_level: 'low',
                caller_emotion: 'calm',
                caller_language: 'english',
                status: 'resolved',
                category: 'water_supply',
                created_offset_days: 10,
                pipeline_key: 'Annur-Tiruppur Secondary Conduit',
                assigned_to: plumber?.id,
                resolution: {
                    note: 'Applied epoxy compound sealant to repair the pinhole leak. Leak stopped.',
                    image_url: 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600',
                    offset_resolved_days: 9
                }
            },
            {
                panchayat_id: tholampalay.id,
                complaint_type: 'light pole not working',
                description: 'Streetlight near School Gate (TH-006) not working. Students returning from special classes find it dark.',
                urgency_level: 'medium',
                caller_emotion: 'concerned',
                caller_language: 'tamil',
                status: 'in_progress',
                category: 'electricity',
                created_offset_days: 3,
                pole_key: 'TH-006'
            },
            {
                panchayat_id: tholampalay.id,
                complaint_type: 'wire damage',
                description: 'Tree branches rubbing against power lines near Church (TH-010). Heavy sparks during winds.',
                urgency_level: 'high',
                caller_emotion: 'scared',
                caller_language: 'tamil',
                status: 'in_progress',
                category: 'electricity',
                created_offset_days: 2,
                pole_key: 'TH-010'
            },
            {
                panchayat_id: tholampalay.id,
                complaint_type: 'light pole not working',
                description: 'Under the banyan tree (TH-003) - street light is not working. Gathering spot is pitch black.',
                urgency_level: 'low',
                caller_emotion: 'calm',
                caller_language: 'tamil',
                status: 'pending',
                category: 'electricity',
                created_offset_days: 1,
                pole_key: 'TH-003'
            },
            {
                panchayat_id: thayanur.id,
                complaint_type: 'water leak',
                description: 'Public tap leaking near Panchayat Office. Tap valve body needs replacing.',
                urgency_level: 'low',
                caller_emotion: 'calm',
                caller_language: 'tamil',
                status: 'pending',
                category: 'water_supply',
                created_offset_days: 0
            }
        ];

        console.log('Inserting voice calls and linked complaints...');

        const now = new Date();

        for (const vc of voiceCalls) {
            // 1. Calculate time
            const createdTime = new Date(now.getTime() - vc.complaint.created_offset_days * 24 * 60 * 60 * 1000);

            // 2. Insert voice call
            const vcRes = await client.query(`
                INSERT INTO voice_calls (call_sid, audio_url, transcript, transcript_english, ai_extracted_json, processing_status, confidence_score, attempt_number, created_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
                RETURNING id
            `, [
                vc.call_sid,
                `https://supabase.co/storage/v1/object/public/calls/${vc.call_sid}.mp3`,
                vc.transcript,
                vc.transcript_english,
                JSON.stringify(vc.ai_extracted_json),
                'completed',
                vc.confidence_score,
                1,
                createdTime
            ]);
            const voiceCallId = vcRes.rows[0].id;

            // 3. Match pole, pipeline or tank
            let poleId = null;
            let pipelineId = null;
            let tankId = null;
            let refLat = 0;
            let refLng = 0;

            if (vc.pole_key) {
                const matchedPole = poles.find(p => p.pole_number === vc.pole_key && p.panchayat_id === vc.panchayat_id);
                if (matchedPole) {
                    poleId = matchedPole.id;
                    refLat = matchedPole.latitude || 11.0168;
                    refLng = matchedPole.longitude || 76.9558;
                }
            } else if (vc.pipeline_key) {
                const matchedPipeline = pipelines.find(p => p.name === vc.pipeline_key);
                if (matchedPipeline) {
                    pipelineId = matchedPipeline.id;
                    refLat = thayanur.center_lat;
                    refLng = thayanur.center_lng;
                }
            } else if (vc.tank_key) {
                const matchedTank = tanks.find(t => t.name === vc.tank_key);
                if (matchedTank) {
                    tankId = matchedTank.id;
                    refLat = matchedTank.latitude;
                    refLng = matchedTank.longitude;
                }
            }

            // 4. Resolve details if resolved
            let assignedAt: Date | null = null;
            let resolvedAt: Date | null = null;
            let resolutionNote: string | null = null;
            let resolutionImageUrl: string | null = null;
            let resolutionLat: number | null = null;
            let resolutionLng: number | null = null;
            let resolutionDistance: number | null = null;
            let resolutionLocationValid: boolean | null = null;
            let resolutionSubmittedKey: string | null = null;

            if (vc.complaint.status === 'resolved' && vc.complaint.resolution) {
                const assignTime = new Date(createdTime.getTime() + 2 * 60 * 60 * 1000); // 2 hours later
                assignedAt = assignTime;

                const resolveTime = new Date(now.getTime() - vc.complaint.resolution.offset_resolved_days * 24 * 60 * 60 * 1000);
                resolvedAt = resolveTime;

                resolutionNote = vc.complaint.resolution.note;
                resolutionImageUrl = vc.complaint.resolution.image_url;

                // Shift coordinates slightly for verification location
                const shifted = shiftCoords(refLat, refLng);
                resolutionLat = shifted.lat;
                resolutionLng = shifted.lng;
                resolutionDistance = shifted.distance;
                resolutionLocationValid = true;
                resolutionSubmittedKey = `key-${vc.call_sid}`;
            } else if (vc.complaint.status === 'in_progress' && vc.complaint.assigned_to) {
                const assignTime = new Date(createdTime.getTime() + 3 * 60 * 60 * 1000);
                assignedAt = assignTime;
            }

            // 5. Insert complaint
            await client.query(`
                INSERT INTO complaints (
                    voice_call_id, pole_id, pipeline_id, tank_id, panchayat_id,
                    complaint_type, description, caller_language, caller_emotion, urgency_level,
                    audio_url, status, created_at, category,
                    assigned_electrician_id, assigned_plumber_id, assigned_at, resolved_at,
                    resolution_image_url, resolution_note, resolution_image_latitude, resolution_image_longitude,
                    resolution_image_captured_at, resolution_distance_meters, resolution_location_valid, resolution_submitted_key
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26)
            `, [
                voiceCallId,
                poleId,
                pipelineId,
                tankId,
                vc.panchayat_id,
                vc.complaint.complaint_type,
                vc.complaint.description,
                vc.complaint.caller_language,
                vc.complaint.caller_emotion,
                vc.complaint.urgency_level,
                `https://supabase.co/storage/v1/object/public/calls/${vc.call_sid}.mp3`,
                vc.complaint.status,
                createdTime,
                vc.complaint.category,
                vc.complaint.category === 'electricity' ? vc.complaint.assigned_to || null : null,
                vc.complaint.category === 'water_supply' ? vc.complaint.assigned_to || null : null,
                assignedAt,
                resolvedAt,
                resolutionImageUrl,
                resolutionNote,
                resolutionLat,
                resolutionLng,
                resolvedAt, // captured at resolution time
                resolutionDistance,
                resolutionLocationValid,
                resolutionSubmittedKey
            ]);

            // 6. Create call state entry
            await client.query(`
                INSERT INTO call_state (call_sid, phase1_status, phase2_status, complaint_created, finalized_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6)
            `, [
                vc.call_sid,
                'completed',
                'completed',
                true,
                createdTime,
                createdTime
            ]);
        }

        console.log('Inserting additional complaints for rich history...');
        for (const ac of additionalComplaints) {
            const createdTime = new Date(now.getTime() - ac.created_offset_days * 24 * 60 * 60 * 1000);

            // Match pole/pipeline
            let poleId = null;
            let pipelineId = null;
            let refLat = 0;
            let refLng = 0;

            if (ac.pole_key) {
                const matchedPole = poles.find(p => p.pole_number === ac.pole_key && p.panchayat_id === ac.panchayat_id);
                if (matchedPole) {
                    poleId = matchedPole.id;
                    refLat = matchedPole.latitude || 11.0168;
                    refLng = matchedPole.longitude || 76.9558;
                }
            } else if (ac.pipeline_key) {
                const matchedPipeline = pipelines.find(p => p.name === ac.pipeline_key);
                if (matchedPipeline) {
                    pipelineId = matchedPipeline.id;
                    refLat = thayanur.center_lat;
                    refLng = thayanur.center_lng;
                }
            } else {
                refLat = panchayats.find(p => p.id === ac.panchayat_id)?.center_lat || 11.0168;
                refLng = panchayats.find(p => p.id === ac.panchayat_id)?.center_lng || 76.9558;
            }

            let assignedAt: Date | null = null;
            let resolvedAt: Date | null = null;
            let resolutionNote: string | null = null;
            let resolutionImageUrl: string | null = null;
            let resolutionLat: number | null = null;
            let resolutionLng: number | null = null;
            let resolutionDistance: number | null = null;
            let resolutionLocationValid: boolean | null = null;
            let resolutionSubmittedKey: string | null = null;

            if (ac.status === 'resolved' && ac.resolution) {
                assignedAt = new Date(createdTime.getTime() + 2 * 60 * 60 * 1000);
                resolvedAt = new Date(now.getTime() - ac.resolution.offset_resolved_days * 24 * 60 * 60 * 1000);
                resolutionNote = ac.resolution.note;
                resolutionImageUrl = ac.resolution.image_url;

                const shifted = shiftCoords(refLat, refLng);
                resolutionLat = shifted.lat;
                resolutionLng = shifted.lng;
                resolutionDistance = shifted.distance;
                resolutionLocationValid = true;
                resolutionSubmittedKey = `key-add-${Math.random().toString(36).substring(7)}`;
            } else if (ac.status === 'in_progress' && ac.assigned_to) {
                assignedAt = new Date(createdTime.getTime() + 3 * 60 * 60 * 1000);
            }

            await client.query(`
                INSERT INTO complaints (
                    pole_id, pipeline_id, panchayat_id,
                    complaint_type, description, caller_language, caller_emotion, urgency_level,
                    status, created_at, category,
                    assigned_electrician_id, assigned_plumber_id, assigned_at, resolved_at,
                    resolution_image_url, resolution_note, resolution_image_latitude, resolution_image_longitude,
                    resolution_image_captured_at, resolution_distance_meters, resolution_location_valid, resolution_submitted_key
                ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23)
            `, [
                poleId,
                pipelineId,
                ac.panchayat_id,
                ac.complaint_type,
                ac.description,
                ac.caller_language,
                ac.caller_emotion,
                ac.urgency_level,
                ac.status,
                createdTime,
                ac.category,
                ac.category === 'electricity' ? ac.assigned_to || null : null,
                ac.category === 'water_supply' ? ac.assigned_to || null : null,
                assignedAt,
                resolvedAt,
                resolutionImageUrl,
                resolutionNote,
                resolutionLat,
                resolutionLng,
                resolvedAt,
                resolutionDistance,
                resolutionLocationValid,
                resolutionSubmittedKey
            ]);
        }

        // 7. Verify counts
        const { rows: voiceCallCount } = await client.query('SELECT count(*) FROM voice_calls');
        const { rows: complaintsCount } = await client.query('SELECT count(*) FROM complaints');
        const { rows: callStateCount } = await client.query('SELECT count(*) FROM call_state');

        console.log('\n🎉 Real-looking seed data successfully inserted!');
        console.log(`- Voice Calls Created: ${voiceCallCount[0].count}`);
        console.log(`- Call States Created: ${callStateCount[0].count}`);
        console.log(`- Complaints Created: ${complaintsCount[0].count}`);

        const { rows: statusDistribution } = await client.query('SELECT status, count(*) FROM complaints GROUP BY status');
        console.log('\nStatus Distribution:');
        for (const dist of statusDistribution) {
            console.log(`  * ${dist.status}: ${dist.count}`);
        }

    } catch (error) {
        console.error('❌ Error seeding realistic complaints:', error);
    } finally {
        await client.end();
    }
}

main();
