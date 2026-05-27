# Exotel IVR Backend System

## Project Overview
A production-grade backend system for handling Exotel IVR callbacks and AI-powered voice complaint processing for panchayat electrical infrastructure management.

## Architecture
- **Framework**: NestJS (Node.js TypeScript)
- **Database**: PostgreSQL with PostGIS (Supabase)
- **ORM**: Prisma
- **AI/ML**: OpenAI (Whisper + GPT-4o-mini)

## Features

### 1. IVR Callback Handling
- `POST /api/ivr/service` - Service selection
- `POST /api/ivr/poll` - Poll ID input
- `POST /api/ivr/voice-complaint` - Voice complaint recording

### 2. AI Voice Processing
- Automatic speech-to-text (Whisper)
- Location extraction from Tamil/English audio (GPT)
- Geo-matching with PostGIS
- Automatic complaint creation

### 3. Admin Dashboard APIs
- Pole Management (CRUD)
- Panchayat Management (CRUD)
- Complaint Management (Status updates, filtering)
- Dashboard Analytics

## Setup Instructions

### Option 1: Docker Setup (Recommended)

#### Prerequisites
- Docker & Docker Compose installed

#### Quick Start
```bash
# 1. Copy environment template
cp .env.example .env

# 2. Edit .env — see .env.example for every variable (GROQ, JWT, DB, etc.)
# For production PDFs on Vercel also set GOTENBERG_URL and SUPABASE_SERVICE_ROLE_KEY

# 3. Start all services (PostgreSQL + Backend)
docker-compose up -d

# 4. View logs
docker-compose logs -f app

# Application runs on http://localhost:3000
```

**That's it!** Database migrations run automatically.

See [DOCKER.md](DOCKER.md) for detailed Docker documentation.

---

### Option 2: Local Development (Without Docker)

#### Prerequisites
- Node.js v18+ installed
- PostgreSQL with PostGIS installed locally OR Supabase account

#### Setup
1. **Environment Configuration**
   ```bash
   cp .env.example .env
   # Edit .env — full list in .env.example
   # Flutter: node ivr_frontend/scripts/sync_env_from_root.js (uses FLUTTER_API_BASE_URL + GOOGLE_MAPS_API_KEY)
   ```

2. **Install Dependencies**
   ```bash
   npm install
   ```

3. **Enable PostGIS** (if using local PostgreSQL)
   ```sql
   CREATE EXTENSION postgis;
   ```

4. **Run Migrations**
   ```bash
   npx prisma migrate dev
   ```

5. **Start Server**
   ```bash
   npm run start:dev
   ```

## API Documentation

## Vercel Configuration Checklist

Set these environment variables in your Vercel project before deploy (see `.env.example` for the full list):

- `DATABASE_URL`, `JWT_SECRET`, `DB_POOL_MAX` (e.g. `3`)
- `GROQ_API_KEY`, `GOOGLE_API_KEY`, `GOOGLE_SPEECH_API_KEY`, `RAPIDAPI_KEY` (as needed)
- `EXOTEL_API_KEY`, `EXOTEL_API_TOKEN` (if using Exotel recordings)
- `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_STORAGE_BUCKET` (default: `tender-documents`)
- `GOTENBERG_URL`, `GOTENBERG_TIMEOUT_MS` (recommended: `45000`)
- `CANVAS_LOCKED_TEMPLATES` (optional CSV; empty = all six templates editable via canvas)

Deployment notes:
- Keep Gotenberg as a separate service and point `GOTENBERG_URL` to it.
- `SUPABASE_SERVICE_ROLE_KEY` must be set on Vercel (server-side only), never in frontend env.
- Leave `CANVAS_LOCKED_TEMPLATES` empty to allow canvas edit for all templates.

### Document template designer (Flutter web)

- Sidebar → **Document templates** — Fabric.js canvas (text, shapes, images, draw) plus **Advanced** panel for page margins and alignment.
- Super admin edits platform defaults; panchayat admin overrides per panchayat. Designs save as `fabric_scene` + `overlay_svg` and merge into generated PDFs.
- Full canvas editor requires **Flutter web**; mobile/desktop shows layout settings only.

### IVR Endpoints
All endpoints accept `application/x-www-form-urlencoded` and return HTTP 200.

#### Service Selection
```
POST /api/ivr/service
Body: { CallSid, CallFrom, CallTo, digits, ... }
```

#### Poll Input
```
POST /api/ivr/poll
Body: { CallSid, CallFrom, digits, ... }
```

#### Voice Complaint
```
POST /api/ivr/voice-complaint
Body: { CallSid, RecordingUrl, ... }
```

### Admin Endpoints

#### Pole Management
```
GET    /api/admin/poles?panchayat_id=1
POST   /api/admin/poles
PUT    /api/admin/poles/:id
DELETE /api/admin/poles/:id
```

#### Panchayat Management
```
GET    /api/admin/panchayats
POST   /api/admin/panchayats
PUT    /api/admin/panchayats/:id
```

#### Complaint Management
```
GET   /api/admin/complaints?status=pending&panchayat_id=1
PATCH /api/admin/complaints/:id/status
```

#### Dashboard Stats
```
GET /api/admin/stats
```

## Database Schema

### Core Tables
- `calls_master` - Call session tracking
- `ivr_service_selection` - Service selections
- `ivr_poll_input` - Poll inputs
- `voice_calls` - AI processing pipeline
- `panchayats` - Panchayat boundaries (with PostGIS)
- `electric_poles` - Pole locations (with PostGIS)
- `complaints` - Complaint records

## Project Structure
```
src/
├── prisma/           # Database service
├── ivr/              # IVR callback handlers
├── voice-processing/ # AI pipeline
│   ├── voice-to-text.service.ts
│   ├── location-extraction.service.ts
│   ├── geo-matching.service.ts
│   └── voice-processing.service.ts
├── admin/            # Admin APIs
└── app.module.ts     # Main module
```

## Testing
```bash
# Unit tests
npm run test

# E2E tests
npm run test:e2e

# Test coverage
npm run test:cov
```

## Deployment
```bash
# Build
npm run build

# Production start
npm run start:prod
```

## Notes
- All Prisma models use snake_case for database compatibility
- PostGIS functions are used for geospatial queries
- AI confidence threshold is set to 0.65 for auto-processing
- Raw payloads are stored as JSONB for auditing

## License
UNLICENSED
