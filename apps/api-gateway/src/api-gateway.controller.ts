import { Controller, Get, Post, Body, Req, All } from '@nestjs/common';
import type { Request } from 'express';

// In a real environment, these would be retrieved from ConfigService
const COMPLAINT_SERVICE_URL = process.env.COMPLAINT_SERVICE_URL || 'http://localhost:3001';
const TENDER_SERVICE_URL = process.env.TENDER_SERVICE_URL || 'http://localhost:3002';

@Controller('v1')
export class ApiGatewayController {
  
  @Get('complaints/clusters/tender-eligible')
  async getTenderEligibleClusters() {
    const res = await fetch(`${COMPLAINT_SERVICE_URL}/complaints/clusters/tender-eligible`);
    if (!res.ok) throw new Error(`Complaint service failed: ${res.statusText}`);
    return res.json();
  }

  @Post('tenders')
  async createTender(@Req() request: Request, @Body() createTenderDto: any) {
    const res = await fetch(`${TENDER_SERVICE_URL}/tenders`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        // Forwarding auth headers
        ...(request.headers.authorization ? { Authorization: request.headers.authorization } : {})
      },
      body: JSON.stringify(createTenderDto),
    });
    
    if (!res.ok) {
        throw new Error(await res.text());
    }
    return res.json();
  }

  @Post('tenders/:id/invite-links')
  async generateInviteLink(@Req() request: Request, @Body() body: any) {
    const res = await fetch(`${TENDER_SERVICE_URL}/tenders/${request.params.id}/invite-links`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(request.headers.authorization ? { Authorization: request.headers.authorization } : {})
      },
      body: JSON.stringify(body),
    });
    
    if (!res.ok) {
        throw new Error(await res.text());
    }
    return res.json();
  }
}
