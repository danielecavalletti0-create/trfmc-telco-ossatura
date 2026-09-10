from fastapi import APIRouter, HTTPException

from app.core.config import settings
from app.domains.ew_lab.services import EWLabService
from app.domains.ew_lab.schemas import JammerScenarioRequest

router = APIRouter(prefix="/api/ew-lab", tags=["EW Training Lab"])
service = EWLabService()


def _require_restricted_enabled():
    """Riusa lo stesso gate gia' dichiarato in app/domains/restricted:
    EW_JAMMING_SIMULATION e' esplicitamente elencato li' come categoria
    che richiede restricted_enabled=true. Nessuna eccezione qui."""
    if not settings.restricted_enabled:
        raise HTTPException(
            status_code=403,
            detail=(
                "EW training lab richiede restricted_enabled=true "
                "(vedi /api/restricted/status per i controlli richiesti). "
                "Modulo di calcolo didattico (SIMULATION_ONLY), nessun "
                "controllo hardware o emissione RF in nessun caso."
            ),
        )


@router.get("/status")
def status():
    return {
        "service": "ew-training-lab",
        "mode": "SIMULATION_ONLY",
        "restricted_enabled": settings.restricted_enabled,
        "note": "Calcolatore di scenari J/S, CINR, burn-through, FHSS. Nessuna emissione RF, nessun controllo hardware.",
    }


@router.post("/scenario")
def compute_scenario(req: JammerScenarioRequest):
    _require_restricted_enabled()
    return service.compute_scenario(req)
