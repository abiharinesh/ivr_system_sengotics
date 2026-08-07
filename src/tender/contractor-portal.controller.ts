import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Req,
  UseGuards,
} from '@nestjs/common';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { RolesGuard } from '../auth/guards/roles.guard';
import { Roles } from '../auth/decorators/roles.decorator';
import { ContractorPortalService } from './contractor-portal.service';

interface AuthenticatedRequest {
  user: { id: number; email: string; role: string };
}

/**
 * The contractor's own view of the tenders they were invited to.
 *
 * Kept apart from {@link TenderController}, which is the council's side and
 * lists every tender at a branch. Two audiences, two controllers: a contractor
 * reaching a council endpoint by guessing a path is a much easier mistake to
 * make when both live behind one prefix and one guard.
 *
 * Nothing here takes a branch or a contractor id from the caller. Everything
 * resolves from `Contractor.user_id`, so the only tenders reachable are the
 * ones this login was actually invited to.
 */
@UseGuards(JwtAuthGuard, RolesGuard)
@Roles('contractor')
@Controller('api/contractor')
export class ContractorPortalController {
  constructor(private readonly portal: ContractorPortalService) {}

  /** GET /api/contractor/tenders — everything they were invited to. */
  @Get('tenders')
  myTenders(@Req() req: AuthenticatedRequest) {
    return this.portal.myInvites(req.user.id);
  }

  /** GET /api/contractor/tenders/:id — one of them, in full. */
  @Get('tenders/:id')
  myTender(
    @Req() req: AuthenticatedRequest,
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.portal.myTender(req.user.id, id);
  }
}
