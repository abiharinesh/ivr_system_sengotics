const fs = require('fs');
const path = require('path');
const {
    Document,
    Packer,
    Paragraph,
    TextRun,
    Table,
    TableRow,
    TableCell,
    WidthType,
    AlignmentType,
    BorderStyle,
    HeadingLevel,
    ShadingType,
    Header,
    Footer,
    PageNumber,
    PageBreak,
} = require('docx');

// --- COLOR PALETTE & DESIGN SYSTEM ---
const NAVY_PRIMARY = "0F2B5C";     // Deep Tamil Nadu Government Navy
const BLUE_ACCENT = "1E4B8F";      // Slate / Royal Blue
const AMBER_ACCENT = "D97706";     // Warning / Ad Amber
const AMBER_BG = "FEF3C7";         // Soft Amber Fill for Ad Zone
const GREEN_ACCENT = "059669";     // Success Green
const GREEN_BG = "ECFDF5";         // Light Green Background
const TEXT_MAIN = "1F2937";        // Dark Charcoal
const TEXT_MUTED = "4B5563";       // Cool Grey
const BORDER_LIGHT = "CBD5E1";     // Soft Table Border
const ROW_ALT_BG = "F8FAFC";       // Alternating Table Row Fill
const FONT_FAMILY = "Calibri";

const borderNone = { style: BorderStyle.NONE };
const borderThin = { style: BorderStyle.SINGLE, size: 4, color: BORDER_LIGHT };

const tableBordersStandard = {
    top: borderThin,
    bottom: borderThin,
    left: borderThin,
    right: borderThin,
    insideHorizontal: borderThin,
    insideVertical: borderThin,
};

const cellPaddingStandard = { top: 120, bottom: 120, left: 160, right: 160 };

// Helper: Standard Heading 1
function heading1(text) {
    return new Paragraph({
        children: [
            new TextRun({
                text: text,
                bold: true,
                size: 28, // 14pt
                color: NAVY_PRIMARY,
                font: FONT_FAMILY,
            }),
        ],
        spacing: { before: 340, after: 140 },
        keepNext: true,
    });
}

// Helper: Standard Heading 2
function heading2(text) {
    return new Paragraph({
        children: [
            new TextRun({
                text: text,
                bold: true,
                size: 24, // 12pt
                color: BLUE_ACCENT,
                font: FONT_FAMILY,
            }),
        ],
        spacing: { before: 240, after: 100 },
        keepNext: true,
    });
}

// Helper: Standard Heading 3
function heading3(text) {
    return new Paragraph({
        children: [
            new TextRun({
                text: text,
                bold: true,
                size: 21, // 10.5pt
                color: "334155",
                font: FONT_FAMILY,
            }),
        ],
        spacing: { before: 180, after: 80 },
        keepNext: true,
    });
}

// Helper: Body Paragraph
function bodyP(runs, spacingAfter = 120) {
    const children = typeof runs === 'string'
        ? [new TextRun({ text: runs, size: 21, color: TEXT_MAIN, font: FONT_FAMILY })]
        : runs;
    return new Paragraph({
        children: children,
        spacing: { after: spacingAfter, line: 276 },
    });
}

// Helper: Bullet item with bold prefix
function bulletP(boldPrefix, text) {
    return new Paragraph({
        bullet: { level: 0 },
        children: [
            new TextRun({ text: boldPrefix + " ", bold: true, size: 21, color: NAVY_PRIMARY, font: FONT_FAMILY }),
            new TextRun({ text: text, size: 21, color: TEXT_MAIN, font: FONT_FAMILY }),
        ],
        spacing: { after: 90, line: 260 },
    });
}

// Helper: Callout Box
function calloutBox(title, lines, borderColor = BLUE_ACCENT, bgColor = "EFF6FF") {
    const paragraphs = [
        new Paragraph({
            children: [
                new TextRun({ text: title, bold: true, size: 21, color: NAVY_PRIMARY, font: FONT_FAMILY }),
            ],
            spacing: { after: 80 },
        }),
    ];

    lines.forEach(l => {
        if (typeof l === 'string') {
            paragraphs.push(new Paragraph({
                children: [new TextRun({ text: l, size: 20, color: TEXT_MAIN, font: FONT_FAMILY })],
                spacing: { after: 60, line: 260 },
            }));
        } else if (Array.isArray(l)) {
            paragraphs.push(new Paragraph({
                children: l,
                spacing: { after: 60, line: 260 },
            }));
        }
    });

    return new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        borders: {
            top: borderNone,
            bottom: borderNone,
            right: borderNone,
            left: { style: BorderStyle.SINGLE, size: 24, color: borderColor },
            insideHorizontal: borderNone,
            insideVertical: borderNone,
        },
        rows: [
            new TableRow({
                children: [
                    new TableCell({
                        shading: { fill: bgColor, type: ShadingType.CLEAR },
                        margins: { top: 140, bottom: 140, left: 180, right: 180 },
                        children: paragraphs,
                    }),
                ],
            }),
        ],
    });
}

// Helper: QR Plate Mockup in Word (Dual Compartment)
function qrPlateMockup() {
    return new Table({
        width: { size: 70, type: WidthType.PERCENTAGE },
        alignment: AlignmentType.CENTER,
        borders: {
            top: { style: BorderStyle.SINGLE, size: 16, color: "334155" },
            bottom: { style: BorderStyle.SINGLE, size: 16, color: "334155" },
            left: { style: BorderStyle.SINGLE, size: 16, color: "334155" },
            right: { style: BorderStyle.SINGLE, size: 16, color: "334155" },
            insideHorizontal: { style: BorderStyle.DASHED, size: 12, color: AMBER_ACCENT },
            insideVertical: borderNone,
        },
        rows: [
            // Top Zone: Commercial Sponsor Advertisement
            new TableRow({
                children: [
                    new TableCell({
                        shading: { fill: AMBER_BG, type: ShadingType.CLEAR },
                        margins: { top: 120, bottom: 120, left: 160, right: 160 },
                        children: [
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "📢 COMMERCIAL ADVERTISEMENT / SPONSOR SPACE", bold: true, size: 18, color: "B45309", font: FONT_FAMILY }),
                                ],
                            }),
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "KALYAN JEWELLERS / CANARA BANK", bold: true, size: 22, color: "1F2937", font: FONT_FAMILY }),
                                ],
                            }),
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "“Near Mettupalayam Bus Stand • Special Festival Offers”", italics: true, size: 18, color: "4B5563", font: FONT_FAMILY }),
                                ],
                            }),
                        ],
                    }),
                ],
            }),
            // Bottom Zone: Municipal QR Grievance Plate
            new TableRow({
                children: [
                    new TableCell({
                        shading: { fill: "FFFFFF", type: ShadingType.CLEAR },
                        margins: { top: 140, bottom: 140, left: 160, right: 160 },
                        children: [
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "🏛️ தமிழ்நாடு அரசு • மேட்டுப்பாளையம் நகராட்சி", bold: true, size: 20, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                                ],
                            }),
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "METTUPALAYAM MUNICIPALITY — STREET LIGHT & ASSET TAG", bold: true, size: 18, color: BLUE_ACCENT, font: FONT_FAMILY }),
                                ],
                            }),
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "Scan to Report Fault • பழுது புகாரளிக்க", size: 19, color: "334155", font: FONT_FAMILY }),
                                ],
                                spacing: { after: 80 },
                            }),
                            // QR Box representation
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "[  ■ ■ ■ ■   2D DYNAMIC QR CODE   ■ ■ ■ ■  ]\n(Encoded with Cryptographic Public Asset Token)", bold: true, size: 18, color: "475569", font: "Consolas" }),
                                ],
                                spacing: { after: 80 },
                            }),
                            // Pole ID Banner
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "  POLE KEYPAD ID: 101  ", bold: true, size: 24, color: "FFFFFF", font: FONT_FAMILY }),
                                ],
                                shading: { fill: "0F172A", type: ShadingType.CLEAR },
                                spacing: { after: 80 },
                            }),
                            new Paragraph({
                                alignment: AlignmentType.CENTER,
                                children: [
                                    new TextRun({ text: "24/7 AI Voice Helpline: ", bold: true, size: 19, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                                    new TextRun({ text: "04440115043", bold: true, size: 19, color: GREEN_ACCENT, font: FONT_FAMILY }),
                                    new TextRun({ text: "  |  Keypad IVR: ", bold: true, size: 19, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                                    new TextRun({ text: "04440115434", bold: true, size: 19, color: BLUE_ACCENT, font: FONT_FAMILY }),
                                ],
                            }),
                        ],
                    }),
                ],
            }),
        ],
    });
}

// Helper: Code / Monospace Diagram Box
function diagramBox(diagramLines) {
    const paragraphs = diagramLines.map(line => new Paragraph({
        children: [
            new TextRun({
                text: line,
                font: "Consolas",
                size: 17,
                color: "1E293B",
            }),
        ],
        spacing: { after: 20, line: 200 },
    }));

    return new Table({
        width: { size: 100, type: WidthType.PERCENTAGE },
        borders: {
            top: borderThin,
            bottom: borderThin,
            left: borderThin,
            right: borderThin,
            insideHorizontal: borderNone,
            insideVertical: borderNone,
        },
        rows: [
            new TableRow({
                children: [
                    new TableCell({
                        shading: { fill: "F1F5F9", type: ShadingType.CLEAR },
                        margins: { top: 120, bottom: 120, left: 160, right: 160 },
                        children: paragraphs,
                    }),
                ],
            }),
        ],
    });
}

async function buildFullEditableDocx() {
    console.log("Building Comprehensive Editable Word Document (.docx)...");

    const doc = new Document({
        sections: [{
            properties: {
                page: {
                    margin: {
                        top: 1150,    // ~20mm
                        bottom: 1150,
                        left: 1150,
                        right: 1150,
                    },
                },
            },
            headers: {
                default: new Header({
                    children: [
                        new Paragraph({
                            alignment: AlignmentType.RIGHT,
                            children: [
                                new TextRun({
                                    text: "GOVERNMENT OF TAMIL NADU  |  SMART GIS STREET LIGHT TENDER SPECIFICATION",
                                    size: 16,
                                    color: "64748B",
                                    bold: true,
                                    font: FONT_FAMILY,
                                }),
                            ],
                        }),
                    ],
                }),
            },
            footers: {
                default: new Footer({
                    children: [
                        new Table({
                            width: { size: 100, type: WidthType.PERCENTAGE },
                            borders: {
                                top: { style: BorderStyle.SINGLE, size: 4, color: "E2E8F0" },
                                bottom: borderNone,
                                left: borderNone,
                                right: borderNone,
                                insideHorizontal: borderNone,
                                insideVertical: borderNone,
                            },
                            rows: [
                                new TableRow({
                                    children: [
                                        new TableCell({
                                            children: [
                                                new Paragraph({
                                                    children: [
                                                        new TextRun({
                                                            text: "Tender Ref: ROC / ENGG / ELEC / 2026 / T-01 — Official Tender Document",
                                                            size: 16,
                                                            color: "64748B",
                                                            font: FONT_FAMILY,
                                                        }),
                                                    ],
                                                }),
                                            ],
                                            width: { size: 70, type: WidthType.PERCENTAGE },
                                        }),
                                        new TableCell({
                                            children: [
                                                new Paragraph({
                                                    alignment: AlignmentType.RIGHT,
                                                    children: [
                                                        new TextRun({ text: "Page ", size: 16, color: "64748B", font: FONT_FAMILY }),
                                                        new TextRun({ children: [PageNumber.CURRENT], size: 16, color: "64748B", font: FONT_FAMILY }),
                                                        new TextRun({ text: " of ", size: 16, color: "64748B", font: FONT_FAMILY }),
                                                        new TextRun({ children: [PageNumber.TOTAL_PAGES], size: 16, color: "64748B", font: FONT_FAMILY }),
                                                    ],
                                                }),
                                            ],
                                            width: { size: 30, type: WidthType.PERCENTAGE },
                                        }),
                                    ],
                                }),
                            ],
                        }),
                    ],
                }),
            },
            children: [
                // --- OFFICIAL GOVERNMENT HEADER ---
                new Paragraph({
                    alignment: AlignmentType.CENTER,
                    children: [
                        new TextRun({
                            text: "தமிழ்நாடு அரசு • உள்ளாட்சி நிர்வாகத் துறை",
                            bold: true,
                            size: 26, // 13pt
                            color: NAVY_PRIMARY,
                            font: FONT_FAMILY,
                        }),
                    ],
                }),
                new Paragraph({
                    alignment: AlignmentType.CENTER,
                    children: [
                        new TextRun({
                            text: "GOVERNMENT OF TAMIL NADU • MUNICIPAL ADMINISTRATION DEPARTMENT",
                            bold: true,
                            size: 22, // 11pt
                            color: BLUE_ACCENT,
                            font: FONT_FAMILY,
                        }),
                    ],
                }),
                new Paragraph({
                    alignment: AlignmentType.CENTER,
                    children: [
                        new TextRun({
                            text: "Office of the Municipal Commissioner / Executive Officer • Engineering Section",
                            size: 19,
                            color: TEXT_MUTED,
                            font: FONT_FAMILY,
                        }),
                    ],
                    spacing: { after: 140 },
                }),

                // Title Block Card
                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    borders: {
                        top: { style: BorderStyle.SINGLE, size: 12, color: NAVY_PRIMARY },
                        bottom: { style: BorderStyle.SINGLE, size: 12, color: NAVY_PRIMARY },
                        left: { style: BorderStyle.SINGLE, size: 12, color: NAVY_PRIMARY },
                        right: { style: BorderStyle.SINGLE, size: 12, color: NAVY_PRIMARY },
                        insideHorizontal: borderNone,
                        insideVertical: borderNone,
                    },
                    rows: [
                        new TableRow({
                            children: [
                                new TableCell({
                                    shading: { fill: "0F2B5C", type: ShadingType.CLEAR },
                                    margins: { top: 180, bottom: 180, left: 200, right: 200 },
                                    children: [
                                        new Paragraph({
                                            alignment: AlignmentType.CENTER,
                                            children: [
                                                new TextRun({
                                                    text: "SMART GIS STREET LIGHT & ELECTRIC POLE INFRASTRUCTURE MANAGEMENT SYSTEM",
                                                    bold: true,
                                                    size: 26, // 13pt
                                                    color: "FFFFFF",
                                                    font: FONT_FAMILY,
                                                }),
                                            ],
                                        }),
                                        new Paragraph({
                                            alignment: AlignmentType.CENTER,
                                            children: [
                                                new TextRun({
                                                    text: "Comprehensive Concept Proposal, Technical Schedule of Requirements, Bill of Quantities (BOQ), and Service Level Agreement (SLA) for E-Tender Publication",
                                                    italics: true,
                                                    size: 20,
                                                    color: "E2E8F0",
                                                    font: FONT_FAMILY,
                                                }),
                                            ],
                                            spacing: { before: 80 },
                                        }),
                                    ],
                                }),
                            ],
                        }),
                    ],
                }),

                new Paragraph({ text: "", spacing: { after: 120 } }),

                // Meta Grid Table (6 items)
                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    borders: tableBordersStandard,
                    rows: [
                        new TableRow({
                            children: [
                                metaCell("TENDER REFERENCE NO.", "ROC / ENGG / ELEC / 2026 / T-01", 33),
                                metaCell("PROCUREMENT FRAMEWORK", "TN Transparency in Tenders Act 1998 & Rules 2000", 33),
                                metaCell("TARGET LOCAL BODY", "[Mettupalayam Municipality / Local Body]", 34),
                            ],
                        }),
                        new TableRow({
                            children: [
                                metaCell("CONTRACT DURATION", "60 Days Setup + 36 Months O&M", 33),
                                metaCell("BIDDING SYSTEM", "Two-Cover (Technical + Financial)", 33),
                                metaCell("HELPLINE CHANNELS", "AI Voice Agent + DTMF IVR (24x7)", 34),
                            ],
                        }),
                    ],
                }),

                new Paragraph({ text: "", spacing: { after: 150 } }),

                // --- SECTION 1 ---
                heading1("1. PROJECT BACKGROUND & EXECUTIVE SUMMARY"),
                bodyP("Urban and Rural Local Bodies in Tamil Nadu manage extensive street lighting networks. However, civic administrations face critical operational bottlenecks:"),
                bulletP("• Unreported Dark Spots:", "Faulty lights remain dark for weeks because civic bodies lack proactive complaint detection and automated spatial logging."),
                bulletP("• Digital Exclusion:", "Traditional text-based web portals and mobile apps fail to cater to senior citizens, rural residents, and semi-literate demographics who cannot type written complaints."),
                bulletP("• Fraudulent Complaint Closures:", "Contractors or maintenance staff frequently mark tickets 'Resolved' without physically attending the site, leading to citizen dissatisfaction and wasted public funds."),
                bodyP("This project introduces a turnkey e-governance framework integrating Conversational AI Voice Redressal in Tamil and English, Weatherproof Retroreflective QR Asset Tags, Citizen Instant Scan Portals, Field Electrician Geo-Fencing (≤ 50m), and Executive I3C GIS Command Dashboards."),

                calloutBox("Core Objective for Tender Publication:", [
                    "To procure a turnkey technology partner who will survey 100% of the municipal electric poles, install tamper-proof QR plates, operate 24/7 dual-helpline AI voice infrastructure, and provide geo-verified field enforcement to maintain 99%+ street light uptime.",
                ], GREEN_ACCENT, GREEN_BG),

                new Paragraph({ text: "", spacing: { after: 150 } }),

                // --- SECTION 2 ---
                heading1("2. DETAILED SCOPE OF WORK (SOW)"),
                heading2("2.1 Door-to-Door GIS Asset Survey & Retroreflective QR Tagging"),
                bulletP("Sub-Meter GNSS Survey:", "Field mapping of every street light pole capturing Latitude, Longitude (WGS-84), Pole Material (Tubular, PSC Concrete, Octagonal), Lamp Type (LED, SV), Wattage (20W, 40W, 70W, 120W), Feeder Phase, and bilingual Tamil/English landmark."),
                bulletP("Weatherproof Anodized Aluminum Plates:", "Fabrication and physical installation of 150mm × 100mm retroreflective QR plates attached with Grade 304 Stainless Steel banding at a standard height of 2.2m to 2.5 meters."),

                new Paragraph({ text: "", spacing: { after: 100 } }),
                bodyP("Below is the official physical design layout of the Dual-Compartment QR Plate:"),

                // Visual Mockup of QR Plate
                qrPlateMockup(),

                new Paragraph({ text: "", spacing: { after: 140 } }),

                // Municipal Non-Tax Revenue Model
                calloutBox("Municipal Non-Tax Revenue Generation Model (Self-Funding Asset):", [
                    "By monetizing the top commercial advertisement panel across 5,000 electric poles, the municipality can generate substantial recurring non-tax revenue:",
                    [
                        new TextRun({ text: "• Commercial Arterial Roads (1,500 Poles @ ₹200/month): ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "₹36,00,000 / year", bold: true, size: 20, color: GREEN_ACCENT, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Residential Wards (2,500 Poles @ ₹75/month): ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "₹22,50,000 / year", bold: true, size: 20, color: GREEN_ACCENT, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Peripheral Wards (1,000 Poles @ ₹40/month): ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "₹4,80,000 / year", bold: true, size: 20, color: GREEN_ACCENT, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Total Potential Annual Municipal Ad Revenue: ", bold: true, size: 21, font: FONT_FAMILY }),
                        new TextRun({ text: "₹63,30,000 / Year (₹63.3 Lakhs/Year)", bold: true, size: 21, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                    ],
                    "💡 Even at an average 40% occupancy rate, the municipality recovers over ₹25.0 Lakhs annually, turning this entire smart governance initiative into a net-profitable municipal asset! In-software digital banner impressions are also tracked via the AdCampaign & AdImpression database engine.",
                ], AMBER_ACCENT, AMBER_BG),

                new Paragraph({ text: "", spacing: { after: 150 } }),
                new Paragraph({ children: [new PageBreak()] }),

                heading2("2.2 24/7 Dual-Helpline AI Voice Telephony Infrastructure"),
                bulletP("Primary Conversational AI Agent (04440115043):", "Equipped with realistic natural Tamil speech recognition (ASR) tuned to regional Tamil Nadu dialects (Kongu, Chennai, Madurai, Delta). Citizens speak colloquially without rigid keypad IVR menus (e.g. 'பஸ் ஸ்டாண்ட் பக்கத்துல ஸ்ட்ரீட் லைட் எரியல'). The AI dynamically queries existing complaint statuses from PostgreSQL and speaks back live updates in Tamil."),
                bulletP("Secondary DTMF Keypad IVR (04440115434):", "Optimized for basic 2G feature phones and poor signal conditions. The citizen enters their 3-digit or 4-digit Pole ID (e.g. 101#) to instantly locate the asset and log the ticket."),

                calloutBox("Sample Live Tamil AI Voice Redressal Dialogue:", [
                    [new TextRun({ text: "குடிமகன்: “வணக்கம், காந்தி நகர் 3வது தெருவுல லைட் எரியல.”", bold: true, size: 20, color: NAVY_PRIMARY, font: FONT_FAMILY })],
                    [new TextRun({ text: "AI குரல் முகவர்: “உங்கள் புகார் பதிவு செய்யப்பட்டது. மின்கம்ப எண் 101-க்கு கள மின்சார பணியாளர் நியமிக்கப்பட்டுள்ளார்; இன்று மாலைக்குள் சரிசெய்யப்படும்.”", italics: true, bold: true, size: 20, color: GREEN_ACCENT, font: FONT_FAMILY })],
                ], GREEN_ACCENT, GREEN_BG),

                new Paragraph({ text: "", spacing: { after: 120 } }),

                heading2("2.3 Multi-Platform Application Suite (Flutter Web & Mobile for All Roles)"),
                bodyP("Engineered on a unified Flutter codebase, providing specialized native Mobile Applications and Desktop Web Applications tailored to every municipal role:"),

                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    borders: tableBordersStandard,
                    rows: [
                        tableHeaderRow(["User Suite", "Desktop Web Application Features", "Mobile Application Features"], [25, 40, 35]),
                        tableDataRow([
                            "👨‍💼 Administrator Suite",
                            "Full GIS command center, ward dark-spot cluster heatmaps, automated statutory tender PDF compiler, and commercial ad campaign manager.",
                            "Real-time on-the-go alerts, ticket approvals, field staff live tracking, and emergency escalations on Android/iOS.",
                        ], [25, 40, 35], false),
                        tableDataRow([
                            "⚡ Field Electrician Suite",
                            "Workshop dispatch queue and job card view for electrical supervisors in municipal workshops.",
                            "Mandatory ≤ 50m Geo-Fencing lock, live camera EXIF capture, OCR pole plate scanning, and offline sync in cellular shadow zones.",
                        ], [25, 40, 35], true),
                        tableDataRow([
                            "👥 Citizen Engagement Suite",
                            "Zero-install camera QR scan PWA from any mobile browser with top sponsor ad banner and 1-tap fault logging.",
                            "Play Store mobile app with live push notifications, complaint timeline, and ward street lighting status map.",
                        ], [25, 40, 35], false),
                    ],
                }),

                new Paragraph({ text: "", spacing: { after: 140 } }),

                heading2("2.4 Executive I3C Command Dashboard & Tamil Nadu Statutory Tender Engine"),
                bodyP("The Integrated Command & Control Center (I3C) web portal aggregates live telemetry and recurring defect clusters directly into procurement bundles, compiling statutory Tamil Nadu local body document packs:"),
                bulletP("• விலைப்புள்ளி கோருதல் (RFQ Document):", "Request for Quotation with line item schedule and statutory notice rules."),
                bulletP("• கொட்டேஷன் (Vendor Quotation Forms):", "Pre-formatted quotation templates per registered electrical contractor."),
                bulletP("• ஒப்பு நோக்கு பட்டியல் (Comparative Statement):", "Automated L1 rate evaluation, tax breakdown, and lowest bidder determination table."),
                bulletP("• வேலை உத்தரவு (Official Work Order):", "Legally binding municipal contract specifying execution window and terms."),
                bulletP("• தனி அலுவலர் நடவடிக்கைகள் (Special Officer Proceedings):", "Financial sanction proceedings with administrative amount in figures and Tamil words."),
                bulletP("• செலவினச் சீட்டு (Form 19 Expenditure Voucher):", "Complete digital measurement book (M-Book) certification for audit compliance."),

                new Paragraph({ text: "", spacing: { after: 150 } }),
                new Paragraph({ children: [new PageBreak()] }),

                // --- SECTION 3 ---
                heading1("3. HARDWARE & MATERIAL SPECIFICATIONS"),
                heading2("3.1 Weatherproof QR Asset Plates"),
                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    borders: tableBordersStandard,
                    rows: [
                        tableHeaderRow(["Specification Parameter", "Mandatory Technical Requirement"], [30, 70]),
                        tableDataRow(["Plate Material & Thickness", "Anodized Aluminum Alloy (6061-T6), 1.5 mm thickness ± 5%."], [30, 70], false),
                        tableDataRow(["Plate Dimensions", "150 mm (Height) × 100 mm (Width) with rounded safety corners."], [30, 70], true),
                        tableDataRow(["Reflective Sheeting", "Class 2 Retroreflective sheeting (ASTM D4956 Type IV) visible at night under vehicle headlights."], [30, 70], false),
                        tableDataRow(["Coating & Weatherproofing", "UV-curable industrial screen printing with protective polyurethane clear coat; 7-year tropical lifespan."], [30, 70], true),
                        tableDataRow(["Mounting Hardware", "Grade 304 Stainless Steel strapping bands (12.7mm width) with heavy-duty wing seals or drive rivets."], [30, 70], false),
                    ],
                }),

                new Paragraph({ text: "", spacing: { after: 150 } }),

                // --- SECTION 4 ---
                heading1("4. SERVICE LEVEL AGREEMENT (SLA) & PENALTY DEDUCTION SCHEDULE"),
                bodyP("The contractor shall strictly adhere to the turnaround times (TAT) for grievance resolution and system uptime. Penalties shall be computed automatically by the I3C engine and deducted from monthly bills:"),

                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    borders: tableBordersStandard,
                    rows: [
                        tableHeaderRow(["Incident Classification", "Description & Fault Type", "Max Turnaround Time (TAT)", "Penalty for SLA Breach"], [24, 36, 20, 20]),
                        tableDataRow(["Tier-1: Critical Hazard", "Fallen pole, dangling live wire, shock risk near public institutions.", "Within 4 Hours", "₹500 / hour delay"], [24, 36, 20, 20], false),
                        tableDataRow(["Tier-2: High Priority", "Complete street outage (>3 poles dark), main commercial road.", "Within 12 Hours", "₹200 / pole / day"], [24, 36, 20, 20], true),
                        tableDataRow(["Tier-3: Standard Fault", "Single bulb failure, fixture flickering.", "Within 24 Hours", "₹100 / pole / day"], [24, 36, 20, 20], false),
                        tableDataRow(["Tier-4: Daytime Burning", "Street lights remaining ON during daylight (>06:30 AM).", "Within 2 Hours", "₹50 / pole / event"], [24, 36, 20, 20], true),
                        tableDataRow(["Telephony Availability", "AI Voice Helpline & IVR Uptime (≥ 99.5% monthly).", "24x7 Continuous", "₹2,000 / hour downtime"], [24, 36, 20, 20], false),
                    ],
                }),

                new Paragraph({ text: "", spacing: { after: 150 } }),
                new Paragraph({ children: [new PageBreak()] }),

                // --- SECTION 5 ---
                heading1("5. BILL OF QUANTITIES (BOQ) & FINANCIAL SCHEDULE TEMPLATE"),
                bodyP("Bidders shall quote rates strictly in the electronic financial bid cover (Cover 2). Below is the comprehensive Bill of Quantities schedule based on a baseline municipal infrastructure of 5,000 electric poles:"),

                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    borders: tableBordersStandard,
                    rows: [
                        tableHeaderRow(["Item", "Description of Item / Scope Component", "UOM", "Qty", "Unit Rate (₹)", "Total Amount (₹)"], [8, 46, 10, 10, 12, 14]),
                        tableDataRow(["1.01", "Physical GIS Asset Survey: Comprehensive door-to-door ground mapping of electric poles including sub-meter GNSS coordinates, fixture type, wattage, phase, line condition, and bilingual street landmarks.", "Per Pole", "5,000", "₹50.00", "₹2,50,000.00"], [8, 46, 10, 10, 12, 14], false),
                        tableDataRow(["1.02", "QR Asset Plate Fabrication & Installation: Supply and installation of retroreflective anodized aluminum QR plates (150x100 mm, 1.5mm thickness) with stainless steel bands, high-contrast Pole ID, and UV protective clear coat.", "Per Plate", "5,000", "₹120.00", "₹6,00,000.00"], [8, 46, 10, 10, 12, 14], true),
                        tableDataRow(["1.03", "Software Platform Setup: Ooraatchi GIS platform, Web Dashboard, RBAC modules, automated tender engine, PostGIS spatial database, and integration with local body GIS boundary.", "Lump Sum", "1 Job", "₹3,00,000.00", "₹3,00,000.00"], [8, 46, 10, 10, 12, 14], false),
                        tableDataRow(["1.04", "Dual-Helpline AI Voice Telephony & IVR Channel: Setup and operation of conversational Tamil/English AI Voice Agent and DTMF Keypad IVR lines, including Exotel SIP trunks, ASR speech recognition models, and cloud dialer.", "Per Month", "36 Mos", "₹20,000.00", "₹7,20,000.00"], [8, 46, 10, 10, 12, 14], true),
                        tableDataRow(["1.05", "Field Workforce & Citizen Mobile Applications: Mobile app deployment on Android Play Store, including geo-fenced resolution engine (≤ 50m radius lock), OCR verification, and PWA instant scan portal.", "Lump Sum", "1 Job", "₹2,00,000.00", "₹2,00,000.00"], [8, 46, 10, 10, 12, 14], false),
                        tableDataRow(["1.06", "Cloud Hosting & Data Security: High-availability MeitY-empaneled Tier-III cloud hosting, automated daily backups, SSL TLS 1.3 certificates, and 99.5% uptime assurance.", "Per Year", "3 Years", "₹90,000.00", "₹2,70,000.00"], [8, 46, 10, 10, 12, 14], true),
                        tableDataRow(["1.07", "Turnkey Operations & On-Site I3C Support: Provision of dedicated, trained technical operator deployed at the Municipal Command Center for daily ticket triage, SLA monitoring, and report generation.", "Per Month", "36 Mos", "₹20,000.00", "₹7,20,000.00"], [8, 46, 10, 10, 12, 14], false),
                        // Subtotal
                        new TableRow({
                            children: [
                                new TableCell({
                                    shading: { fill: "E2E8F0", type: ShadingType.CLEAR },
                                    margins: cellPaddingStandard,
                                    columnSpan: 5,
                                    children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "SUBTOTAL (Base Turnkey Contract Value Excl. GST):", bold: true, size: 20, color: NAVY_PRIMARY, font: FONT_FAMILY })] })],
                                }),
                                new TableCell({
                                    shading: { fill: "E2E8F0", type: ShadingType.CLEAR },
                                    margins: cellPaddingStandard,
                                    children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "₹30,60,000.00", bold: true, size: 20, color: NAVY_PRIMARY, font: FONT_FAMILY })] })],
                                }),
                            ],
                        }),
                        // GST
                        new TableRow({
                            children: [
                                new TableCell({
                                    shading: { fill: "F8FAFC", type: ShadingType.CLEAR },
                                    margins: cellPaddingStandard,
                                    columnSpan: 5,
                                    children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "Applicable GST @ 18% (CGST 9% ₹2,75,400 + SGST 9% ₹2,75,400):", bold: true, size: 20, color: TEXT_MUTED, font: FONT_FAMILY })] })],
                                }),
                                new TableCell({
                                    shading: { fill: "F8FAFC", type: ShadingType.CLEAR },
                                    margins: cellPaddingStandard,
                                    children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "₹5,50,800.00", bold: true, size: 20, color: TEXT_MUTED, font: FONT_FAMILY })] })],
                                }),
                            ],
                        }),
                        // Total
                        new TableRow({
                            children: [
                                new TableCell({
                                    shading: { fill: NAVY_PRIMARY, type: ShadingType.CLEAR },
                                    margins: cellPaddingStandard,
                                    columnSpan: 5,
                                    children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "TOTAL COMPREHENSIVE CONTRACT VALUE (INCLUSIVE OF 18% GST):", bold: true, size: 21, color: "FFFFFF", font: FONT_FAMILY })] })],
                                }),
                                new TableCell({
                                    shading: { fill: NAVY_PRIMARY, type: ShadingType.CLEAR },
                                    margins: cellPaddingStandard,
                                    children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "₹36,10,800.00", bold: true, size: 21, color: "FFFFFF", font: FONT_FAMILY })] })],
                                }),
                            ],
                        }),
                    ],
                }),

                new Paragraph({ text: "", spacing: { after: 120 } }),

                calloutBox("Financial Summary & Statutory Certification:", [
                    [
                        new TextRun({ text: "• Base Contract Value (Excl. GST): ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "₹30,60,000.00 (Rupees Thirty Lakhs Sixty Thousand Only / ரூபாய் முப்பது லட்சத்து அறுபதாயிரம் மட்டும்)", size: 20, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Total Contract Value (Incl. 18% GST): ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "₹36,10,800.00 (Rupees Thirty-Six Lakhs Ten Thousand Eight Hundred Only / ரூபாய் முப்பத்தாறு லட்சத்து பத்தாயிரத்து எண்ணூறு மட்டும்)", size: 20, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Capital Expenditure (Capex - Year 1 Setup, Survey, Plates & Software): ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "₹13,50,000.00 (44.1% of base budget)", size: 20, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Operational Expenditure (Opex - 36-Month Telephony, Cloud & On-Site Operator): ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "₹17,10,000.00 (55.9% of base budget)", size: 20, font: FONT_FAMILY }),
                    ],
                ], "1E40AF", "EFF6FF"),

                new Paragraph({ text: "", spacing: { after: 150 } }),

                // --- SECTION 6 ---
                heading1("6. BIDDER ELIGIBILITY & TECHNICAL EVALUATION MATRIX"),
                heading2("6.1 Minimum Pre-Qualification (PQ) Criteria"),
                bulletP("• Legal Entity:", "Registered Company / LLP / MSME in India with valid GSTIN and PAN."),
                bulletP("• Financial Standing:", "Average annual turnover of ≥ ₹50 Lakhs in the last 3 financial years. (Exemption for registered Tamil Nadu MSMEs / DPIIT startups as per government procurement rules)."),
                bulletP("• Past Experience:", "Prior proven deployment of GIS Asset Mapping, Cloud Portals, or Telephony IVR for a Municipal or Government body."),
                bulletP("• GeM Seller:", "Must hold an active Seller Profile on Government e-Marketplace (GeM)."),
                bulletP("• No Blacklisting:", "Affidavit on ₹100 stamp paper certifying no debarment by Central/State Governments or PSUs."),

                heading2("6.2 Technical Evaluation Scoring Matrix (100 Marks Total)"),
                bodyP("Only bidders scoring ≥ 75 marks in the technical evaluation shall qualify for opening of the electronic financial bid (Cover 2):"),

                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    borders: tableBordersStandard,
                    rows: [
                        tableHeaderRow(["Evaluation Parameter", "Criteria & Detailed Mark Breakdown", "Max Marks"], [30, 55, 15]),
                        tableDataRow(["Organizational Strength & Financial Turnover", "• Turnover > ₹1 Crore: 15 Marks\n• Turnover ₹50 Lakhs to ₹1 Crore: 10 Marks\n• Registered MSME / Startup in Tamil Nadu: 5 Marks bonus", "20 Marks"], [30, 55, 15], false),
                        tableDataRow(["Prior Experience in GIS & Civic Technology", "• ≥ 3 Similar Projects executed: 20 Marks\n• 1 to 2 Similar Projects executed: 10 Marks", "20 Marks"], [30, 55, 15], true),
                        tableDataRow(["Live Product Demonstration & Feature Validation", "Real-time demonstration before the technical evaluation committee:\n• Conversational AI Tamil Voice Call test\n• DTMF Keypad IVR pole lookup test\n• QR scan instant reporting PWA\n• Field mobile app ≤ 50m geo-fencing lock verification", "30 Marks"], [30, 55, 15], false),
                        tableDataRow(["System Architecture & Cloud Security Plan", "Cloud architecture blueprint, MeitY Tier-III compliance, PostGIS spatial indexing schema, disaster recovery, and automated backup strategy.", "15 Marks"], [30, 55, 15], true),
                        tableDataRow(["On-Site Operational Support Methodology", "Staffing plan, command center operations manual, field workforce training modules, and multi-tier SLA escalation framework.", "15 Marks"], [30, 55, 15], false),
                        // Total Row
                        new TableRow({
                            children: [
                                new TableCell({
                                    shading: { fill: NAVY_PRIMARY, type: ShadingType.CLEAR },
                                    margins: cellPaddingStandard,
                                    columnSpan: 2,
                                    children: [new Paragraph({ alignment: AlignmentType.RIGHT, children: [new TextRun({ text: "TOTAL MAXIMUM TECHNICAL SCORE (Qualifying Threshold ≥ 75 Marks):", bold: true, size: 20, color: "FFFFFF", font: FONT_FAMILY })] })],
                                }),
                                new TableCell({
                                    shading: { fill: NAVY_PRIMARY, type: ShadingType.CLEAR },
                                    margins: cellPaddingStandard,
                                    children: [new Paragraph({ alignment: AlignmentType.CENTER, children: [new TextRun({ text: "100 Marks", bold: true, size: 21, color: "FFFFFF", font: FONT_FAMILY })] })],
                                }),
                            ],
                        }),
                    ],
                }),

                new Paragraph({ text: "", spacing: { after: 150 } }),
                new Paragraph({ children: [new PageBreak()] }),

                // --- SECTION 7 ---
                heading1("7. ANNEXURES & STATUTORY SIGNATURE BLOCKS"),
                heading2("Annexure I: Live System Evaluation Credentials"),
                calloutBox("Live Production Demonstration Environments:", [
                    [
                        new TextRun({ text: "• Live Platform Web Portal: ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "https://ivr-frontend-system-sengotics.vercel.app/", size: 20, color: "2563EB", underline: {}, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Primary Conversational AI Voice Line: ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "04440115043 ", bold: true, size: 21, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                        new TextRun({ text: "(Dial from any phone to test natural spoken Tamil grievance intake)", size: 19, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Secondary DTMF Keypad IVR Helpline: ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "04440115434 ", bold: true, size: 21, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                        new TextRun({ text: "(Dial and enter test Pole Keypad IDs: 101, 102, or 103 followed by #)", size: 19, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Evaluation Admin Login: ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "admin@sengotics.com  |  Password: ", size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "Admin@1234", bold: true, size: 20, font: FONT_FAMILY }),
                    ],
                    [
                        new TextRun({ text: "• Field Electrician Mobile Login: ", bold: true, size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "electrician@sengotics.com  |  Password: ", size: 20, font: FONT_FAMILY }),
                        new TextRun({ text: "Admin@1234", bold: true, size: 20, font: FONT_FAMILY }),
                    ],
                ], "1E40AF", "F0F9FF"),

                new Paragraph({ text: "", spacing: { after: 200 } }),

                heading2("Annexure II: Officer Certification & Approval Block"),
                bodyP("(To be signed by the competent municipal authority upon formal adoption into the local body tender notification):"),

                new Table({
                    width: { size: 100, type: WidthType.PERCENTAGE },
                    borders: {
                        top: borderThin,
                        bottom: borderThin,
                        left: borderThin,
                        right: borderThin,
                        insideHorizontal: borderThin,
                        insideVertical: borderThin,
                    },
                    rows: [
                        new TableRow({
                            children: [
                                new TableCell({
                                    margins: { top: 160, bottom: 160, left: 180, right: 180 },
                                    width: { size: 50, type: WidthType.PERCENTAGE },
                                    children: [
                                        new Paragraph({
                                            children: [
                                                new TextRun({ text: "Prepared & Technically Verified:\n\n\n\n\n", bold: true, size: 20, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                                                new TextRun({ text: "_________________________________________\n", bold: true, size: 20, color: "334155", font: FONT_FAMILY }),
                                                new TextRun({ text: "Junior Engineer / Municipal Engineer\n", bold: true, size: 20, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                                                new TextRun({ text: "[Name of Local Body / Engineering Section]\n\nDate: __________________\nOfficial Seal:", size: 19, color: TEXT_MUTED, font: FONT_FAMILY }),
                                            ],
                                        }),
                                    ],
                                }),
                                new TableCell({
                                    margins: { top: 160, bottom: 160, left: 180, right: 180 },
                                    width: { size: 50, type: WidthType.PERCENTAGE },
                                    children: [
                                        new Paragraph({
                                            children: [
                                                new TextRun({ text: "Approved for Tender Notification:\n\n\n\n\n", bold: true, size: 20, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                                                new TextRun({ text: "_________________________________________\n", bold: true, size: 20, color: "334155", font: FONT_FAMILY }),
                                                new TextRun({ text: "Municipal Commissioner / Executive Officer\n", bold: true, size: 20, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                                                new TextRun({ text: "[Name of Local Body / Administration]\n\nDate: __________________\nOfficial Seal:", size: 19, color: TEXT_MUTED, font: FONT_FAMILY }),
                                            ],
                                        }),
                                    ],
                                }),
                            ],
                        }),
                    ],
                }),
            ],
        }],
    });

    const buffer = await Packer.toBuffer(doc);
    
    // Output path 1: Exactly matching user's active PDF name
    const outputPathUpdated = path.join(__dirname, '..', 'docs', 'TENDER_CONCEPT_ELECTRICAL_POLE_MODULE_UPDATED.docx');
    fs.writeFileSync(outputPathUpdated, buffer);
    console.log("Successfully generated:", outputPathUpdated);

    // Output path 2: Standard module docx name
    const outputPathStandard = path.join(__dirname, '..', 'docs', 'TENDER_CONCEPT_ELECTRICAL_POLE_MODULE.docx');
    fs.writeFileSync(outputPathStandard, buffer);
    console.log("Successfully generated:", outputPathStandard);
}

// Helper: Meta cell
function metaCell(title, value, widthPct) {
    return new TableCell({
        shading: { fill: "F8FAFC", type: ShadingType.CLEAR },
        margins: cellPaddingStandard,
        width: { size: widthPct, type: WidthType.PERCENTAGE },
        children: [
            new Paragraph({
                children: [
                    new TextRun({ text: title + "\n", bold: true, size: 17, color: NAVY_PRIMARY, font: FONT_FAMILY }),
                    new TextRun({ text: value, size: 19, color: TEXT_MAIN, font: FONT_FAMILY }),
                ],
            }),
        ],
    });
}

function tableHeaderRow(titles, widths) {
    return new TableRow({
        children: titles.map((title, i) => new TableCell({
            shading: { fill: NAVY_PRIMARY, type: ShadingType.CLEAR },
            margins: cellPaddingStandard,
            width: { size: widths[i], type: WidthType.PERCENTAGE },
            children: [
                new Paragraph({
                    alignment: (i === 0 || title.includes("Qty") || title.includes("UOM") || title.includes("Item")) ? AlignmentType.CENTER : (title.includes("Rate") || title.includes("Total") || title.includes("Marks")) ? AlignmentType.RIGHT : AlignmentType.LEFT,
                    children: [
                        new TextRun({
                            text: title,
                            bold: true,
                            size: 19,
                            color: "FFFFFF",
                            font: FONT_FAMILY,
                        }),
                    ],
                }),
            ],
        })),
    });
}

function tableDataRow(values, widths, isAlt = false) {
    return new TableRow({
        children: values.map((val, i) => {
            const isCenter = (i === 0 && val.length <= 6) || (widths[i] <= 10 && !val.includes("₹"));
            const isRight = val.includes("₹") || val.includes("Marks") || (i === values.length - 1 && val.includes("%"));
            
            const lines = val.split('\n');
            const paragraphs = lines.map(line => new Paragraph({
                alignment: isCenter ? AlignmentType.CENTER : isRight ? AlignmentType.RIGHT : AlignmentType.LEFT,
                children: [
                    new TextRun({
                        text: line,
                        bold: (i === 0 || (i === 1 && widths[0] <= 10 && val.length < 35)),
                        size: 19,
                        color: TEXT_MAIN,
                        font: FONT_FAMILY,
                    }),
                ],
                spacing: { after: lines.length > 1 ? 40 : 0, line: 240 },
            }));

            return new TableCell({
                shading: isAlt ? { fill: ROW_ALT_BG, type: ShadingType.CLEAR } : undefined,
                margins: cellPaddingStandard,
                width: { size: widths[i], type: WidthType.PERCENTAGE },
                children: paragraphs,
            });
        }),
    });
}

buildFullEditableDocx().catch(err => {
    console.error("FATAL Error building editable docx:", err);
    process.exit(1);
});
