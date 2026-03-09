import { NestFactory } from '@nestjs/core';
import { AppModule } from './src/app.module';
import { VoiceProcessingService } from './src/voice-processing/voice-processing.service';
import { PrismaService } from './src/prisma/prisma.service';

async function bootstrap() {
    console.log('Initializing Application Context...');
    const app = await NestFactory.createApplicationContext(AppModule);
    const voiceService = app.get(VoiceProcessingService);
    const prisma = app.get(PrismaService);

    console.log('Fetching a valid Panchayat...');
    const panchayat = await prisma.panchayat.findFirst({
        where: { ivr_number: '04440115434' } // Tholampalay
    });

    if (!panchayat) {
        console.error('No panchayat found with an IVR number!');
        await app.close();
        return;
    }

    // Test parameters
    const ivrNumber = '04440115434'; // Tholampalay Panchayat IVR Number
    const audioUrl = 'https://recordings.exotel.com/exotelrecordings/nexerawe1/4f93e674c92cc78d9ae012ea6c1e1a3a.mp3';
    const callSid = `test-call-live-${Date.now()}`;

    // ==========================================
    // TEST 1: PHASE 1 DIRECT DB MATCH
    // ==========================================
    console.log(`\n======================================================`);
    console.log(`🧪 TEST SCENARIO 1: PHASE 1 (FAST DIRECT DB MATCH)`);
    console.log(`======================================================\n`);

    const callSid1 = `TEST-PHASE1-${Date.now()}`;

    console.log(`CallSid: ${callSid1}`);
    console.log(`Downloading Audio From: "${audioUrl}"\n`);

    try {
        const result1 = await voiceService.processVoiceComplaint(callSid1, audioUrl, ivrNumber);

        console.log('\n⏳ Waiting 5 seconds for async background LLM enrichment to finish...');
        await new Promise(r => setTimeout(r, 5000));

        if (result1.complaintId) {
            const complaint = await prisma.complaint.findUnique({
                where: { id: result1.complaintId }
            });
            console.log('\n📄 [PHASE 1] Final Complaint Data in DB:\n', JSON.stringify(complaint, null, 2));
        }
    } catch (e) {
        console.error('❌ Phase 1 Pipeline Error:', e);
    }

    // ==========================================
    // TEST 2: PHASE 2 LLM MATCHING
    // ==========================================
    console.log(`\n\n======================================================`);
    console.log(`🧪 TEST SCENARIO 2: PHASE 2 (LLM FALLBACK MATCHING)`);
    console.log(`======================================================\n`);

    const callSid2 = `TEST-PHASE2-${Date.now()}`;
    const mockTranscript2 = "enga street la light eriyala, ration shop pakkathula"
    voiceService['voiceToText'].transcribeAudio = async () => mockTranscript2

    // Force strict match to fail so we observe Phase 2 LLM execution
    const originalStrictMatch = voiceService['geoMatching'].strictMatchPole.bind(voiceService['geoMatching'])
    voiceService['geoMatching'].strictMatchPole = async () => null

    console.log(`CallSid: ${callSid2}`);
    console.log(`Audio Transcript: "${mockTranscript2}"`);
    console.log(`(Forcing Phase 1 strict match to fail so it cascades to Phase 2 LLM)\n`);

    try {
        const result2 = await voiceService.processVoiceComplaint(callSid2, audioUrl, ivrNumber);

        if (result2.complaintId) {
            const complaint = await prisma.complaint.findUnique({
                where: { id: result2.complaintId }
            });
            console.log('\n📄 [PHASE 2] Final Complaint Data in DB:\n', JSON.stringify(complaint, null, 2));
        } else {
            console.log('\n⚠️ [PHASE 2] Complaint was not created (likely low confidence or no matched pole). Result:', result2);
        }
    } catch (e) {
        console.error('❌ Phase 2 Pipeline Error:', e);
    }

    // Restore
    voiceService['geoMatching'].strictMatchPole = originalStrictMatch

    await app.close();
    process.exit(0);
}

bootstrap().catch(e => {
    console.error(e);
    process.exit(1);
});
