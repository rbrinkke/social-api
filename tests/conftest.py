import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.security import get_current_user

# Mock user for testing
def override_get_current_user():
    return {
        "user_id": "550e8400-e29b-41d4-a716-446655440000",
        "email": "test@example.com",
        "subscription_level": "premium",
        "ghost_mode": False
    }

@pytest.fixture
def client():
    """Test client with mocked authentication"""
    app.dependency_overrides[get_current_user] = override_get_current_user
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()

@pytest.fixture
def auth_headers():
    """Mock authentication headers"""
    return {"Authorization": "Bearer mock-token-for-testing"}

@pytest.fixture
def test_user_id():
    return "550e8400-e29b-41d4-a716-446655440000"

@pytest.fixture
def test_target_user_id():
    return "660e8400-e29b-41d4-a716-446655440000"
