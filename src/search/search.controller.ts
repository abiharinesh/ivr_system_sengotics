import { Controller, Get, Query, Req, UseGuards } from '@nestjs/common';
import { SearchService } from './search.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';

interface AuthenticatedRequest {
  user: {
    id: number;
    email: string;
    role: string;
    org_unit_id: number | null;
    tenant_id: string;
    user_type: string;
    employee_id: number | null;
    access_scope: string;
  };
}

@UseGuards(JwtAuthGuard)
@Controller('api/search')
export class SearchController {
  constructor(private readonly service: SearchService) {}

  @Get()
  search(@Req() req: AuthenticatedRequest, @Query('q') query: string) {
    const orgUnitId = req.user.org_unit_id ?? undefined;
    return this.service.universalSearch(req.user.tenant_id, query, orgUnitId);
  }
}
