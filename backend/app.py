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
