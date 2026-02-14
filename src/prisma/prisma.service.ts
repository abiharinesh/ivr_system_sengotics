import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { PrismaClient } from '@prisma/client'
import { PrismaPg } from '@prisma/adapter-pg'
import { Pool } from 'pg'

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
    constructor(private configService: ConfigService) {
        // Initialize PostgreSQL connection pool
        const pool = new Pool({
            connectionString: configService.get<string>('DATABASE_URL')
        })

        // Initialize Prisma with PostgreSQL adapter (required for Prisma v7)
        const adapter = new PrismaPg(pool)
        super({
            adapter,
            log: ['query', 'info', 'warn', 'error']
        })
    }

    async onModuleInit() {
        await this.$connect()
    }

    async onModuleDestroy() {
        await this.$disconnect()
    }
}
