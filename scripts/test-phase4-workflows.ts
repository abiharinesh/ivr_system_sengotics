import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { WorkflowService } from '../src/core/workflow/workflow.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function test() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const workflow = app.get(WorkflowService);
  const prisma = app.get(PrismaService);

  console.log('🧪 Verifying Phase 4 Workflow Conditional Routing...');

  // Clean up any previous test instances
  await prisma.workflowInstance.deleteMany({
    where: { entity_type: 'WorkOrder' },
  });

  const woA = await prisma.workOrder.findFirst({
    where: { title: 'Minor Drain Cleaning Thayanur' },
  });

  const woB = await prisma.workOrder.findFirst({
    where: { title: 'Main Road Water conduit replacement' },
  });

  if (!woA || !woB) {
    console.error('❌ Seeding data missing.');
    await app.close();
    return;
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Test WO-A: Cost 45k (Should skip Step 2 AE & Step 3 BDO, completing after Step 1 JE approval)
  // ───────────────────────────────────────────────────────────────────────────
  console.log(`\n▶ Starting workflow for WO-A (Cost: ${woA.estimated_cost})...`);
  const instanceA = await workflow.startWorkflow(
    'default',
    woA.branch_id,
    'work_order_approval',
    'WorkOrder',
    woA.id,
  );

  console.log(`👉 WO-A started: status = "${instanceA?.status}", step_order = ${instanceA?.current_step_order}`);
  if (instanceA?.status === 'in_progress' && instanceA?.current_step_order === 1) {
    console.log('✅ Success: WO-A initiated at Step 1 (JE Review).');
  } else {
    console.error('❌ Failed: WO-A did not initiate correctly.');
  }

  console.log('👉 Approving Step 1 (JE Review) for WO-A...');
  const nextA = await workflow.processAction(
    'default',
    instanceA!.id,
    1,
    'approved',
    'JE approved and checked measurements.',
  );

  console.log(`👉 WO-A next state: status = "${nextA?.status}", step_order = ${nextA?.current_step_order}`);
  if (nextA?.status === 'completed') {
    console.log('✅ Success: WO-A skipped Step 2 & 3 and completed immediately!');
  } else {
    console.error('❌ Failed: WO-A did not skip AE/BDO approvals.');
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Test WO-B: Cost 175k (Should keep all steps, progressing JE -> AE -> BDO -> Complete)
  // ───────────────────────────────────────────────────────────────────────────
  console.log(`\n▶ Starting workflow for WO-B (Cost: ${woB.estimated_cost})...`);
  const instanceB = await workflow.startWorkflow(
    'default',
    woB.branch_id,
    'work_order_approval',
    'WorkOrder',
    woB.id,
  );

  console.log(`👉 WO-B started: status = "${instanceB?.status}", step_order = ${instanceB?.current_step_order}`);
  if (instanceB?.status === 'in_progress' && instanceB?.current_step_order === 1) {
    console.log('✅ Success: WO-B initiated at Step 1 (JE Review).');
  } else {
    console.error('❌ Failed: WO-B did not initiate correctly.');
  }

  console.log('👉 Approving Step 1 (JE Review) for WO-B...');
  const step2B = await workflow.processAction(
    'default',
    instanceB!.id,
    1,
    'approved',
    'JE checks ok.',
  );
  console.log(`👉 WO-B next state: status = "${step2B?.status}", step_order = ${step2B?.current_step_order}`);
  if (step2B?.status === 'in_progress' && step2B?.current_step_order === 2) {
    console.log('✅ Success: WO-B kept Step 2 (AE Approval).');
  } else {
    console.error('❌ Failed: WO-B skipped AE Approval.');
  }

  console.log('👉 Approving Step 2 (AE Approval) for WO-B...');
  const step3B = await workflow.processAction(
    'default',
    step2B!.id,
    1,
    'approved',
    'AE approves funding scope.',
  );
  console.log(`👉 WO-B next state: status = "${step3B?.status}", step_order = ${step3B?.current_step_order}`);
  if (step3B?.status === 'in_progress' && step3B?.current_step_order === 3) {
    console.log('✅ Success: WO-B kept Step 3 (BDO Approval).');
  } else {
    console.error('❌ Failed: WO-B skipped BDO Approval.');
  }

  console.log('👉 Approving Step 3 (BDO Approval) for WO-B...');
  const finalB = await workflow.processAction(
    'default',
    step3B!.id,
    1,
    'approved',
    'BDO executes administrative sanction.',
  );
  console.log(`👉 WO-B final state: status = "${finalB?.status}", step_order = ${finalB?.current_step_order}`);
  if (finalB?.status === 'completed') {
    console.log('✅ Success: WO-B traversed all steps and completed!');
  } else {
    console.error('❌ Failed: WO-B did not complete correctly.');
  }

  await app.close();
}

test().catch(console.error);
