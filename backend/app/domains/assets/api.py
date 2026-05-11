from fastapi import APIRouter
from app.domains.assets.services import AssetRegistryService
router = APIRouter(prefix="/api/assets", tags=["asset-registry"])
service = AssetRegistryService()
@router.get("/demo")
def demo_assets(): return service.demo_assets()
