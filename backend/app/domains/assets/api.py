from fastapi import APIRouter, HTTPException

from app.domains.assets.services import AssetRegistryService

router = APIRouter(prefix="/api/assets", tags=["asset-digital-twin"])
service = AssetRegistryService()


@router.get("/demo")
def demo_assets():
    return service.demo_assets()


@router.get("/list")
def list_assets():
    return service.list_assets()


@router.get("/graph")
def graph():
    return service.graph()


@router.get("/mission-map")
def mission_map():
    return service.mission_map()


@router.get("/{asset_id}")
def get_asset(asset_id: str):
    asset = service.get_asset(asset_id)
    if not asset:
        raise HTTPException(status_code=404, detail=f"Asset not found: {asset_id}")
    return asset


@router.get("/{asset_id}/links")
def get_asset_links(asset_id: str):
    return service.get_asset_links(asset_id)


@router.get("/{asset_id}/events")
def get_asset_events(asset_id: str, limit: int = 50):
    return service.get_asset_events(asset_id, limit=limit)
