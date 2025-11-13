from app.utils.database import get_db_connection
from typing import Dict

class FriendshipService:
    def send_friend_request(self, requester_id: str, target_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_send_friend_request(%s, %s)",
                    (requester_id, target_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def accept_friend_request(self, accepting_id: str, requester_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_accept_friend_request(%s, %s)",
                    (accepting_id, requester_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def decline_friend_request(self, declining_id: str, requester_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_decline_friend_request(%s, %s)",
                    (declining_id, requester_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def remove_friend(self, user_id: str, friend_id: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_remove_friend(%s, %s)",
                    (user_id, friend_id)
                )
                result = cursor.fetchone()[0]
                conn.commit()
                return result

    def get_friends_list(self, user_id: str, limit: int = 100, offset: int = 0) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_get_friends_list(%s, %s, %s)",
                    (user_id, limit, offset)
                )
                result = cursor.fetchone()[0]
                return result

    def get_pending_friend_requests(self, user_id: str, limit: int = 50, offset: int = 0) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_get_pending_friend_requests(%s, %s, %s)",
                    (user_id, limit, offset)
                )
                result = cursor.fetchone()[0]
                return result

    def get_sent_friend_requests(self, user_id: str, limit: int = 50, offset: int = 0) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_get_sent_friend_requests(%s, %s, %s)",
                    (user_id, limit, offset)
                )
                result = cursor.fetchone()[0]
                return result

    def check_friendship_status(self, user_id_1: str, user_id_2: str) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_check_friendship_status(%s, %s)",
                    (user_id_1, user_id_2)
                )
                result = cursor.fetchone()[0]
                return result
