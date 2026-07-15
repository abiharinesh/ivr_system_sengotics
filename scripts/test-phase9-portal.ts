import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { SearchService } from '../src/search/search.service';
import { CitizenPortalService } from '../src/citizen-portal/citizen-portal.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function test() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const search = app.get(SearchService);
  const portal = app.get(CitizenPortalService);
  const prisma = app.get(PrismaService);

  console.log('🧪 Verifying Phase 9 Universal Search & Citizen Portal...');

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

  // 2. Clean previous portal and test user records
  await prisma.citizenFeedback.deleteMany({ where: { tenant_id: tenantId } });
  await prisma.announcement.deleteMany({ where: { tenant_id: tenantId } });
  await prisma.citizenProfile.deleteMany({ where: { tenant_id: tenantId } });
  await prisma.user.deleteMany({ where: { email: 'arun@citizen.in' } });

  // 3. Register citizen User record first (to fulfill CitizenProfile user_id FK)
  const testUser = await prisma.user.create({
    data: {
      tenant_id: tenantId,
      email: 'arun@citizen.in',
      password_hash: '$2b$10$dummyhashplaceholdertext',
      role: 'citizen',
      user_type: 'citizen',
      panchayat_id: branch.id,
      phone_e164: '+919988776655',
    },
  });
  console.log(`✅ Citizen user created (ID: ${testUser.id})`);

  // Register citizen profile linked to the test user
  const profile = await portal.createProfile(tenantId, testUser.id, {
    fullName: 'Arun Kumar',
    phone: '+919988776655',
    email: 'arun@citizen.in',
    address: '42, South Street, Thayanur',
    ward: 'Ward 3',
    branchId: branch.id,
  });
  console.log(`✅ Citizen profile created: ${profile.full_name} (ID: ${profile.id})`);

  // 4. Create announcements (one pinned, one regular)
  const ann1 = await portal.createAnnouncement(
    tenantId,
    {
      branchId: branch.id,
      title: 'Water Supply Maintenance Schedule',
      body: 'Piped water supply will be closed tomorrow from 9 AM to 1 PM due to filter bed cleansing.',
      category: 'water',
      isPinned: false,
    },
    1,
  );

  const ann2 = await portal.createAnnouncement(
    tenantId,
    {
      branchId: branch.id,
      title: '⚠️ Emergency Cholera Vaccination Camp',
      body: 'Free vaccination camp organized at the primary health center this Sunday starting at 8 AM.',
      category: 'general',
      isPinned: true,
      expiresAt: new Date(Date.now() + 5 * 24 * 60 * 60 * 1000),
    },
    1,
  );
  console.log('✅ Announcements published. 캠프 (Pinned) and Maintenance schedule (Regular).');

  // Verify list ordering (Pinned first)
  const list = await portal.getAnnouncements(tenantId, branch.id);
  console.log(`👉 Announcements list count = ${list.length}`);
  if (list[0]?.is_pinned === true) {
    console.log('✅ Success: Pinned announcement is sorted first in feeds!');
  } else {
    console.error('❌ Failed: Announcement sorting is incorrect.');
  }

  // 5. Submit Citizen Feedback
  const feedback = await portal.createFeedback(tenantId, testUser.id, {
    branchId: branch.id,
    rating: 5,
    comment: 'Panchayat desk resolved my overhead tank leakage complaint extremely fast! Very satisfied.',
  });
  console.log(`✅ Feedback registered: Rating = ${feedback.rating}, Comment = "${feedback.comment}"`);

  // 6. Test Universal Search
  console.log('\n▶ Testing Universal Search for query "Sengotics"...');
  const searchResult = await search.universalSearch(tenantId, 'Sengotics');
  console.log(`👉 Found ${searchResult.contractors.length} contractors, ${searchResult.workOrders.length} work orders`);

  if (searchResult.contractors.some((c) => c.name.includes('Sengotics'))) {
    console.log('✅ Success: Sengotics contractor found successfully!');
  } else {
    console.error('❌ Failed: Contractor search failed.');
  }

  console.log('\n▶ Testing Universal Search for query "Colony"...');
  const searchResult2 = await search.universalSearch(tenantId, 'Colony');
  console.log(`👉 Found ${searchResult2.assets.length} assets, ${searchResult2.complaints.length} complaints`);

  if (searchResult2.assets.length > 0 || searchResult2.workOrders.length > 0) {
    console.log('✅ Success: Search resolved matching assets/works correctly!');
  } else {
    console.log('ℹ Info: No assets/works matched keyword "Colony" in this database sweep.');
  }

  // 7. Clean up mock citizen details
  await prisma.citizenFeedback.delete({ where: { id: feedback.id } });
  await prisma.citizenProfile.delete({ where: { id: profile.id } });
  await prisma.user.delete({ where: { id: testUser.id } });
  console.log('✅ Test user and profile successfully cleaned up.');

  await app.close();
}

test().catch(console.error);
