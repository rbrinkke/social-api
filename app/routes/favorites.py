from fastapi import APIRouter, Depends, Query, Request
from app.core.security import get_current_user
from app.services.favorite_service import FavoriteService
from app.models.requests import FavoriteUserRequest
from app.utils.errors import create_error_response
from slowapi import Limiter
from slowapi.util import get_remote_address
from typing import Dict

router = APIRouter(prefix="/social/favorites", tags=["favorites"])
limiter = Limiter(key_func=get_remote_address)

@router.post("", status_code=201)
@limiter.limit("30/minute")
async def favorite_user(
    request_obj: FavoriteUserRequest,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Favorite user"""
    try:
        service = FavoriteService()
        result = service.favorite_user(
            favoriting_id=current_user["user_id"],
            favorited_id=str(request_obj.favorited_user_id)
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.delete("/{favorited_user_id}", status_code=200)
@limiter.limit("30/minute")
async def unfavorite_user(
    favorited_user_id: str,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Unfavorite user"""
    try:
        service = FavoriteService()
        result = service.unfavorite_user(
            favoriting_id=current_user["user_id"],
            favorited_id=favorited_user_id
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("/mine")
@limiter.limit("60/minute")
async def get_my_favorites(
    request: Request,
    limit: int = Query(default=100, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: Dict = Depends(get_current_user)
):
    """Get my favorites"""
    try:
        service = FavoriteService()
        result = service.get_my_favorites(
            user_id=current_user["user_id"],
            limit=limit,
            offset=offset
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("/who-favorited-me")
@limiter.limit("60/minute")
async def get_who_favorited_me(
    request: Request,
    limit: int = Query(default=100, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: Dict = Depends(get_current_user)
):
    """Get who favorited me (Premium feature)"""
    try:
        service = FavoriteService()
        result = service.get_who_favorited_me(
            user_id=current_user["user_id"],
            subscription_level=current_user["subscription_level"],
            limit=limit,
            offset=offset
        )
        return result
    except Exception as e:
        if "PREMIUM_REQUIRED" in str(e):
            return create_error_response(e, 403)
        return create_error_response(e, 400)

@router.get("/status/{target_user_id}")
@limiter.limit("100/minute")
async def check_favorite_status(
    target_user_id: str,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Check favorite status"""
    try:
        service = FavoriteService()
        result = service.check_favorite_status(
            favoriting_id=current_user["user_id"],
            favorited_id=target_user_id
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)
