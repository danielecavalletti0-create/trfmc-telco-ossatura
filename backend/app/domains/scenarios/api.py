from fastapi import APIRouter, HTTPException

from app.domains.scenarios.services import ScenarioService

router = APIRouter(prefix="/api/scenarios", tags=["scenarios"])
service = ScenarioService()


@router.get("/catalog")
def catalog():
    return service.catalog()


@router.post("/run/{scenario_id}")
async def run_scenario(scenario_id: str):
    try:
        return await service.run(scenario_id=scenario_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc))


@router.get("/runs")
def runs(limit: int = 100):
    return service.runs(limit=limit)
