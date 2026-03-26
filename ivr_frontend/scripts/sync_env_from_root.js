/**
 * Syncs GOOGLE_MAPS_API_KEY from the repo root .env into ivr_frontend/.env.
 * Single source of truth: root .env (used by backend + this script for Flutter).
 * Run from repo root: node ivr_frontend/scripts/sync_env_from_root.js
 * Or from ivr_frontend: node scripts/sync_env_from_root.js
 */

const fs = require('fs');
const path = require('path');

const rootDir = path.resolve(__dirname, '../..');
const frontendDir = path.resolve(__dirname, '..');
const rootEnv = path.join(rootDir, '.env');
const frontendEnv = path.join(frontendDir, '.env');

function getKeyFromRoot() {
  if (!fs.existsSync(rootEnv)) return null;
  const content = fs.readFileSync(rootEnv, 'utf8');
  const match = content.match(/^\s*GOOGLE_MAPS_API_KEY\s*=\s*(.+)\s*$/m);
  return match ? match[1].trim() : null;
}

function getFlutterApiBaseFromRoot() {
  if (!fs.existsSync(rootEnv)) return null;
  const content = fs.readFileSync(rootEnv, 'utf8');
  const match = content.match(/^\s*FLUTTER_API_BASE_URL\s*=\s*(.+)\s*$/m);
  return match ? match[1].trim() : null;
}

function getApiBaseFromFrontend() {
  if (!fs.existsSync(frontendEnv)) return null;
  const content = fs.readFileSync(frontendEnv, 'utf8');
  const match = content.match(/^\s*API_BASE_URL\s*=\s*(.+)\s*$/m);
  return match ? match[1].trim() : null;
}

const key = process.env.GOOGLE_MAPS_API_KEY || getKeyFromRoot();
const apiBase =
  process.env.FLUTTER_API_BASE_URL ||
  getFlutterApiBaseFromRoot() ||
  getApiBaseFromFrontend();

if (key) {
  let out = `# Auto-synced from root .env – edit ivr_system_sengotics/.env only\nGOOGLE_MAPS_API_KEY=${key}\n`;
  if (apiBase) {
    out += `API_BASE_URL=${apiBase}\n`;
  }
  fs.writeFileSync(frontendEnv, out);
  console.log('Synced GOOGLE_MAPS_API_KEY to ivr_frontend/.env');
  if (apiBase) {
    console.log('Kept or set API_BASE_URL in ivr_frontend/.env (from FLUTTER_API_BASE_URL / existing file)');
  }
} else {
  console.warn('GOOGLE_MAPS_API_KEY not found in root .env or env; ivr_frontend/.env unchanged.');
}
