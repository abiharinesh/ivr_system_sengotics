import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { FormService } from '../src/form/form.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function test() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const service = app.get(FormService);
  const prisma = app.get(PrismaService);

  console.log('🧪 Verifying Phase 5 Dynamic Form Builder & Validation...');

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

  // 2. Clean previous template
  const existing = await prisma.formTemplate.findFirst({
    where: { tenant_id: tenantId, code: 'leak_report_form' },
  });
  if (existing) {
    await prisma.formTemplate.delete({ where: { id: existing.id } });
  }

  // 3. Create a form template with fields
  const template = await service.createTemplate(tenantId, {
    code: 'leak_report_form',
    name: 'Water Leak Custom Fields',
    module: 'complaints',
    version: 1,
    fields: [
      {
        field_key: 'leak_type',
        field_type: 'select',
        label: 'Leak Severity Type',
        options: ['major', 'minor', 'none'],
        display_order: 1,
        is_required: true,
      },
      {
        field_key: 'leak_location',
        field_type: 'text',
        label: 'Leak Location Detail',
        display_order: 2,
        is_required: true,
        visible_when: { field: 'leak_type', value: 'major' },
      },
      {
        field_key: 'leak_flow_rate',
        field_type: 'number',
        label: 'Est Flow Rate (LPS)',
        display_order: 3,
        is_required: false,
        validation: { min: 1, max: 100 },
        visible_when: { field: 'leak_type', value: 'major' },
      },
    ],
  });
  console.log(`✅ Form template created. ID: ${template.id}`);

  // 4. Test Submission A (leak_type: "none" -> conditional fields hidden, should PASS)
  console.log('\n▶ Submission A: leak_type = "none"');
  try {
    const subA = await service.submitForm(tenantId, branch.id, template.id, null, {
      leak_type: 'none',
    });
    console.log(`✅ Success: Submission A passed! Submission ID: ${subA.id}`);
  } catch (err) {
    console.error(`❌ Unexpected error: ${err.message}`);
  }

  // 5. Test Submission B (leak_type: "major", no location -> visible & required, should FAIL)
  console.log('\n▶ Submission B: leak_type = "major" (missing location)');
  try {
    await service.submitForm(tenantId, branch.id, template.id, null, {
      leak_type: 'major',
    });
    console.error('❌ Failed: Submission B should have failed validation but passed!');
  } catch (err) {
    console.log(`✅ Success: Submission B rejected correctly: ${err.message}`);
  }

  // 6. Test Submission C (leak_type: "major", location ok, flow rate 150 -> exceeds max 100, should FAIL)
  console.log('\n▶ Submission C: leak_type = "major" (flow rate out of bounds)');
  try {
    await service.submitForm(tenantId, branch.id, template.id, null, {
      leak_type: 'major',
      leak_location: 'West Mada Street corner',
      leak_flow_rate: 150,
    });
    console.error('❌ Failed: Submission C should have failed validation but passed!');
  } catch (err) {
    console.log(`✅ Success: Submission C rejected correctly: ${err.message}`);
  }

  // 7. Test Submission D (leak_type: "major", location ok, flow rate 45 -> within bounds, should PASS)
  console.log('\n▶ Submission D: leak_type = "major" (valid input)');
  try {
    const subD = await service.submitForm(tenantId, branch.id, template.id, null, {
      leak_type: 'major',
      leak_location: 'West Mada Street corner',
      leak_flow_rate: 45,
    });
    console.log(`✅ Success: Submission D passed! Submission ID: ${subD.id}`);
  } catch (err) {
    console.error(`❌ Unexpected error: ${err.message}`);
  }

  await app.close();
}

test().catch(console.error);
