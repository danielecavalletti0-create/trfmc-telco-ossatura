export const API_BASE = '/api'
export async function apiGet<T>(path: string): Promise<T> { const res = await fetch(`${API_BASE}${path}`); if (!res.ok) throw new Error(`${res.status} ${res.statusText}`); return res.json() }
