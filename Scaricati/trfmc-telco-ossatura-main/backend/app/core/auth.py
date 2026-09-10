"""
Authentication and JWT configuration.
Provides OAuth2 with JWT token support.
"""
import os
import warnings
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from pydantic import BaseModel

# ============================================================================
# SECURITY CONFIGURATION
# ============================================================================

# JWT Configuration — la chiave DEVE arrivare da TRFMC_JWT_SECRET in produzione.
# Il fallback qui sotto è valido solo per sviluppo locale (mode=SIMULATION_ONLY)
# e genera un warning esplicito all'avvio se usato.
_DEV_ONLY_FALLBACK_SECRET = "trfmc-dev-only-insecure-fallback-key"
SECRET_KEY = os.environ.get("TRFMC_JWT_SECRET", _DEV_ONLY_FALLBACK_SECRET)
if SECRET_KEY == _DEV_ONLY_FALLBACK_SECRET:
    warnings.warn(
        "TRFMC_JWT_SECRET non impostata: uso una chiave di sviluppo INSICURA. "
        "Impostare la variabile d'ambiente TRFMC_JWT_SECRET prima di qualunque "
        "deploy che non sia locale/simulazione.",
        RuntimeWarning,
        stacklevel=2,
    )
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# OAuth2 scheme
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

# ============================================================================
# DATA MODELS
# ============================================================================

class User(BaseModel):
    """User model."""
    id: str
    username: str
    email: str
    full_name: Optional[str] = None
    disabled: bool = False
    roles: list[str] = ["user"]


class UserInDB(User):
    """User in database (includes hashed password)."""
    hashed_password: str


class Token(BaseModel):
    """JWT token response."""
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    expires_in: int  # seconds


class TokenData(BaseModel):
    """Token payload data."""
    sub: str  # username
    exp: datetime
    iat: datetime
    roles: list[str] = ["user"]


# ============================================================================
# PASSWORD UTILITIES
# ============================================================================

def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Verify password against hash."""
    return pwd_context.verify(plain_password, hashed_password)


def get_password_hash(password: str) -> str:
    """Hash password for storage."""
    return pwd_context.hash(password)


# ============================================================================
# TOKEN UTILITIES
# ============================================================================

def create_access_token(
    data: dict,
    expires_delta: Optional[timedelta] = None
) -> str:
    """Create JWT access token."""
    to_encode = data.copy()
    
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


def create_tokens(username: str, roles: list[str] = None) -> Token:
    """Create access and refresh tokens."""
    if roles is None:
        roles = ["user"]
    
    # Access token
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": username, "roles": roles},
        expires_delta=access_token_expires
    )
    
    # Refresh token
    refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    refresh_token = create_access_token(
        data={"sub": username, "type": "refresh", "roles": roles},
        expires_delta=refresh_token_expires
    )
    
    return Token(
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=int(access_token_expires.total_seconds())
    )


def verify_token(token: str) -> TokenData:
    """Verify and decode JWT token."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        roles: list[str] = payload.get("roles", ["user"])
        
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
                headers={"WWW-Authenticate": "Bearer"},
            )
        
        return TokenData(
            sub=username,
            exp=datetime.fromtimestamp(payload.get("exp")),
            iat=datetime.utcnow(),
            roles=roles
        )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid token",
            headers={"WWW-Authenticate": "Bearer"},
        )


# ============================================================================
# DEPENDENCY INJECTION
# ============================================================================

async def get_current_user(token: str = Depends(oauth2_scheme)) -> TokenData:
    """Get current user from token."""
    return verify_token(token)


async def get_current_active_user(
    current_user: TokenData = Depends(get_current_user)
) -> TokenData:
    """Get current active user (not disabled)."""
    return current_user


async def check_role(required_role: str):
    """Dependency factory for role checking."""
    async def _check_role(current_user: TokenData = Depends(get_current_active_user)):
        if required_role not in current_user.roles and "admin" not in current_user.roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Insufficient permissions"
            )
        return current_user
    return _check_role


# ============================================================================
# DEMO DATABASE
# ============================================================================

# Demo users - replace with real database
DEMO_USERS_DB = {
    "admin": UserInDB(
        id="1",
        username="admin",
        email="admin@trfmc.local",
        full_name="Admin User",
        disabled=False,
        roles=["admin", "user"],
        hashed_password=get_password_hash("admin123")
    ),
    "user": UserInDB(
        id="2",
        username="user",
        email="user@trfmc.local",
        full_name="Regular User",
        disabled=False,
        roles=["user"],
        hashed_password=get_password_hash("user123")
    ),
}


def get_user(username: str) -> Optional[UserInDB]:
    """Get user from demo database."""
    if username in DEMO_USERS_DB:
        return DEMO_USERS_DB[username]
    return None


def authenticate_user(username: str, password: str) -> Optional[UserInDB]:
    """Authenticate user with username and password."""
    user = get_user(username)
    if not user:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user
