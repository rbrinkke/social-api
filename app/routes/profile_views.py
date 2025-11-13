from fastapi import APIRouter, Depends, Query, Request
from app.core.security import get_current_user
from app.services.profile_view_service import ProfileViewService
from app.models.requests import RecordProfileViewRequest
from app.utils.errors import create_error_response
from slowapi import Limiter
from slowapi.util import get_remote_address
from typing import Dict

router = APIRouter(prefix="/social/profile-views", tags=["profile_views"])
limiter = Limiter(key_func=get_remote_address)

@router.post("", status_code=200)
@limiter.limit("100/minute")
async def record_profile_view(
    request_obj: RecordProfileViewRequest,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Record profile view (respects Ghost Mode)"""
    try:
        service = ProfileViewService()
        result = service.record_profile_view(
            viewer_id=current_user["user_id"],
            viewed_id=str(request_obj.viewed_user_id),
            ghost_mode=current_user["ghost_mode"]
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("/who-viewed-me")
@limiter.limit("60/minute")
async def get_who_viewed_me(
    request: Request,
    limit: int = Query(default=100, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: Dict = Depends(get_current_user)
):
    """Get who viewed my profile (Premium feature)"""
    try:
        service = ProfileViewService()
        result = service.get_who_viewed_my_profile(
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

@router.get("/my-count")
@limiter.limit("60/minute")
async def get_profile_view_count(
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Get my profile view count"""
    try:
        service = ProfileViewService()
        result = service.get_profile_view_count(
            user_id=current_user["user_id"]
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)
