from fastapi import APIRouter

from app.domains.portal_index.services import PortalIndexService

router = APIRouter(prefix="/api/portal", tags=["portal"])
service = PortalIndexService()


@router.get("/index")
def index():
    return service.index()


@router.get("/pages")
def pages():
    return {
        "service": service.service_name,
        "timestamp": service.now(),
        "pages": service.pages(),
    }


@router.get("/health-summary")
def health_summary():
    return service.health_summary()
