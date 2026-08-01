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
    return this.prisma.orgUnit.findMany({
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
    org_unit_id: number;
    phone_e164?: string;
  }) {
    const email = data.email.toLowerCase().trim();

    // Check if user already exists
    const existing = await this.prisma.user.findFirst({ where: { email } });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    // Verify panchayat exists
    const panchayat = await this.prisma.orgUnit.findUnique({
      where: { id: data.org_unit_id },
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
        primary_org_unit_id: data.org_unit_id,
        phone_e164: data.phone_e164 || null,
      },
    });

    const payload = {
      sub: user.id,
      email: user.email,
      role: user.role,
      org_unit_id: user.primary_org_unit_id,
    };

    return {
      access_token: this.jwtService.sign(payload),
      role: user.role,
      org_unit_id: user.primary_org_unit_id,
    };
  }

  async listPoles(orgUnitId: number) {
    return this.prisma.electricPole.findMany({
      where: { org_unit_id: orgUnitId },
      orderBy: { id: 'desc' },
      include: {
        _count: { select: { complaints: true } },
      },
    });
  }

  async createComplaint(
    orgUnitId: number,
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
    if (pole.org_unit_id !== orgUnitId) {
      throw new ConflictException('Pole belongs to another panchayat');
    }

    return this.prisma.complaint.create({
      data: {
        pole_id: data.pole_id,
        org_unit_id: orgUnitId,
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

  async listComplaints(orgUnitId: number) {
    return this.prisma.complaint.findMany({
      where: { org_unit_id: orgUnitId },
      orderBy: { created_at: 'desc' },
      include: {
        pole: true,
      },
    });
  }
}
