https://repos-00.onrender.com/

```render
Login failed — is the backend running on :5001?
```

# Strata Stone Digital Twin · v0.3
**Ukubona LLC** · Stake-Gated · Immutable Ledger · Sequential Consequential Play

## Core Philosophy
- Access is gated by stake, not seniority
- The ledger is append-only — reality happened, it's logged
- Corrections are new entries, not edits
- You can only see the territory you inhabit

## Quick Start

### Backend
```bash
cd backend && source venv/bin/activate && PORT=5001 python app.py
```
Runs on http://localhost:5001

### Frontend
```bash
cd frontend && npm run dev
```
Runs on http://localhost:5173

## Demo Login Roles
| User | Stake | Access |
|------|-------|--------|
| demo_investor | $250,000 financial | Full phase-space + ledger |
| demo_operator | operational | Construction/permits + ledger |
| demo_observer | none | Ledger read-only |

## Deploy to Render
1. Push to GitHub (private)
2. Go to render.com → New → Blueprint
3. Connect your GitHub repo
4. Render reads render.yaml automatically
5. Update VITE_API_URL in frontend env vars to your backend URL
6. Deploy

## Iteration Path
- v0.1 ✓ in-browser simulator
- v0.2 ✓ Flask + SocketIO backend
- v0.3 ✓ stake-gated JWT + immutable ledger + full stack
- v0.4   real data ingest (spreadsheet / webhook)
- v0.5   LLM interpretation layer ("cash is drifting because...")
