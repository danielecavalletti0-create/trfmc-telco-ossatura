"""
Test del dominio urban_uav: geometrie verificabili a mano (drone visibile,
drone nascosto dietro un edificio, drone che vola sopra il tetto) prima
di qualunque test end-to-end.
"""
import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.domains.urban_uav.services import UrbanUavService
from app.domains.urban_uav.schemas import (
    CorridorScenarioRequest, Building, GroundStation, UavWaypoint, JammerSpec,
)

client = TestClient(app)


def _base_request(path, buildings, jammer=None):
    return CorridorScenarioRequest(
        frequency_hz=2.44e9,
        bandwidth_hz=1e6,
        buildings=buildings,
        ground_station=GroundStation(x_m=0, y_m=0, z_m=10),
        path=path,
        jammer=jammer,
    )


class TestGeometryAndDiffraction:
    def test_clear_sky_no_buildings_line_of_sight_open(self):
        """Nessun edificio -> nessuna ostruzione, perdita da diffrazione zero."""
        service = UrbanUavService()
        req = _base_request([UavWaypoint(x_m=500, y_m=0, z_m=50)], buildings=[])
        result = service.evaluate_corridor(req)
        p = result["points"][0]
        assert p["line_of_sight_blocked"] is False
        assert p["diffraction_loss_db"] == 0.0

    def test_drone_flies_high_above_building_clear(self):
        """Drone che vola ben sopra il tetto di un edificio basso, lungo
        la stessa rotta orizzontale: la linea di vista deve restare
        libera (l'edificio e' sotto la retta stazione-drone)."""
        service = UrbanUavService()
        building = Building(building_id="B1", x_m=250, y_m=0, width_m=40, depth_m=40, height_m=20)
        # Stazione a z=10, drone a z=100 a 500m: a x=250 (meta' strada) la
        # retta e' a circa z=55, ben sopra il tetto a 20m.
        req = _base_request([UavWaypoint(x_m=500, y_m=0, z_m=100)], buildings=[building])
        result = service.evaluate_corridor(req)
        p = result["points"][0]
        assert p["line_of_sight_blocked"] is False
        assert p["diffraction_loss_db"] < 1.0

    def test_drone_hidden_behind_tall_building_high_loss(self):
        """Drone basso, edificio alto esattamente sulla rotta: la linea
        di vista deve risultare bloccata con una perdita da diffrazione
        significativa (> il valore di riferimento noto di 6dB a v=0)."""
        service = UrbanUavService()
        building = Building(building_id="B1", x_m=250, y_m=0, width_m=60, depth_m=60, height_m=80)
        # Stazione z=10, drone z=15 a 500m: la retta a x=250 e' a circa
        # z=12.5, l'edificio (80m) la sovrasta di gran lunga -> v molto > 0
        req = _base_request([UavWaypoint(x_m=500, y_m=0, z_m=15)], buildings=[building])
        result = service.evaluate_corridor(req)
        p = result["points"][0]
        assert p["line_of_sight_blocked"] is True
        assert p["blocking_building_id"] == "B1"
        assert p["diffraction_loss_db"] > 6.0

    def test_diffraction_loss_increases_as_drone_descends_behind_building(self):
        """Monotonia fisica: piu' il drone scende dietro lo stesso
        edificio, piu' la perdita da diffrazione deve aumentare."""
        service = UrbanUavService()
        building = Building(building_id="B1", x_m=250, y_m=0, width_m=60, depth_m=60, height_m=50)
        losses = []
        for z in [80, 60, 40, 20, 10]:
            req = _base_request([UavWaypoint(x_m=500, y_m=0, z_m=z)], buildings=[building])
            result = service.evaluate_corridor(req)
            losses.append(result["points"][0]["diffraction_loss_db"])
        assert all(losses[i] <= losses[i + 1] for i in range(len(losses) - 1))

    def test_worst_obstacle_selected_among_multiple_buildings(self):
        """Con piu' edifici sulla rotta, deve essere selezionato quello
        che causa la perdita maggiore (knife-edge singolo dominante)."""
        service = UrbanUavService()
        low = Building(building_id="LOW", x_m=150, y_m=0, width_m=30, depth_m=30, height_m=15)
        high = Building(building_id="HIGH", x_m=350, y_m=0, width_m=30, depth_m=30, height_m=90)
        req = _base_request([UavWaypoint(x_m=500, y_m=0, z_m=15)], buildings=[low, high])
        result = service.evaluate_corridor(req)
        p = result["points"][0]
        assert p["blocking_building_id"] == "HIGH"


class TestLinkBudgetIntegration:
    def test_link_ok_far_from_any_obstruction(self):
        service = UrbanUavService()
        req = _base_request([UavWaypoint(x_m=50, y_m=0, z_m=50)], buildings=[])
        result = service.evaluate_corridor(req)
        assert result["points"][0]["cn_db"] > 0

    def test_link_degrades_close_to_strong_obstruction(self):
        """Il C/N con edificio che blocca deve essere peggiore del C/N
        senza alcun edificio, a parita' di geometria."""
        service = UrbanUavService()
        wp = UavWaypoint(x_m=500, y_m=0, z_m=15)
        req_clear = _base_request([wp], buildings=[])
        req_blocked = _base_request(
            [wp], buildings=[Building(building_id="B1", x_m=250, y_m=0, width_m=60, depth_m=60, height_m=80)]
        )
        cn_clear = UrbanUavService().evaluate_corridor(req_clear)["points"][0]["cn_db"]
        cn_blocked = UrbanUavService().evaluate_corridor(req_blocked)["points"][0]["cn_db"]
        assert cn_blocked < cn_clear


class TestJammerGateConsistency:
    """Il gate di accesso per il jammer deve comportarsi esattamente come
    quello di ew_lab: bloccato di default, accessibile solo se abilitato."""

    def test_corridor_without_jammer_always_accessible(self):
        payload = {
            "frequency_hz": 2.44e9,
            "bandwidth_hz": 1e6,
            "buildings": [],
            "ground_station": {"x_m": 0, "y_m": 0, "z_m": 10},
            "path": [{"x_m": 500, "y_m": 0, "z_m": 50}],
        }
        response = client.post("/api/urban-uav/corridor", json=payload)
        assert response.status_code == 200

    def test_corridor_with_jammer_blocked_by_default(self):
        payload = {
            "frequency_hz": 2.44e9,
            "bandwidth_hz": 1e6,
            "buildings": [],
            "ground_station": {"x_m": 0, "y_m": 0, "z_m": 10},
            "path": [{"x_m": 500, "y_m": 0, "z_m": 50}],
            "jammer": {"enabled": True, "jammer_type": "barrage", "x_m": 100, "y_m": 100, "eirp_dbw": 30, "bandwidth_hz": 5e6},
        }
        response = client.post("/api/urban-uav/corridor", json=payload)
        assert response.status_code == 403

    def test_corridor_with_jammer_works_when_enabled(self, monkeypatch):
        from app.core.config import settings
        monkeypatch.setattr(settings, "restricted_enabled", True)
        payload = {
            "frequency_hz": 2.44e9,
            "bandwidth_hz": 1e6,
            "buildings": [],
            "ground_station": {"x_m": 0, "y_m": 0, "z_m": 10},
            "path": [{"x_m": 500, "y_m": 0, "z_m": 50}],
            "jammer": {"enabled": True, "jammer_type": "barrage", "x_m": 100, "y_m": 100, "eirp_dbw": 30, "bandwidth_hz": 5e6},
            "hopping_bandwidth_hz": 10e6,
        }
        response = client.post("/api/urban-uav/corridor", json=payload)
        assert response.status_code == 200
        p = response.json()["points"][0]
        assert "jammer" in p
        assert "fhss_hit_probability" in p["jammer"]
        # Regressione bug di segno: CINR sotto jamming deve essere peggiore
        # del C/N senza jamming, non sostanzialmente uguale.
        assert p["jammer"]["cinr_db"] < p["cn_db"]


class TestUrbanUavAPI:
    def test_status_endpoint(self):
        response = client.get("/api/urban-uav/status")
        assert response.status_code == 200
        assert response.json()["mode"] == "SIMULATION_ONLY"

    def test_full_multi_waypoint_corridor(self):
        """Percorso a piu' waypoint attraverso un canyon urbano semplice."""
        payload = {
            "frequency_hz": 2.44e9,
            "bandwidth_hz": 1e6,
            "buildings": [
                {"building_id": "B1", "x_m": 200, "y_m": 0, "width_m": 50, "depth_m": 50, "height_m": 60},
                {"building_id": "B2", "x_m": 400, "y_m": 0, "width_m": 50, "depth_m": 50, "height_m": 40},
            ],
            "ground_station": {"x_m": 0, "y_m": 0, "z_m": 10},
            "path": [
                {"x_m": 100, "y_m": 0, "z_m": 60},
                {"x_m": 200, "y_m": 0, "z_m": 30},
                {"x_m": 300, "y_m": 0, "z_m": 60},
                {"x_m": 500, "y_m": 0, "z_m": 60},
            ],
        }
        response = client.post("/api/urban-uav/corridor", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["waypoint_count"] == 4
        assert len(data["points"]) == 4
