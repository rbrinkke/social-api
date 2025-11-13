from fastapi import APIRouter
from app.models.responses import HealthCheckResponse
from datetime import datetime

router = APIRouter(tags=["health"])

@router.get("/health", response_model=HealthCheckResponse)
async def health_check():
    return {
        "status": "healthy",
        "service": "social-api",
        "version": "1.0.0",
        "timestamp": datetime.utcnow()
    }
