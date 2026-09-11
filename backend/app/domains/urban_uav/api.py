from fastapi import APIRouter, HTTPException

from app.core.config import settings
from app.domains.urban_uav.services import UrbanUavService
from app.domains.urban_uav.schemas import CorridorScenarioRequest

router = APIRouter(prefix="/api/urban-uav", tags=["Urban UAV Corridor"])
service = UrbanUavService()


@router.get("/status")
def status():
    return {
        "service": "urban-uav-corridor",
        "mode": "SIMULATION_ONLY",
        "model": service.model_name,
        "note": "Link budget C2 UAV lungo un percorso urbano, con diffrazione knife-edge ITU-R P.526 quando la linea di vista e' bloccata da un edificio. Jammer opzionale (calcolatore, nessuna emissione RF) richiede restricted_enabled=true, stesso gate di /api/ew-lab.",
    }


@router.post("/corridor")
def evaluate_corridor(req: CorridorScenarioRequest):
    if req.jammer and req.jammer.enabled and not settings.restricted_enabled:
        raise HTTPException(
            status_code=403,
            detail=(
                "Lo scenario con jammer richiede restricted_enabled=true "
                "(stesso gate di /api/ew-lab, categoria EW_JAMMING_SIMULATION). "
                "Il corridoio senza jammer (solo link budget + diffrazione) "
                "resta liberamente accessibile."
            ),
        )
    return service.evaluate_corridor(req)
