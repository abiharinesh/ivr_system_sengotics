import { NestFactory } from '@nestjs/core';
import { AppModule } from '../src/app.module';
import { ReportsService } from '../src/reports/reports.service';
import { PrismaService } from '../src/prisma/prisma.service';

async function test() {
  const app = await NestFactory.createApplicationContext(AppModule);
  const service = app.get(ReportsService);
  const prisma = app.get(PrismaService);

  console.log('🧪 Verifying Phase 8 Dashboard & Reporting Engine...');

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

  // 2. Clean previous instances
  await prisma.roleDashboard.deleteMany({ where: { tenant_id: tenantId } });
  await prisma.dashboardWidget.deleteMany({ where: { tenant_id: tenantId } });
  await prisma.savedReport.deleteMany({ where: { tenant_id: tenantId } });

  // 3. Create Dashboard Widgets
  const widget1 = await service.createWidget(tenantId, {
    code: 'complaint_trends_line',
    title: 'Complaints Trend Analytics',
    widget_type: 'line_chart',
    data_source: 'complaints',
    query_config: { rangeDays: 30, group: 'day' },
  });

  const widget2 = await service.createWidget(tenantId, {
    code: 'water_telemetry_kpi',
    title: 'Water Level Reservoirs KPI',
    widget_type: 'kpi',
    data_source: 'waterSupply',
    query_config: { refreshSeconds: 60 },
  });

  console.log(`✅ Dashboard widgets created. Trend Widget ID: ${widget1.id}, Telemetry Widget ID: ${widget2.id}`);

  // 4. Create Role Dashboard
  const roleDash = await service.updateRoleDashboard(
    tenantId,
    'panchayat_admin',
    [widget1.id, widget2.id],
    { grid: '2-column', positions: [0, 1] },
  );

  console.log(`✅ Role dashboard configured for "panchayat_admin" with ${roleDash.widget_ids.length} widgets.`);

  // 5. Create Saved Report with Cron layout
  const savedReport = await service.createSavedReport(tenantId, branch.id, {
    name: 'Weekly Water Supply & Telemetry Report',
    report_type: 'waterSupply',
    format: 'html',
    filters: {},
    schedule_cron: '0 8 * * 1', // Weekly on Mondays at 8 AM
    email_to: ['bdo@thayanur.tn.gov.in'],
    created_by: 1,
  });

  console.log(`✅ Saved Report scheduled: "${savedReport.name}" (Format: ${savedReport.format}, Cron: "${savedReport.schedule_cron}")`);

  // 6. Trigger Report Generation
  console.log('👉 Triggering on-demand generation for saved report...');
  const result = await service.triggerReportGeneration(tenantId, savedReport.id);

  console.log(`👉 Generation complete! Updated last_generated = ${result.report.last_generated?.toISOString()}`);
  console.log(`👉 Payload preview:\n${result.payload_preview}`);

  if (result.report.last_generated && result.payload_preview.includes('<!DOCTYPE html>')) {
    console.log('✅ Success: Dashboard & Reporting engine verified successfully!');
  } else {
    console.error('❌ Failed: Report generation or telemetry compilation failed.');
  }

  await app.close();
}

test().catch(console.error);
