const fs = require('fs');
const path = require('path');

async function createDocx() {
    try {
        const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, WidthType, AlignmentType, BorderStyle, HeadingLevel, ShadingType } = require('docx');

        const doc = new Document({
            sections: [{
                properties: {
                    page: {
                        margin: {
                            top: 1000,
                            right: 1200,
                            bottom: 1000,
                            left: 1200,
                        },
                    },
                },
                children: [
                    // Header
                    new Paragraph({
                        alignment: AlignmentType.CENTER,
                        children: [
                            new TextRun({ text: "SENGOTICS", bold: true, size: 36, color: "0A2463", font: "Calibri" }),
                        ],
                    }),
                    new Paragraph({
                        alignment: AlignmentType.CENTER,
                        children: [
                            new TextRun({ text: "TRUSTED DIGITAL FUTURE", bold: true, size: 18, color: "2563EB", font: "Calibri" }),
                        ],
                    }),
                    new Paragraph({
                        alignment: AlignmentType.CENTER,
                        children: [
                            new TextRun({ text: "4/360, Anna Nagar, Dhayanur, Karamadai - Tholampalayam Road, Near Gram Panchayat Office,\nKemmarampalayam, Kalampalayam, Mettupalayam, Coimbatore, Tamil Nadu – 641113", size: 17, color: "4B5563", font: "Calibri" }),
                        ],
                    }),
                    new Paragraph({
                        alignment: AlignmentType.CENTER,
                        children: [
                            new TextRun({ text: "Email: contact@sengotics.com | Web: www.sengotics.com | Phone: +91 9597769501\nGSTIN: 33DKDPA5555E1ZL | UDYAM: UDYAM-TN-03-0308455 | GeM Seller ID: N78K260014298113", size: 16, bold: true, color: "374151", font: "Calibri" }),
                        ],
                    }),
                    new Paragraph({
                        children: [
                            new TextRun({ text: "_________________________________________________________________________________", color: "0A2463" })
                        ],
                        spacing: { after: 200 }
                    }),

                    // Meta
                    new Table({
                        width: { size: 100, type: WidthType.PERCENTAGE },
                        borders: {
                            top: { style: BorderStyle.NONE },
                            bottom: { style: BorderStyle.NONE },
                            left: { style: BorderStyle.NONE },
                            right: { style: BorderStyle.NONE },
                            insideHorizontal: { style: BorderStyle.NONE },
                            insideVertical: { style: BorderStyle.NONE },
                        },
                        rows: [
                            new TableRow({
                                children: [
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "Ref: SEG/M/PROP/2026/08", bold: true, size: 20, font: "Calibri" })] })],
                                    }),
                                    new TableCell({
                                        children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "Date: 28th August 2026", bold: true, size: 20, font: "Calibri" })] })],
                                    }),
                                ],
                            }),
                        ],
                    }),

                    new Paragraph({ text: "", spacing: { after: 150 } }),

                    // Recipient
                    new Paragraph({
                        children: [
                            new TextRun({ text: "To,\n", bold: true, size: 21, font: "Calibri" }),
                            new TextRun({ text: "The Municipal Commissioner & The Municipal Engineer,\n", bold: true, size: 21, font: "Calibri" }),
                            new TextRun({ text: "Mettupalayam Municipality,\nCoimbatore District, Tamil Nadu.", size: 21, font: "Calibri" }),
                        ],
                        spacing: { after: 200 },
                    }),

                    // Subject
                    new Paragraph({
                        children: [
                            new TextRun({ text: "Subject: ", bold: true, size: 21, color: "0A2463", font: "Calibri" }),
                            new TextRun({ text: "Submission of Project Proposal for Smart GIS Municipal Governance Platform, AI Citizen Voice Helpline, and On-Site I3C Turnkey Operations — Reg.", bold: true, size: 21, font: "Calibri" }),
                        ],
                        spacing: { after: 200 },
                    }),

                    // Salutation
                    new Paragraph({
                        children: [
                            new TextRun({ text: "Respected Sir / Madam,", bold: true, size: 21, font: "Calibri" }),
                        ],
                        spacing: { after: 150 },
                    }),

                    // Body
                    new Paragraph({
                        children: [
                            new TextRun({ text: "Greetings from Sengotics.", bold: true, size: 21, font: "Calibri" }),
                        ],
                        spacing: { after: 150 },
                    }),

                    new Paragraph({
                        children: [
                            new TextRun({ text: "We are pleased to submit our comprehensive Project Proposal (Ref: SEG/M/PROP/2026/08) for the implementation of the ", size: 21, font: "Calibri" }),
                            new TextRun({ text: "Smart GIS Municipal Governance Platform (Ooraatchi)", bold: true, size: 21, font: "Calibri" }),
                            new TextRun({ text: " for Mettupalayam Municipality.", size: 21, font: "Calibri" }),
                        ],
                        spacing: { after: 150 },
                    }),

                    new Paragraph({
                        children: [
                            new TextRun({ text: "As a homegrown technology enterprise based directly in Mettupalayam, Sengotics offers a complete ", size: 21, font: "Calibri" }),
                            new TextRun({ text: "Turnkey Model (Product + Full Service On-Site Operations)", bold: true, size: 21, font: "Calibri" }),
                            new TextRun({ text: ". Unlike distant vendors who provide only remote support, Sengotics takes complete ground-level ownership by deputing dedicated personnel inside the Municipality’s Integrated Command & Control Center (I3C) to manage daily operations.", size: 21, font: "Calibri" }),
                        ],
                        spacing: { after: 200 },
                    }),

                    // Highlights Table
                    new Table({
                        width: { size: 100, type: WidthType.PERCENTAGE },
                        rows: [
                            new TableRow({
                                children: [
                                    new TableCell({
                                        shading: { fill: "0A2463", type: ShadingType.CLEAR },
                                        children: [new Paragraph({ children: [new TextRun({ text: "Key Pillar", bold: true, color: "FFFFFF", size: 19, font: "Calibri" })] })],
                                        width: { size: 30, type: WidthType.PERCENTAGE },
                                    }),
                                    new TableCell({
                                        shading: { fill: "0A2463", type: ShadingType.CLEAR },
                                        children: [new Paragraph({ children: [new TextRun({ text: "Turnkey Municipal Capability & Value Delivery", bold: true, color: "FFFFFF", size: 19, font: "Calibri" })] })],
                                        width: { size: 70, type: WidthType.PERCENTAGE },
                                    }),
                                ],
                            }),
                            new TableRow({
                                children: [
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "1. 100% Dual-Helpline Inclusivity", bold: true, size: 18, font: "Calibri" })] })],
                                    }),
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "24/7 AI-Powered Bilingual (Tamil & English) Voice Helpline (04440115043) for natural spoken grievance logging and live status inquiries, alongside Keypad DTMF IVR (04440115434).", size: 18, font: "Calibri" })] })],
                                    }),
                                ],
                            }),
                            new TableRow({
                                children: [
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "2. Complete Turnkey Field Execution", bold: true, size: 18, font: "Calibri" })] })],
                                    }),
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "Sengotics teams physically survey, map GIS coordinates, and affix weatherproof QR tags to street light poles, water valves, and municipal assets.", size: 18, font: "Calibri" })] })],
                                    }),
                                ],
                            }),
                            new TableRow({
                                children: [
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "3. Verifiable Field Accountability", bold: true, size: 18, font: "Calibri" })] })],
                                    }),
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "Mandatory geo-fenced (≤ 50m GPS radius) live photo verification for electricians and plumbers before closing tickets, eliminating false resolutions.", size: 18, font: "Calibri" })] })],
                                    }),
                                ],
                            }),
                            new TableRow({
                                children: [
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "4. Municipal Revenue Engine", bold: true, size: 18, font: "Calibri" })] })],
                                    }),
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "Digital tracking of weekly market (santhai) stall fees, community hall bookings, and commercial utility pole leases to maximize non-tax revenue recovery.", size: 18, font: "Calibri" })] })],
                                    }),
                                ],
                            }),
                            new TableRow({
                                children: [
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "5. On-Site I3C Staffing & Support", bold: true, size: 18, font: "Calibri" })] })],
                                    }),
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "Dedicated Sengotics personnel stationed inside Mettupalayam Municipality's command center for daily triage, monitoring, and immediate support.", size: 18, font: "Calibri" })] })],
                                    }),
                                ],
                            }),
                            new TableRow({
                                children: [
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "6. MeitY & Cloud Compliance", bold: true, size: 18, font: "Calibri" })] })],
                                    }),
                                    new TableCell({
                                        children: [new Paragraph({ children: [new TextRun({ text: "Hosted on secure, India-based MeitY-compliant cloud infrastructure with complete data sovereignty and role-based access controls (RBAC).", size: 18, font: "Calibri" })] })],
                                    }),
                                ],
                            }),
                        ],
                    }),

                    new Paragraph({ text: "", spacing: { after: 150 } }),

                    new Paragraph({
                        children: [
                            new TextRun({ text: "We have established a live working demo system with active test phone lines and credentials for your immediate evaluation (Live Portal: https://ivr-frontend-system-sengotics.vercel.app/ | AI Voice Helpline: 04440115043).", size: 20, font: "Calibri" }),
                        ],
                        spacing: { after: 150 },
                    }),

                    new Paragraph({
                        children: [
                            new TextRun({ text: "We respectfully request a 15–20 minute demonstration and alignment session with your good selves to showcase the live GIS dashboard and discuss on-site deputation plans.", size: 20, font: "Calibri" }),
                        ],
                        spacing: { after: 200 },
                    }),

                    new Paragraph({
                        children: [
                            new TextRun({ text: "Thanking you.\n\nYours faithfully,\nFor SENGOTICS,\n\n\n\n__________________________________\nAuthorized Signatory / Founder & CEO\n(Official Company Seal)", size: 20, font: "Calibri" }),
                        ],
                        spacing: { after: 250 },
                    }),

                    // Enclosure
                    new Paragraph({
                        children: [
                            new TextRun({ text: "Enclosures:\n", bold: true, size: 19, font: "Calibri" }),
                            new TextRun({ text: "1. Detailed 12-Page Project Proposal Document (Ref: SEG/M/PROP/2026/08)\n2. Live System Demonstration Access Sheet & Test Pole Registry\n3. QR Code Asset Maintenance Demo Card", size: 18, color: "4B5563", font: "Calibri" }),
                        ],
                    }),
                ],
            }],
        });

        const buffer = await Packer.toBuffer(doc);
        const outputPath = path.join(__dirname, '..', 'docs', 'SENGOTICS_PROPOSAL_LETTER.docx');
        fs.writeFileSync(outputPath, buffer);
        console.log("Successfully generated DOCX at:", outputPath);
    } catch (err) {
        console.error("Error generating docx:", err);
    }
}

createDocx();
