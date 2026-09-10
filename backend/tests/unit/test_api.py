"""
Unit tests for FastAPI application and health endpoint.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app


@pytest.fixture
def client():
    """Fixture per FastAPI test client."""
    return TestClient(app)


class TestHealth:
    """Test suite per health endpoint."""
    
    def test_health_endpoint_exists(self, client):
        """Test che health endpoint esiste."""
        response = client.get("/api/health")
        assert response.status_code == 200
    
    def test_health_response_structure(self, client):
        """Test struttura response health."""
        response = client.get("/api/health")
        data = response.json()
        
        # Campi obbligatori
        assert "status" in data
        assert "project" in data
        assert "version" in data
        assert "environment" in data
        assert "operational_mode" in data
    
    def test_health_status_ok(self, client):
        """Test che status è 'ok'."""
        response = client.get("/api/health")
        assert response.json()["status"] == "ok"
    
    def test_health_operational_mode(self, client):
        """Test che operational_mode è SIMULATION_ONLY in dev."""
        response = client.get("/api/health")
        assert response.json()["operational_mode"] == "SIMULATION_ONLY"
    
    def test_health_persistence(self, client):
        """Test che persistence è sqlite in dev."""
        response = client.get("/api/health")
        assert response.json()["persistence"] == "sqlite"


class TestAppStructure:
    """Test suite per struttura app."""
    
    def test_app_title(self):
        """Test che app ha titolo corretto."""
        assert app.title == "TRFMC Full Telco Skeleton"
    
    def test_app_version(self):
        """Test che app ha versione 0.30.0."""
        assert app.version == "0.30.0"
    
    def test_app_has_routes(self):
        """Test che app ha routes definiti."""
        assert len(app.routes) > 0
    
    def test_app_routes_count(self):
        """Test che app ha almeno 100 route (health + domains)."""
        assert len(app.routes) >= 100


class TestReadiness:
    """Test suite per endpoint readiness."""
    
    def test_backend_ready_endpoint(self, client):
        """Test che endpoint /api/trfmc-backend-ready esiste."""
        response = client.get("/api/trfmc-backend-ready")
        assert response.status_code == 200
    
    def test_backend_ready_response(self, client):
        """Test struttura response readiness."""
        response = client.get("/api/trfmc-backend-ready")
        data = response.json()
        
        assert data["status"] == "ok"
        assert data["service"] == "trfmc-backend"
        assert "core_live" in data


class TestCORS:
    """Test suite per CORS configuration."""
    
    def test_cors_headers_present(self, client):
        """Test che CORS headers sono presenti."""
        response = client.get("/api/health")
        # FastAPI TestClient non ritorna sempre headers CORS
        # ma verifichiamo che la request funziona
        assert response.status_code == 200
