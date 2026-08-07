import { ForbiddenException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

/**
 * What a contractor sees when they sign in.
 *
 * The portal behind the contractor's only sidebar entry was four static HTML
 * pages in an iframe. It could not have been anything else: `contractors` and
 * `users` were unrelated tables, so nothing connected the person signing in to
 * any of the registered businesses, and "your invited tenders" had no way to
 * decide whose. `Contractor.user_id` is that link; this reads through it.
 *
 * Scoped to the caller's own invites throughout. A contractor asking for their
 * tenders must never be able to see a competitor's — not the invite list, not
 * the quotations, not the amounts. Every query here starts from the contractor
 * record their login resolves to, never from a tender id they supplied.
 */
@Injectable()
export class ContractorPortalService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The business this login belongs to.
   *
   * A `contractor` role with no linked business is a provisioning mistake, not
   * a reason to show them everything — refused rather than defaulted.
   */
  private async businessFor(userId: number) {
    const contractor = await this.prisma.contractor.findFirst({
      where: { user_id: userId, is_deleted: false },
      select: { id: true, name: true, tenant_id: true, blacklisted: true },
    });
    if (!contractor) {
      throw new ForbiddenException(
        'This login is not linked to a registered contractor. ' +
          'Ask the council office to connect it to your business.',
      );
    }
    return contractor;
  }

  /**
   * Tenders this contractor was invited to bid on.
   *
   * Ordered by what needs attention: an open invitation they have not answered
   * comes before one they have, and the soonest deadline comes first within
   * each. A list sorted by id would bury the thing they logged in to do.
   */
  async myInvites(userId: number) {
    const business = await this.businessFor(userId);

    const invites = await this.prisma.tenderInvite.findMany({
      where: { contractor_id: business.id },
      include: {
        tender: {
          include: {
            org_unit: { select: { id: true, name: true, district: true } },
            line_items: { select: { id: true } },
          },
        },
      },
      orderBy: { created_at: 'desc' },
    });

    // Their own quotations, to show what they already offered. Fetched by
    // contractor id rather than by tender, so a bug here cannot widen into
    // another bidder's amounts.
    const quotations = await this.prisma.tenderQuotation.findMany({
      where: {
        contractor_id: business.id,
        tender_id: { in: invites.map((i) => i.tender_id) },
      },
      select: {
        tender_id: true,
        amount: true,
        submitted_at: true,
        screening_outcome: true,
      },
      orderBy: { submitted_at: 'desc' },
    });
    const myQuote = new Map<number, (typeof quotations)[number]>();
    for (const q of quotations) {
      if (!myQuote.has(q.tender_id)) myQuote.set(q.tender_id, q);
    }

    const now = Date.now();

    const rows = invites.map((invite) => {
      const t = invite.tender;
      const quote = myQuote.get(invite.tender_id) ?? null;
      const expiresAt = invite.invite_expires_at;

      const state = invite.invite_revoked_at
        ? 'withdrawn'
        : invite.invite_submitted_at || quote
          ? 'submitted'
          : expiresAt && expiresAt.getTime() < now
            ? 'closed'
            : 'awaiting_your_quote';

      return {
        invite_id: invite.id,
        tender_id: t.id,
        title: t.title_en ?? t.title_ta ?? `Tender #${t.id}`,
        title_ta: t.title_ta,
        status: t.status,
        branch: t.org_unit?.name ?? null,
        district: t.org_unit?.district ?? null,
        line_item_count: t.line_items.length,
        invited_at: invite.created_at,
        expires_at: expiresAt,
        opened_at: invite.invite_opened_at,
        submitted_at: invite.invite_submitted_at ?? quote?.submitted_at ?? null,
        /// `awaiting_your_quote` | `submitted` | `closed` | `withdrawn`
        state,
        my_quote:
          quote == null
            ? null
            : {
                amount: Number(quote.amount),
                submitted_at: quote.submitted_at,
                outcome: quote.screening_outcome,
              },
        /// The one this tender was awarded to, when it is theirs. Never
        /// exposes who won when it is somebody else.
        won: t.awarded_quotation_id != null && quote != null
          ? quote.screening_outcome === 'accepted'
          : false,
      };
    });

    const rank: Record<string, number> = {
      awaiting_your_quote: 0,
      submitted: 1,
      closed: 2,
      withdrawn: 3,
    };
    rows.sort((a, b) => {
      const byState = (rank[a.state] ?? 9) - (rank[b.state] ?? 9);
      if (byState !== 0) return byState;
      const aDue = a.expires_at?.getTime() ?? Number.MAX_SAFE_INTEGER;
      const bDue = b.expires_at?.getTime() ?? Number.MAX_SAFE_INTEGER;
      return aDue - bDue;
    });

    return {
      contractor: { id: business.id, name: business.name },
      blacklisted: business.blacklisted,
      totals: {
        invited: rows.length,
        awaiting: rows.filter((r) => r.state === 'awaiting_your_quote').length,
        submitted: rows.filter((r) => r.state === 'submitted').length,
        closed: rows.filter((r) => r.state === 'closed').length,
      },
      tenders: rows,
    };
  }

  /**
   * One invited tender in full.
   *
   * Reached through the invite, not the tender: asking for a tender id they
   * were never invited to must return nothing rather than its line items.
   */
  async myTender(userId: number, tenderId: number) {
    const business = await this.businessFor(userId);

    const invite = await this.prisma.tenderInvite.findFirst({
      where: { contractor_id: business.id, tender_id: tenderId },
      include: {
        tender: {
          include: {
            org_unit: { select: { name: true, district: true } },
            line_items: true,
          },
        },
      },
    });
    if (!invite) {
      throw new ForbiddenException('You were not invited to that tender');
    }

    const t = invite.tender;
    return {
      tender_id: t.id,
      title: t.title_en ?? t.title_ta ?? `Tender #${t.id}`,
      narrative: t.narrative_en ?? t.narrative_ta,
      status: t.status,
      branch: t.org_unit?.name ?? null,
      expires_at: invite.invite_expires_at,
      line_items: t.line_items,
      // Deliberately absent: other bidders, their amounts, and the count of
      // quotations received. None of it is this contractor's to see.
    };
  }
}
