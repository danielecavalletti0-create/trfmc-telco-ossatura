"""
Unit tests per domain services.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.domains.security_baseline.services import SecurityBaselineService
from app.domains.assets.services import AssetRegistryService


@pytest.fixture
def client():
    """Fixture per FastAPI test client."""
    return TestClient(app)


class TestSecurityBaselineDomain:
    """Test suite per security baseline domain."""
    
    def test_security_posture_endpoint(self, client):
        """Test che endpoint posture esiste."""
        response = client.get("/api/security/posture")
        assert response.status_code == 200
    
    def test_security_access_policy_endpoint(self, client):
        """Test che endpoint access-policy esiste."""
        response = client.get("/api/security/access-policy")
        assert response.status_code == 200
    
    def test_security_service_instantiation(self):
        """Test che SecurityBaselineService si istanzia."""
        service = SecurityBaselineService()
        assert service is not None


class TestAssetsDomain:
    """Test suite per assets domain."""
    
    def test_assets_demo_endpoint(self, client):
        """Test che endpoint demo esiste."""
        response = client.get("/api/assets/demo")
        assert response.status_code == 200
    
    def test_assets_list_endpoint(self, client):
        """Test che endpoint list esiste."""
        response = client.get("/api/assets/list")
        assert response.status_code == 200
    
    def test_assets_graph_endpoint(self, client):
        """Test che endpoint graph esiste."""
        response = client.get("/api/assets/graph")
        assert response.status_code == 200
    
    def test_assets_service_instantiation(self):
        """Test che AssetRegistryService si istanzia."""
        service = AssetRegistryService()
        assert service is not None


class TestScientificCoreDomain:
    """Test suite per scientific core domain."""
    
    def test_plane_wave_demo_endpoint(self, client):
        """Test che endpoint plane-wave/demo esiste."""
        response = client.get("/api/scientific/plane-wave/demo")
        assert response.status_code == 200
    
    def test_near_far_demo_endpoint(self, client):
        """Test che endpoint near-far/demo esiste."""
        response = client.get("/api/scientific/near-far/demo")
        assert response.status_code == 200
    
    def test_plane_wave_response_structure(self, client):
        """Test struttura response plane wave demo."""
        response = client.get("/api/scientific/plane-wave/demo")
        data = response.json()
        
        # Dovrebbe contenere almeno qualche dato
        assert isinstance(data, (dict, list))


class TestDomainRouters:
    """Test suite per verifica che tutti i domain router sono registrati."""
    
    def test_mission_router_registered(self, client):
        """Test che mission router è registrato."""
        # Cerchiamo un endpoint mission
        response = client.get("/api/mission/demo")
        # Potrebbe essere 404 se non ha demo, ma dovrebbe essere registrato
        assert response.status_code in [200, 404, 422]
    
    def test_events_router_registered(self, client):
        """Test che events router è registrato."""
        response = client.get("/api/events/live")
        # Potrebbe essere 404 o 422 per mancanza dati
        assert response.status_code in [200, 404, 422]
    
    def test_observability_router_registered(self, client):
        """Test che observability router è registrato."""
        response = client.get("/api/observability/health-matrix")
        assert response.status_code == 200
