-- CreateExtension
CREATE EXTENSION IF NOT EXISTS "postgis";

-- CreateTable
CREATE TABLE "calls_master" (
    "call_sid" TEXT NOT NULL,
    "caller_number" TEXT,
    "call_to" TEXT,
    "flow_id" TEXT,
    "tenant_id" TEXT,
    "call_start_time" TIMESTAMP(3),
    "call_end_time" TIMESTAMP(3),
    "service_selected" BOOLEAN NOT NULL DEFAULT false,
    "poll_entered" BOOLEAN NOT NULL DEFAULT false,
    "voicemail_left" BOOLEAN NOT NULL DEFAULT false,
    "final_call_status" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "calls_master_pkey" PRIMARY KEY ("call_sid")
);

-- CreateTable
CREATE TABLE "ivr_service_selection" (
    "id" BIGSERIAL NOT NULL,
    "call_sid" TEXT NOT NULL,
    "caller_number" TEXT,
    "service_option" TEXT,
    "received_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "raw_payload" JSONB,

    CONSTRAINT "ivr_service_selection_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ivr_poll_input" (
    "id" BIGSERIAL NOT NULL,
    "call_sid" TEXT NOT NULL,
    "caller_number" TEXT,
    "poll_id" TEXT,
    "received_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "raw_payload" JSONB,

    CONSTRAINT "ivr_poll_input_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ivr_voicemail" (
    "id" BIGSERIAL NOT NULL,
    "call_sid" TEXT NOT NULL,
    "caller_number" TEXT,
    "recording_url" TEXT,
    "recording_available_by" TIMESTAMP(3),
    "received_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "raw_payload" JSONB,

    CONSTRAINT "ivr_voicemail_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "voice_calls" (
    "id" SERIAL NOT NULL,
    "call_sid" TEXT,
    "audio_url" TEXT,
    "transcript" TEXT,
    "ai_extracted_json" JSONB,
    "processing_status" TEXT NOT NULL DEFAULT 'pending',
    "confidence_score" DOUBLE PRECISION,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "voice_calls_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "panchayats" (
    "id" SERIAL NOT NULL,
    "name" TEXT NOT NULL,
    "boundary" geometry(Polygon, 4326),
    "center_lat" DOUBLE PRECISION,
    "center_lng" DOUBLE PRECISION,
    "ivr_number" TEXT,

    CONSTRAINT "panchayats_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "electric_poles" (
    "id" SERIAL NOT NULL,
    "pole_number" TEXT,
    "location" geometry(Point, 4326),
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "panchayat_id" INTEGER,

    CONSTRAINT "electric_poles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "complaints" (
    "id" SERIAL NOT NULL,
    "voice_call_id" INTEGER,
    "pole_id" INTEGER,
    "panchayat_id" INTEGER,
    "complaint_type" TEXT,
    "description" TEXT,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "complaints_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "panchayats_ivr_number_key" ON "panchayats"("ivr_number");

-- AddForeignKey
ALTER TABLE "ivr_service_selection" ADD CONSTRAINT "ivr_service_selection_call_sid_fkey" FOREIGN KEY ("call_sid") REFERENCES "calls_master"("call_sid") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ivr_poll_input" ADD CONSTRAINT "ivr_poll_input_call_sid_fkey" FOREIGN KEY ("call_sid") REFERENCES "calls_master"("call_sid") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ivr_voicemail" ADD CONSTRAINT "ivr_voicemail_call_sid_fkey" FOREIGN KEY ("call_sid") REFERENCES "calls_master"("call_sid") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "electric_poles" ADD CONSTRAINT "electric_poles_panchayat_id_fkey" FOREIGN KEY ("panchayat_id") REFERENCES "panchayats"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_voice_call_id_fkey" FOREIGN KEY ("voice_call_id") REFERENCES "voice_calls"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_pole_id_fkey" FOREIGN KEY ("pole_id") REFERENCES "electric_poles"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "complaints" ADD CONSTRAINT "complaints_panchayat_id_fkey" FOREIGN KEY ("panchayat_id") REFERENCES "panchayats"("id") ON DELETE SET NULL ON UPDATE CASCADE;
