#!/usr/bin/env bash
set -e

CYAN="\033[0;36m"; GREEN="\033[0;32m"; RESET="\033[0m"
info() { echo -e "${CYAN}→ $*${RESET}"; }
ok()   { echo -e "${GREEN}✓ $*${RESET}"; }

echo ""
echo "┌──────────────────────────────────────────────┐"
echo "│  Strata Stone Digital Twin · DEPLOY (FIXED)  │"
echo "└──────────────────────────────────────────────┘"
echo ""

read -p "GitHub username [muzaale]: " GH_USER
GH_USER=${GH_USER:-muzaale}

read -p "GitHub repo name [repos-00]: " GH_REPO
GH_REPO=${GH_REPO:-repos-00}

read -s -p "GitHub Personal Access Token: " GH_TOKEN
echo ""
read -s -p "Render API Key: " RENDER_KEY
echo ""

# ── 1. Build frontend ───────────────────────────────────────────────
info "Building frontend…"
cd frontend
rm -rf node_modules package-lock.json
npm install --silent
echo "VITE_API_URL=/api" > .env
npm run build
cd ..
ok "Frontend built"

# ── 2. Copy frontend CORRECTLY ──────────────────────────────────────
info "Copying frontend build into backend/static…"
rm -rf backend/static
mkdir -p backend/static
cp -r frontend/dist/* backend/static/
ok "Frontend copied correctly"

# ── 3. Write backend/app.py (SERVES UI PROPERLY) ─────────────────────
info "Writing backend/app.py…"
cat > backend/app.py << 'PYEOF'
import eventlet
eventlet.monkey_patch()

import os
from flask import Flask, jsonify, request, send_from_directory
from flask_socketio import SocketIO
from flask_cors import CORS

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(BASE_DIR, "static")

app = Flask(__name__, static_folder=STATIC_DIR, static_url_path="")
CORS(app)
socketio = SocketIO(app, cors_allowed_origins="*")

@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def serve_frontend(path):
    file_path = os.path.join(STATIC_DIR, path)
    if path and os.path.exists(file_path):
        return send_from_directory(STATIC_DIR, path)
    return send_from_directory(STATIC_DIR, "index.html")

@app.route("/api/health")
def health():
    return jsonify({"status": "ok", "ui": "served"})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    socketio.run(app, host="0.0.0.0", port=port)
PYEOF
ok "backend/app.py written"

# ── 4. requirements.txt ─────────────────────────────────────────────
info "Writing requirements.txt…"
cat > backend/requirements.txt << 'EOF'
Flask==3.0.0
Flask-SocketIO==5.3.6
flask-cors==4.0.0
gunicorn==21.2.0
eventlet==0.35.2
EOF
ok "requirements.txt written"

# ── 5. render.yaml ──────────────────────────────────────────────────
info "Writing render.yaml…"
cat > render.yaml << 'EOF'
services:
  - type: web
    name: repos-00
    runtime: python
    rootDir: backend
    buildCommand: pip install -r requirements.txt
    startCommand: gunicorn -k eventlet -w 1 app:app --bind 0.0.0.0:$PORT
EOF
ok "render.yaml written"

# ── 6. Push to GitHub (FORCE) ────────────────────────────────────────
info "Pushing to GitHub…"
git init -q
git checkout -B ukhona
git remote remove origin 2>/dev/null || true
git remote add origin "https://$GH_USER:$GH_TOKEN@github.com/$GH_USER/$GH_REPO.git"
git add .
git commit -m "deploy: FIX UI serving" || true
git push -f origin ukhona
ok "Pushed to GitHub"

# ── 7. FORCE Render redeploy (NO CACHE) ──────────────────────────────
info "Triggering Render redeploy (cache cleared)…"
SERVICES=$(curl -s -H "Authorization: Bearer $RENDER_KEY" https://api.render.com/v1/services)
SRV_ID=$(echo "$SERVICES" | grep -o '"id":"srv-[^"]*"' | head -1 | cut -d'"' -f4)

if [ -n "$SRV_ID" ]; then
  curl -s -X POST \
    -H "Authorization: Bearer $RENDER_KEY" \
    -H "Content-Type: application/json" \
    https://api.render.com/v1/services/$SRV_ID/deploys \
    -d '{"clearCache": true}' >/dev/null
  ok "Render redeploy triggered (cache cleared)"
else
  echo "⚠️ Could not find Render service ID"
fi

echo ""
echo "✅ DONE. Wait ~2 minutes, then HARD REFRESH the site (Cmd+Shift+R)."