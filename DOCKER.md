# Docker Deployment Guide

## Quick Start (Development)

### Prerequisites
- Docker installed
- Docker Compose installed

### 1. Environment Setup
```bash
# Copy environment template
cp .env.example .env

# Edit .env and add your OpenAI API key
# OPENAI_API_KEY=sk-your-key-here
```

### 2. Start All Services
```bash
# Start PostgreSQL + Application
docker-compose up -d

# View logs
docker-compose logs -f app
```

### 3. Access the Application
- Backend API: http://localhost:3000
- PostgreSQL: localhost:5432
  - User: `postgres`
  - Password: `postgres`
  - Database: `ivr_system`

### 4. Run Migrations
```bash
# Migrations are auto-run on startup, but you can manually run:
docker-compose exec app npx prisma migrate dev
```

### 5. Stop Services
```bash
docker-compose down

# Stop and remove volumes (WARNING: deletes all data)
docker-compose down -v
```

---

## Production Deployment

### 1. Create Production Environment File
```bash
cp .env.example .env.production

# Edit .env.production with production values
```

### 2. Build and Start Production
```bash
docker-compose -f docker-compose.prod.yml up -d --build
```

### 3. Check Health
```bash
# Check app health
docker-compose -f docker-compose.prod.yml ps

# View logs
docker-compose -f docker-compose.prod.yml logs -f
```

---

## Common Docker Commands

### View Logs
```bash
# Application logs
docker-compose logs -f app

# Database logs
docker-compose logs -f postgres
```

### Execute Commands Inside Container
```bash
# Access app shell
docker-compose exec app sh

# Run Prisma commands
docker-compose exec app npx prisma studio

# Access PostgreSQL
docker-compose exec postgres psql -U postgres -d ivr_system
```

### Rebuild After Code Changes
```bash
# Rebuild and restart
docker-compose up -d --build
```

### Database Backup
```bash
# Backup
docker-compose exec postgres pg_dump -U postgres ivr_system > backup.sql

# Restore
cat backup.sql | docker-compose exec -T postgres psql -U postgres ivr_system
```

---

## Architecture

```
┌─────────────────────────┐
│   Docker Network        │
│   (ivr-network)         │
│                         │
│  ┌──────────────────┐   │
│  │  NestJS App      │   │
│  │  (Port 3000)     │   │
│  └────────┬─────────┘   │
│           │             │
│  ┌────────▼─────────┐   │
│  │  PostgreSQL +    │   │
│  │  PostGIS         │   │
│  │  (Port 5432)     │   │
│  └──────────────────┘   │
│           │             │
│      ┌────▼────┐        │
│      │ Volume  │        │
│      │ (Data)  │        │
│      └─────────┘        │
└─────────────────────────┘
```

---

## Troubleshooting

### App won't start
```bash
# Check if database is ready
docker-compose exec postgres pg_isready -U postgres

# Rebuild from scratch
docker-compose down -v
docker-compose up -d --build
```

### Can't connect to database
```bash
# Verify DATABASE_URL in .env
# Should be: postgresql://postgres:postgres@postgres:5432/ivr_system

# Check if postgres container is running
docker-compose ps postgres
```

### Prisma errors
```bash
# Regenerate Prisma client
docker-compose exec app npx prisma generate

# Reset database (WARNING: deletes all data)
docker-compose exec app npx prisma migrate reset
```

### Port already in use
```bash
# Change PORT in .env
PORT=3001

# Or stop the conflicting service
docker-compose down
```

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| DB_USER | postgres | PostgreSQL username |
| DB_PASSWORD | postgres | PostgreSQL password |
| DB_NAME | ivr_system | Database name |
| PORT | 3000 | Application port |
| OPENAI_API_KEY | - | OpenAI API key (required) |
| DATABASE_URL | auto-set | Full database URL |

---

## Notes

- **Development**: Hot-reload enabled via volume mounting
- **Production**: Optimized build with minimal dependencies
- **Database**: PostgreSQL 15 with PostGIS 3.3
- **Migrations**: Auto-run on container start
- **Health Checks**: Automatic restart if services fail
