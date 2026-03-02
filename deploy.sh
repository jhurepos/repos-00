#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Strata Stone Digital Twin
# Ukubona LLC · v0.3
#
# Usage (run from inside strata-twin/ or repos-00/):
#   bash deploy.sh
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
rm -rf node_modules package-lock.json
npm install --silent
npm run build
cd ..
ok "Frontend built → frontend/dist/"

# ── 2. Ensure .gitignore is correct ──────────────────────────────────────────
cat > .gitignore << 'EOF'
node_modules/
frontend/node_modules/
backend/venv/
__pycache__/
*.pyc
.env
.DS_Store
dist/
*.db
EOF

# ── 3. Push to GitHub ─────────────────────────────────────────────────────────
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

git init --quiet
git checkout -B main 2>/dev/null || git checkout main

# Remove node_modules/venv from git tracking if previously committed
git rm -r --cached frontend/node_modules 2>/dev/null || true
git rm -r --cached backend/venv 2>/dev/null || true

git remote remove origin 2>/dev/null || true
git remote add origin "https://$GH_USER:$GH_TOKEN@github.com/$GH_USER/$GH_REPO.git"

git add .
git commit --quiet -m "deploy: strata-twin v0.3 $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || \
  git commit --allow-empty --quiet -m "deploy: strata-twin v0.3 $(date '+%Y-%m-%d %H:%M')"

git push -f origin main
ok "Pushed to https://github.com/$GH_USER/$GH_REPO"

# ── 4. Trigger Render redeploy ────────────────────────────────────────────────
info "Triggering Render deploy..."

SERVICES_JSON=$(curl -s \
  -H "Authorization: Bearer $RENDER_KEY" \
  -H "Accept: application/json" \
  "https://api.render.com/v1/services?limit=20")

# Extract unique service IDs only
SRV_IDS=$(echo "$SERVICES_JSON" | grep -o '"id":"srv-[^"]*"' | grep -o 'srv-[^"]*' | sort -u)

if [ -n "$SRV_IDS" ]; then
  info "Services found — triggering redeploy..."
  while IFS= read -r SRV_ID; do
    curl -s -X POST \
      -H "Authorization: Bearer $RENDER_KEY" \
      -H "Accept: application/json" \
      "https://api.render.com/v1/services/$SRV_ID/deploys" \
      -d '{"clearCache": false}' > /dev/null
    ok "Triggered redeploy: $SRV_ID"
  done <<< "$SRV_IDS"
else
  echo ""
  echo "┌──────────────────────────────────────────────────────────────┐"
  echo "│  FIRST DEPLOY — one manual step required                     │"
  echo "│                                                              │"
  echo "│  1. Go to: https://dashboard.render.com                     │"
  echo "│  2. Click New → Blueprint                                    │"
  echo "│  3. Connect GitHub → select: $GH_USER/$GH_REPO              │"
  echo "│  4. Render reads render.yaml automatically                   │"
  echo "│  5. Click Apply and wait ~5 min                              │"
  echo "│                                                              │"
  echo "│  After that, run deploy.sh again — fully automatic.         │"
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