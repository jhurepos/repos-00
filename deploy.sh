#!/usr/bin/env bash
set -e

# ─────────────────────────────────────────────────────────────────────────────
# deploy.sh — Strata Stone Digital Twin
# Ukubona LLC · v0.3
#
# Usage (run from inside repos-00/):
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

# ── 1. Write correct render.yaml ──────────────────────────────────────────────
info "Writing render.yaml..."
cat > render.yaml << 'EOF'
services:
  - type: web
    name: strata-twin-backend
    runtime: python
    rootDir: backend
    buildCommand: pip install -r requirements.txt
    startCommand: gunicorn --worker-class gthread --threads 4 -w 1 --chdir backend app:app --bind 0.0.0.0:$PORT
    envVars:
      - key: JWT_SECRET
        generateValue: true
      - key: DB_PATH
        value: /opt/render/project/src/twin.db
    disk:
      name: twin-db
      mountPath: /opt/render/project/src
      sizeGB: 1

  - type: web
    name: repos-00-frontend
    runtime: static
    rootDir: frontend
    buildCommand: npm install && npm run build
    staticPublishPath: dist
    envVars:
      - key: VITE_API_URL
        value: https://strata-twin-backend.onrender.com
EOF
ok "render.yaml written"

# ── 2. Write correct backend files ────────────────────────────────────────────
info "Writing backend/requirements.txt..."
cat > backend/requirements.txt << 'EOF'
Flask==3.0.0
Flask-SocketIO==5.3.6
flask-cors==4.0.0
PyJWT==2.8.0
gunicorn==21.2.0
simple-websocket==1.1.0
EOF

info "Writing backend/Procfile..."
cat > backend/Procfile << 'EOF'
web: gunicorn --worker-class gthread --threads 4 -w 1 --chdir backend app:app --bind 0.0.0.0:$PORT
EOF

info "Ensuring app.py uses threading mode..."
sed -i '' 's/async_mode="eventlet"/async_mode="threading"/' backend/app.py 2>/dev/null || true
sed -i '' 's/async_mode="gevent"/async_mode="threading"/'  backend/app.py 2>/dev/null || true
grep async_mode backend/app.py

# ── 3. Build frontend ─────────────────────────────────────────────────────────
info "Building frontend for production..."
cd frontend
rm -rf node_modules package-lock.json
npm install --silent
npm run build
cd ..
ok "Frontend built → frontend/dist/"

# ── 4. Ensure .gitignore ──────────────────────────────────────────────────────
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

# ── 5. Push to GitHub ─────────────────────────────────────────────────────────
info "Pushing to GitHub ($GH_USER/$GH_REPO)..."

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
git checkout -B ukhona 2>/dev/null || git checkout ukhona
git rm -r --cached frontend/node_modules 2>/dev/null || true
git rm -r --cached backend/venv 2>/dev/null || true

git remote remove origin 2>/dev/null || true
git remote add origin "https://$GH_USER:$GH_TOKEN@github.com/$GH_USER/$GH_REPO.git"

git add .
git commit --quiet -m "deploy: strata-twin v0.3 $(date '+%Y-%m-%d %H:%M')" 2>/dev/null || \
  git commit --allow-empty --quiet -m "deploy: strata-twin v0.3 $(date '+%Y-%m-%d %H:%M')"

git push -f origin ukhona
ok "Pushed to https://github.com/$GH_USER/$GH_REPO"

# ── 6. Trigger Render redeploy ────────────────────────────────────────────────
info "Triggering Render deploy..."

SERVICES_JSON=$(curl -s \
  -H "Authorization: Bearer $RENDER_KEY" \
  -H "Accept: application/json" \
  "https://api.render.com/v1/services?limit=20")

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
  echo "└──────────────────────────────────────────────────────────────┘"
fi

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  ✓ Done                                                      │"
echo "│                                                              │"
echo "│  Backend: https://repos-00.onrender.com                      │"
echo "│  GitHub:  https://github.com/$GH_USER/$GH_REPO               │"
echo "│  Render:  https://dashboard.render.com                        │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""