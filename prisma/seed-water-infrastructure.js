const { Client } = require('pg');
require('dotenv').config();

async function seedWater() {
    const client = new Client({
        connectionString: process.env.DATABASE_URL
    });

    try {
        await client.connect();
        console.log('Connected to database for water infrastructure seeding...');

        // 1. Find the Thayanur panchayat
        const { rows: panchayats } = await client.query("SELECT id FROM panchayats WHERE name = 'Thayanur' LIMIT 1");
        if (panchayats.length === 0) {
            console.error('❌ Panchayat Thayanur not found! Please run the main seed first.');
            return;
        }
        const panchayatId = panchayats[0].id;
        console.log(`Found Thayanur Panchayat with ID: ${panchayatId}`);

        // 2. Clear existing water data
        console.log('Cleaning existing water supply infrastructure data...');
        await client.query('TRUNCATE water_flow_logs, water_pipelines, water_tank_borewells, water_valves, captured_assets CASCADE');

        // 3. Insert Pipelines
        console.log('Inserting water pipelines...');
        const pipeline1Path = {
            type: 'LineString',
            coordinates: [
                [76.9616, 11.0168],
                [77.0123, 11.0850],
                [77.0984, 11.1678],
                [77.1025, 11.2341]
            ]
        };
        const pipeline2Path = {
            type: 'LineString',
            coordinates: [
                [77.1025, 11.2341],
                [77.1892, 11.1890],
                [77.2504, 11.1542],
                [77.3411, 11.1085]
            ]
        };
        const pipeline3Path = {
            type: 'LineString',
            coordinates: [
                [77.1025, 11.2341],
                [77.0911, 11.1524],
                [77.1232, 11.0921]
            ]
        };

        const { rows: pipeline1 } = await client.query(
            `INSERT INTO water_pipelines (name, panchayat_id, diameter_mm, material, status, path_geojson, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING id`,
            ['Annur-Coimbatore Main Trunk', panchayatId, 250.0, 'Cast Iron', 'leak_alert', JSON.stringify(pipeline1Path)]
        );
        const pipeline1Id = pipeline1[0].id;

        const { rows: pipeline2 } = await client.query(
            `INSERT INTO water_pipelines (name, panchayat_id, diameter_mm, material, status, path_geojson, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW()) RETURNING id`,
            ['Annur-Tiruppur Secondary Conduit', panchayatId, 160.0, 'HDPE', 'active', JSON.stringify(pipeline2Path)]
        );
        const pipeline2Id = pipeline2[0].id;

        await client.query(
            `INSERT INTO water_pipelines (name, panchayat_id, diameter_mm, material, status, path_geojson, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW())`,
            ['Alngkhal Distribution Grid', panchayatId, 110.0, 'PVC', 'active', JSON.stringify(pipeline3Path)]
        );

        // 4. Insert Tanks & Borewells
        console.log('Inserting water tanks & borewells...');
        const { rows: tank1 } = await client.query(
            `INSERT INTO water_tank_borewells (name, type, latitude, longitude, panchayat_id, capacity_liters, current_level_pct, status, pump_status, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW()) RETURNING id`,
            ['Annur Main Elevated Reservoir', 'overhead_tank', 11.2341, 77.1025, panchayatId, 500000.0, 82.5, 'active', 'on']
        );
        const tank1Id = tank1[0].id;

        await client.query(
            `INSERT INTO water_tank_borewells (name, type, latitude, longitude, panchayat_id, capacity_liters, current_level_pct, status, pump_status, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
            ['Coimbatore Central Reservoirs', 'overhead_tank', 11.0168, 76.9616, panchayatId, 1200000.0, 100.0, 'active', 'off']
        );

        await client.query(
            `INSERT INTO water_tank_borewells (name, type, latitude, longitude, panchayat_id, capacity_liters, current_level_pct, status, pump_status, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, NOW())`,
            ['Alngkhal Deep Borewell Pump', 'borewell_pump', 11.0921, 77.1232, panchayatId, 0.0, 0.0, 'active', 'on']
        );

        // 5. Insert Valves
        console.log('Inserting water valves...');
        await client.query(
            `INSERT INTO water_valves (valve_number, latitude, longitude, panchayat_id, status, updated_at)
             VALUES 
             ('V-AN-01', 11.1678, 77.0984, $1, 'open', NOW()),
             ('V-CO-12', 11.0850, 77.0123, $1, 'open', NOW()),
             ('V-TP-04', 11.1890, 77.1892, $1, 'closed', NOW())`,
            [panchayatId]
        );

        // 6. Insert Flow Logs
        console.log('Inserting historical flow logs...');
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

            // Seed logs for a tank as well
            await client.query(
                `INSERT INTO water_flow_logs (tank_id, flow_rate_lps, pressure_bar, logged_at)
                 VALUES ($1, $2, $3, $4)`,
                [tank1Id, flowRate * 0.8, pressure * 0.9, loggedAt]
            );
        }

        // 7. Seed sample Captured Assets
        console.log('Inserting sample captured assets...');
        await client.query(
            `INSERT INTO captured_assets (type, material, diameter_mm, latitude, longitude, photo_url, status, agent_name, device_model, altitude, precision, submitted_at, updated_at)
             VALUES 
             ('public_tap', 'PVC', 50.0, 11.2356, 77.1042, 'https://images.unsplash.com/photo-1585338107529-13afc5f02586?w=600', 'pending_approval', 'Ramanathan K.', 'Samsung Galaxy Tab Active 3', 12.4, 0.4, NOW() - INTERVAL '4 hours', NOW()),
             ('main_pipeline', 'HDPE', 110.0, 11.2389, 77.1085, 'https://images.unsplash.com/photo-1542060748-10c28b629f6f?w=600', 'pending_approval', 'Muthu Swamy', 'Nokia XR20 Rugged', 14.1, 0.6, NOW() - INTERVAL '8 hours', NOW()),
             ('household_tap', 'Cast Iron', 25.0, 11.2312, 77.0984, 'https://images.unsplash.com/photo-1605647540924-852290f6b0d5?w=600', 'approved', 'Ramanathan K.', 'Samsung Galaxy Tab Active 3', 11.8, 0.3, NOW() - INTERVAL '1 day', NOW()),
             ('public_tap', 'PVC', 32.0, 11.2401, 77.1120, 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=600', 'rejected', 'Muthu Swamy', 'Nokia XR20 Rugged', 13.5, 0.5, NOW() - INTERVAL '2 days', NOW())`
        );

        console.log('🎉 Water supply infrastructure seeded successfully!');

    } catch (error) {
        console.error('❌ Error seeding water infrastructure:', error);
    } finally {
        await client.end();
    }
}

seedWater();
