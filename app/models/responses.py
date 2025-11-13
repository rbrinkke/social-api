from pydantic import BaseModel
from datetime import datetime
from uuid import UUID
from typing import List, Optional

# Health Check
class HealthCheckResponse(BaseModel):
    status: str
    service: str
    version: str
    timestamp: datetime

# Friendships
class FriendshipResponse(BaseModel):
    friendship_id: str
    requester_user_id: UUID
    target_user_id: UUID
    status: str
    initiated_by: UUID
    created_at: datetime

class FriendProfileResponse(BaseModel):
    user_id: UUID
    username: str
    first_name: Optional[str]
    last_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool
    friendship_since: datetime

class FriendsListResponse(BaseModel):
    friends: List[FriendProfileResponse]
    total_count: int
    limit: int
    offset: int

class FriendshipStatusResponse(BaseModel):
    status: str
    initiated_by: Optional[UUID] = None
    created_at: Optional[datetime] = None
    accepted_at: Optional[datetime] = None

# Blocking
class BlockUserResponse(BaseModel):
    blocker_user_id: UUID
    blocked_user_id: UUID
    blocked_at: datetime
    friendship_removed: bool

class BlockedUserProfile(BaseModel):
    blocked_user_id: UUID
    username: str
    first_name: Optional[str]
    last_name: Optional[str]
    main_photo_url: Optional[str]
    blocked_at: datetime
    reason: Optional[str]

class BlockedUsersListResponse(BaseModel):
    blocked_users: List[BlockedUserProfile]
    total_count: int
    limit: int
    offset: int

class BlockStatusResponse(BaseModel):
    user_1_blocked_user_2: bool
    user_2_blocked_user_1: bool
    any_block_exists: bool

class CanInteractResponse(BaseModel):
    can_interact: bool
    reason: str
    activity_type: str

# Favorites
class FavoriteUserResponse(BaseModel):
    favoriting_user_id: UUID
    favorited_user_id: UUID
    favorited_at: datetime

class FavoriteProfile(BaseModel):
    user_id: UUID
    username: str
    first_name: Optional[str]
    last_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool
    favorited_at: datetime

class FavoritesListResponse(BaseModel):
    favorites: List[FavoriteProfile]
    total_count: int
    limit: int
    offset: int

class WhoFavoritedMeResponse(BaseModel):
    favorited_by: List[FavoriteProfile]
    total_count: int
    limit: int
    offset: int

class FavoriteStatusResponse(BaseModel):
    is_favorited: bool
    favorited_at: Optional[datetime] = None

# Profile Views
class ProfileViewRecordedResponse(BaseModel):
    view_recorded: bool
    view_id: Optional[UUID] = None
    viewer_user_id: Optional[UUID] = None
    viewed_user_id: UUID
    viewed_at: Optional[datetime] = None
    ghost_mode: Optional[bool] = False

class ProfileViewerProfile(BaseModel):
    viewer_user_id: UUID
    username: str
    first_name: Optional[str]
    last_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool
    last_viewed_at: datetime
    view_count: int

class WhoViewedMyProfileResponse(BaseModel):
    viewers: List[ProfileViewerProfile]
    total_viewers: int
    total_views: int
    limit: int
    offset: int

class ProfileViewCountResponse(BaseModel):
    user_id: UUID
    total_views: int
    unique_viewers: int

# User Search
class SearchedUserProfile(BaseModel):
    user_id: UUID
    username: str
    first_name: Optional[str]
    last_name: Optional[str]
    main_photo_url: Optional[str]
    is_verified: bool
    activities_created_count: int
    activities_attended_count: int

class UserSearchResponse(BaseModel):
    users: List[SearchedUserProfile]
    total_count: int
    search_query: str
    limit: int
    offset: int
