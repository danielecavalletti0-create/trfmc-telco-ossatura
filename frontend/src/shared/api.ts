// Il dev server Vite proxa SOLO /trfmc-api/backend/* verso il backend
// (vedi vite.config.ts) - un path relativo '/api' semplice non viene
// proxato affatto (tranne il solo /api/health, gestito a parte da un
// middleware dedicato) e risolverebbe sulla stessa origin del frontend
// (porta 5173), non sul backend (porta 8000). Bug preesistente confermato
// nell'audit del 2026-09-10: le chiamate reali (access-trust, restricted,
// ecc.) fallivano silenziosamente, assorbite da try/catch difensivi.
export const API_BASE = '/trfmc-api/backend/api'
export async function apiGet<T>(path: string): Promise<T> { const res = await fetch(`${API_BASE}${path}`); if (!res.ok) throw new Error(`${res.status} ${res.statusText}`); return res.json() }
