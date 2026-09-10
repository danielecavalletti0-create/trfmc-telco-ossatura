"""
Pytest configuration and shared fixtures.
"""
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

# Aggiungi backend al path
backend_path = Path(__file__).parent.parent
sys.path.insert(0, str(backend_path))

from app.main import app


@pytest.fixture(scope="session")
def app_client():
    """Session-wide app client."""
    return TestClient(app)


@pytest.fixture
def client():
    """Test client fixture per ogni test."""
    return TestClient(app)


def pytest_configure(config):
    """Configurazione pytest."""
    # Marker custom
    config.addinivalue_line(
        "markers", "unit: test unitari"
    )
    config.addinivalue_line(
        "markers", "integration: test di integrazione"
    )
    config.addinivalue_line(
        "markers", "slow: test lenti"
    )


def pytest_collection_modifyitems(config, items):
    """Modifica item collection."""
    for item in items:
        # Assegna marker automaticamente in base al path
        if "integration" in str(item.fspath):
            item.add_marker(pytest.mark.integration)
        elif "unit" in str(item.fspath):
            item.add_marker(pytest.mark.unit)
