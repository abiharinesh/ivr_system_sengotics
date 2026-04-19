import { Injectable, BadRequestException } from '@nestjs/common'
import { randomUUID } from 'crypto'
import * as fs from 'fs/promises'
import * as path from 'path'

const ALLOWED_EXT = new Set(['.jpg', '.jpeg', '.png', '.webp'])

@Injectable()
export class LocalFilesService {
    private readonly root = path.join(process.cwd(), 'uploads')

    async ensureUploadRoot(): Promise<void> {
        await fs.mkdir(this.root, { recursive: true })
    }

    /**
     * Persists a buffer under uploads/{subdir}/ and returns a URL path beginning with /uploads/
     */
    async saveBuffer(subdir: string, buffer: Buffer, originalName: string): Promise<string> {
        if (!buffer?.length) {
            throw new BadRequestException('Empty file')
        }
        await this.ensureUploadRoot()
        const ext = path.extname(originalName || '').toLowerCase() || '.jpg'
        const safeExt = ALLOWED_EXT.has(ext) ? ext : '.jpg'
        const filename = `${randomUUID()}${safeExt}`
        const dir = path.join(this.root, subdir)
        await fs.mkdir(dir, { recursive: true })
        const fullPath = path.join(dir, filename)
        await fs.writeFile(fullPath, buffer)
        const rel = path.posix.join('/uploads', subdir.replace(/\\/g, '/'), filename)
        return rel.replace(/\\/g, '/')
    }
}
