from fastapi import APIRouter, Depends, Query, Request
from app.core.security import get_current_user
from app.services.block_service import BlockService
from app.models.requests import BlockUserRequest
from app.utils.errors import create_error_response
from slowapi import Limiter
from slowapi.util import get_remote_address
from typing import Dict

router = APIRouter(prefix="/social/blocks", tags=["blocking"])
limiter = Limiter(key_func=get_remote_address)

@router.post("", status_code=201)
@limiter.limit("10/minute")
async def block_user(
    request_obj: BlockUserRequest,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Block user"""
    try:
        service = BlockService()
        result = service.block_user(
            blocker_id=current_user["user_id"],
            blocked_id=str(request_obj.blocked_user_id),
            reason=request_obj.reason
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.delete("/{blocked_user_id}", status_code=200)
@limiter.limit("20/minute")
async def unblock_user(
    blocked_user_id: str,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Unblock user"""
    try:
        service = BlockService()
        result = service.unblock_user(
            blocker_id=current_user["user_id"],
            blocked_id=blocked_user_id
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("")
@limiter.limit("30/minute")
async def get_blocked_users(
    request: Request,
    limit: int = Query(default=100, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: Dict = Depends(get_current_user)
):
    """Get blocked users list"""
    try:
        service = BlockService()
        result = service.get_blocked_users(
            blocker_id=current_user["user_id"],
            limit=limit,
            offset=offset
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("/status/{target_user_id}")
@limiter.limit("100/minute")
async def check_block_status(
    target_user_id: str,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Check block status"""
    try:
        service = BlockService()
        result = service.check_block_status(
            user_id_1=current_user["user_id"],
            user_id_2=target_user_id
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("/can-interact/{target_user_id}")
@limiter.limit("100/minute")
async def check_can_interact(
    target_user_id: str,
    request: Request,
    activity_type: str = Query(default="standard"),
    current_user: Dict = Depends(get_current_user)
):
    """Check if users can interact (respects XXL exception)"""
    try:
        service = BlockService()
        result = service.check_can_interact(
            user_id_1=current_user["user_id"],
            user_id_2=target_user_id,
            activity_type=activity_type
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)
