import { useEffect, useState } from "react";
import axios from "axios";

const API = import.meta.env.VITE_API_URL || "http://localhost:5001";
const TYPE = {
  FORECAST:   { color: "text-blue-400",    icon: "→" },
  ACTUAL:     { color: "text-emerald-400", icon: "✓" },
  LOSS:       { color: "text-yellow-400",  icon: "Δ" },
  CORRECTION: { color: "text-orange-400",  icon: "⟳" },
  NOTE:       { color: "text-zinc-500",    icon: "·" },
  STAKE:      { color: "text-purple-400",  icon: "$" },
};
const fmtTime = (ts) => new Date(ts * 1000).toISOString().replace("T", " ").slice(0, 19);

function Row({ row }) {
  const s = TYPE[row.entry_type] || TYPE.NOTE;
  const payload = typeof row.payload === "string" ? JSON.parse(row.payload) : row.payload;
  return (
    <div className="border-b border-zinc-900 py-3 px-4 font-mono text-xs hover:bg-white/[0.02] transition-colors">
      <div className="flex gap-3">
        <span className={`${s.color} mt-0.5`}>{s.icon}</span>
        <div className="flex-1 min-w-0">
          <div className="flex gap-2 flex-wrap items-baseline">
            <span className="text-zinc-700">{fmtTime(row.timestamp)}</span>
            <span className={`${s.color} tracking-widest`}>{row.entry_type}</span>
            {row.author && <span className="text-zinc-600">{row.author}</span>}
            {row.stake_usd > 0 && <span className="text-purple-600">${row.stake_usd.toLocaleString()} stake</span>}
          </div>
          <div className="mt-1 text-zinc-500 flex flex-wrap gap-x-3">
            {Object.entries(payload).map(([k, v]) => (
              <span key={k}>
                <span className="text-zinc-700">{k}:</span>{" "}
                <span className={k === "loss" ? "text-yellow-400" : "text-zinc-400"}>
                  {typeof v === "number" ? v.toLocaleString() : String(v)}
                </span>
              </span>
            ))}
          </div>
          {row.loss != null && (
            <div className="mt-1 text-yellow-500">
              loss {row.loss.toFixed(4)}
              {row.bias_before != null && (
                <span className="text-zinc-700 ml-3">bias {row.bias_before?.toFixed(3)} → {row.bias_after?.toFixed(3)}</span>
              )}
            </div>
          )}
          {row.references_id && <div className="mt-1 text-orange-700">⟳ corrects #{row.references_id}</div>}
        </div>
      </div>
    </div>
  );
}

export default function LedgerFeed({ projectId, token }) {
  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [form,    setForm]    = useState({ entry_type: "NOTE", text: "" });
  const [posting, setPosting] = useState(false);

  const load = async () => {
    try {
      const res = await axios.get(`${API}/api/ledger/${projectId}`,
        { headers: { Authorization: `Bearer ${token}` } });
      setEntries(res.data);
    } catch {}
    finally { setLoading(false); }
  };

  useEffect(() => { load(); const i = setInterval(load, 10000); return () => clearInterval(i); }, []);

  const submit = async () => {
    if (!form.text.trim()) return;
    setPosting(true);
    try {
      await axios.post(`${API}/api/ledger/${projectId}/entry`,
        { entry_type: form.entry_type, payload: { note: form.text } },
        { headers: { Authorization: `Bearer ${token}` } });
      setForm(f => ({ ...f, text: "" }));
      await load();
    } finally { setPosting(false); }
  };

  return (
    <div className="flex flex-col h-full">
      <div className="px-4 py-3 border-b border-zinc-900 flex justify-between items-baseline">
        <span className="font-mono text-xs tracking-widest text-zinc-600">IMMUTABLE LEDGER</span>
        <span className="font-mono text-xs text-zinc-800">{entries.length} entries</span>
      </div>
      <div className="flex-1 overflow-y-auto">
        {loading && <p className="p-4 font-mono text-xs text-zinc-800">loading...</p>}
        {!loading && entries.length === 0 && (
          <p className="p-4 font-mono text-xs text-zinc-800">No entries yet. Reality hasn't happened here.</p>
        )}
        {entries.map(r => <Row key={r.id} row={r} />)}
      </div>
      <div className="border-t border-zinc-900 p-3 flex gap-2">
        <select value={form.entry_type} onChange={e => setForm(f => ({ ...f, entry_type: e.target.value }))}
          className="bg-zinc-900 border border-zinc-800 rounded font-mono text-xs text-zinc-400 px-2 py-2">
          {["FORECAST","ACTUAL","NOTE","STAKE","CORRECTION"].map(t => <option key={t} value={t}>{t}</option>)}
        </select>
        <input value={form.text} onChange={e => setForm(f => ({ ...f, text: e.target.value }))}
          onKeyDown={e => e.key === "Enter" && submit()} placeholder="Append to ledger..."
          className="flex-1 bg-zinc-900 border border-zinc-800 rounded font-mono text-xs text-zinc-400 px-3 py-2 placeholder-zinc-800 focus:outline-none focus:border-zinc-600" />
        <button onClick={submit} disabled={posting}
          className="bg-zinc-800 hover:bg-zinc-700 rounded px-4 font-mono text-xs text-zinc-400 transition-colors">
          {posting ? "…" : "→"}
        </button>
      </div>
    </div>
  );
}
