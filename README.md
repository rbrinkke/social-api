# Social API

FastAPI microservice for social features: friendships, blocking, favorites, profile views, user search.

## Features

- 21 REST API endpoints
- 22 PostgreSQL stored procedures
- JWT authentication
- Rate limiting (Redis)
- Async support
- Docker deployment
- Comprehensive testing

## Quick Start

### Development

```bash
# Create .env file
cp .env.example .env

# Install dependencies
pip install -r requirements.txt

# Run database migrations
psql -U postgres -d activitydb -f sql/01_stored_procedures_friendships.sql
psql -U postgres -d activitydb -f sql/02_stored_procedures_blocks.sql
# ... repeat for all SQL files

# Run server
uvicorn app.main:app --reload
```

### Docker

```bash
# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f social-api

# Stop services
docker-compose down
```

## API Documentation

- Swagger UI: http://localhost:8000/docs
- ReDoc: http://localhost:8000/redoc

## Testing

```bash
pytest tests/ -v
```

## Architecture

- **Database Layer**: PostgreSQL stored procedures only
- **Service Layer**: Business logic, calls stored procedures
- **API Layer**: FastAPI routes with validation
- **Authentication**: JWT tokens from Auth API

## Endpoints

### Friendships (8)
- POST /social/friends/request
- POST /social/friends/accept
- POST /social/friends/decline
- DELETE /social/friends/{friend_user_id}
- GET /social/friends
- GET /social/friends/requests/received
- GET /social/friends/requests/sent
- GET /social/friends/status/{target_user_id}

### Blocking (5)
- POST /social/blocks
- DELETE /social/blocks/{blocked_user_id}
- GET /social/blocks
- GET /social/blocks/status/{target_user_id}
- GET /social/blocks/can-interact/{target_user_id}

### Favorites (5)
- POST /social/favorites
- DELETE /social/favorites/{favorited_user_id}
- GET /social/favorites/mine
- GET /social/favorites/who-favorited-me (Premium)
- GET /social/favorites/status/{target_user_id}

### Profile Views (3)
- POST /social/profile-views
- GET /social/profile-views/who-viewed-me (Premium)
- GET /social/profile-views/my-count

### User Search (1)
- GET /social/users/search

## Environment Variables

See `.env.example` for all required environment variables.
