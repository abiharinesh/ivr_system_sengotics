import {
  Controller,
  Get,
  Post,
  Put,
  Param,
  Body,
  Query,
  ParseIntPipe,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { PropertyTaxService } from './property-tax.service';

@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('super_admin', 'panchayat_admin', 'revenue_officer', 'revenue_inspector')
@Controller('property-tax')
export class PropertyTaxController {
  constructor(private readonly propertyTaxService: PropertyTaxService) {}

  // ─── Property CRUD ──────────────────────────────────────────────────────────

  /** GET /property-tax/properties?org_unit_id=1 */
  @Get('properties')
  async listProperties(@Query('org_unit_id', ParseIntPipe) orgUnitId: number) {
    return this.propertyTaxService.listProperties(orgUnitId);
  }

  /** GET /property-tax/properties/:id */
  @Get('properties/:id')
  async getProperty(@Param('id', ParseIntPipe) id: number) {
    return this.propertyTaxService.getPropertyById(id);
  }

  /** POST /property-tax/properties */
  @Post('properties')
  async createProperty(@Body() body: {
    org_unit_id: number;
    owner_name: string;
    owner_phone?: string;
    door_number?: string;
    address?: string;
    property_type?: string;
    area_sqft: number;
    latitude?: number;
    longitude?: number;
    annual_tax: number;
  }) {
    return this.propertyTaxService.createProperty(body);
  }

  /** PUT /property-tax/properties/:id */
  @Put('properties/:id')
  async updateProperty(
    @Param('id', ParseIntPipe) id: number,
    @Body() body: Partial<{
      owner_name: string;
      owner_phone: string;
      address: string;
      property_type: string;
      area_sqft: number;
      annual_tax: number;
      status: string;
    }>,
  ) {
    return this.propertyTaxService.updateProperty(id, body);
  }

  // ─── Tax Demands ────────────────────────────────────────────────────────────

  /** POST /property-tax/generate-demands — bulk generate for a financial year */
  @Post('generate-demands')
  async generateDemands(@Body() body: {
    org_unit_id: number;
    financial_year: string;
    due_date: string;
  }) {
    return this.propertyTaxService.generateTaxDemands(
      body.org_unit_id,
      body.financial_year,
      body.due_date,
    );
  }

  // ─── Payments ───────────────────────────────────────────────────────────────

  /** POST /property-tax/payments/:paymentId/pay */
  @Post('payments/:paymentId/pay')
  async recordPayment(
    @Param('paymentId', ParseIntPipe) paymentId: number,
    @Body() body: {
      paid_amount: number;
      payment_method: string;
      transaction_ref?: string;
    },
  ) {
    return this.propertyTaxService.recordPayment(paymentId, body);
  }

  // ─── Reports ────────────────────────────────────────────────────────────────

  /** GET /property-tax/defaulters?org_unit_id=1&financial_year=2025-26 */
  @Get('defaulters')
  async getDefaulters(
    @Query('org_unit_id', ParseIntPipe) orgUnitId: number,
    @Query('financial_year') financialYear?: string,
  ) {
    return this.propertyTaxService.getDefaulters(orgUnitId, financialYear);
  }

  /** GET /property-tax/revenue-summary?org_unit_id=1&financial_year=2025-26 */
  @Get('revenue-summary')
  async getRevenueSummary(
    @Query('org_unit_id', ParseIntPipe) orgUnitId: number,
    @Query('financial_year') financialYear?: string,
  ) {
    return this.propertyTaxService.getRevenueSummary(orgUnitId, financialYear);
  }
}
