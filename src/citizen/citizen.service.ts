import { Injectable, ConflictException, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';

@Injectable()
export class CitizenService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async listPanchayats() {
    return this.prisma.panchayat.findMany({
      select: {
        id: true,
        name: true,
      },
      orderBy: { name: 'asc' },
    });
  }

  async registerCitizen(data: {
    email: string;
    password_hash: string;
    panchayat_id: number;
    phone_e164?: string;
  }) {
    const email = data.email.toLowerCase().trim();

    // Check if user already exists
    const existing = await this.prisma.user.findUnique({ where: { email } });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    // Verify panchayat exists
    const panchayat = await this.prisma.panchayat.findUnique({
      where: { id: data.panchayat_id },
    });
    if (!panchayat) {
      throw new NotFoundException('Panchayat not found');
    }

    const hashed = await bcrypt.hash(data.password_hash, 10);

    const user = await this.prisma.user.create({
      data: {
        email,
        password_hash: hashed,
        role: 'citizen',
        panchayat_id: data.panchayat_id,
        phone_e164: data.phone_e164 || null,
      },
    });

    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      panchayat_id: user.panchayat_id,
    };

    return {
      access_token: this.jwtService.sign(payload),
      role: user.role,
      panchayat_id: user.panchayat_id,
    };
  }

  async listPoles(panchayatId: number) {
    return this.prisma.electricPole.findMany({
      where: { panchayat_id: panchayatId },
      orderBy: { id: 'desc' },
      include: {
        _count: { select: { complaints: true } },
      },
    });
  }

  async createComplaint(
    panchayatId: number,
    data: {
      pole_id: number;
      complaint_type?: string;
      description?: string;
      urgency_level?: string;
    },
  ) {
    const pole = await this.prisma.electricPole.findUnique({
      where: { id: data.pole_id },
    });
    if (!pole) throw new NotFoundException(`Pole #${data.pole_id} not found`);
    if (pole.panchayat_id !== panchayatId) {
      throw new ConflictException('Pole belongs to another panchayat');
    }

    return this.prisma.complaint.create({
      data: {
        pole_id: data.pole_id,
        panchayat_id: panchayatId,
        complaint_type: data.complaint_type?.trim() || 'citizen_reported',
        description: data.description?.trim() || null,
        urgency_level: data.urgency_level?.trim() || 'medium',
        status: 'pending',
      },
      include: {
        pole: true,
      },
    });
  }

  async listComplaints(panchayatId: number) {
    return this.prisma.complaint.findMany({
      where: { panchayat_id: panchayatId },
      orderBy: { created_at: 'desc' },
      include: {
        pole: true,
      },
    });
  }
}
