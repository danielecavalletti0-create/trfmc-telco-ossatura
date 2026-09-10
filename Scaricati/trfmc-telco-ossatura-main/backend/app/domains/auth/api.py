"""
Authentication API endpoints.
Handles login, token refresh, and user information.
"""
from fastapi import APIRouter, HTTPException, status, Depends
from fastapi.security import OAuth2PasswordRequestForm
from app.core.auth import (
    authenticate_user,
    create_tokens,
    get_current_active_user,
    TokenData,
    Token,
    User,
)
from app.core.logging import get_logger

logger = get_logger(__name__)

router = APIRouter(prefix="/api/auth", tags=["authentication"])


# ============================================================================
# LOGIN
# ============================================================================

@router.post("/login", response_model=Token)
async def login(form_data: OAuth2PasswordRequestForm = Depends()):
    """
    Login endpoint - returns JWT tokens.
    
    Demo credentials:
    - admin / admin123
    - user / user123
    """
    logger.info("login_attempt", username=form_data.username)
    
    user = authenticate_user(form_data.username, form_data.password)
    if not user:
        logger.warning("login_failed", username=form_data.username, reason="invalid_credentials")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    tokens = create_tokens(user.username, roles=user.roles)
    logger.info("login_success", username=user.username, roles=user.roles)
    
    return tokens


# ============================================================================
# TOKEN REFRESH
# ============================================================================

@router.post("/refresh", response_model=Token)
async def refresh_token(current_user: TokenData = Depends(get_current_active_user)):
    """
    Refresh access token using current (valid) token.
    """
    logger.info("token_refresh", username=current_user.sub)
    
    tokens = create_tokens(current_user.sub, roles=current_user.roles)
    return tokens


# ============================================================================
# USER INFO
# ============================================================================

@router.get("/me", response_model=User)
async def get_me(current_user: TokenData = Depends(get_current_active_user)):
    """
    Get current authenticated user information.
    """
    return User(
        id="current",
        username=current_user.sub,
        email=f"{current_user.sub}@trfmc.local",
        full_name=f"User {current_user.sub}",
        roles=current_user.roles,
    )


# ============================================================================
# HEALTH CHECK (protected)
# ============================================================================

@router.get("/health")
async def auth_health(current_user: TokenData = Depends(get_current_active_user)):
    """
    Protected health endpoint - requires authentication.
    """
    return {
        "status": "ok",
        "authenticated_user": current_user.sub,
        "roles": current_user.roles,
    }


# ============================================================================
# DEMO ENDPOINTS
# ============================================================================

@router.get("/demo/public")
async def demo_public():
    """
    Public endpoint (no authentication required).
    """
    return {
        "message": "This endpoint is public",
        "note": "Try /api/auth/login to get a token"
    }


@router.get("/demo/protected")
async def demo_protected(current_user: TokenData = Depends(get_current_active_user)):
    """
    Protected endpoint (requires valid token).
    """
    return {
        "message": f"Hello {current_user.sub}!",
        "roles": current_user.roles,
        "note": "This endpoint requires authentication"
    }


@router.get("/demo/admin")
async def demo_admin(current_user: TokenData = Depends(get_current_active_user)):
    """
    Admin-only endpoint.
    """
    if "admin" not in current_user.roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    
    return {
        "message": f"Admin panel for {current_user.sub}",
        "admin_features": ["user_management", "system_config", "audit_logs"]
    }
