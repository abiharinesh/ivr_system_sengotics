require('dotenv').config();
const { PrismaClient } = require('@prisma/client');
const { PrismaPg } = require('@prisma/adapter-pg');
const { Pool } = require('pg');
const bcrypt = require('bcrypt');

const pool = new Pool({ connectionString: process.env.DATABASE_URL });
const adapter = new PrismaPg(pool);
const prisma = new PrismaClient({ adapter });

async function safeDelete(modelName, fn) {
  try {
    await fn();
    console.log(`  - Cleared ${modelName}`);
  } catch (e) {
    console.log(`  - ${modelName} cleanup note: ${e.message}`);
  }
}

async function main() {
  console.log('🧹 Starting Complete Database Clean & Minimal Seeding...\n');

  // 1. Tender sub-tables
  await safeDelete('TenderVendorInvite', () => prisma.tenderVendorInvite.deleteMany({}));
  await safeDelete('TenderLineItem', () => prisma.tenderLineItem.deleteMany({}));
  await safeDelete('TenderQuotation', () => prisma.tenderQuotation.deleteMany({}));
  await safeDelete('TenderFieldChecklistItem', () => prisma.tenderFieldChecklistItem.deleteMany({}));
  await safeDelete('FieldVerificationUpload', () => prisma.fieldVerificationUpload.deleteMany({}));
  await safeDelete('FieldVerificationSession', () => prisma.fieldVerificationSession.deleteMany({}));
  await safeDelete('TenderAuditLog', () => prisma.tenderAuditLog.deleteMany({}));
  await safeDelete('TenderDocument', () => prisma.tenderDocument.deleteMany({}));
  await safeDelete('Tender', () => prisma.tender.deleteMany({}));
  await safeDelete('Vendor', () => prisma.vendor.deleteMany({}));

  // 2. IVR & Complaints
  await safeDelete('IvrServiceSelection', () => prisma.ivrServiceSelection.deleteMany({}));
  await safeDelete('IvrPollInput', () => prisma.ivrPollInput.deleteMany({}));
  await safeDelete('Complaint', () => prisma.complaint.deleteMany({}));
  await safeDelete('CallsMaster', () => prisma.callsMaster.deleteMany({}));
  await safeDelete('VoiceCall', () => prisma.voiceCall.deleteMany({}));

  // 3. Infrastructure Assets & IoT
  await safeDelete('ElectricPole', () => prisma.electricPole.deleteMany({}));
  await safeDelete('WaterFlowLog', () => prisma.waterFlowLog.deleteMany({}));
  await safeDelete('WaterPipeline', () => prisma.waterPipeline.deleteMany({}));
  await safeDelete('WaterTankBorewell', () => prisma.waterTankBorewell.deleteMany({}));
  await safeDelete('WaterValve', () => prisma.waterValve.deleteMany({}));
  await safeDelete('CapturedAsset', () => prisma.capturedAsset.deleteMany({}));

  // 4. Revenue Modules
  await safeDelete('AdImpression', () => prisma.adImpression.deleteMany({}));
  await safeDelete('AdCampaign', () => prisma.adCampaign.deleteMany({}));
  await safeDelete('UserPenalty', () => prisma.userPenalty.deleteMany({}));
  await safeDelete('PenaltyRule', () => prisma.penaltyRule.deleteMany({}));
  await safeDelete('TaxPayment', () => prisma.taxPayment.deleteMany({}));
  await safeDelete('Property', () => prisma.property.deleteMany({}));
  await safeDelete('CertificateRequest', () => prisma.certificateRequest.deleteMany({}));
  await safeDelete('AssetBooking', () => prisma.assetBooking.deleteMany({}));
  await safeDelete('PanchayatAsset', () => prisma.panchayatAsset.deleteMany({}));
  await safeDelete('MarketVendorPayment', () => prisma.marketVendorPayment.deleteMany({}));
  await safeDelete('MarketVendor', () => prisma.marketVendor.deleteMany({}));
  await safeDelete('MarketDay', () => prisma.marketDay.deleteMany({}));
  await safeDelete('WaterBill', () => prisma.waterBill.deleteMany({}));
  await safeDelete('WaterConnection', () => prisma.waterConnection.deleteMany({}));
  await safeDelete('PoleLeaseAgreement', () => prisma.poleLeaseAgreement.deleteMany({}));

  // 5. Profiles, Roles, & System
  await safeDelete('DesignationHistory', () => prisma.designationHistory.deleteMany({}));
  await safeDelete('Employee', () => prisma.employee.deleteMany({}));
  await safeDelete('CitizenProfile', () => prisma.citizenProfile.deleteMany({}));
  await safeDelete('UserRole', () => prisma.userRole.deleteMany({}));
  await safeDelete('ExportJob', () => prisma.exportJob.deleteMany({}));

  // 6. Branch Governance & Zones
  await safeDelete('Department', () => prisma.department.deleteMany({}));
  await safeDelete('BranchFeatureConfig', () => prisma.branchFeatureConfig.deleteMany({}));
  await safeDelete('WorkflowStepHistory', () => prisma.workflowStepHistory.deleteMany({}));
  await safeDelete('WorkflowStepInstance', () => prisma.workflowStepInstance.deleteMany({}));
  await safeDelete('WorkflowInstance', () => prisma.workflowInstance.deleteMany({}));
  await safeDelete('WorkflowTemplate', () => prisma.workflowTemplate.deleteMany({}));
  await safeDelete('BranchLifecycleEvent', () => prisma.branchLifecycleEvent.deleteMany({}));
  await safeDelete('Role', () => prisma.role.deleteMany({}));
  await safeDelete('PanchayatZone', () => prisma.panchayatZone.deleteMany({}));

  // 7. Clear Users
  await safeDelete('User', () => prisma.user.deleteMany({}));

  // 8. Clear Panchayats
  await prisma.panchayat.updateMany({
    data: { parent_branch_id: null, merged_into_id: null, upgraded_to_id: null },
  }).catch(() => {});
  await safeDelete('Panchayat', () => prisma.panchayat.deleteMany({}));

  // 9. Seed 1 Primary Panchayat
  const primaryPanchayat = await prisma.panchayat.create({
    data: {
      name: 'ஆலந்தூர் கிராம ஊராட்சி',
      branch_code: 'TN-PNC-01',
      branch_type: 'VILLAGE_PANCHAYAT',
      branch_status: 'ACTIVE',
      district: 'Chengalpattu',
      taluk: 'Alandur',
      address: 'No. 1, Main Panchayat Office Road, Alandur, Chengalpattu - 600016',
      contact_phone: '+91 98401 23456',
      contact_email: 'admin@sengotics.com',
      ivr_number: '1800-425-0014',
      software_name_ta: 'ஊராட்சி குரல்',
      software_name_en: 'Ooratchi Kural',
      software_tagline_ta: 'குடிமக்கள் சேவை மையம்',
      software_tagline_en: 'Citizen Service Portal',
      logo_url: '/uploads/logos/default_emblem.png',
      primary_color: '#006C4A',
      secondary_color: '#0EA5E9',
      ward_count: 12,
    },
  });

  console.log(`\n✅ Primary Panchayat created: #${primaryPanchayat.id} - ${primaryPanchayat.name} (${primaryPanchayat.branch_code})`);

  // 10. Seed 1 Super Admin & 1 Panchayat Admin
  const passwordHash = await bcrypt.hash('Password@123', 10);

  const superAdmin = await prisma.user.create({
    data: {
      email: 'superadmin@sengotics.com',
      password_hash: passwordHash,
      role: 'super_admin',
      user_type: 'employee',
      phone_e164: '+919999900001',
      is_active: true,
      is_verified: true,
    },
  });

  console.log(`✅ Super Admin created: #${superAdmin.id} - ${superAdmin.email} (Role: ${superAdmin.role})`);

  const panchayatAdmin = await prisma.user.create({
    data: {
      email: 'admin@sengotics.com',
      password_hash: passwordHash,
      role: 'panchayat_admin',
      user_type: 'employee',
      panchayat_id: primaryPanchayat.id,
      phone_e164: '+919840123456',
      is_active: true,
      is_verified: true,
    },
  });

  console.log(`✅ Panchayat Admin created: #${panchayatAdmin.id} - ${panchayatAdmin.email} (Role: ${panchayatAdmin.role}, Panchayat ID: ${primaryPanchayat.id})`);

  // Create Employee record for Panchayat Admin
  await prisma.employee.create({
    data: {
      tenant_id: 'default',
      user_id: panchayatAdmin.id,
      employee_code: 'TN-PA-2026-101',
      service_book_number: 'SB-TN-2026-001',
      branch_id: primaryPanchayat.id,
      designation: 'Panchayat Administrative Officer',
      cadre: 'TNCS',
      status: 'active',
    },
  });

  console.log('✅ Employee service record linked to Panchayat Admin.');

  // Final summary check
  const finalPanchayatCount = await prisma.panchayat.count();
  const finalUserCount = await prisma.user.count();

  console.log('\n=============================================================');
  console.log(`🎉 DATABASE CLEANUP COMPLETE!`);
  console.log(`   - Total Panchayats in DB: ${finalPanchayatCount}`);
  console.log(`   - Total Users in DB: ${finalUserCount}`);
  console.log('=============================================================\n');
  console.log('🔑 Credentials Summary:');
  console.log('   1. Super Admin: superadmin@sengotics.com / Password@123');
  console.log('   2. Panchayat Admin: admin@sengotics.com / Password@123');
  console.log('=============================================================\n');
}

main()
  .catch((err) => {
    console.error('❌ Reset script error:', err);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
    await pool.end();
  });
