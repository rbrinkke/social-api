from fastapi import APIRouter, Depends, Query, HTTPException, Request
from app.core.security import get_current_user
from app.services.user_search_service import UserSearchService
from app.utils.errors import create_error_response
from slowapi import Limiter
from slowapi.util import get_remote_address
from typing import Dict

router = APIRouter(prefix="/social/users", tags=["user_search"])
limiter = Limiter(key_func=get_remote_address)

@router.get("/search")
@limiter.limit("60/minute")
async def search_users(
    request: Request,
    q: str = Query(..., min_length=2, max_length=100),
    limit: int = Query(default=20, le=50),
    offset: int = Query(default=0, ge=0),
    current_user: Dict = Depends(get_current_user)
):
    """Search users by name or username"""
    if len(q) < 2:
        raise HTTPException(status_code=400, detail="Search query must be at least 2 characters")

    try:
        service = UserSearchService()
        result = service.search_users(
            searcher_id=current_user["user_id"],
            query=q,
            limit=limit,
            offset=offset
        )
        return result
    except Exception as e:
        return create_error_response(e, 400)
