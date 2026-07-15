import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { SyncService } from '../src/sync/sync.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function test() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const service = app.get(SyncService);
  const prisma = app.get(PrismaService);

  console.log('🧪 Verifying Phase 10 Offline Sync & Conflict Resolution...');

  const tenantId = 'default';

  // 1. Fetch Thayanur branch
  const branch = await prisma.panchayat.findFirst({
    where: { tenant_id: tenantId, name: 'Thayanur Village Panchayat' },
  });

  if (!branch) {
    console.error('❌ Thayanur Village Panchayat not found.');
    await app.close();
    return;
  }

  // 2. Clean previous test sync records
  await prisma.fieldInspection.deleteMany({ where: { tenant_id: tenantId } });
  await prisma.complaint.deleteMany({ where: { panchayat_id: branch.id } });

  // 3. Seed an existing complaint on the server (simulating already synced)
  const existingComplaint = await prisma.complaint.create({
    data: {
      panchayat_id: branch.id,
      complaint_type: 'electric_pole',
      description: 'Streetlight blinking on Main Road.',
      status: 'pending',
    },
  });
  console.log(`✅ Seeded existing complaint: ID = ${existingComplaint.id}, Status = "${existingComplaint.status}"`);

  // 4. Test Scenario A: Upload Sync (Create Complaint and Inspection)
  console.log('\n▶ Uploading Sync Queue (2 operations)...');
  const syncPayload = {
    lastSyncTime: new Date(Date.now() - 60000).toISOString(), // Synced 1 min ago
    operations: [
      {
        id: 'offline-uuid-complaint-100',
        table: 'complaints' as const,
        action: 'create' as const,
        clientTimestamp: new Date().toISOString(),
        data: {
          complaint_type: 'water_leakage',
          description: 'Pipeline broken near ration shop.',
          status: 'pending',
        },
      },
      {
        id: 'offline-uuid-inspect-200',
        table: 'inspections' as const,
        action: 'create' as const,
        clientTimestamp: new Date().toISOString(),
        data: {
          template_id: 1, // Created in Phase 7 test
          asset_id: 1,
          location_lat: 11.0171,
          location_lng: 76.9561,
          checklist_results: { 'Bulb functioning correctly': 'yes' },
          overall_score: 90,
          remarks: 'Offline survey verified.',
        },
      },
    ],
  };

  const uploadResult = await service.processSyncUpload(tenantId, branch.id, 1, syncPayload);
  console.log(`👉 Upload results count = ${uploadResult.results.length}`);
  uploadResult.results.forEach((r) => {
    console.log(`  - Op ID: ${r.id}, Success: ${r.success}, Server ID: ${r.serverId}, Action: ${r.action}`);
  });

  const createdComplaint = uploadResult.results.find((r) => r.id === 'offline-uuid-complaint-100');
  const createdInspection = uploadResult.results.find((r) => r.id === 'offline-uuid-inspect-200');

  if (createdComplaint?.success && createdInspection?.success) {
    console.log('✅ Success: Offline created records successfully synced to server!');
  } else {
    console.error('❌ Failed: Offline creations sync failed.');
  }

  // 5. Test Scenario B: Conflict Resolution Check (Server wins)
  console.log('\n▶ Simulating Sync Update with Conflict (lastSyncTime older than server record)...');
  const conflictPayload = {
    lastSyncTime: new Date(Date.now() - 300000).toISOString(), // synced 5 mins ago (older than seed created_at)
    operations: [
      {
        id: 'offline-uuid-update-300',
        table: 'complaints' as const,
        action: 'update' as const,
        clientTimestamp: new Date().toISOString(),
        data: {
          id: existingComplaint.id,
          status: 'resolved',
          description: 'Client overrides description.',
        },
      },
    ],
  };

  const conflictResult = await service.processSyncUpload(tenantId, branch.id, 1, conflictPayload);
  const updateOp = conflictResult.results[0];
  console.log(`👉 Update Op ID: ${updateOp?.id}, Success: ${updateOp?.success}, Conflict: ${updateOp?.conflict}`);

  if (updateOp?.conflict === 'server-wins') {
    console.log('✅ Success: Conflict detected and resolved using "server-wins" strategy correctly!');
  } else {
    console.error('❌ Failed: Conflict resolution check failed.');
  }

  // 6. Test Scenario C: Delta changes retrieval
  console.log('\n▶ Downloading Delta Sync changes since 5 seconds ago...');
  const deltaResult = await service.getSyncDelta(tenantId, branch.id, new Date(Date.now() - 5000).toISOString());
  console.log(`👉 Delta output: complaints count = ${deltaResult.delta.complaints.length}, assets count = ${deltaResult.delta.assets.length}`);

  if (deltaResult.delta.complaints.length > 0) {
    console.log('✅ Success: Delta sync downloaded newly created complaints correctly!');
  } else {
    console.error('❌ Failed: Delta sync retrieval failed.');
  }

  await app.close();
}

test().catch(console.error);
