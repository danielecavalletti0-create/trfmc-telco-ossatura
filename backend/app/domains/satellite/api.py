from fastapi import APIRouter, HTTPException

from app.domains.satellite.services import SatelliteService
from app.domains.satellite.schemas import LinkBudgetRequest, GeometryRequest

router = APIRouter(prefix="/api/satellite", tags=["Satellite"])
service = SatelliteService()


@router.get("/assets")
def list_assets():
    return {"assets": service.list_assets(), "mode": "SIMULATION_ONLY"}


@router.get("/assets/{asset_id}/geometry")
def asset_geometry(asset_id: str, ground_lat_deg: float, ground_lon_deg: float):
    try:
        return service.compute_geometry(asset_id, ground_lat_deg, ground_lon_deg)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.get("/assets/{asset_id}/doppler")
def asset_doppler(asset_id: str, ground_lat_deg: float, ground_lon_deg: float):
    try:
        return service.compute_doppler(asset_id, ground_lat_deg, ground_lon_deg)
    except KeyError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.post("/link-budget")
def link_budget(req: LinkBudgetRequest):
    return service.compute_link_budget(req)
