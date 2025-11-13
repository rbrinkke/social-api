from app.utils.database import get_db_connection
from typing import Dict

class UserSearchService:
    def search_users(self, searcher_id: str, query: str, limit: int = 20, offset: int = 0) -> Dict:
        with get_db_connection() as conn:
            with conn.cursor() as cursor:
                cursor.execute(
                    "SELECT activity.sp_social_search_users(%s, %s, %s, %s)",
                    (searcher_id, query, limit, offset)
                )
                result = cursor.fetchone()[0]
                return result
