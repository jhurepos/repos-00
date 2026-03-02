#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Strata Stone Digital Twin
# Ukubona LLC · v0.3
#
# What this does:
#   1. Builds the React frontend for production
#   2. Pushes everything to GitHub (muzaale/repos-00)
#   3. Triggers Render to deploy via Blueprint
#
# Usage (run from inside strata-twin/):
#   bash ../deploy.sh
# ─────────────────────────────────────────────────────────────────────────────

CYAN="\033[0;36m"; GREEN="\033[0;32m"; RED="\033[0;31m"; RESET="\033[0m"
info() { echo -e "${CYAN}→ $*${RESET}"; }
ok()   { echo -e "${GREEN}✓ $*${RESET}"; }
fail() { echo -e "${RED}✗ $*${RESET}"; exit 1; }

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│   Strata Stone Digital Twin · Deploy                │"
echo "│   GitHub → Render                                   │"
echo "└─────────────────────────────────────────────────────┘"
echo ""

# ── Credentials ───────────────────────────────────────────────────────────────
read -p "GitHub username [muzaale]: " GH_USER
GH_USER=${GH_USER:-muzaale}

read -p "GitHub repo name [repos-00]: " GH_REPO
GH_REPO=${GH_REPO:-repos-00}

read -s -p "GitHub Personal Access Token: " GH_TOKEN
echo ""

read -s -p "Render API Key: " RENDER_KEY
echo ""
echo ""

# ── 1. Build frontend ─────────────────────────────────────────────────────────
info "Building frontend for production..."
cd frontend
npm install --silent
npm run build
cd ..
ok "Frontend built → frontend/dist/"

# ── 2. Push to GitHub ─────────────────────────────────────────────────────────
info "Pushing to GitHub ($GH_USER/$GH_REPO)..."

# Create repo if it doesn't exist
STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/$GH_USER/$GH_REPO")

if [ "$STATUS" != "200" ]; then
  info "Repo not found — creating $GH_REPO as private..."
  curl -s -X POST "https://api.github.com/user/repos" \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "{\"name\": \"$GH_REPO\", \"private\": true, \"auto_init\": false}" \
    > /dev/null
  ok "Repo created"
fi

# Init git if needed, set remote, push
git init --quiet
git checkout -B main 2>/dev/null || git checkout main

git remote remove origin 2>/dev/null || true
git remote add origin "https://$GH_USER:$GH_TOKEN@github.com/$GH_USER/$GH_REPO.git"

git add .
git commit --quiet -m "deploy: strata-twin v0.3 $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || \
  git commit --allow-empty --quiet -m "deploy: strata-twin v0.3 $(date '+%Y-%m-%d %H:%M')"

git push -f origin main
ok "Pushed to https://github.com/$GH_USER/$GH_REPO"

# ── 3. Trigger Render Blueprint deploy ────────────────────────────────────────
info "Triggering Render Blueprint deploy..."

# List existing services to check if already deployed
SERVICES=$(curl -s \
  -H "Authorization: Bearer $RENDER_KEY" \
  -H "Accept: application/json" \
  "https://api.render.com/v1/services?limit=20")

BACKEND_ID=$(echo "$SERVICES" | grep -o '"id":"[^"]*"' | head -1 | grep -o 'srv-[^"]*' || true)

if [ -n "$BACKEND_ID" ]; then
  # Services exist — trigger redeploy
  info "Services found — triggering redeploy..."
  for SRV_ID in $(echo "$SERVICES" | grep -o 'srv-[^"]*'); do
    curl -s -X POST \
      -H "Authorization: Bearer $RENDER_KEY" \
      -H "Accept: application/json" \
      "https://api.render.com/v1/services/$SRV_ID/deploys" \
      -d '{"clearCache": false}' > /dev/null
    ok "Triggered redeploy: $SRV_ID"
  done
else
  # First deploy — must be done via Blueprint in Render dashboard
  echo ""
  echo "┌──────────────────────────────────────────────────────────────┐"
  echo "│  FIRST DEPLOY — one manual step required                     │"
  echo "│                                                              │"
  echo "│  1. Go to: https://dashboard.render.com                     │"
  echo "│  2. Click New → Blueprint                                    │"
  echo "│  3. Connect GitHub and select: $GH_USER/$GH_REPO            │"
  echo "│  4. Render reads render.yaml automatically                   │"
  echo "│  5. Click Apply                                              │"
  echo "│                                                              │"
  echo "│  After deploy, get your backend URL from Render dashboard    │"
  echo "│  then run this script again — it will auto-redeploy          │"
  echo "│  from that point forward.                                    │"
  echo "└──────────────────────────────────────────────────────────────┘"
fi

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  ✓ Done                                                      │"
echo "│                                                              │"
echo "│  GitHub: https://github.com/$GH_USER/$GH_REPO               │"
echo "│  Render: https://dashboard.render.com                        │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""