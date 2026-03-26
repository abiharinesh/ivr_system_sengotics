# Deploying Flutter Web to Vercel (with Google Maps)

**Note:** Locally, the single `.env` is at the **repo root** (`ivr_system_sengotics/.env`). The frontend has its own `.env` only because Flutter loads env from inside its project; sync with `node ivr_frontend/scripts/sync_env_from_root.js`. On Vercel you set the key in the dashboard (see below).

## 1. Environment variable

In your **Vercel project** → **Settings** → **Environment Variables**, add:

- **Name:** `GOOGLE_MAPS_API_KEY`
- **Value:** Your [Google Maps JavaScript API](https://console.cloud.google.com/apis/library/maps-backend.googleapis.com) key
- **Environment:** Production (and Preview if you want maps in preview deployments)

Restrict the key to your domain in Google Cloud Console (e.g. `*.vercel.app` and your custom domain) to avoid misuse.

## 2. Build command

So the Flutter app gets the key at build time, run the inject script before building:

```bash
cd ivr_frontend && sh scripts/vercel_build.sh
```

If the frontend is the only thing deployed (root = `ivr_frontend`):

```bash
sh scripts/vercel_build.sh
```

**Output directory:** `build/web`

## 3. If the map still doesn’t show

- Confirm **Maps JavaScript API** is enabled for your Google Cloud project.
- In [Google Cloud Console](https://console.cloud.google.com/google/maps-apis/credentials) → **API key** → **Application restrictions**, allow your Vercel URLs (e.g. `https://*.vercel.app`).
- Redeploy after changing env vars or key restrictions.
