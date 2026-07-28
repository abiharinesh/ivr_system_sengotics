import { Client } from 'pg';
import * as bcrypt from 'bcrypt';
import * as dotenv from 'dotenv';

dotenv.config();

const DEFAULT_PASSWORD = 'Admin@1234';

async function runDirectAuthTest() {
  console.log('\n======================================================================');
  console.log(' 🧪 DIRECT PG DATABASE & AUTHENTICATION TEST FOR ALL 13 USER LOGINS');
  console.log('======================================================================\n');

  const client = new Client({ connectionString: process.env.DATABASE_URL });
  await client.connect();

  const usersRes = await client.query(`
    SELECT u.id, u.email, u.role, u.panchayat_id, u.password_hash, u.user_type
    FROM users u
    ORDER BY u.id ASC
  `);

  console.log(`📊 Found ${usersRes.rows.length} total users in PostgreSQL database.\n`);

  let passCount = 0;
  let failCount = 0;

  for (const user of usersRes.rows) {
    const isValidPassword = await bcrypt.compare(DEFAULT_PASSWORD, user.password_hash);
    if (isValidPassword) {
      console.log(`✅ [LOGIN SUCCESS] User #${user.id.toString().padEnd(3)} | Email: ${user.email.padEnd(32)} | Role: ${user.role.padEnd(24)} | Type: ${user.user_type}`);
      passCount++;
    } else {
      console.log(`❌ [LOGIN FAILED] User #${user.id} (${user.email}) password validation failed.`);
      failCount++;
    }
  }

  // Verify RBAC roles in roles table
  const rolesRes = await client.query(`SELECT id, name, display_name FROM roles WHERE is_active = true`);
  console.log(`\n🎭 RBAC Roles Active in Database: ${rolesRes.rows.length} roles found.`);
  for (const r of rolesRes.rows) {
    console.log(`   • Role: ${r.name.padEnd(24)} | Display: ${r.display_name}`);
  }

  console.log('\n======================================================================');
  console.log(` 📊 AUTH TEST RESULTS: ${passCount} LOGINS PASSED / ${failCount} FAILED`);
  console.log('======================================================================\n');

  await client.end();
}

runDirectAuthTest().catch((err) => {
  console.error('Direct auth test error:', err);
  process.exit(1);
});
