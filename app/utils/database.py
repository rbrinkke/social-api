from psycopg_pool import ConnectionPool
from app.config import settings
from contextlib import contextmanager

pool = ConnectionPool(
    conninfo=settings.DATABASE_URL,
    min_size=settings.DATABASE_POOL_MIN_SIZE,
    max_size=settings.DATABASE_POOL_MAX_SIZE,
    timeout=30
)

@contextmanager
def get_db_connection():
    conn = None
    try:
        conn = pool.getconn()
        yield conn
    except Exception as e:
        if conn:
            conn.rollback()
        raise
    finally:
        if conn:
            pool.putconn(conn)

def close_pool():
    pool.close()
