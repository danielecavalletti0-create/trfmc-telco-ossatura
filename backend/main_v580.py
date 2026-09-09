from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse

def _try_router(import_path, attr="router"):
    try:
        mod = __import__(import_path, fromlist=[attr])
        return getattr(mod, attr)
    except Exception as exc:
        print(f"WARN: router not loaded {import_path}: {exc}")
        return None

app = FastAPI(
    title="RF PRO Unified Instrument Console",
    version="FINAL",
    description="Unified RX-only portal: Spectrum, Realtime, UAV/FHSS, IQ/Demod, Evidence, Audit."
)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

for import_path in [
    "backend.routers.workbench_v580",
    "backend.routers.demod_v581",
    "backend.routers.workbench_v582",
    "backend.routers.master_v583",
    "backend.routers.uav_v584",
    "backend.routers.realtime_v585",
    "backend.routers.fullband_v586",
    "backend.routers.rfpro_final",
    "backend.routers.rfpro_polish",
    "backend.routers.rfpro_bridges",
]:
    r = _try_router(import_path)
    if r is not None:
        app.include_router(r)

@app.get("/")
def root():
    return RedirectResponse(url="/api/rfpro/console")

@app.get("/health")
def health():
    return {
        "ok": True,
        "service": "rfpro-unified-instrument-console",
        "mode": "RX_ONLY",
        "entrypoint": "/api/rfpro/console"
    }


# === TRFMC BATCH2F RF NORMALIZED TRACE ROUTER START ===
try:
    from routers import rf_normalized_trace_v1
except Exception:
    try:
        from backend.routers import rf_normalized_trace_v1
    except Exception:
        rf_normalized_trace_v1 = None

try:
    if rf_normalized_trace_v1 is not None:
        app.include_router(rf_normalized_trace_v1.router)
except Exception as exc:
    print("TRFMC Batch2F normalized RF trace router include failed:", repr(exc))
# === TRFMC BATCH2F RF NORMALIZED TRACE ROUTER END ===

