import { Client } from 'pg';
import * as dotenv from 'dotenv';
import * as bcrypt from 'bcrypt';
import { randomUUID } from 'crypto';

dotenv.config();

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
        console.log('🌱 Connected to database. Starting master demo seeding...');

        // 1. Truncate all tables
        console.log('🧹 Clearing all existing data...');
        await client.query(`
            TRUNCATE 
              complaints, 
              electric_poles, 
              voice_calls, 
              ivr_poll_input, 
              ivr_service_selection, 
              calls_master, 
              panchayat_zones,
              panchayats, 
              users, 
              system_settings, 
              call_state, 
              export_jobs, 
              vendors, 
              tenders, 
              tender_vendor_invites, 
              tender_line_items, 
              tender_quotations, 
              tender_documents, 
              field_verification_sessions, 
              field_verification_uploads, 
              tender_field_checklist_items, 
              tender_audit_logs, 
              water_pipelines, 
              water_tank_borewells, 
              water_valves, 
              water_flow_logs, 
              captured_assets 
            CASCADE;
        `);

        // 2. System Settings
        console.log('⚙️ Seeding system settings...');
        await client.query(`
            INSERT INTO system_settings (key, value, updated_at)
            VALUES ('ai_provider', 'gemini', NOW());
        `);

        // 3. Panchayats
        console.log('🏘️ Seeding panchayats...');
        const thayanurRes = await client.query(`
            INSERT INTO panchayats (name, center_lat, center_lng, ivr_number)
            VALUES ('Thayanur', 11.0168, 76.9558, '04440115043')
            RETURNING id;
        `);
        const thayanurId = thayanurRes.rows[0].id;

        const tholampalayRes = await client.query(`
            INSERT INTO panchayats (name, center_lat, center_lng, ivr_number)
            VALUES ('Tholampalay', 11.2420, 76.9520, '04440115434')
            RETURNING id;
        `);
        const tholampalayId = tholampalayRes.rows[0].id;

        const vadavalliRes = await client.query(`
            INSERT INTO panchayats (name, center_lat, center_lng, ivr_number)
            VALUES ('Vadavalli', 11.0234, 76.9012, '04442123457')
            RETURNING id;
        `);
        const vadavalliId = vadavalliRes.rows[0].id;

        console.log(`... Created 3 Panchayats (Thayanur: ${thayanurId}, Tholampalay: ${tholampalayId}, Vadavalli: ${vadavalliId})`);

        // 4. Panchayat Zones
        console.log('🗺️ Seeding panchayat zones...');
        const zoneThayanurA = {
            type: 'Polygon',
            coordinates: [[[76.9500, 11.0100], [76.9600, 11.0100], [76.9600, 11.0200], [76.9500, 11.0200], [76.9500, 11.0100]]]
        };
        const zoneThayanurB = {
            type: 'Polygon',
            coordinates: [[[76.9600, 11.0100], [76.9700, 11.0100], [76.9700, 11.0200], [76.9600, 11.0200], [76.9600, 11.0100]]]
        };
        const zoneTholampalayA = {
            type: 'Polygon',
            coordinates: [[[76.9450, 11.2380], [76.9580, 11.2380], [76.9580, 11.2480], [76.9450, 11.2480], [76.9450, 11.2380]]]
        };

        await client.query(`
            INSERT INTO panchayat_zones (panchayat_id, name, boundary_geojson, color, opacity, places, is_active, created_at, updated_at)
            VALUES 
              ($1, 'Ward 1 North', $2, '#3B82F6', 0.3, ARRAY['Mariamman Temple Street', 'Bus Stand Area'], true, NOW(), NOW()),
              ($1, 'Ward 2 South', $3, '#10B981', 0.3, ARRAY['Ration Shop Colony', 'Hospital Block'], true, NOW(), NOW()),
              ($4, 'Main Temple Zone', $5, '#F59E0B', 0.3, ARRAY['Main Road', 'Pond Side'], true, NOW(), NOW())
        `, [thayanurId, JSON.stringify(zoneThayanurA), JSON.stringify(zoneThayanurB), tholampalayId, JSON.stringify(zoneTholampalayA)]);

        // 5. Users
        console.log('👤 Seeding users...');
        const passwordHash = await bcrypt.hash('Admin@1234', 10);

        // Super Admin
        await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('superadmin@sengotics.com', $1, 'super_admin', NULL, '+919999999999', NOW());
        `, [passwordHash]);

        // Thayanur Users
        const tAdminRes = await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('admin@thayanur.com', $1, 'panchayat_admin', $2, '+919876543001', NOW()) RETURNING id;
        `, [passwordHash, thayanurId]);
        const thayanurAdminId = tAdminRes.rows[0].id;

        const tElectricianRes = await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('electrician@thayanur.com', $1, 'electrician', $2, '+919876543210', NOW()) RETURNING id;
        `, [passwordHash, thayanurId]);
        const thayanurElectricianId = tElectricianRes.rows[0].id;

        const tPlumberRes = await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('plumber@thayanur.com', $1, 'plumber', $2, '+919876543211', NOW()) RETURNING id;
        `, [passwordHash, thayanurId]);
        const thayanurPlumberId = tPlumberRes.rows[0].id;

        await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('agent@thayanur.com', $1, 'agent', $2, '+919876543214', NOW());
        `, [passwordHash, thayanurId]);

        // Tholampalay Users
        const thAdminRes = await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('admin@tholampalay.com', $1, 'panchayat_admin', $2, '+919876543002', NOW()) RETURNING id;
        `, [passwordHash, tholampalayId]);
        const tholampalayAdminId = thAdminRes.rows[0].id;

        const thElectricianRes = await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('electrician@tholampalay.com', $1, 'electrician', $2, '+919876543212', NOW()) RETURNING id;
        `, [passwordHash, tholampalayId]);
        const tholampalayElectricianId = thElectricianRes.rows[0].id;

        const thPlumberRes = await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('plumber@tholampalay.com', $1, 'plumber', $2, '+919876543213', NOW()) RETURNING id;
        `, [passwordHash, tholampalayId]);
        const tholampalayPlumberId = thPlumberRes.rows[0].id;

        await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('agent@tholampalay.com', $1, 'agent', $2, '+919876543215', NOW());
        `, [passwordHash, tholampalayId]);

        // Vadavalli Admin
        await client.query(`
            INSERT INTO users (email, password_hash, role, panchayat_id, phone_e164, created_at)
            VALUES ('admin@vadavalli.com', $1, 'panchayat_admin', $2, '+919876543003', NOW());
        `, [passwordHash, vadavalliId]);

        console.log('✅ Created users: superadmin, admin, electrician, plumber, and agent for both panchayats.');

        // 6. Electric Poles
        console.log('🔌 Seeding electric poles...');
        const polesData = [
            // Thayanur Poles
            { pole_number: 'TY-001', keypad_id: '1', lat: 11.0170, lng: 76.9560, panchayat_id: thayanurId, landmarks: ['மாரியம்மன் கோயில் பக்கத்துல', 'Mariamman kovil kitta', 'near Mariamman temple'] },
            { pole_number: 'TY-002', keypad_id: '2', lat: 11.0165, lng: 76.9555, panchayat_id: thayanurId, landmarks: ['அரசு பள்ளி பக்கத்துல', 'school kitta', 'near government school'] },
            { pole_number: 'TY-003', keypad_id: '3', lat: 11.0172, lng: 76.9562, panchayat_id: thayanurId, landmarks: ['பஸ் ஸ்டாண்ட் பக்கத்துல', 'bus stop kitta', 'near bus stand'] },
            { pole_number: 'TY-004', keypad_id: '4', lat: 11.0175, lng: 76.9565, panchayat_id: thayanurId, landmarks: ['ரேஷன் கடை பக்கத்துல', 'ration shop pakkam', 'near ration shop'] },
            { pole_number: 'TY-005', keypad_id: '5', lat: 11.0160, lng: 76.9550, panchayat_id: thayanurId, landmarks: ['தண்ணி டேங்க் பக்கத்துல', 'water tank kitta', 'near water tank'] },
            { pole_number: 'TY-006', keypad_id: '6', lat: 11.0178, lng: 76.9568, panchayat_id: thayanurId, landmarks: ['பெட்ரோல் பங்க் பக்கத்துல', 'petrol bunk kitta', 'near petrol bunk'] },
            { pole_number: 'TY-007', keypad_id: '7', lat: 11.0162, lng: 76.9552, panchayat_id: thayanurId, landmarks: ['ஆலமரம் கீழ', 'banyan tree pakkam', 'under the banyan tree'] },
            { pole_number: 'TY-008', keypad_id: '8', lat: 11.0168, lng: 76.9558, panchayat_id: thayanurId, landmarks: ['பஞ்சாயத்து ஆபிஸ் பக்கத்துல', 'panchayat office kitta', 'near panchayat office'] },
            { pole_number: 'TY-009', keypad_id: '9', lat: 11.0182, lng: 76.9572, panchayat_id: thayanurId, landmarks: ['ஆஸ்பத்திரி பக்கத்துல', 'hospital pakkam', 'near hospital'] },
            { pole_number: 'TY-010', keypad_id: '10', lat: 11.0155, lng: 76.9545, panchayat_id: thayanurId, landmarks: ['விநாயகர் கோயில் பக்கத்துல', 'Vinayagar temple pakkam', 'near Pillaiyar temple'] },

            // Tholampalay Poles
            { pole_number: 'TH-001', keypad_id: '1', lat: 11.2425, lng: 76.9525, panchayat_id: tholampalayId, landmarks: ['மெயின் ரோடு ஜங்ஷன் பக்கத்துல', 'main road kitta', 'near main road junction'] },
            { pole_number: 'TH-002', keypad_id: '2', lat: 11.2418, lng: 76.9518, panchayat_id: tholampalayId, landmarks: ['மாரியம்மன் கோயில் பக்கத்துல', 'temple pakkam', 'near Mariamman temple'] },
            { pole_number: 'TH-003', keypad_id: '3', lat: 11.2430, lng: 76.9530, panchayat_id: tholampalayId, landmarks: ['ஆலமரம் கீழ', 'banyan tree keezha', 'under the banyan tree'] },
            { pole_number: 'TH-004', keypad_id: '4', lat: 11.2412, lng: 76.9512, panchayat_id: tholampalayId, landmarks: ['குளம் பக்கத்துல', 'pond pakkam', 'near the pond'] },
            { pole_number: 'TH-005', keypad_id: '5', lat: 11.2435, lng: 76.9535, panchayat_id: tholampalayId, landmarks: ['ரேஷன் கடை பக்கத்துல', 'ration shop pakkam', 'near ration shop'] },
            { pole_number: 'TH-006', keypad_id: '6', lat: 11.2408, lng: 76.9508, panchayat_id: tholampalayId, landmarks: ['ஸ்கூல் கேட் பக்கத்துல', 'school kitta', 'near school gate'] },
            { pole_number: 'TH-007', keypad_id: '7', lat: 11.2440, lng: 76.9540, panchayat_id: tholampalayId, landmarks: ['டீ கடை பக்கத்துல', 'tea shop pakkam', 'near the tea shop'] },
            { pole_number: 'TH-008', keypad_id: '8', lat: 11.2402, lng: 76.9502, panchayat_id: tholampalayId, landmarks: ['பஞ்சாயத்து ஆபிஸ் பக்கத்துல', 'panchayat office pakkam', 'near panchayat office'] },
            { pole_number: 'TH-009', keypad_id: '9', lat: 11.2445, lng: 76.9545, panchayat_id: tholampalayId, landmarks: ['மசூதி பக்கத்துல', 'mosque pakkam', 'near the mosque'] },
            { pole_number: 'TH-010', keypad_id: '10', lat: 11.2398, lng: 76.9498, panchayat_id: tholampalayId, landmarks: ['சர்ச் பக்கத்துல', 'church pakkam', 'near the church'] }
        ];

        for (const p of polesData) {
            const token = randomUUID();
            await client.query(`
                INSERT INTO electric_poles (pole_number, keypad_id, latitude, longitude, location, panchayat_id, landmarks, public_report_token)
                VALUES ($1, $2, $3, $4, ST_SetSRID(ST_MakePoint($4, $3), 4326), $5, $6, $7);
            `, [p.pole_number, p.keypad_id, p.lat, p.lng, p.panchayat_id, p.landmarks, token]);
        }

        // Fetch back poles with their IDs for later mapping
        const { rows: dbPoles } = await client.query('SELECT id, pole_number, latitude, longitude, panchayat_id FROM electric_poles');
        console.log(`... Created ${dbPoles.length} electric poles (10 in Thayanur, 10 in Tholampalay).`);

        // 7. Water Supply Infrastructure (Thayanur & Tholampalay)
        console.log('💧 Seeding water supply infrastructure...');
        
        // Pipelines
        const pipeline1Path = { type: 'LineString', coordinates: [[76.9616, 11.0168], [77.0123, 11.0850], [77.0984, 11.1678], [77.1025, 11.2341]] };
        const pipeline2Path = { type: 'LineString', coordinates: [[77.1025, 11.2341], [77.1892, 11.1890], [77.2504, 11.1542], [77.3411, 11.1085]] };
        const pipeline3Path = { type: 'LineString', coordinates: [[77.1025, 11.2341], [77.0911, 11.1524], [77.1232, 11.0921]] };
        const pipelineTholampalayPath = { type: 'LineString', coordinates: [[76.9520, 11.2420], [76.9530, 11.2450], [76.9550, 11.2480]] };

        const p1Res = await client.query(
            `INSERT INTO water_pipelines (name, panchayat_id, diameter_mm, material, status, path_geojson, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING id`,
            ['Annur-Coimbatore Main Trunk', thayanurId, 250.0, 'Cast Iron', 'leak_alert', JSON.stringify(pipeline1Path)]
        );
        const pipeline1Id = p1Res.rows[0].id;

        const p2Res = await client.query(
            `INSERT INTO water_pipelines (name, panchayat_id, diameter_mm, material, status, path_geojson, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING id`,
            ['Annur-Tiruppur Secondary Conduit', thayanurId, 160.0, 'HDPE', 'active', JSON.stringify(pipeline2Path)]
        );
        const pipeline2Id = p2Res.rows[0].id;

        await client.query(
            `INSERT INTO water_pipelines (name, panchayat_id, diameter_mm, material, status, path_geojson, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
            ['Alngkhal Distribution Grid', thayanurId, 110.0, 'PVC', 'active', JSON.stringify(pipeline3Path)]
        );

        await client.query(
            `INSERT INTO water_pipelines (name, panchayat_id, diameter_mm, material, status, path_geojson, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
            ['Tholampalay Central Pipe', tholampalayId, 150.0, 'PVC', 'active', JSON.stringify(pipelineTholampalayPath)]
        );

        // Tanks & Borewells
        const wt1Res = await client.query(
            `INSERT INTO water_tank_borewells (name, type, latitude, longitude, panchayat_id, capacity_liters, current_level_pct, status, pump_status, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW()) RETURNING id`,
            ['Annur Main Elevated Reservoir', 'overhead_tank', 11.2341, 77.1025, thayanurId, 500000.0, 82.5, 'active', 'on']
        );
        const tank1Id = wt1Res.rows[0].id;

        await client.query(
            `INSERT INTO water_tank_borewells (name, type, latitude, longitude, panchayat_id, capacity_liters, current_level_pct, status, pump_status, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
            ['Coimbatore Central Reservoirs', 'overhead_tank', 11.0168, 76.9616, thayanurId, 1200000.0, 100.0, 'active', 'off']
        );

        await client.query(
            `INSERT INTO water_tank_borewells (name, type, latitude, longitude, panchayat_id, capacity_liters, current_level_pct, status, pump_status, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
            ['Alngkhal Deep Borewell Pump', 'borewell_pump', 11.0921, 77.1232, thayanurId, 0.0, 0.0, 'active', 'on']
        );

        await client.query(
            `INSERT INTO water_tank_borewells (name, type, latitude, longitude, panchayat_id, capacity_liters, current_level_pct, status, pump_status, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
            ['Tholampalay Main Elevated Reservoir', 'overhead_tank', 11.2420, 76.9520, tholampalayId, 300000.0, 75.0, 'active', 'off']
        );

        // Valves
        await client.query(
            `INSERT INTO water_valves (valve_number, latitude, longitude, panchayat_id, status, updated_at)
             VALUES 
             ('V-AN-01', 11.1678, 77.0984, $1, 'open', NOW()),
             ('V-CO-12', 11.0850, 77.0123, $1, 'open', NOW()),
             ('V-TP-04', 11.1890, 77.1892, $1, 'closed', NOW()),
             ('V-TH-01', 11.2425, 76.9525, $2, 'open', NOW())`,
            [thayanurId, tholampalayId]
        );

        // Flow Logs (Historical)
        const now = new Date();
        for (let i = 0; i < 24; i++) {
            const loggedAt = new Date(now.getTime() - i * 60 * 60 * 1000);
            const isPeak = loggedAt.getHours() >= 7 && loggedAt.getHours() <= 10;
            const flowRate = isPeak ? 22.4 : 14.8;
            const pressure = isPeak ? 1.8 : 2.6;

            await client.query(
                `INSERT INTO water_flow_logs (pipeline_id, flow_rate_lps, pressure_bar, logged_at)
                 VALUES ($1, $2, $3, $4)`,
                [pipeline1Id, flowRate, pressure, loggedAt]
            );

            await client.query(
                `INSERT INTO water_flow_logs (tank_id, flow_rate_lps, pressure_bar, logged_at)
                 VALUES ($1, $2, $3, $4)`,
                [tank1Id, flowRate * 0.8, pressure * 0.9, loggedAt]
            );
        }

        // Captured Assets
        await client.query(
            `INSERT INTO captured_assets (type, material, diameter_mm, latitude, longitude, photo_url, status, agent_name, device_model, altitude, precision, submitted_at, updated_at)
             VALUES 
             ('public_tap', 'PVC', 50.0, 11.2356, 77.1042, 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600', 'pending_approval', 'Ramanathan K.', 'Samsung Galaxy Tab Active 3', 12.4, 0.4, NOW() - INTERVAL '4 hours', NOW()),
             ('main_pipeline', 'HDPE', 110.0, 11.2389, 77.1085, 'https://images.unsplash.com/photo-1542060748-10c28b629f6f?w=600', 'pending_approval', 'Muthu Swamy', 'Nokia XR20 Rugged', 14.1, 0.6, NOW() - INTERVAL '8 hours', NOW()),
             ('household_tap', 'Cast Iron', 25.0, 11.2312, 77.0984, 'https://images.unsplash.com/photo-1605647540924-852290f6b0d5?w=600', 'approved', 'Ramanathan K.', 'Samsung Galaxy Tab Active 3', 11.8, 0.3, NOW() - INTERVAL '1 day', NOW()),
             ('public_tap', 'PVC', 32.0, 11.2401, 77.1120, 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=600', 'rejected', 'Muthu Swamy', 'Nokia XR20 Rugged', 13.5, 0.5, NOW() - INTERVAL '2 days', NOW())`
        );

        console.log('✅ Created water pipelines, reservoirs, flow logs, and captured assets.');

        // 8. Fetch newly created info from DB to build relationships for Voice Calls and Complaints
        const { rows: dbPipelines } = await client.query('SELECT id, name, panchayat_id FROM water_pipelines');
        const { rows: dbTanks } = await client.query('SELECT id, name, panchayat_id FROM water_tank_borewells');

        // 9. Voice Calls & Complaints seeding (with proper assignments to our staff)
        console.log('📞 Seeding voice calls and complaints...');
        
        const voiceCallsAndComplaints = [
            // --- THAYANUR LIGHT POLES (Assigned to thayanurElectricianId) ---
            {
                call_sid: 'CALL-TY-LIGHT-001',
                transcript: 'வணக்கம், மாரியம்மன் கோவில் தெருவில் இருக்கும் கம்பத்தில் நேற்று இரவு முதல் விளக்கு எரியவில்லை. தயவுசெய்து சரிசெய்யவும்.',
                transcript_english: 'Hello, the light on the pole in Mariamman Temple Street has not been working since yesterday night. Please fix it.',
                ai_extracted_json: { village: 'Thayanur', landmark: 'மாரியம்மன் கோயில்', complaint_type: 'light pole not working', urgency_level: 'medium', caller_emotion: 'calm', caller_language: 'tamil' },
                confidence_score: 0.95,
                panchayat_id: thayanurId,
                pole_key: 'TY-001',
                complaint: {
                    complaint_type: 'light pole not working',
                    description: 'Street light not working since last night near Mariamman Temple. Extremely dark and unsafe.',
                    urgency_level: 'medium',
                    caller_emotion: 'calm',
                    caller_language: 'tamil',
                    status: 'resolved',
                    category: 'electricity',
                    created_offset_days: 28,
                    assigned_to: thayanurElectricianId,
                    resolution: {
                        note: 'Replaced the fused 40W LED bulb with a new one and cleaned the holder contacts.',
                        image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600',
                        offset_resolved_days: 26
                    }
                }
            },
            {
                call_sid: 'CALL-TY-LIGHT-002',
                transcript: 'அரசு பள்ளிக்கு பக்கத்தில் இருக்கிற மின்சார கம்பத்திலிருந்து ஒயர்கள் கீழே தொங்குகின்றன. குழந்தைகள் நடமாடும் இடம் என்பதால் ஆபத்தாக உள்ளது. உடனே சரிசெய்ய வேண்டும்.',
                transcript_english: 'Wires are hanging down from the electric pole next to the government school. It is dangerous as children walk around. Please fix it immediately.',
                ai_extracted_json: { village: 'Thayanur', landmark: 'அரசு பள்ளி', complaint_type: 'wire damage', urgency_level: 'high', caller_emotion: 'concerned', caller_language: 'tamil' },
                confidence_score: 0.98,
                panchayat_id: thayanurId,
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
                    assigned_to: thayanurElectricianId,
                    resolution: {
                        note: 'Tightened and anchored the dangling overhead cables to the school compound wall support hook.',
                        image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600',
                        offset_resolved_days: 19
                    }
                }
            },
            {
                call_sid: 'CALL-TY-LIGHT-003',
                transcript: 'தண்ணி டேங்க் ரோட்டில் இருக்கும் கம்பத்தில் லைட் எரியாமல் இருட்டாக இருக்கிறது. இரவு நேரத்தில் நடக்க பயமாக உள்ளது.',
                transcript_english: 'The light on the pole in Water Tank Road is not working and it is dark. It is scary to walk at night.',
                ai_extracted_json: { village: 'Thayanur', landmark: 'தண்ணி டேங்க்', complaint_type: 'light pole not working', urgency_level: 'low', caller_emotion: 'anxious', caller_language: 'tamil' },
                confidence_score: 0.92,
                panchayat_id: thayanurId,
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
                    assigned_to: thayanurElectricianId
                }
            },
            {
                call_sid: 'CALL-TY-LIGHT-004',
                transcript: 'ரேஷன் கடை கிட்ட இருக்கிற கம்பத்தில வயரிங்ல தீப்பொறி பறக்குதுங்க. பயமா இருக்கு, சீக்கிரம் யாரையாவது அனுப்பி பாருங்க.',
                transcript_english: 'Sparking observed in the wiring of the pole near the ration shop. We are scared, please send someone quickly.',
                ai_extracted_json: { village: 'Thayanur', landmark: 'ரேஷன் கடை', complaint_type: 'sparking/fire hazard', urgency_level: 'high', caller_emotion: 'scared', caller_language: 'tamil' },
                confidence_score: 0.97,
                panchayat_id: thayanurId,
                pole_key: 'TY-004',
                complaint: {
                    complaint_type: 'wire damage',
                    description: 'Active sparking on the junctions of pole TY-004 near the ration shop. Urgent attention needed.',
                    urgency_level: 'high',
                    caller_emotion: 'scared',
                    caller_language: 'tamil',
                    status: 'pending',
                    category: 'electricity',
                    created_offset_days: 0
                }
            },

            // --- THOLAMPALAY LIGHT POLES (Assigned to tholampalayElectricianId) ---
            {
                call_sid: 'CALL-TH-LIGHT-001',
                transcript: 'தோலாம்பாளையம் மாரியம்மன் கோவில் பக்கத்தில் இருக்கும் மின் கம்பத்தில் விளக்கு தொடர்ந்து மின்னி மின்னி எரிகிறது. பல்பை மாற்ற வேண்டும்.',
                transcript_english: 'The light on the electric pole near Tholampalay Mariamman temple is flickering continuously. The bulb needs to be replaced.',
                ai_extracted_json: { village: 'Tholampalay', landmark: 'மாரியம்மன் கோயில்', complaint_type: 'light pole flickering', urgency_level: 'low', caller_emotion: 'calm', caller_language: 'tamil' },
                confidence_score: 0.91,
                panchayat_id: tholampalayId,
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
                    assigned_to: tholampalayElectricianId,
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
                ai_extracted_json: { village: 'Tholampalay', landmark: 'டீ கடை', complaint_type: 'light pole not working', urgency_level: 'medium', caller_emotion: 'concerned', caller_language: 'tamil' },
                confidence_score: 0.94,
                panchayat_id: tholampalayId,
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

            // --- THAYANUR WATER COMPLAINTS (Assigned to thayanurPlumberId) ---
            {
                call_sid: 'CALL-TY-WATER-001',
                transcript: 'அண்ணூர் ரோடு மெயின் பைப்லைனில் இருந்து தண்ணீர் பெருக்கெடுத்து ஓடுகிறது. பெரிய அளவில் கசிவு ஏற்பட்டு வீணாகிறது.',
                transcript_english: 'Water is gushing out from the Annur Road main pipeline. There is a huge leak and water is being wasted.',
                ai_extracted_json: { village: 'Thayanur', landmark: 'அண்ணூர் ரோடு', complaint_type: 'pipeline leak', urgency_level: 'high', caller_emotion: 'angry', caller_language: 'tamil' },
                confidence_score: 0.96,
                panchayat_id: thayanurId,
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
                    assigned_to: thayanurPlumberId,
                    resolution: {
                        note: 'Excavated the site and installed a leak repair clamp on the pipe joint. Backfilled and leveled.',
                        image_url: 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600',
                        offset_resolved_days: 11
                    }
                }
            },
            {
                call_sid: 'CALL-TY-WATER-002',
                transcript: 'அண்ணூர் மேல்நிலை நீர்த்தேக்க தொட்டியில் இருந்து மோட்டார் ஓடும் போது தண்ணீர் பக்கவாட்டில் வழிகிறது. வால்வு ஒழுங்காக மூடவில்லை போலிருக்கிறது.',
                transcript_english: 'Water is overflowing from the side of the Annur elevated reservoir when the motor runs. It seems the valve is not closed properly.',
                ai_extracted_json: { village: 'Thayanur', landmark: 'மேல்நிலை நீர்த்தேக்க தொட்டி', complaint_type: 'tank overflow', urgency_level: 'medium', caller_emotion: 'calm', caller_language: 'tamil' },
                confidence_score: 0.93,
                panchayat_id: thayanurId,
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
                    assigned_to: thayanurPlumberId,
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
                ai_extracted_json: { village: 'Thayanur', landmark: 'அலங்கால்', complaint_type: 'dirty water', urgency_level: 'high', caller_emotion: 'angry', caller_language: 'tamil' },
                confidence_score: 0.97,
                panchayat_id: thayanurId,
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
                    assigned_to: thayanurPlumberId
                }
            },
            {
                call_sid: 'CALL-TY-WATER-004',
                transcript: 'போர்வெல் பம்ப் மோட்டார் ஓடவில்லை. தண்ணி வரல. மக்கள் கஷ்டப்படுறாங்க. உடனே பாருங்க.',
                transcript_english: 'Borewell pump motor is not running. No water supply. People are suffering. Look into this immediately.',
                ai_extracted_json: { village: 'Thayanur', landmark: 'போர்வெல்', complaint_type: 'borewell pump fault', urgency_level: 'high', caller_emotion: 'angry', caller_language: 'tamil' },
                confidence_score: 0.94,
                panchayat_id: thayanurId,
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

        for (const vc of voiceCallsAndComplaints) {
            // 1. Calculate creation time offset
            const createdTime = new Date(now.getTime() - vc.complaint.created_offset_days * 24 * 60 * 60 * 1000);

            // 2. Insert voice call
            const vcRes = await client.query(`
                INSERT INTO voice_calls (call_sid, audio_url, transcript, transcript_english, ai_extracted_json, processing_status, confidence_score, attempt_number, created_at)
                VALUES ($1, $2, $3, $4, $5, $6, $7, 1, $8)
                RETURNING id;
            `, [
                vc.call_sid,
                `https://supabase.co/storage/v1/object/public/calls/${vc.call_sid}.mp3`,
                vc.transcript,
                vc.transcript_english,
                JSON.stringify(vc.ai_extracted_json),
                'completed',
                vc.confidence_score,
                createdTime
            ]);
            const voiceCallId = vcRes.rows[0].id;

            // 3. Match spatial items
            let poleId = null;
            let pipelineId = null;
            let tankId = null;
            let refLat = 11.0168;
            let refLng = 76.9558;

            if (vc.pole_key) {
                const matchedPole = dbPoles.find(p => p.pole_number === vc.pole_key && p.panchayat_id === vc.panchayat_id);
                if (matchedPole) {
                    poleId = matchedPole.id;
                    refLat = matchedPole.latitude || 11.0168;
                    refLng = matchedPole.longitude || 76.9558;
                }
            } else if (vc.pipeline_key) {
                const matchedPipeline = dbPipelines.find(p => p.name === vc.pipeline_key && p.panchayat_id === vc.panchayat_id);
                if (matchedPipeline) {
                    pipelineId = matchedPipeline.id;
                }
            } else if (vc.tank_key) {
                const matchedTank = dbTanks.find(t => t.name === vc.tank_key && t.panchayat_id === vc.panchayat_id);
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
                assignedAt = new Date(createdTime.getTime() + 2 * 60 * 60 * 1000); // 2 hours later
                resolvedAt = new Date(now.getTime() - vc.complaint.resolution.offset_resolved_days * 24 * 60 * 60 * 1000);

                resolutionNote = vc.complaint.resolution.note;
                resolutionImageUrl = vc.complaint.resolution.image_url;

                const shifted = shiftCoords(refLat, refLng);
                resolutionLat = shifted.lat;
                resolutionLng = shifted.lng;
                resolutionDistance = shifted.distance;
                resolutionLocationValid = true;
                resolutionSubmittedKey = `key-${vc.call_sid}`;
            } else if (vc.complaint.status === 'in_progress' && vc.complaint.assigned_to) {
                assignedAt = new Date(createdTime.getTime() + 3 * 60 * 60 * 1000);
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
                resolvedAt,
                resolutionDistance,
                resolutionLocationValid,
                resolutionSubmittedKey
            ]);

            // 6. Create call state entry
            await client.query(`
                INSERT INTO call_state (call_sid, phase1_status, phase2_status, complaint_created, finalized_at, updated_at)
                VALUES ($1, $2, $3, $4, $5, $6);
            `, [
                vc.call_sid,
                'completed',
                'completed',
                true,
                createdTime,
                createdTime
            ]);
        }

        console.log('✅ Seeding additional manual complaints for background history...');
        const additionalComplaints = [
            {
                panchayat_id: thayanurId,
                complaint_type: 'light pole not working',
                description: 'Flickering street light near Hospital (TY-009). Creating visibility issues for ambulance entry.',
                urgency_level: 'medium',
                caller_emotion: 'concerned',
                caller_language: 'tamil',
                status: 'resolved',
                category: 'electricity',
                created_offset_days: 25,
                pole_key: 'TY-009',
                assigned_to: thayanurElectricianId,
                resolution: { note: 'Fixed a loose wire connection inside the pole junction box and wrapped with insulated tape.', image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600', offset_resolved_days: 24 }
            },
            {
                panchayat_id: thayanurId,
                complaint_type: 'light pole not working',
                description: 'Street light bulb completely broken near Vinayagar Temple (TY-010). Heavy darkness during evening worship.',
                urgency_level: 'low',
                caller_emotion: 'calm',
                caller_language: 'tamil',
                status: 'resolved',
                category: 'electricity',
                created_offset_days: 18,
                pole_key: 'TY-010',
                assigned_to: thayanurElectricianId,
                resolution: { note: 'Installed a new energy-efficient LED lamp and verified its functionality.', image_url: 'https://images.unsplash.com/photo-1544724569-5f546fd6f2b5?w=600', offset_resolved_days: 17 }
            },
            {
                panchayat_id: thayanurId,
                complaint_type: 'water leak',
                description: 'Slow leakage on Annur-Tiruppur Secondary Conduit pipeline. Minor dampness spreading near road.',
                urgency_level: 'low',
                caller_emotion: 'calm',
                caller_language: 'english',
                status: 'resolved',
                category: 'water_supply',
                created_offset_days: 10,
                pipeline_key: 'Annur-Tiruppur Secondary Conduit',
                assigned_to: thayanurPlumberId,
                resolution: { note: 'Applied epoxy compound sealant to repair the pinhole leak. Leak stopped.', image_url: 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600', offset_resolved_days: 9 }
            },
            {
                panchayat_id: tholampalayId,
                complaint_type: 'light pole not working',
                description: 'Streetlight near School Gate (TH-006) not working. Students returning from special classes find it dark.',
                urgency_level: 'medium',
                caller_emotion: 'concerned',
                caller_language: 'tamil',
                status: 'in_progress',
                category: 'electricity',
                created_offset_days: 3,
                pole_key: 'TH-006',
                assigned_to: tholampalayElectricianId
            },
            {
                panchayat_id: tholampalayId,
                complaint_type: 'wire damage',
                description: 'Tree branches rubbing against power lines near Church (TH-010). Heavy sparks during winds.',
                urgency_level: 'high',
                caller_emotion: 'scared',
                caller_language: 'tamil',
                status: 'in_progress',
                category: 'electricity',
                created_offset_days: 2,
                pole_key: 'TH-010',
                assigned_to: tholampalayElectricianId
            },
            {
                panchayat_id: tholampalayId,
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
                panchayat_id: thayanurId,
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

        for (const ac of additionalComplaints) {
            const createdTime = new Date(now.getTime() - ac.created_offset_days * 24 * 60 * 60 * 1000);
            
            let poleId = null;
            let pipelineId = null;
            let refLat = 11.0168;
            let refLng = 76.9558;

            if (ac.pole_key) {
                const matchedPole = dbPoles.find(p => p.pole_number === ac.pole_key && p.panchayat_id === ac.panchayat_id);
                if (matchedPole) {
                    poleId = matchedPole.id;
                    refLat = matchedPole.latitude || 11.0168;
                    refLng = matchedPole.longitude || 76.9558;
                }
            } else if (ac.pipeline_key) {
                const matchedPipeline = dbPipelines.find(p => p.name === ac.pipeline_key && p.panchayat_id === ac.panchayat_id);
                if (matchedPipeline) {
                    pipelineId = matchedPipeline.id;
                }
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

        console.log('✅ Seeding vendors, tenders, line items and quotations...');
        
        // 10. Vendors
        // Thayanur Vendors
        const v1Res = await client.query(`
            INSERT INTO vendors (panchayat_id, name, phone_e164, place, notes, active, created_at)
            VALUES ($1, 'Raja Electricals & Contractors', '+919000000001', 'Thayanur Center', 'Government grade-A license', true, NOW()) RETURNING id;
        `, [thayanurId]);
        const vendor1Id = v1Res.rows[0].id;

        const v2Res = await client.query(`
            INSERT INTO vendors (panchayat_id, name, phone_e164, place, notes, active, created_at)
            VALUES ($1, 'Sri Sai Water Works', '+919000000002', 'Coimbatore', 'Specialists in leak sealings', true, NOW()) RETURNING id;
        `, [thayanurId]);
        const vendor2Id = v2Res.rows[0].id;

        const v3Res = await client.query(`
            INSERT INTO vendors (panchayat_id, name, phone_e164, place, notes, active, created_at)
            VALUES ($1, 'Amman Builders', '+919000000003', 'Annur', 'General civil contractor', true, NOW()) RETURNING id;
        `, [thayanurId]);
        const vendor3Id = v3Res.rows[0].id;

        // Tholampalay Vendors
        const v4Res = await client.query(`
            INSERT INTO vendors (panchayat_id, name, phone_e164, place, notes, active, created_at)
            VALUES ($1, 'Kovai Power Systems', '+919000000004', 'Tholampalay West', 'Familiar with high mast setups', true, NOW()) RETURNING id;
        `, [tholampalayId]);
        const vendor4Id = v4Res.rows[0].id;

        const v5Res = await client.query(`
            INSERT INTO vendors (panchayat_id, name, phone_e164, place, notes, active, created_at)
            VALUES ($1, 'Selvam Plumbing Services', '+919000000005', 'Mettupalayam', 'Pipes & borewell specialists', true, NOW()) RETURNING id;
        `, [tholampalayId]);
        const vendor5Id = v5Res.rows[0].id;

        // Tenders
        // Tender 1 (Thayanur - Published, Electrician domain)
        const t1Res = await client.query(`
            INSERT INTO tenders (panchayat_id, status, title_ta, title_en, narrative_ta, narrative_en, anchor_date, quotation_access_mode, created_by_user_id, created_at, updated_at)
            VALUES ($1, 'published', 'முக்கிய சாலையில் LED தெருவிளக்கு பராமரிப்பு', 'Main Road LED Streetlight Maintenance', 'முக்கிய வீதிகளில் பழுதடைந்த மின் விளக்குகளை மாற்றுதல் மற்றும் வயரிங் சீரமைத்தல்.', 'Replacement of broken street lamps and fixing wire layouts on main road.', NOW(), 'invited_only', $2, NOW() - INTERVAL '4 days', NOW()) RETURNING id;
        `, [thayanurId, thayanurAdminId]);
        const tender1Id = t1Res.rows[0].id;

        // Line items for Tender 1
        const poleTY001 = dbPoles.find(p => p.pole_number === 'TY-001' && p.panchayat_id === thayanurId)?.id;
        const poleTY002 = dbPoles.find(p => p.pole_number === 'TY-002' && p.panchayat_id === thayanurId)?.id;

        await client.query(`
            INSERT INTO tender_line_items (tender_id, seq, description_ta, description_en, quantity, unit, pole_id)
            VALUES 
              ($1, 1, 'பழுதடைந்த LED பல்புகளை மாற்றுதல்', 'Replace faulty LED bulbs', 15.000, 'numbers', $2),
              ($1, 2, 'கேபிள் வயரிங் சீரமைத்தல்', 'Relaying wiring cable', 200.000, 'meters', $3)
        `, [tender1Id, poleTY001, poleTY002]);

        // Invites for Tender 1
        await client.query(`
            INSERT INTO tender_vendor_invites (tender_id, vendor_id, invite_token, invite_expires_at, created_at)
            VALUES 
              ($1, $2, 'token-raja-123', NOW() + INTERVAL '10 days', NOW()),
              ($1, $3, 'token-amman-123', NOW() + INTERVAL '10 days', NOW())
        `, [tender1Id, vendor1Id, vendor3Id]);

        // Quotations for Tender 1
        await client.query(`
            INSERT INTO tender_quotations (tender_id, vendor_id, submitter_name, submitter_phone_e164, amount, remarks, source, screening_outcome, submitted_at)
            VALUES 
              ($1, $2, 'Raja Contractor', '+919000000001', 45000.00, 'Fully compliant with materials', 'officer_entry', 'pending', NOW() - INTERVAL '2 days'),
              ($1, $3, 'Amman Exec', '+919000000003', 52000.00, 'Includes high-tensile wires', 'officer_entry', 'pending', NOW() - INTERVAL '1 day')
        `, [tender1Id, vendor1Id, vendor3Id]);


        // Tender 2 (Thayanur - Awarded, Plumber domain)
        const t2Res = await client.query(`
            INSERT INTO tenders (panchayat_id, status, title_ta, title_en, narrative_ta, narrative_en, anchor_date, quotation_access_mode, created_by_user_id, created_at, updated_at, work_order_date)
            VALUES ($1, 'awarded', 'அண்ணூர் மெயின் பைப்லைன் கசிவு பழுதுபார்த்தல்', 'Annur Main Trunk Leak Repairs', 'அண்ணூர் மெயின் லைன் பைப் கூட்டுப் பகுதிகளை பழுது நீக்குதல்.', 'Repair and sealing joints of the Annur main distribution line.', NOW(), 'invited_only', $2, NOW() - INTERVAL '10 days', NOW(), NOW() - INTERVAL '5 days') RETURNING id;
        `, [thayanurId, thayanurAdminId]);
        const tender2Id = t2Res.rows[0].id;

        // Line item for Tender 2 (linked to pipeline)
        await client.query(`
            INSERT INTO tender_line_items (tender_id, seq, description_ta, description_en, quantity, unit, complaint_id)
            VALUES ($1, 1, 'மெயின் பைப்லைன் பள்ளம் தோண்டி சீரமைத்தல்', 'Excavation and Joint sealing', 1.000, 'job', NULL)
        `, [tender2Id]);

        // Invite for Tender 2
        await client.query(`
            INSERT INTO tender_vendor_invites (tender_id, vendor_id, invite_token, invite_expires_at, created_at)
            VALUES ($1, $2, 'token-saisai-123', NOW() + INTERVAL '10 days', NOW())
        `, [tender2Id, vendor2Id]);

        // Quotation for Tender 2 (Awarded)
        const q2Res = await client.query(`
            INSERT INTO tender_quotations (tender_id, vendor_id, submitter_name, submitter_phone_e164, amount, remarks, source, screening_outcome, submitted_at)
            VALUES ($1, $2, 'Sai Contractor', '+919000000002', 78000.00, 'Heavy machinery required for excavation', 'officer_entry', 'passed', NOW() - INTERVAL '6 days')
            RETURNING id;
        `, [tender2Id, vendor2Id]);
        const quotation2Id = q2Res.rows[0].id;

        // Update Tender 2 to link awarded quote
        await client.query(`
            UPDATE tenders SET awarded_quotation_id = $1 WHERE id = $2;
        `, [quotation2Id, tender2Id]);


        // Tender 3 (Tholampalay - Work Completed, Electrician domain)
        const t3Res = await client.query(`
            INSERT INTO tenders (panchayat_id, status, title_ta, title_en, narrative_ta, narrative_en, anchor_date, quotation_access_mode, created_by_user_id, created_at, updated_at, work_order_date, work_completed_at)
            VALUES ($1, 'work_completed', 'கோவில் தெருவில் உயர்கோபுர மின்விளக்கு பொருத்துதல்', 'Temple Street High Mast Light Installation', 'மாரியம்மன் கோவில் வீதியில் உயர்கோபுர விளக்கு கம்பம் அமைத்தல்.', 'Erecting high mast lighting setup near Mariamman Temple block.', NOW(), 'invited_only', $2, NOW() - INTERVAL '15 days', NOW(), NOW() - INTERVAL '12 days', NOW() - INTERVAL '2 days') RETURNING id;
        `, [tholampalayId, tholampalayAdminId]);
        const tender3Id = t3Res.rows[0].id;

        // Line item for Tender 3
        const poleTH002 = dbPoles.find(p => p.pole_number === 'TH-002' && p.panchayat_id === tholampalayId)?.id;
        await client.query(`
            INSERT INTO tender_line_items (tender_id, seq, description_ta, description_en, quantity, unit, pole_id)
            VALUES ($1, 1, 'உயர்கோபுர மின் கம்பம் மற்றும் விளக்குகள்', 'High-mast lighting set', 1.000, 'number', $2)
        `, [tender3Id, poleTH002]);

        // Invite for Tender 3
        await client.query(`
            INSERT INTO tender_vendor_invites (tender_id, vendor_id, invite_token, invite_expires_at, created_at)
            VALUES ($1, $2, 'token-kovai-123', NOW() + INTERVAL '10 days', NOW())
        `, [tender3Id, vendor4Id]);

        // Quotation for Tender 3 (Awarded & Completed)
        const q3Res = await client.query(`
            INSERT INTO tender_quotations (tender_id, vendor_id, submitter_name, submitter_phone_e164, amount, remarks, source, screening_outcome, submitted_at)
            VALUES ($1, $2, 'Kovai Power Rep', '+919000000004', 120000.00, 'Includes high-mast structural engineering', 'officer_entry', 'passed', NOW() - INTERVAL '13 days')
            RETURNING id;
        `, [tender3Id, vendor4Id]);
        const quotation3Id = q3Res.rows[0].id;

        await client.query(`
            UPDATE tenders SET awarded_quotation_id = $1 WHERE id = $2;
        `, [quotation3Id, tender3Id]);

        console.log(`✅ Created 3 Tenders across Thayanur (2) & Tholampalay (1) along with bids and line items.`);

        // 11. Final summary check
        const { rows: pCount } = await client.query('SELECT count(*) FROM panchayats');
        const { rows: uCount } = await client.query('SELECT count(*) FROM users');
        const { rows: poleCount } = await client.query('SELECT count(*) FROM electric_poles');
        const { rows: callCount } = await client.query('SELECT count(*) FROM voice_calls');
        const { rows: complaintCount } = await client.query('SELECT count(*) FROM complaints');
        const { rows: tenderCount } = await client.query('SELECT count(*) FROM tenders');
        const { rows: vendorCount } = await client.query('SELECT count(*) FROM vendors');

        console.log('\n🎉 SUCCESS: All demo data successfully inserted!');
        console.log('----------------------------------------------------');
        console.log(`Panchayats      : ${pCount[0].count}`);
        console.log(`Users           : ${uCount[0].count}`);
        console.log(`Electric Poles  : ${poleCount[0].count}`);
        console.log(`Voice Calls     : ${callCount[0].count}`);
        console.log(`Complaints      : ${complaintCount[0].count}`);
        console.log(`Tenders         : ${tenderCount[0].count}`);
        console.log(`Vendors         : ${vendorCount[0].count}`);
        console.log('----------------------------------------------------');

    } catch (error) {
        console.error('❌ Error during demo seeding:', error);
    } finally {
        await client.end();
        console.log('🔌 Database connection closed.');
    }
}

main();
