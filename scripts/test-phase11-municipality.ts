import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { MunicipalityService } from '../src/municipality/municipality.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function test() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const service = app.get(MunicipalityService);
  const prisma = app.get(PrismaService);

  console.log('🧪 Verifying Phase 11 Municipality Modules & Feature Gating...');

  const tenantId = 'default';

  // 1. Fetch Thayanur branch
  const branch = await prisma.orgUnit.findFirst({
    where: { tenant_id: tenantId, name: 'Thayanur Village Panchayat' },
  });

  if (!branch) {
    console.error('❌ Thayanur Village Panchayat not found.');
    await app.close();
    return;
  }

  // 2. Clean previous submissions of municipality type
  await prisma.formSubmission.deleteMany({
    where: {
      tenant_id: tenantId,
      branch_id: branch.id,
      entity_type: { startsWith: 'muni_' },
    },
  });

  // 3. Configure BranchFeatureConfig for Thayanur
  await prisma.branchFeatureConfig.upsert({
    where: { panchayat_id: branch.id },
    update: {
      building_permit: true,
      solid_waste_mgmt: true,
      cemetery_mgmt: false, // Explicitly disabled
    },
    create: {
      panchayat_id: branch.id,
      building_permit: true,
      solid_waste_mgmt: true,
      cemetery_mgmt: false,
    },
  });
  console.log('✅ Feature toggles configured: building_permit=ON, solid_waste_mgmt=ON, cemetery_mgmt=OFF.');

  // 4. Test Case A: Submit Building Permit application (Enabled -> should PASS)
  console.log('\n▶ Submitting transaction for building_permit...');
  try {
    const permit = await service.recordTransaction(tenantId, branch.id, 'building_permit', 1, {
      applicant_name: 'Kumar Swamy',
      plot_area_sqft: 2400,
      proposed_floors: 2,
      use_type: 'residential',
    });
    console.log(`✅ Success: Transaction recorded! Submission ID: ${permit.id}, Type: ${permit.entity_type}`);
  } catch (err) {
    console.error(`❌ Unexpected failure: ${err.message}`);
  }

  // 5. Test Case B: Submit Cemetery slot booking (Disabled -> should FAIL with Forbidden)
  console.log('\n▶ Submitting transaction for cemetery_mgmt (Disabled feature)...');
  try {
    await service.recordTransaction(tenantId, branch.id, 'cemetery_mgmt', 1, {
      deceased_name: 'Late Rama Iyer',
      burial_date: '2026-07-20',
      slot_id: 'C-14',
    });
    console.error('❌ Failed: Cemetery transaction should have been blocked by feature gating but passed!');
  } catch (err) {
    console.log(`✅ Success: Transaction blocked correctly with message: "${err.message}"`);
  }

  await app.close();
}

test().catch(console.error);
