require('dotenv/config')
const { PrismaClient } = require('@prisma/client')
const { PrismaPg } = require('@prisma/adapter-pg')
const { Pool } = require('pg')
const bcrypt = require('bcrypt')

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
    const email = 'admin@thayanur.com'
    const password = 'Admin@1234'

    const existing = await prisma.user.findUnique({ where: { email } })
    if (existing) {
        console.log('✅ Admin already exists:', email)
        return
    }

    const panchayat = await prisma.panchayat.findFirst({ where: { name: 'Thayanur' } })

    if (!panchayat) {
        throw new Error('Panchayat not found. Please run seed.js first.')
    }

    const password_hash = await bcrypt.hash(password, 10)
    const user = await prisma.user.create({
        data: {
            email,
            password_hash,
            role: 'panchayat_admin',
            panchayat_id: panchayat.id
        }
    })
    console.log('🎉 Panchayat Admin created!')
    console.log('  Email:', email)
    console.log('  Password:', password)
}

main()
    .catch(e => { console.error('Error:', e); process.exit(1) })
    .finally(() => prisma.$disconnect())
