# Why there are two .env files

| File | Used by | Purpose |
|------|--------|---------|
| **`ivr_system_sengotics/.env`** (root) | NestJS backend + **single source of truth** | Database, JWT, API keys (GROQ, Google, etc.), **GOOGLE_MAPS_API_KEY** |
| **`ivr_frontend/.env`** (inside Flutter) | Flutter web (flutter_dotenv) | Flutter loads `.env` as an **asset** from its own folder, so it needs a file here |

**You only need to edit the root `.env`.**  
The frontend `.env` is a **copy** of the Maps key so the Flutter app can read it. Sync it when you change the key:

```bash
# From repo root
node ivr_frontend/scripts/sync_env_from_root.js
```

Then run or build Flutter as usual. On **Vercel**, set `GOOGLE_MAPS_API_KEY` in the project env and use `scripts/inject_env.sh` before build (see `VERCEL_DEPLOY.md`).
