from app.utils.database import get_db_connection
from typing import Dict

class FavoriteService:
    def favorite_user(self, favoriting_id: str, favorited_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_favorite_user(%s, %s)",
                    (favoriting_id, favorited_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def unfavorite_user(self, favoriting_id: str, favorited_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_unfavorite_user(%s, %s)",
                    (favoriting_id, favorited_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def get_my_favorites(self, user_id: str, limit: int = 100, offset: int = 0) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_get_my_favorites(%s, %s, %s)",
                    (user_id, limit, offset)
                )
                result = cursor.fetchone()[0]
                return result

    def get_who_favorited_me(self, user_id: str, subscription_level: str, limit: int = 100, offset: int = 0) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_get_who_favorited_me(%s, %s, %s, %s)",
                    (user_id, subscription_level, limit, offset)
                )
                result = cursor.fetchone()[0]
                return result

    def check_favorite_status(self, favoriting_id: str, favorited_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_check_favorite_status(%s, %s)",
                    (favoriting_id, favorited_id)
                )
                result = cursor.fetchone()[0]
                return result
