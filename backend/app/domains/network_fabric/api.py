from fastapi import APIRouter
from app.domains.network_fabric.services import GlobalNetworkFabricService
router = APIRouter(prefix="/api/network-fabric", tags=["global-network-fabric"])
service = GlobalNetworkFabricService()
@router.get("/destinations")
def destinations(): return {"destinations": list(service.destinations.keys())}
@router.get("/path")
def path(destination: str="New York"): return service.build_path(destination)
