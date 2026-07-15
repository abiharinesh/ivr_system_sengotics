import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { InspectionService } from '../src/inspection/inspection.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function test() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const service = app.get(InspectionService);
  const prisma = app.get(PrismaService);

  console.log('🧪 Verifying Phase 7 Field Inspections & GPS Locking Validation...');

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

  // 2. Clear previous inspections
  await prisma.fieldInspection.deleteMany({ where: { tenant_id: tenantId } });
  await prisma.inspectionTemplate.deleteMany({ where: { tenant_id: tenantId } });

  // 3. Create Inspection Template
  const template = await service.createTemplate(tenantId, {
    name: 'Standard Streetlight Maintenance Check',
    assetTypeCode: 'electric_pole',
    checklistItems: [
      { item: 'Wiring connections verified', type: 'yes_no' },
      { item: 'LED bulb functioning correctly', type: 'yes_no' },
      { item: 'Control switch verified', type: 'yes_no' },
    ],
  });
  console.log(`✅ Inspection Template created: ${template.name} (ID: ${template.id})`);

  // 4. Fetch the streetlight asset seeded in Phase 2
  const asset = await prisma.asset.findFirst({
    where: { tenant_id: tenantId, asset_code: 'AST-SL-001' },
  });

  if (!asset) {
    console.error('❌ Seeded Streetlight Asset AST-SL-001 not found.');
    await app.close();
    return;
  }
  console.log(`✅ Located target asset for inspection: ${asset.name} at coordinates (${asset.latitude}, ${asset.longitude})`);

  // 5. Test Case A: Inspector is within 100 meters (Approx. 15m away) -> should LOCK GPS
  console.log('\n▶ Submitting Inspection Case A: Inspector within bounds (approx. 15m away)...');
  const inspectA = await service.createInspection(tenantId, {
    templateId: template.id,
    branchId: branch.id,
    inspectorUserId: 1,
    assetId: asset.id,
    locationLat: 11.0171, // Target is 11.0170
    locationLng: 76.9561, // Target is 76.9560
    checklistResults: {
      'Wiring connections verified': 'yes',
      'LED bulb functioning correctly': 'yes',
      'Control switch verified': 'yes',
    },
    overallScore: 95,
    remarks: 'Routine inspection checks completed successfully.',
  });

  console.log(`👉 Inspection A: gps_locked = ${inspectA.gps_locked}, gps_accuracy_m = ${inspectA.gps_accuracy_m?.toFixed(1)}m`);
  if (inspectA.gps_locked) {
    console.log('✅ Success: GPS verification locked correctly because distance is within 100m!');
  } else {
    console.error('❌ Failed: GPS verification failed to lock within bounds.');
  }

  // 6. Test Case B: Inspector is out of bounds (Approx. 1.3km away) -> should NOT lock GPS
  console.log('\n▶ Submitting Inspection Case B: Inspector out of bounds (approx. 1.3km away)...');
  const inspectB = await service.createInspection(tenantId, {
    templateId: template.id,
    branchId: branch.id,
    inspectorUserId: 1,
    assetId: asset.id,
    locationLat: 11.0250, // Target is 11.0170
    locationLng: 76.9650, // Target is 76.9560
    checklistResults: {
      'Wiring connections verified': 'yes',
      'LED bulb functioning correctly': 'no',
      'Control switch verified': 'yes',
    },
    overallScore: 65,
    remarks: 'Bulb broken. Requires maintenance order.',
  });

  console.log(`👉 Inspection B: gps_locked = ${inspectB.gps_locked}, gps_accuracy_m = ${inspectB.gps_accuracy_m?.toFixed(1)}m`);
  if (!inspectB.gps_locked) {
    console.log('✅ Success: GPS verification rejected correctly because distance is out of bounds (> 100m)!');
  } else {
    console.error('❌ Failed: GPS verification incorrectly locked for out of bounds inspector.');
  }

  await app.close();
}

test().catch(console.error);
