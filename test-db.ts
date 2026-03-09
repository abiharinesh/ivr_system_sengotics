import { PrismaClient } from '@prisma/client';
const prisma = new PrismaClient({ datasourceUrl: process.env.DATABASE_URL });

async function check() {
    const poles = await prisma.electricPole.findMany({
        where: { panchayat_id: 28 }, // Tholampalay ? Or Thayanur ? Let's just find panchayat by name or ID
    });
    console.log("Panchayat 28 poles:", poles.length);
    for (const p of poles) {
        if (p.landmarks.length > 0) {
            console.log(`Pole ${p.id} landmarks:`, p.landmarks);
        }
    }
}

check().finally(() => prisma.$disconnect());
