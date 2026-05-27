# Why there are two .env files

| File | Used by | Purpose |
|------|--------|---------|
| **`ivr_system_sengotics/.env`** (root) | NestJS backend + **single source of truth** | Database, JWT, API keys (GROQ, Google, etc.), **GOOGLE_MAPS_API_KEY** |
| **`ivr_frontend/.env`** (inside Flutter) | Flutter web (flutter_dotenv) | Flutter loads `.env` as an **asset** from its own folder, so it needs a file here |

**You only need to edit the root `.env`.**  
The frontend `.env` is synced from root (`GOOGLE_MAPS_API_KEY`, `FLUTTER_API_BASE_URL` → `API_BASE_URL`, `FLUTTER_WEB_APP_BASE_URL` → `WEB_APP_BASE_URL`). See `ivr_frontend/.env.example` for Flutter-only keys. Sync when you change root env:

```bash
# From repo root
node ivr_frontend/scripts/sync_env_from_root.js
```

Then run or build Flutter as usual. On **Vercel**, set `GOOGLE_MAPS_API_KEY` in the project env and use `scripts/inject_env.sh` before build (see `VERCEL_DEPLOY.md`).
