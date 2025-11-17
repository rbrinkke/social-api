from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.config import settings
from app.core.logging_config import setup_logging, get_logger
from app.middleware.correlation import CorrelationMiddleware
from app.utils.database import close_pool
from app.routes import health, friendships, blocks, favorites, profile_views, user_search

# Setup logging
setup_logging(settings.ENVIRONMENT)
logger = get_logger(__name__)

# Create FastAPI app
app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.API_VERSION,
    description="""Social interaction service managing likes, follows, comments, and blocking.

Features premium tier restrictions, activity size limits, and comprehensive social graph management.

## Key Features
- Likes and reactions
- Follow/unfollow with follower counts
- Comment threads
- User blocking (with XXL activity exception)
- Premium tier features (unlimited follows)
- Stored procedure architecture

## Architecture
- Database: PostgreSQL with `activity` schema
- Auth: JWT Bearer tokens
- Rate limiting: Redis-backed limits""",
    docs_url="/docs" if settings.ENABLE_DOCS else None,
    redoc_url="/redoc" if settings.ENABLE_DOCS else None,
    openapi_url="/openapi.json" if settings.ENABLE_DOCS else None,
    contact={"name": "Activity Platform Team", "email": "dev@activityapp.com"},
    license_info={"name": "Proprietary"}
)


def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema
    from fastapi.openapi.utils import get_openapi
    openapi_schema = get_openapi(
        title=settings.PROJECT_NAME,
        version=settings.API_VERSION,
        description=app.description,
        routes=app.routes,
    )
    openapi_schema["components"]["securitySchemes"] = {
        "BearerAuth": {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": "Enter JWT token from auth-api"
        }
    }
    openapi_schema["security"] = [{"BearerAuth": []}]
    app.openapi_schema = openapi_schema
    return app.openapi_schema


app.openapi = custom_openapi

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "DELETE"],
    allow_headers=["Authorization", "Content-Type"]
)

# Correlation Middleware
app.add_middleware(CorrelationMiddleware)

# Include routers
app.include_router(health.router)
app.include_router(friendships.router)
app.include_router(blocks.router)
app.include_router(favorites.router)
app.include_router(profile_views.router)
app.include_router(user_search.router)

@app.on_event("startup")
async def startup_event():
    logger.info("social_api_starting", environment=settings.ENVIRONMENT)

@app.on_event("shutdown")
async def shutdown_event():
    logger.info("social_api_shutting_down")
    close_pool()

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "app.main:app",
        host=settings.API_HOST,
        port=settings.API_PORT,
        reload=settings.ENVIRONMENT == "development"
    )
