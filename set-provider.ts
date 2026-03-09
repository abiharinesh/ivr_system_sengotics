import * as path from 'path'
require('dotenv').config({ path: path.join(__dirname, '.env') })
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
    const sttProvider = process.argv[2] || 'groq'
    const llmProvider = process.argv[3] || 'groq'

    console.log(`Setting STT provider → "${sttProvider}"`)
    const stt = await prisma.systemSettings.upsert({
        where: { key: 'stt_provider' },
        update: { value: sttProvider },
        create: { key: 'stt_provider', value: sttProvider }
    })

    console.log(`Setting LLM provider → "${llmProvider}"`)
    const llm = await prisma.systemSettings.upsert({
        where: { key: 'llm_provider' },
        update: { value: llmProvider },
        create: { key: 'llm_provider', value: llmProvider }
    })

    console.log('Done!', { stt: stt.value, llm: llm.value })
}

main()
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
    .finally(async () => {
        await prisma.$disconnect()
    })
