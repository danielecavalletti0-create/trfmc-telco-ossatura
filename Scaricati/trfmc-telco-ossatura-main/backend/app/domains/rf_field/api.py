from fastapi import APIRouter

from app.domains.rf_field.schemas import RfFieldRequest
from app.domains.rf_field.services import RfFieldService

router = APIRouter(prefix="/api/rf-field", tags=["rf-field"])
service = RfFieldService()


@router.get("/demo")
def demo(target_asset_id: str = "UE-REMOTE-001"):
    return service.run_field(RfFieldRequest(target_asset_id=target_asset_id))


@router.post("/run")
async def run(req: RfFieldRequest):
    return await service.run_and_persist(req)


@router.get("/runs")
def runs():
    return service.list_runs()


@router.get("/antenna-pattern")
def antenna_pattern():
    req = RfFieldRequest()
    return service.antenna_pattern(req)
