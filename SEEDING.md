## Database Seeding - Quick Guide

Due to Prisma v7 configuration constraints, use this simpler approach:

### Method 1: Manual Data Entry via Prisma Studio
```bash
docker-compose exec app npx prisma studio
```
Access at http://localhost:5555 and manually add data.

### Method 2: Direct SQL via PostgreSQL
```bash
# Access database
docker-compose exec postgres psql -U postgres -d ivr_system

# Insert Panchayats
INSERT INTO panchayats (name, center_lat, center_lng, ivr_number)
VALUES 
  ('Thayanur', 11.0168, 76.9558, '04442123456'),
  ('Vadavalli', 11.0234, 76.9012, '04442123457'),
  ('Kurichi', 11.0089, 76.9345, '04442123458');

# Insert Electric Poles (replace panchayat_id with actual IDs from above)
INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id)
VALUES 
  ('POLE-TY-001', 11.0170, 76.9560, ST_SetSRID(ST_MakePoint(76.9560, 11.0170), 4326), 1),
  ('POLE-TY-002', 11.0165, 76.9555, ST_SetSRID(ST_MakePoint(76.9555, 11.0165), 4326), 1),
  ('POLE-VD-001', 11.0236, 76.9015, ST_SetSRID(ST_MakePoint(76.9015, 11.0236), 4326), 2);

# Insert IVR Calls
INSERT INTO calls_master (call_sid, caller_number, call_to, flow_id, tenant_id, service_selected, poll_entered)
VALUES ('CALL-001', '9876543210', '04442123456', 'flow-1', 'tenant-1', true, true);

# Insert Complaints
INSERT INTO complaints (pole_id, panchayat_id, complaint_type, description, status)
VALUES 
  (1, 1, 'light not working', 'Street light pole near school not working', 'pending'),
  (2, 1, 'wire damage', 'Damaged wire near temple', 'in_progress');
```

### Method 3: Via API (Once server is running)
```bash
# Create Panchayat
curl -X POST http://localhost:3000/api/admin/panchayats \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Panchayat",
    "center_lat": 11.0000,
    "center_lng": 76.0000,
    "ivr_number": "04441234567"
  }'

# Create Pole
curl -X POST http://localhost:3000/api/admin/poles \
  -H "Content-Type: application/json" \
  -d '{
    "pole_number": "POLE-001",
    "latitude": 11.0001,
    "longitude": 76.0001,
    "panchayat_id": 1
  }'
```

### Troubleshooting

If you need to reset and start fresh:
```bash
# Drop all data
docker-compose exec postgres psql -U postgres -d ivr_system -c "TRUNCATE complaints, electric_poles, voice_calls, ivr_poll_input, ivr_service_selection, calls_master, panchayats CASCADE;"
```
