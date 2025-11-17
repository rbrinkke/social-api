from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from app.config import settings
from app.utils.database import get_db_connection
from typing import Dict

security = HTTPBearer()

async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
) -> Dict:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, settings.JWT_SECRET_KEY, algorithms=[settings.JWT_ALGORITHM])
        user_id = payload.get("sub")

        if not user_id:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token: missing user ID"
            )

        # Check if email is in token (old format) or fetch from database (new format)
        email = payload.get("email")
        subscription_level = payload.get("subscription_level")
        ghost_mode = payload.get("ghost_mode")

        # If email not in token, fetch user details from database
        if not email:
            with get_db_connection() as conn:
                with conn.cursor() as cursor:
                    cursor.execute(
                        "SELECT email, subscription_level FROM activity.users WHERE user_id = %s",
                        (user_id,)
                    )
                    row = cursor.fetchone()
                    if not row:
                        raise HTTPException(
                            status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="User not found"
                        )
                    email, subscription_level = row
                    # ghost_mode not in database, default to False
                    if ghost_mode is None:
                        ghost_mode = False

        return {
            "user_id": user_id,
            "email": email or "unknown@unknown.com",
            "subscription_level": subscription_level or "free",
            "ghost_mode": ghost_mode if ghost_mode is not None else False
        }
    except JWTError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication credentials: {str(e)}"
        )
