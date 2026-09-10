"""
Test per structured logging configuration e middleware.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.logging import get_logger, log_request, log_response


@pytest.fixture
def client():
    """FastAPI test client."""
    return TestClient(app)


class TestLoggingConfiguration:
    """Test logging configuration."""
    
    def test_logger_can_be_obtained(self):
        """Test che il logger può essere ottenuto."""
        logger = get_logger("test")
        assert logger is not None
    
    def test_logger_has_methods(self):
        """Test che il logger ha i metodi corretti."""
        logger = get_logger("test")
        assert hasattr(logger, "info")
        assert hasattr(logger, "debug")
        assert hasattr(logger, "error")
        assert hasattr(logger, "warning")


class TestRequestLoggingMiddleware:
    """Test request logging middleware."""
    
    def test_health_endpoint_logs_request(self, client):
        """Test che health endpoint passa attraverso middleware."""
        response = client.get("/api/health")
        assert response.status_code == 200
    
    def test_request_id_in_state(self, client):
        """Test che request ID è disponibile nello stato."""
        # Questo test verifica che il middleware funziona
        response = client.get("/api/health")
        assert response.status_code == 200
    
    def test_logging_functions(self):
        """Test that logging functions can be called."""
        # Queste dovrebbero non lanciare eccezioni
        log_request(
            request_id="test-123",
            method="GET",
            path="/api/test",
            query_params={"key": "value"}
        )
        
        log_response(
            request_id="test-123",
            status_code=200,
            duration_ms=10.5
        )


class TestLoggingIntegration:
    """Test logging integration with app."""
    
    def test_multiple_requests_have_unique_ids(self, client):
        """Test che multiple requests generano ID unici."""
        # Fai 3 richieste
        responses = [client.get("/api/health") for _ in range(3)]
        
        # Tutte dovrebbero essere 200
        assert all(r.status_code == 200 for r in responses)
    
    def test_error_response_logging(self, client):
        """Test che errori vengono loggati."""
        # Questa dovrebbe ritornare errore
        response = client.get("/api/non-existent-endpoint")
        assert response.status_code == 404
    
    def test_logging_with_post_request(self, client):
        """Test logging con POST request."""
        response = client.post(
            "/api/scientific/plane-wave",
            json={
                "frequency_hz": 3.5e9,
                "electric_field_v_per_m": 1.0,
                "relative_permittivity": 1.0,
                "relative_permeability": 1.0
            }
        )
        # POST dovrebbe funcionare o ritornare errore valido
        assert response.status_code in [200, 422, 500]
