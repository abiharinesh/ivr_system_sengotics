import * as path from 'path'
require('dotenv').config({ path: path.join(__dirname, '.env') })
import { PrismaClient } from '@prisma/client'

const prisma = new PrismaClient()

async function main() {
    console.log('Updating AI provider to rapidapi in database...')
    const setting = await prisma.systemSettings.upsert({
        where: { key: 'ai_provider' },
        update: { value: 'rapidapi' },
        create: {
            key: 'ai_provider',
            value: 'rapidapi'
        }
    })
    console.log('Successfully updated provider:', setting)
}

main()
    .catch((e) => {
        console.error(e)
        process.exit(1)
    })
    .finally(async () => {
        await prisma.$disconnect()
    })
