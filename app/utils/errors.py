from fastapi import HTTPException
from typing import Any, Dict

def create_error_response(exception: Exception, default_status_code: int = 400) -> HTTPException:
    """
    Create an HTTP error response from an exception.
    Parse PostgreSQL errors and return appropriate status codes.
    """
    error_message = str(exception)

    # Map PostgreSQL error codes to HTTP status codes
    error_mappings = {
        "SELF_FRIEND_ERROR": 400,
        "USER_NOT_FOUND": 404,
        "FRIENDSHIP_EXISTS": 409,
        "BLOCKED_BY_USER": 403,
        "USER_BLOCKED": 403,
        "FRIENDSHIP_NOT_FOUND": 404,
        "INVALID_ACCEPTOR": 400,
        "INVALID_DECLINER": 400,
        "SELF_BLOCK_ERROR": 400,
        "ALREADY_BLOCKED": 409,
        "BLOCK_NOT_FOUND": 404,
        "SELF_FAVORITE_ERROR": 400,
        "ALREADY_FAVORITED": 409,
        "BLOCKED_USER": 403,
        "FAVORITE_NOT_FOUND": 404,
        "PREMIUM_REQUIRED": 403,
        "SELF_VIEW_ERROR": 400,
        "INVALID_QUERY": 400,
    }

    # Extract error code from message (format: "ERROR_CODE: message")
    status_code = default_status_code
    for error_code, code_status in error_mappings.items():
        if error_code in error_message:
            status_code = code_status
            # Clean up the error message
            if ":" in error_message:
                error_message = error_message.split(":", 1)[1].strip()
            break

    raise HTTPException(status_code=status_code, detail=error_message)

def parse_db_error(error: Exception) -> Dict[str, Any]:
    """
    Parse database error and return structured error information.
    """
    error_str = str(error)

    return {
        "error": "DatabaseError",
        "message": error_str,
        "type": type(error).__name__
    }
