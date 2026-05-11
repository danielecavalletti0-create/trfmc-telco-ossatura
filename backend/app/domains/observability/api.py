from fastapi import APIRouter
from app.domains.observability.services import ObservabilityService

router = APIRouter(prefix="/api/observability", tags=["observability"])
service = ObservabilityService()


@router.get("/health-matrix")
def health_matrix():
    return service.health_matrix()


@router.get("/evidence-console")
def evidence_console():
    return service.evidence_console()


@router.get("/runtime")
def runtime_matrix():
    return service.runtime_matrix()
