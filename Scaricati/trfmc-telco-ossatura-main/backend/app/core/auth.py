"""Authentication and JWT configuration."""
from datetime import datetime, timedelta
from typing import Optional
from jose import JWTError, jwt
from passlib.context import CryptContext
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from pydantic import BaseModel

SECRET_KEY = "trfmc-secret-key-change-in-production-2026"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30
REFRESH_TOKEN_EXPIRE_DAYS = 7

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login")

class User(BaseModel):
    id: str
    username: str
    email: str
    full_name: Optional[str] = None
    disabled: bool = False
    roles: list[str] = ["user"]

class UserInDB(User):
    hashed_password: str

class Token(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str = "bearer"
    expires_in: int

class TokenData(BaseModel):
    sub: str
    exp: datetime
    iat: datetime
    roles: list[str] = ["user"]

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def get_password_hash(password: str) -> str:
    return pwd_context.hash(password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def create_tokens(username: str, roles: list[str] = None) -> Token:
    if roles is None:
        roles = ["user"]
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(data={"sub": username, "roles": roles}, expires_delta=access_token_expires)
    refresh_token_expires = timedelta(days=REFRESH_TOKEN_EXPIRE_DAYS)
    refresh_token = create_access_token(data={"sub": username, "type": "refresh", "roles": roles}, expires_delta=refresh_token_expires)
    return Token(access_token=access_token, refresh_token=refresh_token, expires_in=int(access_token_expires.total_seconds()))

def verify_token(token: str) -> TokenData:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        roles: list[str] = payload.get("roles", ["user"])
        if username is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token", headers={"WWW-Authenticate": "Bearer"})
        return TokenData(sub=username, exp=datetime.fromtimestamp(payload.get("exp")), iat=datetime.utcnow(), roles=roles)
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token", headers={"WWW-Authenticate": "Bearer"})

async def get_current_user(token: str = Depends(oauth2_scheme)) -> TokenData:
    return verify_token(token)

async def get_current_active_user(current_user: TokenData = Depends(get_current_user)) -> TokenData:
    return current_user

DEMO_USERS_DB = {
    "admin": UserInDB(id="1", username="admin", email="admin@trfmc.local", full_name="Admin User", disabled=False, roles=["admin", "user"], hashed_password=get_password_hash("admin123")),
    "user": UserInDB(id="2", username="user", email="user@trfmc.local", full_name="Regular User", disabled=False, roles=["user"], hashed_password=get_password_hash("user123")),
}

def get_user(username: str) -> Optional[UserInDB]:
    if username in DEMO_USERS_DB:
        return DEMO_USERS_DB[username]
    return None

def authenticate_user(username: str, password: str) -> Optional[UserInDB]:
    user = get_user(username)
    if not user:
        return None
    if not verify_password(password, user.hashed_password):
        return None
    return user
