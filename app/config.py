from pydantic_settings import BaseSettings
from typing import List

class Settings(BaseSettings):
    ENVIRONMENT: str = "development"
    PROJECT_NAME: str = "Social API"
    API_HOST: str = "0.0.0.0"
    API_PORT: int = 8000
    DATABASE_URL: str
    DATABASE_POOL_MIN_SIZE: int = 5
    DATABASE_POOL_MAX_SIZE: int = 20
    JWT_SECRET_KEY: str
    JWT_ALGORITHM: str = "HS256"
    REDIS_URL: str = "redis://localhost:6379/0"
    CORS_ORIGINS: List[str] = ["http://localhost:3000"]
    LOG_LEVEL: str = "INFO"

    class Config:
        env_file = ".env"
        case_sensitive = True

settings = Settings()
