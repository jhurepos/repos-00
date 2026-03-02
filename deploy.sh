#!/usr/bin/env bash
set -e

CYAN="\033[0;36m"; GREEN="\033[0;32m"; RED="\033[0;31m"; RESET="\033[0m"
info() { echo -e "${CYAN}→ $*${RESET}"; }
ok()   { echo -e "${GREEN}✓ $*${RESET}"; }

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│   Strata Stone Digital Twin · Deploy (Fixed UI)     │"
echo "└─────────────────────────────────────────────────────┘"
echo ""

read -p "GitHub username [muzaale]: " GH_USER
GH_USER=${GH_USER:-muzaale}
read -p "GitHub repo name [repos-00]: " GH_REPO
GH_REPO=${GH_REPO:-repos-00}
read -s -p "GitHub Personal Access Token: " GH_TOKEN
echo ""
read -s -p "Render API Key: " RENDER_KEY
echo ""

# ── 1. Build frontend ─────────────────────────────────────────────────────────
info "Building frontend..."
cd frontend
rm -rf node_modules package-lock.json
npm install --silent
echo "VITE_API_URL=/api" > .env
npm run build
cd ..

info "Copying frontend build into backend/static..."
rm -rf backend/static
cp -r frontend/dist backend/static
ok "Frontend copied to backend/static"

# ── 2. Patch app.py (FIXED: This now serves the UI instead of JSON) ──────────
info "Patching app.py to serve frontend..."
cat > backend/app.py << 'PYEOF'
import eventlet
eventlet.monkey_patch()
import os
from flask import Flask, jsonify, request, send_from_directory
from flask_socketio import SocketIO
from flask_cors import CORS
from models    import init_db, append_ledger, get_ledger, get_bias
from simulator import PhaseSpaceSimulator
from auth      import issue_token, requires_stake

STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")
app = Flask(__name__, static_folder=STATIC_DIR, static_url_path="")
app.config["SECRET_KEY"] = os.environ.get("JWT_SECRET", "ukubona-dev-secret")

CORS(app, resources={r"/api/*": {"origins": "*"}})
socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")

init_db()
simulator = PhaseSpaceSimulator(socketio)

# ── FIXED: Serve React frontend at root ──────────────────────────────────────
@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def serve_frontend(path):
    if path and os.path.exists(os.path.join(STATIC_DIR, path)):
        return send_from_directory(STATIC_DIR, path)
    return send_from_directory(STATIC_DIR, "index.html")

# ── API (Moved Health Check to /api/health so it doesn't block UI) ──────────
@app.route("/api/health")
def health():
    return jsonify({"status": "Strata Twin Running", "version": "0.3", "vendor": "Ukubona LLC"})

@app.route("/api/login", methods=["POST"])
def login():
    data = request.get_json(); username = data.get("username", "")
    token = issue_token(username)
    return jsonify({"token": token}) if token else (jsonify({"error": "Unauthorized"}), 401)

@app.route("/api/state/<project_id>")
@requires_stake(min_usd=10_000)
def get_state(project_id):
    return jsonify({**simulator.state, "loss": simulator._compute_loss(), "bias": get_bias(project_id), "t": simulator.t})

@socketio.on("connect")
def on_connect():
    socketio.emit("phase_update", {**simulator.state, "loss": simulator._compute_loss(), "t": simulator.t})

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    simulator.start()
    socketio.run(app, host="0.0.0.0", port=port, debug=False, use_reloader=False)
PYEOF
ok "app.py patched"

# ── 3. Write config files (Consolidated to 1 service) ────────────────────────
info "Writing config files..."

cat > backend/requirements.txt << 'EOF'
Flask==3.0.0
Flask-SocketIO==5.3.6
flask-cors==4.0.0
PyJWT==2.8.0
gunicorn==21.2.0
simple-websocket==1.1.0
eventlet==0.35.2
EOF

cat > render.yaml << 'EOF'
services:
  - type: web
    name: repos-00
    runtime: python
    rootDir: backend
    buildCommand: pip install -r requirements.txt
    startCommand: gunicorn -k eventlet -w 1 app:app --bind 0.0.0.0:$PORT
    envVars:
      - key: JWT_SECRET
        generateValue: true
      - key: DB_PATH
        value: /opt/render/project/src/twin.db
    disk:
      name: twin-db
      mountPath: /opt/render/project/src
      sizeGB: 1
EOF

cat > .gitignore << 'EOF'
node_modules/
frontend/node_modules/
backend/venv/
__pycache__/
*.pyc
.env
.DS_Store
*.db
EOF

ok "Config files updated"

# ── 4. Push to GitHub ─────────────────────────────────────────────────────────
info "Pushing to GitHub ($GH_USER/$GH_REPO)..."
git init --quiet
git checkout -B ukhona 2>/dev/null || git checkout ukhona
git remote remove origin 2>/dev/null || true
git remote add origin "https://$GH_USER:$GH_TOKEN@github.com/$GH_USER/$GH_REPO.git"
git add .
git commit --quiet -m "deploy: fix UI serving v0.3" || true
git push -f origin ukhona
ok "Pushed to GitHub"

# ── 5. Trigger Render redeploy ────────────────────────────────────────────────
info "Triggering Render deploy..."
SERVICES_JSON=$(curl -s -H "Authorization: Bearer $RENDER_KEY" -H "Accept: application/json" "https://api.render.com/v1/services?limit=20")
SRV_ID=$(echo "$SERVICES_JSON" | grep -o '"id":"srv-[^"]*"' | head -1 | grep -o 'srv-[^"]*')

if [ -n "$SRV_ID" ]; then
  curl -s -X POST -H "Authorization: Bearer $RENDER_KEY" "https://api.render.com/v1/services/$SRV_ID/deploys" -d '{"clearCache": false}' > /dev/null
  ok "Triggered redeploy: $SRV_ID"
fi

echo "✅ All done! Give Render 2 minutes to build, then refresh your URL."