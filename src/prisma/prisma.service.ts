import { Injectable, OnModuleInit, OnModuleDestroy } from '@nestjs/common'
import { ConfigService } from '@nestjs/config'
import { PrismaClient } from '@prisma/client'

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
    constructor(private configService: ConfigService) {
        super({
            log: ['query', 'info', 'warn', 'error']
        })
    }

    async onModuleInit() {
        const url = this.configService.get('DATABASE_URL');
        if (!url) {
            console.error('DATABASE_URL is not defined!');
        } else {
            console.log('DATABASE_URL is defined (length: ' + url.length + ')');
        }
        await this.$connect()
    }

    async onModuleDestroy() {
        await this.$disconnect()
    }
}
