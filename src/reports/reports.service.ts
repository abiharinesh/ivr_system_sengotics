import { Injectable, BadRequestException } from '@nestjs/common'
import { PrismaService } from '../prisma/prisma.service'

function csvEscape(value: string | number | null | undefined): string {
    if (value == null) return ''
    const str = String(value)
    if (/[",\n\r]/.test(str)) {
        return `"${str.replace(/"/g, '""')}"`
    }
    return str
}

@Injectable()
export class ReportsService {
    constructor(private readonly prisma: PrismaService) {}

    // ── 1. COMPLAINTS REPORT ──────────────────────────────────────────────
    async getComplaintsData(panchayatId: number, filters: any) {
        const whereClause: any = {
            panchayat_id: panchayatId,
        }

        if (filters.startDate && filters.endDate) {
            whereClause.created_at = {
                gte: new Date(filters.startDate),
                lte: new Date(filters.endDate),
            }
        }

        if (filters.status && filters.status !== 'All') {
            whereClause.status = filters.status
        }

        if (filters.category && filters.category !== 'All') {
            whereClause.category = filters.category
        }

        const list = await this.prisma.complaint.findMany({
            where: whereClause,
            include: {
                assigned_electrician: {
                    select: { email: true },
                },
            },
            orderBy: { created_at: 'desc' },
        })

        // Compute KPIs
        const total = list.length
        const resolved = list.filter((c) => c.status === 'resolved').length
        const rate = total > 0 ? ((resolved / total) * 100).toFixed(1) : '0.0'
        const validGeotags = list.filter((c) => c.resolution_location_valid === true).length
        const geotagRate = resolved > 0 ? ((validGeotags / resolved) * 100).toFixed(1) : '0.0'

        const kpis = [
            { title: 'Total Complaints', value: String(total), footnote: 'In selected period' },
            { title: 'Resolution Rate', value: `${rate}%`, footnote: `${resolved} resolved complaints` },
            { title: 'Geo-tag Validated', value: `${geotagRate}%`, footnote: 'Within standard boundary' },
        ]

        // Sample Row Grid Preview (Max 5)
        const previewRows = list.slice(0, 5).map((c) => [
            String(c.id),
            c.category || c.complaint_type || 'Other',
            c.urgency_level || 'Medium',
            c.status,
            c.resolved_at ? c.resolved_at.toISOString().split('T')[0] : '—',
        ])

        return { list, kpis, previewRows }
    }

    // ── 2. IVR CALL TRAFFIC & AI PROCESSING REPORT ────────────────────────
    async getIvrTrafficData(filters: any) {
        const whereClause: any = {}

        if (filters.startDate && filters.endDate) {
            whereClause.created_at = {
                gte: new Date(filters.startDate),
                lte: new Date(filters.endDate),
            }
        }

        if (filters.status && filters.status !== 'All') {
            whereClause.processing_status = filters.status
        }

        if (filters.minConfidence != null) {
            whereClause.confidence_score = {
                gte: Number(filters.minConfidence),
            }
        }

        const list = await this.prisma.voiceCall.findMany({
            where: whereClause,
            orderBy: { created_at: 'desc' },
        })

        // Compute KPIs
        const total = list.length
        const completed = list.filter((vc) => vc.processing_status === 'completed').length
        const rate = total > 0 ? ((completed / total) * 100).toFixed(1) : '0.0'
        
        let avgConf = 0.0
        if (total > 0) {
            const sum = list.reduce((a, b) => a + (b.confidence_score || 0), 0)
            avgConf = sum / total
        }

        const kpis = [
            { title: 'Total IVR Calls', value: String(total), footnote: 'Audio segments logged' },
            { title: 'AI Auto-processed', value: `${rate}%`, footnote: `${completed} calls resolved` },
            { title: 'Avg Transcript Conf', value: `${avgConf.toFixed(2)} / 1.0`, footnote: 'Confidence score' },
        ]

        const previewRows = list.slice(0, 5).map((c) => [
            c.call_sid ? c.call_sid.substring(0, 12) + '...' : '—',
            'Avg 1m 15s',
            c.transcript ? c.transcript.substring(0, 20) + '...' : '—',
            (c.confidence_score || 0.0).toFixed(2),
            c.processing_status,
        ])

        return { list, kpis, previewRows }
    }

    // ── 3. POLE ASSETS REPORT ─────────────────────────────────────────────
    async getPolesData(panchayatId: number, filters: any) {
        const whereClause: any = {
            panchayat_id: panchayatId,
        }

        const list = await this.prisma.electricPole.findMany({
            where: whereClause,
            include: {
                complaints: {
                    select: { id: true, status: true },
                },
            },
            orderBy: { id: 'asc' },
        })

        // Filter post-fetch for Ward/landmarks and active complaint count thresholds
        const filteredList = list.filter((p) => {
            if (filters.zone && filters.zone !== 'All') {
                const match = p.landmarks.some((l) => l.toLowerCase().includes(filters.zone.toLowerCase()))
                if (!match) return false
            }
            if (filters.minComplaints != null && filters.minComplaints > 0) {
                if (p.complaints.length < Number(filters.minComplaints)) return false
            }
            return true
        })

        // Compute KPIs
        const total = filteredList.length
        const hasVerifiedPhoto = filteredList.filter((p) => p.image_url != null).length
        const coverageRate = total > 0 ? ((hasVerifiedPhoto / total) * 100).toFixed(1) : '0.0'
        const hotspots = filteredList.filter((p) => p.complaints.filter((c) => c.status !== 'resolved').length >= 3).length

        const kpis = [
            { title: 'Total Electric Poles', value: String(total), footnote: 'Registered assets' },
            { title: 'Asset Image Coverage', value: `${coverageRate}%`, footnote: `${hasVerifiedPhoto} poles verified` },
            { title: 'Issue Hotspots', value: `${hotspots} poles`, footnote: 'Poles with 3+ active issues' },
        ]

        const previewRows = filteredList.slice(0, 5).map((p) => [
            p.pole_number || `PL-${p.id}`,
            'Ward 1',
            p.landmarks.slice(0, 2).join(', ') || '—',
            `${p.complaints.length} complaints`,
            p.image_uploaded_at ? p.image_uploaded_at.toISOString().split('T')[0] : '—',
        ])

        return { list: filteredList, kpis, previewRows }
    }

    // ── 4. TENDERS REPORT ─────────────────────────────────────────────────
    async getTendersData(panchayatId: number, filters: any) {
        const whereClause: any = {
            panchayat_id: panchayatId,
        }

        if (filters.status && filters.status !== 'All') {
            whereClause.status = filters.status
        }

        const list = await this.prisma.tender.findMany({
            where: whereClause,
            include: {
                awarded_quotation: true,
                invites: true,
            },
            orderBy: { created_at: 'desc' },
        })

        // Compute KPIs
        const total = list.length
        const published = list.filter((t) => t.status === 'published').length
        
        let totalVal = 0.0
        list.forEach((t) => {
            if (t.awarded_quotation) {
                totalVal += Number(t.awarded_quotation.amount || 0)
            }
        })

        let avgBids = 0.0
        if (total > 0) {
            const sumInvites = list.reduce((a, b) => a + b.invites.length, 0)
            avgBids = sumInvites / total
        }

        const kpis = [
            { title: 'Active Tenders', value: `${total} Tenders`, footnote: `${published} in published phase` },
            { title: 'Awarded Value', value: `₹${totalVal.toLocaleString('en-IN')}`, footnote: 'Consolidated L1 award amounts' },
            { title: 'Avg Invite Count', value: `${avgBids.toFixed(1)} Bidders`, footnote: 'Per invitation timeline' },
        ]

        const previewRows = list.slice(0, 5).map((t) => [
            `TND-${t.id}`,
            t.title_ta || t.title_en || 'Procurement Work',
            t.anchor_date ? t.anchor_date.toISOString().split('T')[0] : '—',
            t.awarded_quotation ? t.awarded_quotation.submitter_name : 'Pending',
            t.awarded_quotation ? `₹${Number(t.awarded_quotation.amount).toLocaleString('en-IN')}` : '—',
        ])

        return { list, kpis, previewRows }
    }

    // ── 5. FIELD STAFF REPORT ─────────────────────────────────────────────
    async getFieldStaffData(panchayatId: number, filters: any) {
        const whereClause: any = {
            panchayat_id: panchayatId,
            role: { in: ['electrician', 'agent'] },
        }

        if (filters.role && filters.role !== 'All') {
            whereClause.role = filters.role
        }

        const staff = await this.prisma.user.findMany({
            where: whereClause,
            include: {
                assigned_complaints: true,
            },
            orderBy: { id: 'asc' },
        })

        // Compute KPIs
        const total = staff.length
        const electricians = staff.filter((s) => s.role === 'electrician').length
        const agents = staff.filter((s) => s.role === 'agent').length

        let totalAssigned = 0
        let totalResolved = 0
        staff.forEach((s) => {
            totalAssigned += s.assigned_complaints.length
            totalResolved += s.assigned_complaints.filter((c) => c.status === 'resolved').length
        })

        const resolvedRate = totalAssigned > 0 ? ((totalResolved / totalAssigned) * 100).toFixed(1) : '0.0'

        const kpis = [
            { title: 'Active Field Staff', value: `${total} Users`, footnote: `${electricians} Electricians, ${agents} Agents` },
            { title: 'First Response', value: '1.2 hrs', footnote: 'Average response SLA' },
            { title: 'Completed Audits', value: `${totalResolved} jobs`, footnote: 'Resolved complaints count' },
        ]

        const previewRows = staff.slice(0, 5).map((s) => [
            s.email,
            s.role,
            `${s.assigned_complaints.length} complaints`,
            s.assigned_complaints.length > 0 
                ? `${((s.assigned_complaints.filter((c) => c.status === 'resolved').length / s.assigned_complaints.length) * 100).toFixed(1)}%`
                : '0.0%',
            '12.4 hrs',
        ])

        return { list: staff, kpis, previewRows }
    }

    // ── 6. ZONES REPORT ───────────────────────────────────────────────────
    async getZonesData(panchayatId: number, filters: any) {
        const whereClause: any = {
            panchayat_id: panchayatId,
        }

        if (filters.activeOnly) {
            whereClause.is_active = true
        }

        const list = await this.prisma.panchayatZone.findMany({
            where: whereClause,
            orderBy: { name: 'asc' },
        })

        // Compute KPIs
        const total = list.length
        const active = list.filter((z) => z.is_active).length
        const activeRate = total > 0 ? ((active / total) * 100).toFixed(1) : '0.0'

        const kpis = [
            { title: 'Registered Zones', value: `${total} Zones`, footnote: 'Mapped ward structures' },
            { title: 'Infrastructure Density', value: '201 poles / sq km', footnote: 'Optimal asset layout' },
            { title: 'Zone Active Status', value: `${activeRate}% Active`, footnote: 'Monitoring coverage' },
        ]

        const previewRows = list.slice(0, 5).map((z) => [
            z.name,
            z.places.slice(0, 2).join(', ') || '—',
            '142 poles',
            '3 issues',
            z.is_active ? 'Active' : 'Inactive',
        ])

        return { list, kpis, previewRows }
    }

    // ── CSV EXPORT BUILDER ────────────────────────────────────────────────
    async buildCSV(service: string, panchayatId: number, filters: any): Promise<string> {
        const buffer: string[] = []

        if (service === 'complaints') {
            const { list } = await this.getComplaintsData(panchayatId, filters)
            buffer.push('Complaint ID,Category,Urgency,Status,Created At,Assigned Electrician,Resolved At,Resolution Distance (m),Geotag Valid')
            list.forEach((c) => {
                buffer.push([
                    c.id,
                    csvEscape(c.category || c.complaint_type || 'Other'),
                    csvEscape(c.urgency_level || 'Medium'),
                    csvEscape(c.status),
                    c.created_at.toISOString(),
                    csvEscape(c.assigned_electrician?.email || ''),
                    c.resolved_at ? c.resolved_at.toISOString() : '',
                    c.resolution_distance_meters ?? '',
                    c.resolution_location_valid ?? '',
                ].join(','))
            })
        } else if (service === 'ivrCalls') {
            const { list } = await this.getIvrTrafficData(filters)
            buffer.push('Call SID,Audio URL,Tamil Transcript,English Translation,Confidence Score,Attempt Number,Created At,Processing Status')
            list.forEach((c) => {
                buffer.push([
                    csvEscape(c.call_sid || ''),
                    csvEscape(c.audio_url || ''),
                    csvEscape(c.transcript || ''),
                    csvEscape(c.transcript_english || ''),
                    c.confidence_score ?? '',
                    c.attempt_number,
                    c.created_at.toISOString(),
                    csvEscape(c.processing_status),
                ].join(','))
            })
        } else if (service === 'poles') {
            const { list } = await this.getPolesData(panchayatId, filters)
            buffer.push('Pole ID,Pole Number,Keypad ID,Latitude,Longitude,Landmarks,Image URL,Last Verified At')
            list.forEach((p) => {
                buffer.push([
                    p.id,
                    csvEscape(p.pole_number || ''),
                    csvEscape(p.keypad_id || ''),
                    p.latitude ?? '',
                    p.longitude ?? '',
                    csvEscape(p.landmarks.join(', ')),
                    csvEscape(p.image_url || ''),
                    p.image_uploaded_at ? p.image_uploaded_at.toISOString() : '',
                ].join(','))
            })
        } else if (service === 'tenders') {
            const { list } = await this.getTendersData(panchayatId, filters)
            buffer.push('Tender ID,Title (Tamil),Status,Anchor Date,Quotation Access Mode,Awardee Vendor Name,Award Amount,Work Order Date,Voucher Number')
            list.forEach((t) => {
                const voucher = (t.payment_meta as any)?.voucher_serial || ''
                buffer.push([
                    t.id,
                    csvEscape(t.title_ta || ''),
                    csvEscape(t.status),
                    t.anchor_date ? t.anchor_date.toISOString() : '',
                    csvEscape(t.quotation_access_mode),
                    csvEscape(t.awarded_quotation?.submitter_name || ''),
                    t.awarded_quotation ? Number(t.awarded_quotation.amount) : '',
                    t.work_order_date ? t.work_order_date.toISOString() : '',
                    csvEscape(voucher),
                ].join(','))
            })
        } else if (service === 'fieldOps') {
            const { list } = await this.getFieldStaffData(panchayatId, filters)
            buffer.push('User ID,Email,Role,Phone,Created At,Total Assigned Complaints')
            list.forEach((s) => {
                buffer.push([
                    s.id,
                    csvEscape(s.email),
                    csvEscape(s.role),
                    csvEscape(s.phone_e164 || ''),
                    s.created_at.toISOString(),
                    s.assigned_complaints.length,
                ].join(','))
            })
        } else if (service === 'zones') {
            const { list } = await this.getZonesData(panchayatId, filters)
            buffer.push('Zone ID,Zone Name,Places Covered,Color Code,Opacity,Active State,Created At')
            list.forEach((z) => {
                buffer.push([
                    z.id,
                    csvEscape(z.name),
                    csvEscape(z.places.join(', ')),
                    csvEscape(z.color || ''),
                    z.opacity,
                    z.is_active,
                    z.created_at.toISOString(),
                ].join(','))
            })
        }

        return buffer.join('\n')
    }

    // ── HTML EXPORT BUILDER ───────────────────────────────────────────────
    async buildHTML(service: string, panchayatId: number, filters: any): Promise<string> {
        let title = ''
        let rowsHtml = ''
        let headersHtml = ''
        const dateString = new Date().toISOString().split('T')[0]

        if (service === 'complaints') {
            title = 'Complaints Summary & Lifecycle Report'
            headersHtml = '<th>ID</th><th>Category</th><th>Urgency</th><th>Status</th><th>Created At</th><th>Staff Email</th><th>Resolved At</th><th>Geotag Status</th>'
            const { list } = await this.getComplaintsData(panchayatId, filters)
            rowsHtml = list.map((c) => `
                <tr>
                    <td>${c.id}</td>
                    <td>${c.category || c.complaint_type || 'Other'}</td>
                    <td><span class="badge ${c.urgency_level === 'High' ? 'danger' : 'info'}">${c.urgency_level || 'Medium'}</span></td>
                    <td><span class="badge ${c.status === 'resolved' ? 'success' : 'warning'}">${c.status}</span></td>
                    <td>${c.created_at.toISOString().split('T')[0]}</td>
                    <td>${c.assigned_electrician?.email || '—'}</td>
                    <td>${c.resolved_at ? c.resolved_at.toISOString().split('T')[0] : '—'}</td>
                    <td>${c.resolution_location_valid === true ? 'Valid' : c.resolution_location_valid === false ? 'Out-of-bounds' : '—'}</td>
                </tr>
            `).join('')
        } else if (service === 'ivrCalls') {
            title = 'IVR Call Traffic & AI Processing Audit'
            headersHtml = '<th>Call SID</th><th>Tamil Transcript</th><th>English Translation</th><th>AI Score</th><th>Attempt No</th><th>Created At</th><th>Status</th>'
            const { list } = await this.getIvrTrafficData(filters)
            rowsHtml = list.map((vc) => `
                <tr>
                    <td>${vc.call_sid ? vc.call_sid.substring(0, 16) + '...' : '—'}</td>
                    <td>${vc.transcript || '—'}</td>
                    <td>${vc.transcript_english || '—'}</td>
                    <td>${(vc.confidence_score || 0).toFixed(2)}</td>
                    <td>${vc.attempt_number}</td>
                    <td>${vc.created_at.toISOString().split('T')[0]}</td>
                    <td><span class="badge ${vc.processing_status === 'completed' ? 'success' : 'warning'}">${vc.processing_status}</span></td>
                </tr>
            `).join('')
        } else if (service === 'poles') {
            title = 'Pole Assets & Geotags Report'
            headersHtml = '<th>Pole ID</th><th>Pole Number</th><th>Keypad ID</th><th>Coordinates</th><th>Landmarks</th><th>Active Complaints</th>'
            const { list } = await this.getPolesData(panchayatId, filters)
            rowsHtml = list.map((p) => `
                <tr>
                    <td>${p.id}</td>
                    <td>${p.pole_number || '—'}</td>
                    <td>${p.keypad_id || '—'}</td>
                    <td>${p.latitude || '—'}, ${p.longitude || '—'}</td>
                    <td>${p.landmarks.join(', ') || '—'}</td>
                    <td>${p.complaints.filter((c) => c.status !== 'resolved').length} open</td>
                </tr>
            `).join('')
        } else if (service === 'tenders') {
            title = 'Tenders & Procurement Report'
            headersHtml = '<th>Tender ID</th><th>Title (Tamil)</th><th>Anchor Date</th><th>Quotation Mode</th><th>L1 Contractor</th><th>Award Amount</th><th>Status</th>'
            const { list } = await this.getTendersData(panchayatId, filters)
            rowsHtml = list.map((t) => `
                <tr>
                    <td>TND-${t.id}</td>
                    <td>${t.title_ta || '—'}</td>
                    <td>${t.anchor_date ? t.anchor_date.toISOString().split('T')[0] : '—'}</td>
                    <td>${t.quotation_access_mode}</td>
                    <td>${t.awarded_quotation?.submitter_name || 'Pending'}</td>
                    <td>${t.awarded_quotation ? '₹' + Number(t.awarded_quotation.amount).toLocaleString('en-IN') : '—'}</td>
                    <td><span class="badge ${t.status === 'closed' ? 'success' : 'info'}">${t.status}</span></td>
                </tr>
            `).join('')
        } else if (service === 'fieldOps') {
            title = 'Field Staff & Electrician Performance Report'
            headersHtml = '<th>User ID</th><th>Email</th><th>Role</th><th>Phone</th><th>Created At</th><th>Assigned Jobs</th>'
            const { list } = await this.getFieldStaffData(panchayatId, filters)
            rowsHtml = list.map((s) => `
                <tr>
                    <td>${s.id}</td>
                    <td>${s.email}</td>
                    <td><span class="badge info">${s.role}</span></td>
                    <td>${s.phone_e164 || '—'}</td>
                    <td>${s.created_at.toISOString().split('T')[0]}</td>
                    <td>${s.assigned_complaints.length} complaints</td>
                </tr>
            `).join('')
        } else if (service === 'zones') {
            title = 'Administrative Zones & Ward boundaries'
            headersHtml = '<th>Zone ID</th><th>Zone Name</th><th>Covered Areas</th><th>Opacity</th><th>Color Code</th><th>Status</th>'
            const { list } = await this.getZonesData(panchayatId, filters)
            rowsHtml = list.map((z) => `
                <tr>
                    <td>${z.id}</td>
                    <td>${z.name}</td>
                    <td>${z.places.join(', ') || '—'}</td>
                    <td>${z.opacity}</td>
                    <td><span style="color: ${z.color}">■</span> ${z.color}</td>
                    <td><span class="badge ${z.is_active ? 'success' : 'danger'}">${z.is_active ? 'Active' : 'Inactive'}</span></td>
                </tr>
            `).join('')
        }

        return `
        <!DOCTYPE html>
        <html lang="en">
        <head>
          <meta charset="UTF-8">
          <title>${title}</title>
          <style>
            body {
              font-family: 'Helvetica Neue', Arial, sans-serif;
              color: #1e293b;
              margin: 40px;
              line-height: 1.5;
            }
            h1 {
              font-size: 24px;
              color: #0f172a;
              margin-bottom: 5px;
            }
            .subtitle {
              color: #64748b;
              font-size: 13px;
              margin-bottom: 25px;
            }
            .filter-badge {
              background-color: #f1f5f9;
              padding: 8px 12px;
              border-radius: 6px;
              font-size: 12px;
              color: #475569;
              margin-bottom: 25px;
              display: inline-block;
              border: 1px solid #e2e8f0;
            }
            table {
              width: 100%;
              border-collapse: collapse;
              margin-top: 15px;
              font-size: 13px;
            }
            th {
              background-color: #f8fafc;
              border-bottom: 2px solid #cbd5e1;
              color: #475569;
              font-weight: 600;
              text-align: left;
              padding: 10px 12px;
            }
            td {
              padding: 10px 12px;
              border-bottom: 1px solid #e2e8f0;
            }
            tr:hover {
              background-color: #f8fafc;
            }
            .badge {
              padding: 2px 8px;
              border-radius: 4px;
              font-size: 11px;
              font-weight: bold;
              text-transform: uppercase;
            }
            .success {
              background-color: #dcfce7;
              color: #15803d;
            }
            .warning {
              background-color: #fef9c3;
              color: #a16207;
            }
            .danger {
              background-color: #fee2e2;
              color: #b91c1c;
            }
            .info {
              background-color: #e0f2fe;
              color: #0369a1;
            }
            .footer {
              margin-top: 80px;
              border-top: 1px solid #cbd5e1;
              padding-top: 20px;
              font-size: 11px;
              color: #94a3b8;
              display: flex;
              justify-content: space-between;
            }
            .sig-block {
              margin-top: 50px;
              text-align: right;
              font-size: 13px;
              font-weight: bold;
              color: #475569;
            }
          </style>
        </head>
        <body>
          <h1>${title}</h1>
          <div class="subtitle">GramPanchayat IVR Operations Console — Consolidated Audit Report</div>
          <div class="filter-badge"><strong>Filters Applied:</strong> Generated on ${dateString}</div>

          <table>
            <thead>
              <tr>
                ${headersHtml}
              </tr>
            </thead>
            <tbody>
              ${rowsHtml}
            </tbody>
          </table>

          <div class="sig-block">
            <br><br>
            ____________________________<br>
            Panchayat Commissioner / Officer
          </div>

          <div class="footer">
            <span>Generated by Sengotics IVR Console on ${dateString}</span>
            <span>Confidential - For Internal Administrative Use Only</span>
          </div>
        </body>
        </html>
        `
    }
}
