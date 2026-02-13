-- Seed Database with Sample Data
\c ivr_system;

-- Clear existing data
TRUNCATE complaints, electric_poles, voice_calls, ivr_voicemail, ivr_poll_input, ivr_service_selection, calls_master, panchayats CASCADE;

-- Insert Panchayats and get IDs
DO $$
DECLARE
    pan1_id INT;
    pan2_id INT;
    pan3_id INT;
    pole1_id INT;
    pole2_id INT;
    pole4_id INT;
    voice1_id INT;
    voice2_id INT;
BEGIN
    -- Insert Panchayats
    INSERT INTO panchayats (name, center_lat, center_lng, ivr_number) VALUES ('Thayanur', 11.0168, 76.9558, '04442123456') RETURNING id INTO pan1_id;
    INSERT INTO panchayats (name, center_lat, center_lng, ivr_number) VALUES ('Vadavalli', 11.0234, 76.9012, '04442123457') RETURNING id INTO pan2_id;
    INSERT INTO panchayats (name, center_lat, center_lng, ivr_number) VALUES ('Kurichi', 11.0089, 76.9345, '04442123458') RETURNING id INTO pan3_id;
    
    RAISE NOTICE 'Created % panchayats', 3;

    -- Insert Electric Poles with PostGIS geometry
    INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id) VALUES
      ('POLE-TY-001', 11.0170, 76.9560, ST_SetSRID(ST_MakePoint(76.9560, 11.0170), 4326), pan1_id) RETURNING id INTO pole1_id;
    INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id) VALUES
      ('POLE-TY-002', 11.0165, 76.9555, ST_SetSRID(ST_MakePoint(76.9555, 11.0165), 4326), pan1_id) RETURNING id INTO pole2_id;
    INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id) VALUES
      ('POLE-TY-003', 11.0172, 76.9562, ST_SetSRID(ST_MakePoint(76.9562, 11.0172), 4326), pan1_id);
    INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id) VALUES
      ('POLE-VD-001', 11.0236, 76.9015, ST_SetSRID(ST_MakePoint(76.9015, 11.0236), 4326), pan2_id) RETURNING id INTO pole4_id;
    INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id) VALUES
      ('POLE-VD-002', 11.0232, 76.9010, ST_SetSRID(ST_MakePoint(76.9010, 11.0232), 4326), pan2_id);
    INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id) VALUES
      ('POLE-KR-001', 11.0091, 76.9348, ST_SetSRID(ST_MakePoint(76.9348, 11.0091), 4326), pan3_id);
    INSERT INTO electric_poles (pole_number, latitude, longitude, location, panchayat_id) VALUES
      ('POLE-KR-002', 11.0087, 76.9342, ST_SetSRID(ST_MakePoint(76.9342, 11.0087), 4326), pan3_id);
    
    RAISE NOTICE 'Created 7 electric poles';

    -- Insert Sample IVR Calls
    INSERT INTO calls_master (call_sid, caller_number, call_to, flow_id, tenant_id, service_selected, poll_entered, voicemail_left, final_call_status, call_start_time, updated_at) VALUES
      ('CALL-001-SAMPLE', '9876543210', '04442123456', 'flow-001', 'tenant-001', true, true, false, 'SUCCESS', NOW() - INTERVAL '2 hours', NOW());

    INSERT INTO ivr_service_selection (call_sid, caller_number, service_option, raw_payload) VALUES
      ('CALL-001-SAMPLE', '9876543210', '1', '{"test": "sample data"}');

    INSERT INTO ivr_poll_input (call_sid, caller_number, poll_id, raw_payload) VALUES
      ('CALL-001-SAMPLE', '9876543210', '8686', '{"test": "sample data"}');
    
    RAISE NOTICE 'Created 1 IVR call';

    -- Insert Sample Voice Complaints
    INSERT INTO voice_calls (call_sid, audio_url, transcript, ai_extracted_json, processing_status, confidence_score) VALUES
      ('VOICE-001-SAMPLE', 'https://example.com/audio/sample1.mp3', 
       'Inside Thayanur opposite ITC office the light pole is not working',
       '{"village": "Thayanur", "landmark": "ITC office", "direction": "opposite", "complaint_type": "light pole not working", "confidence_score": 0.92}',
       'completed', 0.92) RETURNING id INTO voice1_id;
    INSERT INTO voice_calls (call_sid, audio_url, transcript, ai_extracted_json, processing_status, confidence_score) VALUES
      ('VOICE-002-SAMPLE', 'https://example.com/audio/sample2.mp3',
       'Vadavalli near bus stand power cut issue',
       '{"village": "Vadavalli", "landmark": "bus stand", "direction": "near", "complaint_type": "power cut", "confidence_score": 0.85}',
       'completed', 0.85) RETURNING id INTO voice2_id;
    
    RAISE NOTICE 'Created 2 voice calls';

    -- Insert Complaints
    INSERT INTO complaints (voice_call_id, pole_id, panchayat_id, complaint_type, description, status) VALUES
      (voice1_id, pole1_id, pan1_id, 'light pole not working', 'Inside Thayanur opposite ITC office the light pole is not working', 'pending');
    INSERT INTO complaints (voice_call_id, pole_id, panchayat_id, complaint_type, description, status) VALUES
      (voice2_id, pole4_id, pan2_id, 'power cut', 'Vadavalli near bus stand power cut issue', 'in_progress');
    INSERT INTO complaints (voice_call_id, pole_id, panchayat_id, complaint_type, description, status) VALUES
      (NULL, pole2_id, pan1_id, 'wire damage', 'Manual complaint - wire damage near school', 'resolved');
    
    RAISE NOTICE 'Created 3 complaints';
    
END $$;

-- Display summary
SELECT 'Panchayats' as table_name, COUNT(*) as count FROM panchayats
UNION ALL
SELECT 'Electric Poles', COUNT(*) FROM electric_poles
UNION ALL
SELECT 'IVR Calls', COUNT(*) FROM calls_master
UNION ALL
SELECT 'Voice Calls', COUNT(*) FROM voice_calls
UNION ALL
SELECT 'Complaints', COUNT(*) FROM complaints;
