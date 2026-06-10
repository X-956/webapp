import os
from datetime import datetime, timedelta, timezone
from typing import Any, Callable, Dict, Optional

import pymysql
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt
from passlib.context import CryptContext
from pydantic import BaseModel

from db import get_connection


JWT_SECRET_KEY = os.getenv(
    "JWT_SECRET_KEY", "hospital-outpatient-dev-secret-change-me"
)
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")

try:
    ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "120"))
except ValueError:
    ACCESS_TOKEN_EXPIRE_MINUTES = 120


pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/api/auth/login", auto_error=False)


class LoginRequest(BaseModel):
    username: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str
    display_name: str
    username: str


def _auth_error(message: str = "token缺失或失效") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail={"message": message},
        headers={"WWW-Authenticate": "Bearer"},
    )


def verify_password(plain_password: str, password_hash: str) -> bool:
    return pwd_context.verify(plain_password, password_hash)


def hash_password(password: str) -> str:
    return pwd_context.hash(password)


def _public_user(row: Dict[str, Any]) -> Dict[str, Any]:
    return {
        "user_id": row["user_id"],
        "username": row["username"],
        "role": row["role"],
        "display_name": row["display_name"],
        "related_doctor_id": row.get("related_doctor_id"),
    }


def get_user_by_username(username: str) -> Optional[Dict[str, Any]]:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    user_id,
                    username,
                    password_hash,
                    role,
                    display_name,
                    related_doctor_id,
                    is_active
                FROM app_users
                WHERE username = %s
                LIMIT 1
                """,
                (username,),
            )
            return cursor.fetchone()
    finally:
        conn.close()


def get_user_by_id(user_id: int) -> Optional[Dict[str, Any]]:
    conn = get_connection()
    try:
        with conn.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    user_id,
                    username,
                    role,
                    display_name,
                    related_doctor_id,
                    is_active
                FROM app_users
                WHERE user_id = %s
                LIMIT 1
                """,
                (user_id,),
            )
            return cursor.fetchone()
    finally:
        conn.close()


def authenticate_user(username: str, password: str) -> Optional[Dict[str, Any]]:
    user = get_user_by_username(username)
    if not user or not user.get("is_active"):
        return None
    if not verify_password(password, user["password_hash"]):
        return None
    return user


def create_access_token(user: Dict[str, Any]) -> str:
    expire = datetime.now(timezone.utc) + timedelta(
        minutes=ACCESS_TOKEN_EXPIRE_MINUTES
    )
    payload = {
        "sub": user["username"],
        "user_id": user["user_id"],
        "role": user["role"],
        "exp": expire,
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)


def token_response(user: Dict[str, Any]) -> TokenResponse:
    public_user = _public_user(user)
    return TokenResponse(
        access_token=create_access_token(user),
        role=public_user["role"],
        display_name=public_user["display_name"],
        username=public_user["username"],
    )


def get_current_user(token: Optional[str] = Depends(oauth2_scheme)) -> Dict[str, Any]:
    if not token:
        raise _auth_error()

    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
        user_id = payload.get("user_id")
    except JWTError as exc:
        raise _auth_error() from exc

    if user_id is None:
        raise _auth_error()

    try:
        user = get_user_by_id(int(user_id))
    except (TypeError, ValueError) as exc:
        raise _auth_error() from exc
    except pymysql.MySQLError:
        raise

    if not user or not user.get("is_active"):
        raise _auth_error()
    return _public_user(user)


def require_roles(*roles: str) -> Callable[[Dict[str, Any]], Dict[str, Any]]:
    allowed_roles = set(roles)

    def dependency(
        current_user: Dict[str, Any] = Depends(get_current_user),
    ) -> Dict[str, Any]:
        if current_user["role"] not in allowed_roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail={"message": "权限不足"},
            )
        return current_user

    return dependency
