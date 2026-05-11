from fastapi import APIRouter
from app.domains.rf_coverage.schemas import RfCoverageRequest
from app.domains.rf_coverage.services import RfCoverageService

router = APIRouter(prefix="/api/rf-coverage", tags=["rf-coverage"])
service = RfCoverageService()


@router.get("/obstacles")
def obstacles():
    return service.list_obstacles()


@router.get("/demo")
def demo():
    return service.run_coverage(RfCoverageRequest())


@router.post("/run")
async def run_coverage(req: RfCoverageRequest):
    return await service.run_and_persist(req)


@router.get("/runs")
def runs():
    return service.list_runs()
