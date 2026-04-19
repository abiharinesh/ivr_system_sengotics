export class TenderCreatedEvent {
  constructor(
    public readonly tenderId: number,
    public readonly tenderCode: string,
    public readonly panchayatId: number,
    public readonly complaintCount: number,
    public readonly timestamp: Date,
  ) {}
}
