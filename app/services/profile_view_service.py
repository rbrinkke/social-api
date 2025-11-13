from app.utils.database import get_db_connection
from typing import Dict

class ProfileViewService:
    def record_profile_view(self, viewer_id: str, viewed_id: str, ghost_mode: bool) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_record_profile_view(%s, %s, %s)",
                    (viewer_id, viewed_id, ghost_mode)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def get_who_viewed_my_profile(self, user_id: str, subscription_level: str, limit: int = 100, offset: int = 0) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_get_who_viewed_my_profile(%s, %s, %s, %s)",
                    (user_id, subscription_level, limit, offset)
                )
                result = cursor.fetchone()[0]
                return result

    def get_profile_view_count(self, user_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_get_profile_view_count(%s)",
                    (user_id,)
                )
                result = cursor.fetchone()[0]
                return result
