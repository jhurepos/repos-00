"""simulator.py — Phase-Space Engine · Ukubona LLC v0.3"""
import time
from threading import Thread
from models import append_ledger, get_bias, update_bias

class PhaseSpaceSimulator:
    def __init__(self, socketio):
        self.socketio = socketio
        self.running  = False
        self.t        = 0
        self.state = {
            "project":              "Etori Residence",
            "project_id":           "etori",
            "location":             "Kampala, Uganda",
            "construction":         68.0,
            "units_sold":           32,
            "units_total":          60,
            "cash":                 1_200_000.0,
            "burn_rate":            42_000.0,
            "permit_risk":          0.22,
            "expected_construction":72.0,
            "expected_cash":        1_500_000.0,
            "expected_units":       38,
        }

    def _noise(self, scale):
        import random
        return (sum(random.random() for _ in range(6)) - 3) * scale

    def _step(self):
        import random
        self.t += 1
        s = self.state
        s["construction"] = min(100.0, s["construction"] + 0.05 + self._noise(0.3))
        s["cash"]         = s["cash"] - (s["burn_rate"] / 360) + self._noise(5_000)
        if random.random() < 0.06:
            s["units_sold"] = min(s["units_total"], s["units_sold"] + 1)
        s["permit_risk"]  = max(0.0, min(1.0, s["permit_risk"] + self._noise(0.015)))
        s["burn_rate"]    = max(20_000, s["burn_rate"] + self._noise(1_000))

    def _compute_loss(self):
        s  = self.state
        dc = abs(s["expected_construction"] - s["construction"]) / 100.0
        du = abs(s["expected_units"] - s["units_sold"]) / float(s["units_total"])
        df = abs(s["expected_cash"] - s["cash"]) / max(1, s["expected_cash"])
        return round(dc * 0.35 + du * 0.35 + df * 0.30, 4)

    def _gradient_step(self, loss):
        pid   = self.state["project_id"]
        b_rec = get_bias(pid)
        b_old = b_rec["b"]
        alpha = b_rec["alpha"]
        b_new = round(b_old - alpha * 2 * loss, 4)
        update_bias(pid, b_new)
        return b_old, b_new

    def _emit(self, loss, b_before, b_after):
        payload = {**self.state, "loss": loss, "bias": b_after, "t": self.t, "timestamp": time.time()}
        self.socketio.emit("phase_update", payload)
        if self.t % 10 == 0:
            append_ledger(
                entry_type="LOSS", project_id=self.state["project_id"],
                author="simulator", stake_usd=0,
                payload_dict={
                    "construction": round(self.state["construction"], 2),
                    "cash":         round(self.state["cash"], 0),
                    "units_sold":   self.state["units_sold"],
                    "loss":         loss, "source": "simulated",
                },
                loss=loss, bias_before=b_before, bias_after=b_after,
            )

    def _run(self):
        self.running = True
        while self.running:
            self._step()
            loss = self._compute_loss()
            b_before, b_after = self._gradient_step(loss)
            self._emit(loss, b_before, b_after)
            time.sleep(2)

    def start(self):
        Thread(target=self._run, daemon=True, name="Simulator").start()

    def stop(self):
        self.running = False
