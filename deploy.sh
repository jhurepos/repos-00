#!/usr/bin/env bash
set -e

CYAN="\033[0;36m"; GREEN="\033[0;32m"; RED="\033[0;31m"; RESET="\033[0m"
info() { echo -e "${CYAN}→ $*${RESET}"; }
ok()   { echo -e "${GREEN}✓ $*${RESET}"; }

echo ""
echo "┌─────────────────────────────────────────────────────┐"
echo "│   Strata Stone Digital Twin · Deploy                │"
echo "│   GitHub → Render (single service)                  │"
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
echo ""

# ── 1. Build frontend ─────────────────────────────────────────────────────────
info "Building frontend..."
cd frontend
rm -rf node_modules package-lock.json
npm install --silent

# Point frontend at same origin (backend serves it)
echo "VITE_API_URL=" > .env

npm run build
cd ..

# Copy built frontend into backend/static so Flask can serve it
info "Copying frontend build into backend/static..."
rm -rf backend/static
cp -r frontend/dist backend/static
ok "Frontend copied to backend/static"

# ── 2. Patch app.py to serve frontend ────────────────────────────────────────
info "Patching app.py to serve frontend..."
cat > backend/app.py << 'PYEOF'
"""
app.py — Strata Stone Digital Twin · Flask Backend
Ukubona LLC · v0.3
Serves both API and React frontend from a single process.
"""
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

# ── Serve React frontend ──────────────────────────────────────────────────────
@app.route("/", defaults={"path": ""})
@app.route("/<path:path>")
def serve_frontend(path):
    if path and os.path.exists(os.path.join(STATIC_DIR, path)):
        return send_from_directory(STATIC_DIR, path)
    return send_from_directory(STATIC_DIR, "index.html")

# ── API ───────────────────────────────────────────────────────────────────────
@app.route("/api/health")
def health():
    return jsonify({"status": "Strata Twin Running", "version": "0.3", "vendor": "Ukubona LLC"})

@app.route("/api/login", methods=["POST"])
def login():
    data     = request.get_json()
    username = data.get("username", "")
    token    = issue_token(username)
    if not token:
        return jsonify({"error": "Unknown user"}), 401
    return jsonify({"token": token})

@app.route("/api/state/<project_id>")
@requires_stake(min_usd=10_000)
def get_state(project_id):
    return jsonify({**simulator.state, "loss": simulator._compute_loss(),
                    "bias": get_bias(project_id), "t": simulator.t})

@app.route("/api/ledger/<project_id>")
@requires_stake(min_usd=0)
def get_ledger_route(project_id):
    user = request.user
    if project_id not in user.get("projects", []):
        return jsonify({"error": "No stake in this project"}), 403
    return jsonify(get_ledger(project_id))

@app.route("/api/ledger/<project_id>/entry", methods=["POST"])
@requires_stake(min_usd=0)
def add_entry(project_id):
    user = request.user
    if project_id not in user.get("projects", []):
        return jsonify({"error": "No stake in this project"}), 403
    data          = request.get_json()
    entry_type    = data.get("entry_type", "NOTE")
    payload       = data.get("payload", {})
    references_id = data.get("references_id")
    loss = None
    if entry_type == "ACTUAL" and "actual_days" in payload and "predicted_days" in payload:
        loss = round((payload["predicted_days"] - payload["actual_days"]) ** 2, 2)
    append_ledger(entry_type=entry_type, project_id=project_id, author=user["name"],
                  stake_usd=user["stake_usd"], payload_dict=payload,
                  references_id=references_id, loss=loss)
    return jsonify({"status": "appended", "loss": loss})

@socketio.on("connect")
def on_connect():
    socketio.emit("phase_update", {**simulator.state,
                                   "loss": simulator._compute_loss(), "t": simulator.t})

@socketio.on("disconnect")
def on_disconnect():
    pass

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 5001))
    simulator.start()
    print(f"[twin] running → http://0.0.0.0:{port}")
    socketio.run(app, host="0.0.0.0", port=port, debug=True, use_reloader=False)
PYEOF
ok "app.py patched"

# ── 3. Write all config files ─────────────────────────────────────────────────
info "Writing config files..."

cat > backend/requirements.txt << 'EOF'
Flask==3.0.0
Flask-SocketIO==5.3.6
flask-cors==4.0.0
PyJWT==2.8.0
gunicorn==21.2.0
simple-websocket==1.1.0
EOF

cat > backend/Procfile << 'EOF'
web: gunicorn --worker-class gthread --threads 4 -w 1 --chdir backend app:app --bind 0.0.0.0:$PORT
EOF

cat > render.yaml << 'EOF'
services:
  - type: web
    name: repos-00
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

ok "Config files written"

# ── 4. Push to GitHub ─────────────────────────────────────────────────────────
info "Pushing to GitHub ($GH_USER/$GH_REPO)..."

STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
  -H "Authorization: token $GH_TOKEN" \
  "https://api.github.com/repos/$GH_USER/$GH_REPO")

if [ "$STATUS" != "200" ]; then
  curl -s -X POST "https://api.github.com/user/repos" \
    -H "Authorization: token $GH_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "{\"name\": \"$GH_REPO\", \"private\": true, \"auto_init\": false}" > /dev/null
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

# ── 5. Trigger Render redeploy ────────────────────────────────────────────────
info "Triggering Render deploy..."

SERVICES_JSON=$(curl -s \
  -H "Authorization: Bearer $RENDER_KEY" \
  -H "Accept: application/json" \
  "https://api.render.com/v1/services?limit=20")

SRV_IDS=$(echo "$SERVICES_JSON" | grep -o '"id":"srv-[^"]*"' | grep -o 'srv-[^"]*' | sort -u)

if [ -n "$SRV_IDS" ]; then
  while IFS= read -r SRV_ID; do
    curl -s -X POST \
      -H "Authorization: Bearer $RENDER_KEY" \
      -H "Accept: application/json" \
      "https://api.render.com/v1/services/$SRV_ID/deploys" \
      -d '{"clearCache": false}' > /dev/null
    ok "Triggered redeploy: $SRV_ID"
  done <<< "$SRV_IDS"
fi

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  ✓ Done                                                      │"
echo "│                                                              │"
echo "│  Your app: https://repos-00.onrender.com                     │"
echo "│  GitHub:   https://github.com/$GH_USER/$GH_REPO              │"
echo "└──────────────────────────────────────────────────────────────┘"
echo ""