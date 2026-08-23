/**
 * Test ALL IVR endpoints against a running local server (http://localhost:3000).
 *
 * Endpoints under test:
 *   POST/GET  /api/ivr/service          — EP1: service selection
 *   POST/GET  /api/ivr/ward-identify    — EP-WARD: ward identification
 *   POST/GET  /api/ivr/complaint-method — EP-METHOD: complaint method
 *   POST/GET  /api/ivr/poll             — EP2: pole/detail input
 *   POST/GET  /api/ivr/voice-match      — EP3-P1: voice phase 1
 *   POST/GET  /api/ivr/voice-llm        — EP3-P2: voice LLM phase 2
 *
 * Each test sends an Exotel-style callback and verifies:
 *   1. HTTP status is 200 (or 404 where expected)
 *   2. Content-Type is application/xml
 *   3. Body starts with <?xml
 *   4. Response time is < 5000 ms (Exotel Passthru limit)
 */

const BASE = 'http://localhost:3000';

// A real Exotel recording URL for ward-identify and voice endpoints
const RECORDING_URL =
  'https://recordings.exotel.com/exotelrecordings/nexerawe1/1772118444.76627_1.mp3';

const CALL_SID = `TEST_${Date.now()}`;

// ── helpers ────────────────────────────────────────────────────────────────

async function testEndpoint(label, method, path, body, expectStatus = [200]) {
  const url = `${BASE}${path}`;
  const start = Date.now();
  let res;
  try {
    if (method === 'POST') {
      res = await fetch(url, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      });
    } else {
      const qs = new URLSearchParams(body).toString();
      res = await fetch(`${url}?${qs}`);
    }
  } catch (err) {
    console.log(`❌ ${label} [${method}] — FETCH ERROR: ${err.message}`);
    return false;
  }
  const elapsed = Date.now() - start;
  const text = await res.text();
  const ct = res.headers.get('content-type') || '';

  const statusOk = expectStatus.includes(res.status);
  const xmlOk = ct.includes('xml');
  const bodyOk = text.startsWith('<?xml');
  const timeOk = elapsed < 5000;

  const pass = statusOk && xmlOk && bodyOk && timeOk;

  const icon = pass ? '✅' : '❌';
  console.log(
    `${icon} ${label} [${method}]  status=${res.status}  xml=${xmlOk}  body=${bodyOk ? 'xml' : text.substring(0, 60)}  ${elapsed}ms`,
  );
  if (!statusOk)
    console.log(`   ↳ Expected status ${expectStatus}, got ${res.status}`);
  if (!xmlOk)
    console.log(`   ↳ Content-Type is "${ct}", expected application/xml`);
  if (!bodyOk) console.log(`   ↳ Body does not start with <?xml: "${text.substring(0, 80)}"`);
  if (!timeOk)
    console.log(`   ↳ Response took ${elapsed}ms, exceeds 5000ms limit`);

  return pass;
}

// ── test suite ─────────────────────────────────────────────────────────────

async function main() {
  console.log('═══════════════════════════════════════════════════════════════');
  console.log('  IVR Endpoint Integration Tests');
  console.log(`  Server: ${BASE}`);
  console.log(`  CallSid: ${CALL_SID}`);
  console.log('═══════════════════════════════════════════════════════════════\n');

  // Check server is reachable
  try {
    await fetch(`${BASE}/api`);
  } catch {
    console.log('❌ Server is not reachable at ' + BASE);
    console.log('   Start it with: npx nest start');
    process.exit(1);
  }

  const results = [];

  // ── EP1: Service Selection (/api/ivr/service) ──────────────────────────
  console.log('\n── EP1: Service Selection (/api/ivr/service) ──');
  results.push(
    await testEndpoint('EP1 POST digit=1', 'POST', '/api/ivr/service', {
      CallSid: CALL_SID,
      CallFrom: '+919876543210',
      CallTo: '+914222609028',
      digits: '1',
    }),
  );
  results.push(
    await testEndpoint('EP1 GET digit=2', 'GET', '/api/ivr/service', {
      CallSid: CALL_SID + '_get',
      CallFrom: '+919876543210',
      CallTo: '+914222609028',
      digits: '2',
    }),
  );
  results.push(
    await testEndpoint('EP1 POST no digits', 'POST', '/api/ivr/service', {
      CallSid: CALL_SID + '_nodigit',
      CallFrom: '+919876543210',
      CallTo: '+914222609028',
    }),
  );
  results.push(
    await testEndpoint('EP1 POST empty body', 'POST', '/api/ivr/service', {}),
  );

  // ── EP-WARD: Ward Identification (/api/ivr/ward-identify) ─────────────
  console.log('\n── EP-WARD: Ward Identification (/api/ivr/ward-identify) ──');
  results.push(
    await testEndpoint(
      'WARD POST with recording',
      'POST',
      '/api/ivr/ward-identify',
      {
        CallSid: CALL_SID,
        CallFrom: '+919876543210',
        CallTo: '+914222609028',
        RecordingUrl: RECORDING_URL,
      },
      [200, 404], // 200 if ward found, 404 if not
    ),
  );
  results.push(
    await testEndpoint(
      'WARD POST missing recording',
      'POST',
      '/api/ivr/ward-identify',
      {
        CallSid: CALL_SID + '_norec',
        CallFrom: '+919876543210',
        CallTo: '+914222609028',
      },
    ),
  );
  results.push(
    await testEndpoint(
      'WARD POST missing CallSid',
      'POST',
      '/api/ivr/ward-identify',
      {
        RecordingUrl: RECORDING_URL,
      },
    ),
  );
  results.push(
    await testEndpoint(
      'WARD POST ProcessStatus=queued',
      'POST',
      '/api/ivr/ward-identify',
      {
        CallSid: CALL_SID + '_queued',
        RecordingUrl: RECORDING_URL,
        ProcessStatus: 'queued',
      },
    ),
  );
  results.push(
    await testEndpoint(
      'WARD GET with recording',
      'GET',
      '/api/ivr/ward-identify',
      {
        CallSid: CALL_SID + '_get_ward',
        CallTo: '+914222609028',
        RecordingUrl: RECORDING_URL,
      },
      [200, 404],
    ),
  );

  // ── EP-METHOD: Complaint Method (/api/ivr/complaint-method) ───────────
  console.log('\n── EP-METHOD: Complaint Method (/api/ivr/complaint-method) ──');
  results.push(
    await testEndpoint('METHOD POST digit=1 (keypad)', 'POST', '/api/ivr/complaint-method', {
      CallSid: CALL_SID,
      digits: '1',
    }),
  );
  results.push(
    await testEndpoint('METHOD POST digit=2 (voice)', 'POST', '/api/ivr/complaint-method', {
      CallSid: CALL_SID + '_voice',
      digits: '2',
    }),
  );
  results.push(
    await testEndpoint('METHOD GET digit=1', 'GET', '/api/ivr/complaint-method', {
      CallSid: CALL_SID + '_get_meth',
      digits: '1',
    }),
  );
  results.push(
    await testEndpoint('METHOD POST empty', 'POST', '/api/ivr/complaint-method', {}),
  );

  // ── EP2: Poll Input (/api/ivr/poll) ───────────────────────────────────
  console.log('\n── EP2: Poll Input (/api/ivr/poll) ──');
  results.push(
    await testEndpoint('POLL POST digit=12345', 'POST', '/api/ivr/poll', {
      CallSid: CALL_SID,
      CallFrom: '+919876543210',
      CallTo: '+914222609028',
      digits: '12345',
    }),
  );
  results.push(
    await testEndpoint('POLL GET digit=99999', 'GET', '/api/ivr/poll', {
      CallSid: CALL_SID + '_get_poll',
      CallFrom: '+919876543210',
      CallTo: '+914222609028',
      digits: '99999',
    }),
  );
  results.push(
    await testEndpoint('POLL POST no digits', 'POST', '/api/ivr/poll', {
      CallSid: CALL_SID + '_nodigit_poll',
      CallFrom: '+919876543210',
      CallTo: '+914222609028',
    }),
  );

  // ── EP3-P1: Voice Match (/api/ivr/voice-match) ────────────────────────
  console.log('\n── EP3-P1: Voice Match (/api/ivr/voice-match) ──');
  results.push(
    await testEndpoint('VOICE-MATCH POST with recording', 'POST', '/api/ivr/voice-match', {
      CallSid: CALL_SID + '_vm',
      CallFrom: '+919876543210',
      CallTo: '+914222609028',
      RecordingUrl: RECORDING_URL,
    }),
  );
  results.push(
    await testEndpoint('VOICE-MATCH POST missing recording', 'POST', '/api/ivr/voice-match', {
      CallSid: CALL_SID + '_vm_norec',
    }),
  );
  results.push(
    await testEndpoint('VOICE-MATCH GET with recording', 'GET', '/api/ivr/voice-match', {
      CallSid: CALL_SID + '_vm_get',
      CallTo: '+914222609028',
      RecordingUrl: RECORDING_URL,
    }),
  );

  // ── EP3-P2: Voice LLM (/api/ivr/voice-llm) ───────────────────────────
  console.log('\n── EP3-P2: Voice LLM (/api/ivr/voice-llm) ──');
  results.push(
    await testEndpoint('VOICE-LLM POST with recording', 'POST', '/api/ivr/voice-llm', {
      CallSid: CALL_SID + '_vl',
      CallFrom: '+919876543210',
      CallTo: '+914222609028',
      RecordingUrl: RECORDING_URL,
    }),
  );
  results.push(
    await testEndpoint('VOICE-LLM POST missing recording', 'POST', '/api/ivr/voice-llm', {
      CallSid: CALL_SID + '_vl_norec',
    }),
  );
  results.push(
    await testEndpoint('VOICE-LLM GET with recording', 'GET', '/api/ivr/voice-llm', {
      CallSid: CALL_SID + '_vl_get',
      CallTo: '+914222609028',
      RecordingUrl: RECORDING_URL,
    }),
  );

  // ── Summary ───────────────────────────────────────────────────────────
  console.log('\n═══════════════════════════════════════════════════════════════');
  const passed = results.filter(Boolean).length;
  const total = results.length;
  const allPass = passed === total;
  console.log(
    `  ${allPass ? '✅' : '❌'}  ${passed}/${total} tests passed`,
  );
  console.log('═══════════════════════════════════════════════════════════════');

  if (!allPass) process.exit(1);
}

main().catch((err) => {
  console.error('Fatal:', err);
  process.exit(1);
});
