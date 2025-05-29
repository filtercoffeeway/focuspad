# FocusPad API Architecture 🏗️

## 📁 Project Structure

```
focuspad/
├── app/                          # Main application package
│   ├── __init__.py              # App factory pattern
│   ├── models/                   # Database models
│   │   ├── __init__.py
│   │   └── user.py              # User model
│   ├── routes/                   # Blueprint routes
│   │   ├── __init__.py
│   │   ├── auth.py              # Authentication routes
│   │   └── main.py              # Utility routes
│   ├── config/                   # Configuration settings
│   │   ├── __init__.py
│   │   └── settings.py          # Environment configs
│   ├── utils/                    # Helper utilities
│   │   ├── __init__.py
│   │   └── helpers.py           # OAuth & error handlers
│   └── templates/                # Jinja2 templates
│       ├── login.html
│       └── success.html
├── scripts/                      # Helper scripts
│   ├── db_connect.sh            # Database connection
│   ├── test_db.py               # Database testing
│   ├── init_migrations.py       # Migration setup
│   └── sql_scripts/
│       └── common_queries.sql   # Sample SQL queries
├── migrations/                   # Flask-Migrate files
├── config.py                    # Legacy config (deprecated)
├── flask_cli.py                 # Flask CLI commands
├── run.py                       # Local development entry point
├── run_docker.py               # Docker entry point
├── requirements.txt             # Python dependencies
├── Dockerfile                   # Docker configuration
├── docker-compose.yml          # Multi-container setup
└── README.md                   # Project documentation
```

## 🧩 Architecture Components

### **App Factory Pattern**
- **File**: `app/__init__.py`
- **Purpose**: Creates and configures Flask application instances
- **Benefits**: 
  - Support for multiple configurations (dev, test, prod)
  - Easy testing with different setups
  - Clean extension initialization

### **Modular Blueprints**
- **Location**: `app/routes/`
- **Structure**:
  - `auth.py` - Authentication endpoints
  - `main.py` - Utility endpoints
- **Benefits**:
  - Clean separation of concerns
  - Easy to add new route modules
  - Simplified testing and maintenance

### **Organized Models**
- **Location**: `app/models/`
- **Current Models**:
  - `User` - Google OAuth user management
- **Benefits**:
  - Each model in separate file
  - Easy to add relationships
  - Clear model organization

### **Configuration Management**
- **Location**: `app/config/`
- **Environments**:
  - `DevelopmentConfig` - Local development
  - `TestingConfig` - Unit testing
  - `ProductionConfig` - Production deployment
  - `DockerConfig` - Docker containers
- **Benefits**:
  - Environment-specific settings
  - Easy configuration switching
  - Secure credential management

### **Utility Helpers**
- **Location**: `app/utils/`
- **Functions**:
  - OAuth provider initialization
  - Global error handlers
  - Database helpers
- **Benefits**:
  - Reusable utility functions
  - Clean separation of concerns
  - Easy to extend functionality

## 🗄️ Database Management

### **Flask-Migrate Integration**
```bash
# Initialize migrations
python scripts/init_migrations.py

# Create new migration
flask db migrate -m "Description"

# Apply migrations
flask db upgrade

# Downgrade migrations
flask db downgrade
```

### **Database Operations**
```bash
# Connect to database
./scripts/db_connect.sh

# Test database connection
python scripts/test_db.py

# Database CLI commands
flask init-db     # Initialize tables
flask drop-db     # Drop all tables
flask reset-db    # Drop and recreate
```

## 🔧 Development Workflow

### **Local Development**
1. **Setup Environment**:
   ```bash
   python -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Configure Database**:
   ```bash
   export DATABASE_URL=postgresql://user:pass@localhost:5432/focuspad
   ```

3. **Run Migrations**:
   ```bash
   flask db upgrade
   ```

4. **Start Application**:
   ```bash
   python run.py
   ```

### **Docker Development**
1. **Start Services**:
   ```bash
   docker-compose up --build
   ```

2. **Run Migrations in Container**:
   ```bash
   docker exec focuspad_web flask db upgrade
   ```

## 📦 Extension Management

### **Registered Extensions**
- **SQLAlchemy**: Database ORM
- **Flask-Migrate**: Database migrations
- **Flask-JWT-Extended**: JWT token management
- **Flask-CORS**: Cross-origin requests
- **Authlib**: OAuth integration

### **Extension Initialization**
Extensions are initialized in `app/__init__.py` using the app factory pattern:

```python
# Create extension instances
db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()

# Initialize with app
db.init_app(app)
migrate.init_app(app, db)
jwt.init_app(app)
```

## 🔒 Security Features

### **Authentication Flow**
1. **Google OAuth 2.0** - Secure user authentication
2. **JWT Tokens** - Stateless session management
3. **State Parameters** - CSRF protection
4. **Token Validation** - Secure API access

### **Error Handling**
- **Global Error Handlers** - Consistent error responses
- **Validation Middleware** - Input validation
- **Logging Integration** - Security event tracking

## 🚀 Scalability Features

### **Horizontal Scaling**
- **Stateless Design** - No server-side sessions
- **Database Pooling** - Connection optimization
- **Container Ready** - Docker deployment

### **Vertical Scaling**
- **Lazy Loading** - Models loaded on demand
- **Blueprint Organization** - Route separation
- **Configuration Management** - Environment optimization

## 🧪 Testing Strategy

### **Unit Tests**
- **Model Tests** - Database operations
- **Route Tests** - API endpoint testing
- **Integration Tests** - Full workflow testing

### **Test Configuration**
```python
# Testing with in-memory database
SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
TESTING = True
```

## 📈 Monitoring & Maintenance

### **Health Checks**
- **Database Connectivity** - `/health` endpoint
- **Service Status** - Container health checks
- **OAuth Configuration** - `/api/auth/debug/config`

### **Logging**
- **Application Logs** - Flask logging
- **Database Logs** - SQLAlchemy events
- **OAuth Logs** - Authentication events

This architecture provides a solid foundation for scaling the FocusPad API while maintaining clean code organization and easy maintenance. 