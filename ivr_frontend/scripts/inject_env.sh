#!/bin/sh
# Writes .env for Flutter from GOOGLE_MAPS_API_KEY (e.g. on Vercel).
# Run from repo root: sh ivr_frontend/scripts/inject_env.sh
# Or from ivr_frontend: sh scripts/inject_env.sh
cd "$(dirname "$0")/.." && \
if [ -n "$GOOGLE_MAPS_API_KEY" ]; then
  echo "GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY" > .env
  echo "Wrote .env with GOOGLE_MAPS_API_KEY"
else
  echo "GOOGLE_MAPS_API_KEY not set; .env unchanged"
fi
