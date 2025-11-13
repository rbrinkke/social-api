from fastapi import HTTPException, status

class DatabaseException(Exception):
    """Base exception for database errors"""
    pass

class UserNotFoundException(HTTPException):
    """Exception raised when user is not found"""
    def __init__(self, user_id: str):
        super().__init__(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=f"User with ID {user_id} not found"
        )

class UnauthorizedException(HTTPException):
    """Exception raised for unauthorized access"""
    def __init__(self, detail: str = "Unauthorized"):
        super().__init__(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=detail
        )

class ForbiddenException(HTTPException):
    """Exception raised for forbidden access"""
    def __init__(self, detail: str = "Forbidden"):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=detail
        )

class PremiumRequiredException(HTTPException):
    """Exception raised when premium subscription is required"""
    def __init__(self, detail: str = "This feature requires Premium or Club subscription"):
        super().__init__(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=detail
        )
