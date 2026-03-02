import { useState } from "react";
import axios from "axios";

const API = import.meta.env.VITE_API_URL || "http://localhost:5001";

const USERS = [
  { id: "demo_investor", label: "Investor",  desc: "$250K committed · full phase-space access", color: "text-emerald-400" },
  { id: "demo_operator", label: "Operator",  desc: "Operational stake · construction & permits", color: "text-blue-400"    },
  { id: "demo_observer", label: "Observer",  desc: "No stake · ledger only",                     color: "text-zinc-500"    },
];

export default function Login({ onLogin }) {
  const [loading, setLoading] = useState(false);
  const [error,   setError]   = useState("");

  const login = async (username) => {
    setLoading(true); setError("");
    try {
      const res = await axios.post(`${API}/api/login`, { username });
      localStorage.setItem("token", res.data.token);
      onLogin(res.data.token);
    } catch { setError("Login failed — is the backend running on :5001?"); }
    finally  { setLoading(false); }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center px-6">
      <div className="mb-10 text-center">
        <p className="font-mono text-xs tracking-widest text-zinc-600 mb-3">UKUBONA LLC · STRATA STONE TWIN</p>
        <h1 className="text-4xl font-light tracking-tight">Who are you in this?</h1>
        <p className="mt-3 font-mono text-xs text-zinc-700">Access is gated by stake, not seniority.</p>
      </div>
      <div className="flex flex-col gap-4 w-full max-w-sm">
        {USERS.map(u => (
          <button key={u.id} onClick={() => login(u.id)} disabled={loading}
            className="border border-zinc-800 rounded-xl p-5 text-left hover:border-zinc-600 transition-all">
            <div className={`font-mono text-sm font-bold ${u.color}`}>{u.label}</div>
            <div className="font-mono text-xs text-zinc-600 mt-1">{u.desc}</div>
          </button>
        ))}
      </div>
      {error && <p className="mt-4 font-mono text-xs text-red-500">{error}</p>}
      <p className="mt-12 font-mono text-xs text-zinc-800 max-w-xs text-center leading-relaxed">
        "You can only see the territory you inhabit."
      </p>
    </div>
  );
}
