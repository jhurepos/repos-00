import { useState } from "react";
import Login     from "./Login";
import Dashboard from "./Dashboard";

function parseToken(token) {
  try { return JSON.parse(atob(token.split(".")[1])); }
  catch { return null; }
}

export default function App() {
  const [token, setToken] = useState(() => localStorage.getItem("token"));
  const user = token ? parseToken(token) : null;
  const logout = () => { localStorage.removeItem("token"); setToken(null); };
  if (!token || !user) return <Login onLogin={setToken} />;
  return <Dashboard token={token} user={user} onLogout={logout} />;
}
