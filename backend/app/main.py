from app.domains.docs_portal.api import router as docs_portal_router
from app.domains.restore_readiness.api import router as restore_readiness_router
from app.domains.ops_backup.api import router as ops_backup_router
from app.domains.evidence_vault.api import router as evidence_vault_router
from app.domains.portal_index.api import router as portal_index_router
from app.domains.security_baseline.api import router as security_baseline_router
from app.domains.reports.api import router as reports_router
from app.domains.scenarios.api import router as scenarios_router
from app.domains.correlation.api import router as correlation_router
from app.domains.timeline.api import router as timeline_router
from app.domains.observability.api import router as observability_router
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core.config import settings
from app.persistence.bootstrap import bootstrap_database

from app.domains.mission.api import router as mission_router
from app.domains.events.api import router as events_router
from app.domains.scientific_core.api import router as scientific_router
from app.domains.network_fabric.api import router as network_router
from app.domains.rf_coverage.api import router as rf_coverage_router
from app.domains.rf_field.api import router as rf_field_router
from app.domains.telco_mns.api import router as telco_mns_router
from app.domains.assets.api import router as assets_router
from app.domains.access_trust.api import router as access_trust_router
from app.domains.soc_noc.api import router as soc_noc_router
from app.domains.evidence.api import router as evidence_router
from app.domains.restricted.api import router as restricted_router
from app.persistence.api import router as persistence_router
from app.domains.time_cursor.api import router as time_cursor_router
from app.domains.uav.api import router as uav_router
from app.domains.core_network.api import router as core_network_router
from app.domains.autonomous_vehicles.api import router as autonomous_vehicles_router

bootstrap_database()

app = FastAPI(
    title="TRFMC Full Telco Skeleton",
    version="0.30.0",
    description="Telco RF Mission Control Platform — portal index golden check integration.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://127.0.0.1:5173", "http://localhost:5173"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/api/health", tags=["health"])
def health():
    return {
        "status": "ok",
        "project": settings.project_name,
        "version": "0.30.0",
        "environment": settings.env,
        "operational_mode": settings.operational_mode,
        "restricted_enabled": settings.restricted_enabled,
        "persistence": "sqlite",
        "event_stream": "websocket",
    }


app.include_router(mission_router)
app.include_router(events_router)
app.include_router(scientific_router)
app.include_router(network_router)
app.include_router(rf_coverage_router)
app.include_router(rf_field_router)
app.include_router(telco_mns_router)
app.include_router(assets_router)
app.include_router(access_trust_router)
app.include_router(soc_noc_router)
app.include_router(evidence_router)
app.include_router(restricted_router)
app.include_router(persistence_router)
app.include_router(time_cursor_router)
app.include_router(uav_router)
app.include_router(core_network_router)
app.include_router(autonomous_vehicles_router)
app.include_router(observability_router)
app.include_router(timeline_router)
app.include_router(correlation_router)
app.include_router(scenarios_router)
app.include_router(reports_router)
app.include_router(security_baseline_router)
app.include_router(portal_index_router)
app.include_router(evidence_vault_router)
app.include_router(ops_backup_router)
app.include_router(restore_readiness_router)
app.include_router(docs_portal_router)


# ============================================================
# TRFMC CORE LIVE ROUTER
# ============================================================
try:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=[
            "http://127.0.0.1:5173",
            "http://localhost:5173",
            "http://127.0.0.1:8080",
            "http://localhost:8080",
        ],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )
except Exception:
    pass

try:
    from app.domains.core_live.api import router as trfmc_core_live_router
    app.include_router(trfmc_core_live_router)
except Exception as e:
    print("TRFMC_CORE_LIVE_ROUTER_DISABLED", e)

@app.get("/api/trfmc-backend-ready")
def trfmc_backend_ready():
    return {"status": "ok", "service": "trfmc-backend", "core_live": True}
