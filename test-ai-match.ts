import { NestFactory } from '@nestjs/core';
import { AppModule } from './src/app.module';
import { GeoMatchingService } from './src/voice-processing/geo-matching.service';

async function test() {
    const app = await NestFactory.createApplicationContext(AppModule);
    const geoMatching = app.get(GeoMatchingService);

    // Some fake poles to test the prompt
    const poles = [
        { id: 1, pole_number: 'P1', landmarks: ["near big banyan tree", "near mariamman temple"] },
        { id: 2, pole_number: 'P2', landmarks: ["near old government school"] },
        { id: 3, pole_number: 'P3', landmarks: ["ration shop", "water tank"] },
    ];

    // Simulate Tamil audio clues 
    // "periya maram kitta" -> "near big tree"
    // "mariamman kovil pakkathula" -> "near mariamman temple"
    const hints = ["periya maram kitta", "kovil pakkathula light eriyala"];

    console.log("Running AI Match...");
    // @ts-ignore - accessing private for testing
    const result = await geoMatching.aiMatchWithRetry(hints, poles);
    console.log("Matched Pole ID:", result);

    await app.close();
}

test().catch(console.error);
