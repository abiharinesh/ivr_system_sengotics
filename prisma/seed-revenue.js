require('dotenv/config')
const { PrismaClient } = require('@prisma/client')
const { PrismaPg } = require('@prisma/adapter-pg')
const { Pool } = require('pg')
const { randomUUID } = require('crypto')

const pool = new Pool({ connectionString: process.env.DATABASE_URL })
const adapter = new PrismaPg(pool)
const prisma = new PrismaClient({ adapter })

async function main() {
    console.log('🌱 Seeding revenue module dummy data...');

    // 1. Fetch or create a Panchayat context
    let panchayat = await prisma.org_unit.findFirst();
    if (!panchayat) {
        panchayat = await prisma.org_unit.create({
            data: {
                name: 'Kovilpatti Panchayat',
                center_lat: 9.17,
                center_lng: 77.87,
            }
        });
        console.log('Created a new default Panchayat:', panchayat.name);
    } else {
        console.log('Using existing Panchayat:', panchayat.name);
    }

    // 2. Fetch or create an electric pole context
    let pole = await prisma.electricPole.findFirst({
        where: { org_unit_id: panchayat.id }
    });
    if (!pole) {
        pole = await prisma.electricPole.create({
            data: {
                org_unit_id: panchayat.id,
                pole_number: 'KP-PL-101',
                latitude: 9.171,
                longitude: 77.871,
                public_report_token: randomUUID(),
                keypad_id: 'KP-KPAD-01'
            }
        });
        console.log('Created a new electric pole context:', pole.pole_number);
    } else {
        console.log('Using existing electric pole context:', pole.pole_number);
    }

    // 3. Fetch or create a plumber/electrician context
    let technician = await prisma.user.findFirst({
        where: { role: 'electrician' }
    });
    if (!technician) {
        technician = await prisma.user.create({
            data: {
                email: 'electrician@sengotics.com',
                password_hash: '$2b$10$vN.1Q2.iN8B0KzG6.8pGTeT6.d3d3d3d3d3d3d3d3d3d3d3d3d3d', // dummy hash
                role: 'electrician',
                org_unit_id: panchayat.id,
                phone_e164: '+919999999999'
            }
        });
        console.log('Created a dummy technician user:', technician.email);
    } else {
        console.log('Using existing technician user:', technician.email);
    }

    // 4. Fetch or create a complaint context
    let complaint = await prisma.complaint.findFirst({
        where: { pole_id: pole.id }
    });
    if (!complaint) {
        complaint = await prisma.complaint.create({
            data: {
                pole_id: pole.id,
                org_unit_id: panchayat.id,
                complaint_type: 'street_light',
                description: 'Street light bulb is flickering.',
                status: 'pending',
                assigned_electrician_id: technician.id,
                assigned_at: new Date()
            }
        });
        console.log('Created a dummy complaint:', complaint.id);
    } else {
        console.log('Using existing complaint:', complaint.id);
    }

    // 5. Ad Campaigns & Impressions
    const campaign = await prisma.adCampaign.create({
        data: {
            org_unit_id: panchayat.id,
            advertiser_name: 'Annamalai Builders & Co',
            advertiser_phone: '9845012345',
            title: 'Sree Flats Kovilpatti Launch!',
            description: 'Premium 2BHK starting from ₹35 Lakhs. Spot bookings open now.',
            image_url: 'https://images.unsplash.com/photo-1545324418-cc1a3fa10c00?w=600',
            link_url: 'https://www.annamalai-builders.com',
            campaign_type: 'premium',
            amount_paid: 5000.00,
            starts_at: new Date(),
            ends_at: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000), // 30 days
            is_active: true
        }
    });
    console.log('Created Ad Campaign:', campaign.title);

    await prisma.adImpression.create({
        data: {
            campaign_id: campaign.id,
            pole_id: pole.id,
            device_ip: '192.168.1.50',
            clicked: true
        }
    });
    console.log('Recorded dummy Ad Impression.');

    // 6. Penalty Rules & User Penalty
    const rule = await prisma.penaltyRule.upsert({
        where: {
            panchayat_id_role_urgency_level: {
                org_unit_id: panchayat.id,
                role: 'electrician',
                urgency_level: 'medium'
            }
        },
        update: {},
        create: {
            org_unit_id: panchayat.id,
            role: 'electrician',
            urgency_level: 'medium',
            deadline_hours: 24,
            penalty_amount: 150.00
        }
    });
    console.log('Configured default Electrician SLA Penalty Rule.');

    await prisma.userPenalty.create({
        data: {
            user_id: technician.id,
            complaint_id: complaint.id,
            amount: 150.00,
            hours_delayed: 5.5,
            reason: 'SLA deadline of 24 hours breached on medium-urgency complaint.',
            status: 'pending'
        }
    });
    console.log('Logged dummy technician penalty.');

    // 7. Property & Tax Payment
    const property = await prisma.property.create({
        data: {
            org_unit_id: panchayat.id,
            owner_name: 'Dharmaraja Pillai',
            owner_phone: '9443212345',
            door_number: '12/A, North Street',
            address: 'Ward 3, Kovilpatti',
            property_type: 'residential',
            area_sqft: 1800,
            latitude: 9.172,
            longitude: 77.872,
            annual_tax: 850.00
        }
    });
    console.log('Registered property:', property.door_number);

    await prisma.taxPayment.create({
        data: {
            property_id: property.id,
            financial_year: '2025-26',
            demand_amount: 850.00,
            penalty_amount: 85.00, // 10% late surcharge
            paid_amount: 0,
            status: 'overdue',
            due_date: new Date(Date.now() - 5 * 24 * 60 * 60 * 1000) // 5 days ago
        }
    });
    console.log('Generated overdue tax payment demand log.');

    // 8. Certificate Requests
    const certRequest = await prisma.certificateRequest.create({
        data: {
            org_unit_id: panchayat.id,
            certificate_type: 'birth',
            applicant_name: 'Suresh Kumar (Father)',
            applicant_phone: '9988776655',
            applicant_email: 'suresh@gmail.com',
            fee_amount: 50.00,
            payment_status: 'paid',
            payment_ref: 'PAY-REF-TXN12345',
            review_status: 'pending',
            application_data: {
                child_name: 'Tarun Suresh',
                date_of_birth: '2026-06-15',
                place_of_birth: 'Government Maternity Hospital, Kovilpatti',
                mother_name: 'Meena Suresh'
            }
        }
    });
    console.log('Created Birth Certificate application request.');

    // 9. Rentable Assets & Bookings
    const asset = await prisma.panchayatAsset.create({
        data: {
            org_unit_id: panchayat.id,
            name: 'Kovilpatti Panchayat Community Hall',
            asset_type: 'hall',
            description: 'Air-conditioned main hall with 500 seating capacity, kitchen, and dining area.',
            daily_rate: 6500.00,
            deposit_amount: 2000.00,
            max_capacity: 500,
            is_available: true
        }
    });
    console.log('Registered Panchayat rentable asset:', asset.name);

    const booking = await prisma.assetBooking.create({
        data: {
            asset_id: asset.id,
            booked_by_name: 'Ranganathan (Father of Bride)',
            booked_by_phone: '9444455555',
            event_type: 'Wedding Ceremony',
            start_date: new Date(Date.now() + 10 * 24 * 60 * 60 * 1000), // in 10 days
            end_date: new Date(Date.now() + 12 * 24 * 60 * 60 * 1000),
            total_amount: 13000.00,
            deposit_paid: 2000.00,
            balance_amount: 11000.00,
            booking_status: 'confirmed',
            payment_ref: 'BOOK-PAY-9988'
        }
    });
    console.log('Booked community hall for wedding event.');

    // 10. Shandy Market Days, Vendors & Payments
    const marketDay = await prisma.marketDay.create({
        data: {
            org_unit_id: panchayat.id,
            name: 'Kovilpatti Shandy Ground Market',
            location: 'Old Town Market Ground',
            day_of_week: 0, // Sunday
            daily_fee: 40.00
        }
    });
    console.log('Configured Market Day:', marketDay.name);

    const vendor = await prisma.marketVendor.create({
        data: {
            org_unit_id: panchayat.id,
            vendor_name: 'Muthuvel K. (Fruits Merchant)',
            vendor_phone: '9876543210',
            business_type: 'Fresh Fruits',
            vendor_token: randomUUID()
        }
    });
    console.log('Registered market vendor card:', vendor.vendor_name);

    await prisma.marketVendorPayment.create({
        data: {
            vendor_id: vendor.id,
            market_day_id: marketDay.id,
            amount_paid: 40.00,
            payment_method: 'cash',
            collected_by: 'Inspector Velusamy'
        }
    });
    console.log('Logged market stall payment receipt.');

    // 11. Water connection & metered bill
    const waterConnection = await prisma.waterConnection.create({
        data: {
            org_unit_id: panchayat.id,
            connection_number: 'W-CONN-2099',
            owner_name: 'Dharmaraja Pillai',
            owner_phone: '9443212345',
            connection_type: 'domestic',
            monthly_rate: 150.00,
            is_metered: true,
            meter_reading: 345.50
        }
    });
    console.log('Registered metered water connection:', waterConnection.connection_number);

    await prisma.waterBill.create({
        data: {
            connection_id: waterConnection.id,
            bill_month: '2026-06',
            units_consumed: 22.50,
            bill_amount: 150.00,
            status: 'unpaid',
            due_date: new Date(Date.now() - 15 * 24 * 60 * 60 * 1000)
        }
    });
    console.log('Created water connection utility bill.');

    // 12. Pole Lease Agreements
    const lease = await prisma.poleLeaseAgreement.create({
        data: {
            pole_id: pole.id,
            org_unit_id: panchayat.id,
            lessee_name: 'Reliance Jio Infocomm Ltd',
            equipment_type: '5g_antenna',
            monthly_rent: 3200.00,
            agreement_start: new Date(),
            agreement_end: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000), // 1 year
            status: 'active'
        }
    });
    console.log('Signed Pole real estate lease agreement with telecom lessee:', lease.lessee_name);

    console.log('🎉 Seed complete! Real dummy data successfully populated.');
}

main()
    .catch(e => { console.error('Error during seeding:', e); process.exit(1); })
    .finally(() => prisma.$disconnect());
