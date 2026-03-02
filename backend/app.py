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
