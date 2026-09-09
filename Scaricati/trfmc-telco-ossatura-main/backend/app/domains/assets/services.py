from typing import Dict, Any, Optional

from app.persistence.repositories import (
    AssetRepository,
    AssetLinkRepository,
    asset_get,
    asset_events,
)


class AssetRegistryService:
    def __init__(self):
        self.assets = AssetRepository()
        self.links = AssetLinkRepository()

    def list_assets(self):
        return self.assets.list()

    def get_asset(self, asset_id: str) -> Optional[Dict[str, Any]]:
        return asset_get(asset_id)

    def get_asset_links(self, asset_id: str):
        return self.links.for_asset(asset_id)

    def get_asset_events(self, asset_id: str, limit: int = 50):
        return asset_events(asset_id, limit=limit)

    def graph(self):
        assets = self.assets.list()
        links = self.links.list()

        return {
            "nodes": [
                {
                    "id": a["asset_id"],
                    "type": a["asset_type"],
                    "domain": a["domain"],
                    "status": a["status"],
                    "data": a.get("data", {}),
                }
                for a in assets
            ],
            "links": [
                {
                    "id": l["link_id"],
                    "source": l["source_asset_id"],
                    "target": l["target_asset_id"],
                    "relation": l["relation_type"],
                    "data": l.get("data", {}),
                }
                for l in links
            ],
        }

    def mission_map(self):
        graph = self.graph()

        return {
            "mission_id": "MISSION-FULL-TELCO-BOOT-001",
            "layers": {
                "site": ["SITE-REMOTE-001", "TOWER-REMOTE-001", "AAU-N78-A", "CELL-N78-A"],
                "access": ["UE-REMOTE-001", "UAV-ALPHA-001", "IOT-FIRE-001", "V2X-CAR-001", "WIFI-AP-MISSION-001"],
                "transport": ["MW-LINK-REMOTE-REGIONAL", "POP-REGIONAL-001", "GWAN-TRANSATLANTIC-001"],
                "core": ["GNB-REMOTE-001", "CORE-5GC-001", "IMS-SBC-001"],
                "access_trust": ["ROGUE-CELL-PLACEHOLDER-001", "ROGUE-WIFI-PLACEHOLDER-001"],
            },
            "graph": graph,
        }

    def demo_assets(self):
        return self.mission_map()
