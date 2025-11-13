from pydantic import BaseModel, Field
from uuid import UUID
from typing import Optional

# Friendships
class SendFriendRequestRequest(BaseModel):
    target_user_id: UUID

class AcceptFriendRequestRequest(BaseModel):
    requester_user_id: UUID

class DeclineFriendRequestRequest(BaseModel):
    requester_user_id: UUID

# Blocking
class BlockUserRequest(BaseModel):
    blocked_user_id: UUID
    reason: Optional[str] = Field(None, max_length=500)

# Favorites
class FavoriteUserRequest(BaseModel):
    favorited_user_id: UUID

# Profile Views
class RecordProfileViewRequest(BaseModel):
    viewed_user_id: UUID
