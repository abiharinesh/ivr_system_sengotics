require('dotenv/config')
const { PrismaClient } = require('@prisma/client')
const { PrismaPg } = require('@prisma/adapter-pg')
const { Pool } = require('pg')
const bcrypt = require('bcrypt')

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
    const email = 'superadmin@sengotics.com'
    const password = 'Admin@1234'

    const existing = await prisma.user.findUnique({ where: { email } })
    if (existing) {
        console.log('✅ Super admin already exists:', email)
        return
    }

    const password_hash = await bcrypt.hash(password, 10)
    const user = await prisma.user.create({
        data: {
            email,
            password_hash,
            role: 'super_admin',
            panchayat_id: null
        }
    })
    console.log('🎉 Super admin created!')
    console.log('  Email:', email)
    console.log('  Password:', password)
    console.log('  User ID:', user.id)
}

main()
    .catch(e => { console.error('Error:', e); process.exit(1) })
    .finally(() => prisma.$disconnect())
