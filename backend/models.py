"""
models.py — Immutable Ledger · Ukubona LLC v0.3
No UPDATE. No DELETE. Ever.
"""
import sqlite3, time, json, os

DB_PATH = os.environ.get("DB_PATH", "twin.db")

def get_db():
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()    
    c.execute("""
        CREATE TABLE IF NOT EXISTS ledger (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp     REAL    NOT NULL DEFAULT (strftime('%s','now')),
            entry_type    TEXT    NOT NULL,
            project_id    TEXT    NOT NULL,
            author        TEXT    NOT NULL,
            stake_usd     REAL    DEFAULT 0,
            payload       TEXT    NOT NULL,
            references_id INTEGER,
            loss          REAL,
            bias_before   REAL,
            bias_after    REAL
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS projects (
            id            TEXT PRIMARY KEY,
            name          TEXT NOT NULL,
            location      TEXT,
            started_at    REAL,
            units_total   INTEGER DEFAULT 60,
            expected_days INTEGER,
            budget_usd    REAL
        )
    """)
    c.execute("""
        CREATE TABLE IF NOT EXISTS bias (
            project_id    TEXT PRIMARY KEY,
            b             REAL DEFAULT 0.0,
            alpha         REAL DEFAULT 0.01,
            steps         INTEGER DEFAULT 0,
            last_updated  REAL
        )
    """)
    c.execute("""
        INSERT OR IGNORE INTO projects
            (id, name, location, started_at, units_total, expected_days, budget_usd)
        VALUES ('etori', 'Etori Residence', 'Kampala, Uganda',
                strftime('%s','now'), 60, 180, 1500000)
    """)
    c.execute("""
        INSERT OR IGNORE INTO bias (project_id, b, alpha, steps, last_updated)
        VALUES ('etori', 0.0, 0.01, 0, strftime('%s','now'))
    """)
    conn.commit()
    conn.close()

def append_ledger(entry_type, project_id, author, stake_usd, payload_dict,
                  references_id=None, loss=None, bias_before=None, bias_after=None):
    conn = get_db()
    conn.execute("""
        INSERT INTO ledger
            (timestamp, entry_type, project_id, author, stake_usd, payload,
             references_id, loss, bias_before, bias_after)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (time.time(), entry_type, project_id, author, stake_usd,
          json.dumps(payload_dict), references_id, loss, bias_before, bias_after))
    conn.commit()
    conn.close()

def get_ledger(project_id, limit=100):
    conn = get_db()
    rows = conn.execute("""
        SELECT * FROM ledger WHERE project_id = ?
        ORDER BY timestamp DESC LIMIT ?
    """, (project_id, limit)).fetchall()
    conn.close()
    return [dict(r) for r in rows]

def get_bias(project_id):
    conn = get_db()
    row = conn.execute("SELECT * FROM bias WHERE project_id = ?", (project_id,)).fetchone()
    conn.close()
    return dict(row) if row else {"b": 0.0, "alpha": 0.01, "steps": 0}

def update_bias(project_id, b_new):
    conn = get_db()
    conn.execute("""
        UPDATE bias SET b = ?, steps = steps + 1, last_updated = ?
        WHERE project_id = ?
    """, (b_new, time.time(), project_id))
    conn.commit()
    conn.close()
