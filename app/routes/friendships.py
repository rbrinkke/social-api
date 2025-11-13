from fastapi import APIRouter, Depends, Query, Request
from app.core.security import get_current_user
from app.services.friendship_service import FriendshipService
from app.models.requests import (
    SendFriendRequestRequest,
    AcceptFriendRequestRequest,
    DeclineFriendRequestRequest
)
from app.models.responses import (
    FriendshipResponse,
    FriendsListResponse,
    FriendshipStatusResponse
)
from app.utils.errors import create_error_response
from slowapi import Limiter
from slowapi.util import get_remote_address
from typing import Dict

router = APIRouter(prefix="/social/friends", tags=["friendships"])
limiter = Limiter(key_func=get_remote_address)

@router.post("/request", status_code=201)
@limiter.limit("20/minute")
async def send_friend_request(
    request_obj: SendFriendRequestRequest,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Send friend request"""
    try:
        service = FriendshipService()
        result = service.send_friend_request(
            requester_id=current_user["user_id"],
            target_id=str(request_obj.target_user_id)
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.post("/accept", status_code=200)
@limiter.limit("30/minute")
async def accept_friend_request(
    request_obj: AcceptFriendRequestRequest,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Accept friend request"""
    try:
        service = FriendshipService()
        result = service.accept_friend_request(
            accepting_id=current_user["user_id"],
            requester_id=str(request_obj.requester_user_id)
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.post("/decline", status_code=200)
@limiter.limit("30/minute")
async def decline_friend_request(
    request_obj: DeclineFriendRequestRequest,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Decline friend request"""
    try:
        service = FriendshipService()
        result = service.decline_friend_request(
            declining_id=current_user["user_id"],
            requester_id=str(request_obj.requester_user_id)
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.delete("/{friend_user_id}", status_code=200)
@limiter.limit("20/minute")
async def remove_friend(
    friend_user_id: str,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Remove friend"""
    try:
        service = FriendshipService()
        result = service.remove_friend(
            user_id=current_user["user_id"],
            friend_id=friend_user_id
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("")
@limiter.limit("60/minute")
async def get_friends_list(
    request: Request,
    limit: int = Query(default=100, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: Dict = Depends(get_current_user)
):
    """Get friends list"""
    try:
        service = FriendshipService()
        result = service.get_friends_list(
            user_id=current_user["user_id"],
            limit=limit,
            offset=offset
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("/requests/received")
@limiter.limit("60/minute")
async def get_pending_requests(
    request: Request,
    limit: int = Query(default=50, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: Dict = Depends(get_current_user)
):
    """Get pending friend requests (received)"""
    try:
        service = FriendshipService()
        result = service.get_pending_friend_requests(
            user_id=current_user["user_id"],
            limit=limit,
            offset=offset
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("/requests/sent")
@limiter.limit("60/minute")
async def get_sent_requests(
    request: Request,
    limit: int = Query(default=50, le=100),
    offset: int = Query(default=0, ge=0),
    current_user: Dict = Depends(get_current_user)
):
    """Get sent friend requests"""
    try:
        service = FriendshipService()
        result = service.get_sent_friend_requests(
            user_id=current_user["user_id"],
            limit=limit,
            offset=offset
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)

@router.get("/status/{target_user_id}")
@limiter.limit("100/minute")
async def check_friendship_status(
    target_user_id: str,
    request: Request,
    current_user: Dict = Depends(get_current_user)
):
    """Check friendship status"""
    try:
        service = FriendshipService()
        result = service.check_friendship_status(
            user_id_1=current_user["user_id"],
            user_id_2=target_user_id
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)
