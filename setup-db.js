const { Client } = require('pg');

async function setupDatabase() {
  // Connect to default 'postgres' database first
  const client = new Client({
    host: '127.0.0.1',
    port: 5432,
    user: 'postgres',
    password: 'postgres',
    database: 'postgres',
  });

  try {
    await client.connect();
    console.log('Connected to PostgreSQL successfully!');

    // Check if ivr_system database exists
    const res = await client.query(
      "SELECT 1 FROM pg_database WHERE datname = 'ivr_system'"
    );

    if (res.rows.length === 0) {
      await client.query('CREATE DATABASE ivr_system');
      console.log('Database "ivr_system" created successfully!');
    } else {
      console.log('Database "ivr_system" already exists.');
    }

    // Connect to ivr_system to enable PostGIS
    const ivrClient = new Client({
      host: '127.0.0.1',
      port: 5432,
      user: 'postgres',
      password: 'postgres',
      database: 'ivr_system',
    });

    await ivrClient.connect();
    
    try {
      await ivrClient.query('CREATE EXTENSION IF NOT EXISTS postgis');
      console.log('PostGIS extension enabled!');
    } catch (e) {
      console.log('PostGIS extension note:', e.message);
    }

    await ivrClient.end();
  } catch (err) {
    console.error('Error:', err.message);
  } finally {
    await client.end();
  }
}

setupDatabase();
