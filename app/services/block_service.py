from app.utils.database import get_db_connection
from typing import Dict, Optional

class BlockService:
    def block_user(self, blocker_id: str, blocked_id: str, reason: Optional[str] = None) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_block_user(%s, %s, %s)",
                    (blocker_id, blocked_id, reason)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def unblock_user(self, blocker_id: str, blocked_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_unblock_user(%s, %s)",
                    (blocker_id, blocked_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def get_blocked_users(self, blocker_id: str, limit: int = 100, offset: int = 0) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_get_blocked_users(%s, %s, %s)",
                    (blocker_id, limit, offset)
                )
                result = cursor.fetchone()[0]
                return result

    def check_block_status(self, user_id_1: str, user_id_2: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_check_block_status(%s, %s)",
                    (user_id_1, user_id_2)
                )
                result = cursor.fetchone()[0]
                return result

    def check_can_interact(self, user_id_1: str, user_id_2: str, activity_type: str = "standard") -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_check_can_interact(%s, %s, %s)",
                    (user_id_1, user_id_2, activity_type)
                )
                result = cursor.fetchone()[0]
                return result
