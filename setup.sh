# Strata Stone Digital Twin
**Ukubona LLC · v0.3**

---

## What you need before starting

- A Mac (these instructions are for Mac)
- The `setup.sh` file in your current folder
- The `api.sh` file in your current folder (for GitHub push)

---

## Step 1 — Run setup (once, ever)

Open Terminal. Run:

```
bash setup.sh
```

Wait for it to finish. You'll see a box that says "✓ Setup complete". This takes 2–3 minutes. The app will also launch automatically — skip to Step 5 to open it in your browser.

---

## Step 2 — Open two Terminal windows

If the app didn't launch automatically, you need **two terminals open at the same time**.

**How to open a second Terminal on Mac:**
Press `Cmd + T` in Terminal to open a new tab.

---

## Step 3 — Start the backend (Terminal 1)

In your first terminal tab, run these three commands **one at a time**:

```
cd strata-twin/backend
```
```
source venv/bin/activate
```
```
PORT=5001 python app.py
```

You'll see: `wsgi starting up on http://0.0.0.0:5001`

**Leave this terminal running. Do not close it.**

---

## Step 4 — Start the frontend (Terminal 2)

In your second terminal tab, run these two commands **one at a time**:

```
cd strata-twin/frontend
```
```
npm run dev
```

You'll see: `Local: http://localhost:5173/`

**Leave this terminal running. Do not close it.**

---

## Step 5 — Open the app

Go to your browser and open:

```
http://localhost:5173
```

You'll see a login screen with three options:
- **Investor** — sees everything (phase-space dashboard + ledger)
- **Operator** — sees construction & permits + ledger
- **Observer** — sees ledger only

Click any one to enter.

---

## Every time you want to use the app

You don't run `setup.sh` again. Just repeat Steps 3, 4, and 5:

1. Terminal 1: `cd strata-twin/backend` → `source venv/bin/activate` → `PORT=5001 python app.py`
2. Terminal 2: `cd strata-twin/frontend` → `npm run dev`
3. Browser: `http://localhost:5173`

---

## To stop the app

In each terminal, press `Ctrl + C`.

---

## Step 6 — Push to GitHub (once app is working locally)

Once you're happy with the app running locally, push it to a private GitHub repo using `api.sh`.

First, move into the strata-twin folder:

```
cd strata-twin
```

Then run:

```
bash ../api.sh
```

It will ask you four things:
- **GitHub username** — your GitHub username (e.g. `hades`)
- **Repository name** — what to call it (e.g. `strata-twin`)
- **Make repository private?** — type `y` and press Enter
- **GitHub Personal Access Token** — paste your token (it won't show as you type, that's normal)

When it finishes you'll see a URL like:
```
https://github.com/YOUR_USERNAME/strata-twin
```

Your code is now safely on GitHub.

**Note:** `api.sh` will print a GitHub Pages URL at the end — ignore it. That won't work for this app. The real deploy is on Render (next step).

---

## Step 7 — Deploy to Render (manual, once)

Render hosts your app on the internet. You only do this once.

**Your strata-twin folder already has everything Render needs:**
- `render.yaml` — tells Render how to build and run the app
- `backend/requirements.txt` — Python packages list
- `backend/Procfile` — how to start the server

**Steps:**

1. Go to [render.com](https://render.com) and sign in (or create a free account)
2. Click **New** → **Blueprint**
3. Connect your GitHub account if prompted
4. Select the `strata-twin` repo you pushed in Step 6
5. Render reads `render.yaml` automatically — it will show two services:
   - `strata-twin-backend`
   - `strata-twin-frontend`
6. Click **Apply** and wait ~5 minutes

**One manual step after deploy:**

Once deployed, Render gives your backend a URL like:
```
https://strata-twin-backend.onrender.com
```

You need to tell the frontend about it:
- In Render dashboard → click `strata-twin-frontend` → **Environment**
- Find `VITE_API_URL` and set it to your backend URL
- Click **Save** — Render redeploys the frontend automatically

Your app is then live at the frontend URL Render shows you.

---

## If something goes wrong

**"Address already in use" error:**
```
lsof -ti:5001 | xargs kill -9
```
Then run `PORT=5001 python app.py` again.

**Browser shows "This site can't be reached":**
Make sure both terminals are running (Steps 3 and 4).

**Want to start completely fresh:**
```
rm -rf strata-twin && bash setup.sh
```

No — the repo should contain the **contents** of `strata-twin/`, not the folder itself. So when someone clones it they get this directly:

```
your-repo/
├── backend/
│   ├── app.py
│   ├── auth.py
│   ├── models.py
│   ├── simulator.py
│   ├── requirements.txt
│   ├── Procfile
│   └── venv/          ← ignored by .gitignore, won't be pushed
├── frontend/
│   ├── src/
│   ├── index.html
│   ├── package.json
│   ├── vite.config.js
│   └── node_modules/  ← ignored by .gitignore, won't be pushed
├── render.yaml
├── README.md
└── .gitignore
```

That's exactly what your `api.sh` will push if you run it from **inside** `strata-twin/`:

```
cd strata-twin
bash ../api.sh
```

The `git init` in `api.sh` runs in whatever folder you're in when you call it — so being inside `strata-twin` means the repo root becomes the contents of that folder, not the folder itself. That's the correct structure for Render to read `render.yaml` at the root.