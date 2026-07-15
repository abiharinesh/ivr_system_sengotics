import { PrismaClient } from '@prisma/client';
import { PrismaPg } from '@prisma/adapter-pg';
import { Pool } from 'pg';
import * as dotenv from 'dotenv';

dotenv.config();

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function main() {
  console.log('🌱 Seeding Phase 4 Workflow Engine & Conditional Routing...');

  const tenantId = 'default';

  // 1. Fetch Thayanur branch
  const branch = await prisma.panchayat.findFirst({
    where: { tenant_id: tenantId, name: 'Thayanur Village Panchayat' },
  });

  if (!branch) {
    console.error('❌ Thayanur Village Panchayat not found.');
    return;
  }

  // 2. Create Workflow Template for work orders
  let template = await prisma.workflowTemplate.findFirst({
    where: {
      panchayat_id: branch.id,
      name: 'work_order_approval',
    },
  });

  if (!template) {
    template = await prisma.workflowTemplate.create({
      data: {
        tenant_id: tenantId,
        panchayat_id: branch.id,
        name: 'work_order_approval',
        description: 'Multi-stage approval for Panchayat Work Orders',
        version: 1,
        status: 'published',
        is_active: true,
      },
    });
  }
  console.log(`✅ Verified Workflow Template: ${template.name} (ID: ${template.id})`);

  // 3. Create Steps
  await prisma.workflowStep.deleteMany({ where: { template_id: template.id } });

  const step1 = await prisma.workflowStep.create({
    data: {
      template_id: template.id,
      step_order: 1,
      role_name: 'je',
      action_type: 'review',
      is_required: true,
    },
  });

  const step2 = await prisma.workflowStep.create({
    data: {
      template_id: template.id,
      step_order: 2,
      role_name: 'ae',
      action_type: 'approve',
      is_required: true,
    },
  });

  const step3 = await prisma.workflowStep.create({
    data: {
      template_id: template.id,
      step_order: 3,
      role_name: 'bdo',
      action_type: 'approve',
      is_required: true,
    },
  });
  console.log(`✅ Created Workflow Steps (1: JE Review, 2: AE Approval, 3: BDO Approval).`);

  // 4. Create Rules
  await prisma.workflowRule.deleteMany({ where: { template_id: template.id } });

  // Rule 1: Skip AE Approval (Step 2) if estimated_cost < 1 Lakh (100000)
  const rule1 = await prisma.workflowRule.create({
    data: {
      template_id: template.id,
      step_id: step2.id,
      condition_field: 'estimated_cost',
      condition_op: 'lt',
      condition_value: 100000,
      then_action: 'skip_step',
      priority: 1,
    },
  });

  // Rule 2: Skip BDO Approval (Step 3) if estimated_cost < 50,000
  const rule2 = await prisma.workflowRule.create({
    data: {
      template_id: template.id,
      step_id: step3.id,
      condition_field: 'estimated_cost',
      condition_op: 'lt',
      condition_value: 50000,
      then_action: 'skip_step',
      priority: 1,
    },
  });
  console.log(`✅ Configured Rules: Skip Step 2 if cost < ₹1L | Skip Step 3 if cost < ₹50k`);

  // 5. Create Mock Work Order records to test rules evaluation
  const wo1 = await prisma.workOrder.create({
    data: {
      tenant_id: tenantId,
      branch_id: branch.id,
      title: 'Minor Drain Cleaning Thayanur',
      estimated_cost: 45000, // < 50k, should skip step 2 AND step 3!
      created_by: 1,
      status: 'pending',
    },
  });

  const wo2 = await prisma.workOrder.create({
    data: {
      tenant_id: tenantId,
      branch_id: branch.id,
      title: 'Main Road Water conduit replacement',
      estimated_cost: 175000, // > 100k, should NOT skip AE approval (Step 2) or BDO (Step 3)
      created_by: 1,
      status: 'pending',
    },
  });
  console.log(`✅ Created Work Orders: WO-A (Cost: 45k, skips step 2 & 3) & WO-B (Cost: 175k, keeps all steps)`);

  console.log('✅ Phase 4 Workflow Seeding completed.');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
