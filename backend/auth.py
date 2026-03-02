"""auth.py — Stake-Gated Access Control · Ukubona LLC v0.3"""
import jwt, time, os
from functools import wraps
from flask import request, jsonify

SECRET = os.environ.get("JWT_SECRET", "ukubona-dev-secret")

DEMO_USERS = {
    "demo_investor": {"name": "Demo Investor", "stake_usd": 250_000, "stake_type": "financial", "projects": ["etori"]},
    "demo_operator": {"name": "Demo Operator", "stake_usd": 0,       "stake_type": "operational","projects": ["etori"]},
    "demo_observer": {"name": "Demo Observer", "stake_usd": 0,       "stake_type": "none",       "projects": []},
}

def issue_token(username):
    user = DEMO_USERS.get(username)
    if not user: return None
    payload = {
        "sub": username, "name": user["name"],
        "stake_usd": user["stake_usd"], "stake_type": user["stake_type"],
        "projects": user["projects"],
        "iat": time.time(), "exp": time.time() + 8 * 3600,
    }
    return jwt.encode(payload, SECRET, algorithm="HS256")

def decode_token(token):
    return jwt.decode(token, SECRET, algorithms=["HS256"])

def requires_stake(min_usd=0):
    def decorator(f):
        @wraps(f)
        def wrapper(*args, **kwargs):
            auth = request.headers.get("Authorization", "")
            if not auth.startswith("Bearer "):
                return jsonify({"error": "No token"}), 401
            try:
                payload = decode_token(auth.split(" ")[1])
            except Exception:
                return jsonify({"error": "Invalid token"}), 401
            if payload.get("stake_usd", 0) < min_usd and payload.get("stake_type") == "none":
                return jsonify({"error": "Insufficient stake", "message": "You can only see what you have skin in."}), 403
            request.user = payload
            return f(*args, **kwargs)
        return wrapper
    return decorator
