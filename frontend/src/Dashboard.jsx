import { useState, useEffect } from "react";
import { io } from "socket.io-client";
import LedgerFeed from "./LedgerFeed";

const API = import.meta.env.VITE_API_URL || "http://localhost:5001";
const lossColor = (l) => {
  if (l < 0.15) return { hex: "#00d084", label: "ON TRACK", cls: "text-emerald-400" };
  if (l < 0.30) return { hex: "#f5c542", label: "DRIFTING",  cls: "text-yellow-400"  };
  return             { hex: "#ff4757", label: "CRITICAL", cls: "text-red-400"     };
};

function Meter({ label, actual, expected, color, format }) {
  const pct    = Math.min(100, Math.max(0, actual   || 0));
  const expPct = Math.min(100, Math.max(0, expected || 0));
  const val    = format === "usd" ? `$${((actual||0)/1000).toFixed(0)}K` : `${(actual||0).toFixed(1)}%`;
  return (
    <div className="bg-white/[0.02] border border-white/[0.06] rounded-xl p-5">
      <div className="flex justify-between items-baseline mb-3">
        <span className="font-mono text-xs tracking-widest text-zinc-600 uppercase">{label}</span>
        <span className="font-mono text-xl font-bold text-zinc-100">{val}</span>
      </div>
      <div className="relative h-1.5 bg-white/[0.06] rounded-full">
        {expected !== undefined && (
          <div className="absolute top-[-3px] w-0.5 h-[9px] bg-white/20 rounded"
            style={{ left: `${expPct}%`, transform: "translateX(-50%)" }} />
        )}
        <div className="h-full rounded-full transition-all duration-[1800ms]"
          style={{ width:`${pct}%`, background:`linear-gradient(90deg,${color}80,${color})`,
            boxShadow:`0 0 6px ${color}50` }} />
      </div>
    </div>
  );
}

export default function Dashboard({ token, user, onLogout }) {
  const [state,   setState]   = useState(null);
  const [conn,    setConn]    = useState(false);
  const [history, setHistory] = useState([]);

  const stake      = user?.stake_usd || 0;
  const canSeeFull = stake >= 10_000 || user?.stake_type === "operational";

  useEffect(() => {
    const s = io(API, { transports: ["websocket"] });
    s.on("connect",      ()  => setConn(true));
    s.on("disconnect",   ()  => setConn(false));
    s.on("phase_update", (d) => { setState(d); setHistory(h => [...h.slice(-40), d.loss]); });
    return () => s.disconnect();
  }, []);

  const loss = state?.loss ?? 0;
  const col  = lossColor(loss);

  return (
    <div className="min-h-screen flex flex-col" style={{ background: "#080807" }}>
      <div className="border-b border-zinc-900 px-6 py-4 flex justify-between items-center">
        <div>
          <p className="font-mono text-xs tracking-widest text-zinc-700">UKUBONA LLC · PHASE-SPACE TWIN</p>
          <h1 className="text-lg font-light mt-0.5 tracking-tight">Strata Stone Partners</h1>
        </div>
        <div className="flex items-center gap-5">
          <div className="text-right hidden sm:block">
            <p className="font-mono text-xs text-zinc-500">{user?.name}</p>
            <p className="font-mono text-xs text-zinc-800">
              {stake > 0 ? `$${stake.toLocaleString()} at stake` : user?.stake_type}
            </p>
          </div>
          <div className="flex items-center gap-2">
            <div className={`w-2 h-2 rounded-full ${conn ? "bg-emerald-400" : "bg-zinc-800"}`}
              style={conn ? { boxShadow:"0 0 8px #00d084" } : {}} />
            <span className="font-mono text-xs text-zinc-700">{conn ? "LIVE" : "—"}</span>
          </div>
          <button onClick={onLogout}
            className="font-mono text-xs text-zinc-700 hover:text-zinc-400 transition-colors">exit</button>
        </div>
      </div>

      <div className="flex flex-1 overflow-hidden">
        <div className="flex-1 p-6 overflow-y-auto">
          <div className="mb-6">
            <h2 className="text-2xl font-bold tracking-tight">{state?.project ?? "—"}</h2>
            <p className="font-mono text-xs text-zinc-800 mt-1">q → lifecycle state · p → capital + sales momentum</p>
          </div>

          {canSeeFull ? (
            <>
              <div className="flex items-center gap-6 mb-5 p-5 border border-zinc-900 rounded-xl"
                style={{ boxShadow:`0 0 30px ${col.hex}10` }}>
                <div>
                  <div className={`font-mono text-5xl font-bold leading-none ${col.cls}`}>{loss.toFixed(3)}</div>
                  <div className="font-mono text-xs text-zinc-700 mt-1">L(t)</div>
                </div>
                <div className="flex flex-col gap-2">
                  <span className={`font-mono text-xs tracking-widest ${col.cls}`}>{col.label}</span>
                  {state?.bias !== undefined && (
                    <span className="font-mono text-xs text-zinc-700">
                      bias: {typeof state.bias === "object"
                        ? state.bias.b?.toFixed(3) : Number(state.bias).toFixed(3)} days
                    </span>
                  )}
                  {history.length > 2 && (() => {
                    const min = Math.min(...history), max = Math.max(...history);
                    const range = max - min || 0.001;
                    const W = 100, H = 24;
                    const pts = history.map((v,i) =>
                      `${(i/(history.length-1))*W},${H-((v-min)/range)*H}`).join(" ");
                    return (
                      <svg width={W} height={H}>
                        <polyline points={pts} fill="none" stroke={col.hex} strokeWidth="1.5" opacity="0.7" />
                      </svg>
                    );
                  })()}
                </div>
              </div>

              <div className="flex flex-col gap-3">
                <Meter label="Construction" actual={state?.construction}
                  expected={state?.expected_construction} color="#7eb8f7" format="pct" />
                <Meter label="Cash Reserve" actual={state?.cash}
                  expected={state?.expected_cash} color="#a8e6cf" format="usd" />
                <Meter label={`Units Sold · of ${state?.units_total ?? 60}`}
                  actual={state ? (state.units_sold/state.units_total)*100 : 0}
                  expected={state ? (state.expected_units/state.units_total)*100 : 0}
                  color="#d4a8f0" format="pct" />
                <div className="grid grid-cols-2 gap-3">
                  <div className="bg-white/[0.02] border border-white/[0.06] rounded-xl p-4">
                    <div className="font-mono text-xs tracking-widest text-zinc-700">MONTHLY BURN</div>
                    <div className="font-mono text-xl font-bold text-yellow-400 mt-2">
                      {state ? `$${(state.burn_rate/1000).toFixed(0)}K` : "—"}
                    </div>
                  </div>
                  <div className="bg-white/[0.02] border border-white/[0.06] rounded-xl p-4">
                    <div className="font-mono text-xs tracking-widest text-zinc-700">PERMIT RISK</div>
                    <div className={`font-mono text-xl font-bold mt-2 ${state?.permit_risk > 0.3 ? "text-red-400" : "text-zinc-200"}`}>
                      {state ? `${(state.permit_risk*100).toFixed(1)}%` : "—"}
                    </div>
                  </div>
                </div>
              </div>

              <div className="mt-4 p-4 border border-zinc-900 rounded-xl font-mono text-xs text-zinc-800 leading-relaxed">
                <span className="text-zinc-600">L(t) = </span>
                <span className="text-blue-400/70">|Δconstruction| × 0.35</span>
                <span className="text-zinc-800"> + </span>
                <span className="text-purple-400/70">|Δunits| × 0.35</span>
                <span className="text-zinc-800"> + </span>
                <span className="text-emerald-400/70">|Δcash| × 0.30</span>
                <div className="mt-1 text-zinc-900">v0.3 · stake-gated · immutable ledger · Ukubona LLC</div>
              </div>
            </>
          ) : (
            <div className="border border-zinc-900 rounded-xl p-8 text-center mt-4">
              <p className="font-mono text-xs tracking-widest text-zinc-700 mb-4">OBSERVER ACCESS</p>
              <p className="text-zinc-600 text-sm leading-relaxed">
                You have no financial stake in this project.<br/>
                You can read the ledger.<br/>
                You cannot see the loss surface.
              </p>
              <p className="font-mono text-xs text-zinc-800 mt-8">"You can only see the territory you inhabit."</p>
            </div>
          )}
        </div>

        <div className="w-80 xl:w-96 border-l border-zinc-900 flex flex-col">
          <LedgerFeed projectId="etori" token={token} />
        </div>
      </div>
    </div>
  );
}
