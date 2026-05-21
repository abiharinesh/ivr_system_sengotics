#!/bin/sh
set -eu

echo "Running backend Vercel build..."
npm run vercel-build
