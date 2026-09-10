"""
Tests for authentication endpoints.
Covers login, token refresh, and protected endpoints.
"""
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.auth import create_tokens, get_password_hash

client = TestClient(app)


class TestAuthLogin:
    """Test login endpoint."""
    
    def test_login_success_admin(self):
        """Test successful login with admin credentials."""
        response = client.post(
            "/api/auth/login",
            data={"username": "admin", "password": "admin123"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert "refresh_token" in data
        assert data["token_type"] == "bearer"
    
    def test_login_success_user(self):
        """Test successful login with user credentials."""
        response = client.post(
            "/api/auth/login",
            data={"username": "user", "password": "user123"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
    
    def test_login_invalid_username(self):
        """Test login with invalid username."""
        response = client.post(
            "/api/auth/login",
            data={"username": "nonexistent", "password": "password123"}
        )
        assert response.status_code == 401
    
    def test_login_invalid_password(self):
        """Test login with invalid password."""
        response = client.post(
            "/api/auth/login",
            data={"username": "admin", "password": "wrongpassword"}
        )
        assert response.status_code == 401
    
    def test_login_empty_credentials(self):
        """Test login with empty credentials."""
        response = client.post(
            "/api/auth/login",
            data={"username": "", "password": ""}
        )
        assert response.status_code == 401


class TestAuthMe:
    """Test /me endpoint (current user info)."""
    
    def test_me_without_token(self):
        """Test /me without token."""
        response = client.get("/api/auth/me")
        assert response.status_code in [401, 403]
    
    def test_me_with_valid_token(self):
        """Test /me with valid token."""
        # First login
        login_response = client.post(
            "/api/auth/login",
            data={"username": "user", "password": "user123"}
        )
        token = login_response.json()["access_token"]
        
        # Then get /me
        response = client.get(
            "/api/auth/me",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["username"] == "user"
        assert "user" in data["roles"]
    
    def test_me_with_invalid_token(self):
        """Test /me with invalid token."""
        response = client.get(
            "/api/auth/me",
            headers={"Authorization": "Bearer invalid_token"}
        )
        assert response.status_code == 401


class TestAuthRefresh:
    """Test token refresh endpoint."""
    
    def test_refresh_with_valid_token(self):
        """Test token refresh with valid token."""
        # Login first
        login_response = client.post(
            "/api/auth/login",
            data={"username": "admin", "password": "admin123"}
        )
        token = login_response.json()["access_token"]
        
        # Refresh token
        response = client.post(
            "/api/auth/refresh",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        # Note: may be same token if created within same second
        assert data["access_token"] is not None
    
    def test_refresh_without_token(self):
        """Test refresh without token."""
        response = client.post("/api/auth/refresh")
        assert response.status_code in [401, 403]
    
    def test_refresh_with_invalid_token(self):
        """Test refresh with invalid token."""
        response = client.post(
            "/api/auth/refresh",
            headers={"Authorization": "Bearer invalid_token"}
        )
        assert response.status_code == 401


class TestAuthProtectedEndpoints:
    """Test protected endpoints."""
    
    def test_protected_demo_without_auth(self):
        """Test protected endpoint without authentication."""
        response = client.get("/api/auth/demo/protected")
        assert response.status_code in [401, 403]
    
    def test_protected_demo_with_token(self):
        """Test protected endpoint with valid token."""
        login_response = client.post(
            "/api/auth/login",
            data={"username": "user", "password": "user123"}
        )
        token = login_response.json()["access_token"]
        
        response = client.get(
            "/api/auth/demo/protected",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "user" in data["message"]
    
    def test_public_demo_without_auth(self):
        """Test public endpoint without authentication."""
        response = client.get("/api/auth/demo/public")
        assert response.status_code == 200
    
    def test_admin_demo_as_user(self):
        """Test admin endpoint as regular user."""
        login_response = client.post(
            "/api/auth/login",
            data={"username": "user", "password": "user123"}
        )
        token = login_response.json()["access_token"]
        
        response = client.get(
            "/api/auth/demo/admin",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 403
    
    def test_admin_demo_as_admin(self):
        """Test admin endpoint as admin user."""
        login_response = client.post(
            "/api/auth/login",
            data={"username": "admin", "password": "admin123"}
        )
        token = login_response.json()["access_token"]
        
        response = client.get(
            "/api/auth/demo/admin",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert "admin" in data["message"]


class TestAuthHealth:
    """Test auth health endpoint."""
    
    def test_auth_health_without_token(self):
        """Test auth health without token."""
        response = client.get("/api/auth/health")
        assert response.status_code in [401, 403]
    
    def test_auth_health_with_token(self):
        """Test auth health with token."""
        login_response = client.post(
            "/api/auth/login",
            data={"username": "admin", "password": "admin123"}
        )
        token = login_response.json()["access_token"]
        
        response = client.get(
            "/api/auth/health",
            headers={"Authorization": f"Bearer {token}"}
        )
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "ok"
        assert "authenticated_user" in data
        assert "admin" in data["roles"]
