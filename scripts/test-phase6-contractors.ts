import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { ContractorService } from '../src/contractor/contractor.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function test() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const service = app.get(ContractorService);
  const prisma = app.get(PrismaService);

  console.log('🧪 Verifying Phase 6 Contractor Management & Work Orders...');

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

  // 2. Clear previous contractor instances
  await prisma.workOrder.deleteMany({ where: { tenant_id: tenantId } });
  await prisma.contractor.deleteMany({ where: { tenant_id: tenantId } });

  // 3. Create Contractor
  const contractor = await service.createContractor(tenantId, {
    name: 'Sengotics Civil Infrastructures',
    phone: '+919944883311',
    email: 'info@sengotics.com',
    gstNumber: '33AAACS9988A1Z1',
    category: ['civil', 'plumbing'],
    rating: 4.8,
  });
  console.log(`✅ Contractor registered: ${contractor.name} (ID: ${contractor.id})`);

  // 4. Ensure SequenceConfig for work_order exists
  await prisma.sequenceConfig.upsert({
    where: {
      tenant_id_branch_id_entity_type: {
        tenant_id: tenantId,
        branch_id: branch.id,
        entity_type: 'work_order',
      },
    },
    update: {},
    create: {
      tenant_id: tenantId,
      branch_id: branch.id,
      entity_type: 'work_order',
      prefix: 'WO',
      format: '{prefix}-{fy}-{seq:5}',
      current_seq: 0,
    },
  });

  // 5. Create Work Order with Measurement Book JSON
  const measurements = [
    { desc: 'Excavation in hard soil', qty: 250, unit: 'cum', rate: 450, amount: 112500 },
    { desc: 'Laying laying HDPE pipes 110mm', qty: 300, unit: 'meters', rate: 600, amount: 180000 },
  ];

  const workOrder = await service.createWorkOrder(tenantId, {
    branchId: branch.id,
    contractorId: contractor.id,
    title: 'Thayanur Ration Shop Water Conduit Ext',
    description: 'Excavation and HDPE laying for colony pipeline.',
    estimatedCost: 292500,
    expectedCompletion: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    measurementBook: measurements,
    createdBy: 1,
  });

  console.log(`✅ Work Order created: Number = "${workOrder.work_order_number}", status = "${workOrder.status}"`);
  if (workOrder.work_order_number?.startsWith('WO-')) {
    console.log('✅ Success: Sequence generated matching configuration layout.');
  } else {
    console.error('❌ Failed: Sequence number prefix mismatch.');
  }

  // 6. Test Status transition to completed & verified
  console.log('👉 Transitioning status to completed...');
  const completeWO = await service.transitionStatus(tenantId, workOrder.id, 'completed', {
    actualCost: 290000,
  });
  console.log(`👉 WO state: status = "${completeWO.status}", actual_cost = ${completeWO.actual_cost}`);

  console.log('👉 Transitioning status to verified...');
  const verifyWO = await service.transitionStatus(tenantId, workOrder.id, 'verified', {
    completionCertUrl: 'https://storage.sengotics.gov.in/certs/wo-1024-completed.pdf',
  });
  console.log(`👉 WO state: status = "${verifyWO.status}", certificate = "${verifyWO.completion_cert_url}"`);

  if (verifyWO.status === 'verified' && verifyWO.completion_cert_url) {
    console.log('✅ Success: Work Order status transition and completion audit passed!');
  } else {
    console.error('❌ Failed: Work Order transition audit failed.');
  }

  await app.close();
}

test().catch(console.error);
