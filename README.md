# FocusPad 🎯

**AI-Powered Note Taking Application with End-to-End Security**

FocusPad is a modern, secure note-taking application built with Flask, featuring Google OAuth authentication, server-side encryption, intelligent search, and AI-powered content categorization.

## 📋 Table of Contents

1. [Quick Start](#quick-start) - Get up and running fast
2. [Local Development](#local-development-setup) - Development environment
3. [Production Deployment](#production-deployment) - Live deployment
4. [Configuration](#environment-configuration) - Environment setup
5. [Google OAuth Setup](#google-oauth-setup) - Authentication configuration  
6. [Architecture](#architecture-overview) - System design
7. [Security](#security-features) - Security implementation
8. [API Reference](#api-reference) - Endpoints and usage
9. [Advanced Topics](#advanced-topics) - Deep technical details
   - [Encryption Implementation](#encryption-implementation)
   - [Search Functionality](#search-functionality) 
   - [Database Schema](#database-schema)
10. [Development Guide](#development-guide) - Testing and debugging
11. [Troubleshooting](#troubleshooting) - Common issues
12. [Admin] - Admin Tools

---

## ✨ Key Features

- **🔐 Google OAuth Authentication**: Secure login with Google accounts
- **🛡️ Server-Side Encryption**: AES-256 encryption for all sensitive data
- **🔍 Intelligent Search**: Full-text search across encrypted content
- **🤖 AI Integration**: OpenAI-powered content categorization and suggestions
- **📱 Modern UI**: Responsive design with dark mode support
- **🐳 Docker Deployment**: Production-ready containerized deployment
- **🌐 SSL/HTTPS**: Let's Encrypt integration for secure connections

## 🛠️ Technology Stack

- **Backend**: Flask (Python 3.11+)
- **Database**: PostgreSQL 15
- **Authentication**: Google OAuth 2.0 + JWT
- **Encryption**: AES-256 with PBKDF2 key derivation
- **Deployment**: Docker + Nginx + Let's Encrypt
- **AI**: OpenAI GPT for content processing
- **Caching**: Redis for sessions and performance

---

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Google OAuth credentials from [Google Cloud Console](https://console.cloud.google.com/)
- Git

### Choose Your Environment

FocusPad provides two optimized Docker setups:

| Environment | Use Case | Command |
|-------------|----------|---------|
| **Local Development** | Coding, debugging, testing | `./scripts/start-local.sh` |
| **Production** | Live deployment on servers | `./scripts/deploy.sh` |

---

## 🛠️ Local Development Setup

Perfect for development with debugging tools, hot reload, and database management.

### Quick Start

```bash
# 1. Clone repository
git clone https://github.com/yourusername/focuspad.git
cd focuspad

# 2. Setup environment
cp .env.local.example .env.local
nano .env.local  # Update Google OAuth credentials

# 3. Start development environment
./scripts/start-local.sh
```

### What You Get

- **Application**: http://localhost:5000
- **PgAdmin**: http://localhost:8080 (admin@focuspad.local / admin123)
- **PostgreSQL**: localhost:5432 (focuspad_user / focuspad_dev_password)
- **Redis**: localhost:6379
- **Hot Reload**: Live code changes without rebuilds
- **Debug Mode**: Detailed error messages and logging

### Development Commands

```bash
# Start all services
./scripts/start-local.sh

# View logs in real-time
docker-compose -f docker-compose.local.yml --env-file .env.local logs -f

# Stop all services
docker-compose -f docker-compose.local.yml down

# Restart just the web app
docker-compose -f docker-compose.local.yml restart web

# Access container shell
docker-compose -f docker-compose.local.yml exec web bash

# Run database migrations
docker-compose -f docker-compose.local.yml exec web python3 scripts/setup_encryption.py
```

---

## 🚀 Production Deployment

Optimized for production with security hardening, performance tuning, and monitoring.

### AWS EC2 Quick Deploy

```bash
# 1. Setup EC2 instance (Ubuntu 22.04 LTS)
ssh -i your-key.pem ubuntu@your-ec2-ip
git clone https://github.com/yourusername/focuspad.git /opt/focuspad
cd /opt/focuspad

# 2. Run instance setup
./scripts/setup-instance.sh  # Installs Docker, Nginx, SSL tools
logout && ssh -i your-key.pem ubuntu@your-ec2-ip && cd /opt/focuspad

# 3. Configure production environment
cp .env.prod.example .env.production
nano .env.production  # Update all production values

# 4. Deploy application
./scripts/deploy.sh

# 5. Setup SSL certificate
sudo certbot --nginx -d thefocuspad.com -d www.thefocuspad.com
```

### Production Commands

```bash
# Deploy/update application
./scripts/deploy.sh

# Start/stop services
./scripts/start.sh
./scripts/stop.sh

# Monitor application
docker-compose -f docker-compose.prod.yml --env-file .env.production logs -f
curl https://thefocuspad.com/health
```

---

## ⚙️ Environment Configuration

### Local Development (.env.local)

```bash
# Flask Configuration
FLASK_ENV=development
FLASK_DEBUG=1
SECRET_KEY=dev-secret-key-change-in-production

# Database (Development defaults)
DB_PASSWORD=focuspad_dev_password

# Google OAuth (Configure for localhost:5000)
GOOGLE_CLIENT_ID=your-dev-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-dev-client-secret

# OpenAI API (Optional)
OPENAI_API_KEY=sk-your-openai-api-key-here

# Development features
LOG_LEVEL=DEBUG
BASE_URL=http://localhost:5000
```

### Production (.env.production)

```bash
# Flask Configuration
FLASK_ENV=production
FLASK_DEBUG=0
SECRET_KEY=your-super-secret-production-key

# Database (Use strong password)
DB_PASSWORD=your-strong-database-password

# Google OAuth (Configure for your domain)
GOOGLE_CLIENT_ID=your-prod-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-prod-client-secret

# Production settings
BASE_URL=https://thefocuspad.com
LOG_LEVEL=INFO

# Security (Production hardened)
SECURE_SSL_REDIRECT=True
SESSION_COOKIE_SECURE=True
```

---

## 🔧 Google OAuth Setup

### 1. Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing
3. Enable Google+ API and People API

### 2. Create OAuth Credentials

1. Go to Credentials → Create Credentials → OAuth 2.0 Client ID
2. Configure application type: **Web application**

### 3. Configure Redirect URIs

**For Local Development:**
- Authorized JavaScript origins: `http://localhost:5000`
- Authorized redirect URIs: `http://localhost:5000/auth/callback/google`

**For Production:**
- Authorized JavaScript origins: `https://thefocuspad.com`
- Authorized redirect URIs: `https://thefocuspad.com/auth/callback/google`

---

## 🏗️ Architecture Overview

### Local Development Stack
```
┌─────────────────────────────────────────┐
│           Development Tools            │
│  ┌─────────────┐  ┌─────────────────┐  │
│  │   PgAdmin   │  │   Hot Reload    │  │
│  │ localhost:  │  │   Live Code     │  │
│  │    8080     │  │   Changes       │  │
│  └─────────────┘  └─────────────────┘  │
└─────────────────────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│        Flask Application (Debug)       │
│          localhost:5000                │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│     PostgreSQL + Redis (Development)   │
│    localhost:5432 + localhost:6379    │
└─────────────────────────────────────────┘
```

### Production Stack
```
┌─────────────────────────────────────────┐
│            Nginx (SSL/TLS)             │
│         thefocuspad.com:443            │
└─────────────┬───────────────────────────┘
              ↓ Reverse Proxy
┌─────────────────────────────────────────┐
│       Gunicorn + Flask (Prod)          │
│          localhost:8080                │
└─────────────┬───────────────────────────┘
              ↓
┌─────────────────────────────────────────┐
│    PostgreSQL + Redis (Optimized)      │
│      Internal Docker Network           │
└─────────────────────────────────────────┘
```

---

## 🔐 Security Features

### Data Protection
- **AES-256 Encryption**: All sensitive data encrypted at rest
- **PBKDF2 Key Derivation**: 100,000 iterations for key strengthening
- **Salt-based Security**: Unique salt per field prevents rainbow attacks
- **Zero Knowledge**: Server cannot decrypt data without user session

### Access Control
- **Google OAuth 2.0**: Secure authentication
- **JWT Tokens**: Stateless session management
- **User Isolation**: Strict data separation
- **Rate Limiting**: API protection

### Infrastructure Security
- **HTTPS/TLS**: End-to-end encryption
- **UFW Firewall**: Only essential ports open
- **Fail2ban**: Intrusion detection
- **Docker Isolation**: Containerized boundaries

---

## 🔍 API Reference

### Authentication Endpoints

```bash
# Google OAuth Login
GET /login/google

# OAuth Callback
GET /auth/callback/google

# Logout
GET /logout
```

### Note Management

```bash
# List all notes
GET /api/notes/
Headers: Authorization: Bearer <JWT_TOKEN>

# Create new note
POST /api/notes/
Headers: Authorization: Bearer <JWT_TOKEN>
Body: {
  "title": "Meeting Notes",
  "description": "Weekly team meeting",
  "content": {"action-items": ["Task 1", "Task 2"]},
  "raw_content": "Raw meeting notes...",
  "attendees": ["John", "Jane"]
}

# Get specific note
GET /api/notes/{id}
Headers: Authorization: Bearer <JWT_TOKEN>

# Update note
PUT /api/notes/{id}
Headers: Authorization: Bearer <JWT_TOKEN>

# Delete note
DELETE /api/notes/{id}
Headers: Authorization: Bearer <JWT_TOKEN>

# Search notes
GET /api/notes/search?q=query&include_archived=false
Headers: Authorization: Bearer <JWT_TOKEN>

# Health Check
GET /health
```

### AI-Powered Features

```bash
# AI Title Suggestion
POST /api/notes/{id}/suggest-title
Headers: Authorization: Bearer <JWT_TOKEN>

# AI Content Recategorization
POST /api/notes/{id}/recategorize
Headers: Authorization: Bearer <JWT_TOKEN>
```

---

## 🔬 Advanced Topics

### Encryption Implementation

FocusPad implements enterprise-grade server-side encryption to protect all sensitive user data at rest.

#### 🛡️ Encryption Architecture

**Core Components:**

1. **Encryption Service** (`app/utils/encryption_service.py`)
   - AES-256 encryption using Fernet (symmetric encryption)
   - PBKDF2 key derivation with 100,000 iterations
   - Salt-based per-field encryption
   - Master key management from environment

2. **Database Schema** - Encrypted fields for every sensitive data point:
   ```sql
   -- For each sensitive field (title, content, description, etc.)
   field_encrypted     TEXT,     -- Encrypted data
   field_salt         VARCHAR(32),  -- Unique salt
   field_is_encrypted BOOLEAN DEFAULT FALSE  -- Encryption status
   ```

3. **Model Integration** (`app/models/note.py`)
   - Transparent encryption/decryption methods
   - User-specific key derivation
   - Automatic field handling

#### Encryption Process

```python
# 1. User-specific key derivation
user_key = PBKDF2HMAC(
    algorithm=hashes.SHA256(),
    length=32,
    salt=user_salt,
    iterations=100000
)

# 2. Field-level encryption with unique salts
for each sensitive_field:
    unique_salt = os.urandom(16)
    field_key = derive_key(user_key, unique_salt)
    encrypted_data = Fernet(field_key).encrypt(field_data)
```

#### Encrypted Fields

All sensitive note data is encrypted:
- **Title**: Note titles and headings
- **Content**: Structured note content by category
- **Raw Content**: Original unprocessed content
- **Description**: Note descriptions and summaries
- **Attendees**: Meeting attendee lists

#### Key Management

```bash
# Environment configuration
FOCUSPAD_MASTER_KEY=base64-encoded-master-key

# Key derivation hierarchy:
Master Key → User Salt → User Key → Field Salt → Field Key
```

#### 🔐 Security Features

- **Zero Knowledge**: Server cannot decrypt data without user session
- **Salt-based Encryption**: Unique salt per field prevents rainbow table attacks
- **Key Derivation**: PBKDF2 with 100,000 iterations for key strengthening
- **Transparent Operation**: No changes required to application workflow
- **Migration Safe**: Handles mixed encrypted/unencrypted data during transition

#### 🛡️ Compliance & Standards

- **AES-256**: NIST-approved encryption standard
- **PBKDF2**: RFC 2898 key derivation standard
- **Fernet**: Authenticated encryption with built-in integrity
- **Salt Generation**: Cryptographically secure random salts

### Search Functionality

FocusPad provides powerful search capabilities that work seamlessly with encrypted data.

#### ✨ Search Features

**🎯 Full-Text Search**
- **Encrypted Data Support**: Searches through encrypted content server-side
- **Multi-Field Search**: Searches across title, content, description, attendees
- **Case-Insensitive**: Flexible matching regardless of case
- **Real-Time Results**: 300ms debounced search for instant feedback
- **Minimum Length**: 2 characters minimum to optimize performance

**🔍 Smart Results**
- **Highlighted Matches**: Search terms highlighted with `<mark>` tags
- **Context Snippets**: Surrounding text for better context
- **Field Indicators**: Shows which fields contain matches
- **Category Information**: Displays content category for matches
- **Relevance Ranking**: Sorted by match count and recency

#### 🔧 Search API

**Endpoint: `GET /api/notes/search`**

**Parameters:**
```bash
# Required
q=search_term          # Minimum 2 characters

# Optional  
include_archived=true  # Include archived notes (default: false)
```

**Response Format:**
```json
{
  "query": "meeting notes",
  "total_results": 15,
  "search_time_ms": 45,
  "results": [
    {
      "note": {
        "id": 123,
        "title": "Weekly Team Meeting",
        "description": "Project status meeting",
        "created_at": "2024-01-15T10:30:00Z",
        "updated_at": "2024-01-15T11:00:00Z",
        "is_archived": false
      },
      "matches": {
        "title": {
          "found": true,
          "highlighted": "Weekly Team <mark>Meeting</mark>",
          "snippet": "Weekly Team Meeting - Project Updates"
        },
        "content": {
          "found": true,
          "highlighted": "Discussed project <mark>notes</mark> and timeline",
          "snippet": "...project notes and timeline for Q1 delivery...",
          "categories": ["action-items", "decisions"]
        },
        "description": {
          "found": false
        }
      },
      "match_count": 3,
      "relevance_score": 0.95
    }
  ]
}
```

#### 🛠️ Search Implementation

**Backend Processing:**

```python
def search_notes(user_id, query, include_archived=False):
    # 1. Get user's notes
    notes = Note.query.filter_by(user_id=user_id)
    
    if not include_archived:
        notes = notes.filter_by(is_archived=False)
    
    results = []
    for note in notes:
        # 2. Decrypt note data for searching
        note.decrypt_sensitive_data(user_id)
        
        # 3. Search across all fields
        matches = search_note_fields(note, query)
        
        if matches['found']:
            # 4. Calculate relevance and prepare response
            result = prepare_search_result(note, matches, query)
            results.append(result)
    
    # 5. Sort by relevance and return
    return sorted(results, key=lambda x: x['relevance_score'], reverse=True)
```

**Search Algorithm:**

1. **Field Extraction**: Decrypt and extract searchable text
2. **Pattern Matching**: Case-insensitive substring search
3. **Context Generation**: Extract surrounding text for snippets
4. **Highlighting**: Wrap matches in `<mark>` tags
5. **Relevance Scoring**: Based on match count, position, and recency

**Performance Optimizations:**

- **Lazy Decryption**: Only decrypt when searching
- **Debounced Requests**: Prevents excessive API calls
- **Result Caching**: Cache recent searches (session-based)
- **Pagination**: Limit results for large datasets
- **Index Optimization**: Database indices on searchable fields

#### 🔐 Security Considerations

- **Server-Side Decryption**: Encrypted data never leaves server unencrypted
- **Session-Based**: Search only works for authenticated users
- **No Search Logging**: Search queries are not persisted
- **Rate Limiting**: Prevents search-based attacks

### Database Schema

#### Core Tables

```sql
-- Users table
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    google_id VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) NOT NULL,
    name VARCHAR(255) NOT NULL,
    picture TEXT,
    verified_email BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Notes table (with encryption fields)
CREATE TABLE notes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    
    -- Core fields
    title VARCHAR(255),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_archived BOOLEAN DEFAULT FALSE,
    
    -- Encrypted title
    title_encrypted TEXT,
    title_salt VARCHAR(32),
    title_is_encrypted BOOLEAN DEFAULT FALSE,
    
    -- Encrypted content
    content_encrypted TEXT,
    content_salt VARCHAR(32),
    content_is_encrypted BOOLEAN DEFAULT FALSE,
    
    -- Encrypted raw content
    raw_content_encrypted TEXT,
    raw_content_salt VARCHAR(32),
    raw_content_is_encrypted BOOLEAN DEFAULT FALSE,
    
    -- Encrypted description
    description_encrypted TEXT,
    description_salt VARCHAR(32),
    description_is_encrypted BOOLEAN DEFAULT FALSE,
    
    -- Encrypted attendees
    attendees_encrypted TEXT,
    attendees_salt VARCHAR(32),
    attendees_is_encrypted BOOLEAN DEFAULT FALSE
);

-- Templates table
CREATE TABLE templates (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id),
    name VARCHAR(255) NOT NULL,
    structure JSONB NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Content table (categorized note content)
CREATE TABLE contents (
    id SERIAL PRIMARY KEY,
    note_id INTEGER REFERENCES notes(id) ON DELETE CASCADE,
    category VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

#### Data Flow

**Note Creation Flow**
```
User Input → API Validation → Encryption → Database Storage
     ↓              ↓              ↓             ↓
   JSON Data    JWT Auth     AES-256 Encrypt   PostgreSQL
   + Content    + User ID    + Unique Salt     + Indexes
```

**Search Flow**  
```
Search Query → Authentication → Decryption → Search → Encryption → Response
      ↓              ↓              ↓          ↓         ↓          ↓
   User Input     JWT Token      AES Decrypt   Pattern   Re-encrypt  JSON
   + Filters      + Session      + User Key    Match     + Highlight Results
```

---

## 🚨 Troubleshooting

### Local Development Issues

```bash
# Reset environment
docker-compose -f docker-compose.local.yml down -v
docker system prune -f
./scripts/start-local.sh

# Check database
docker-compose -f docker-compose.local.yml exec db psql -U focuspad_user focuspad

# View logs
docker-compose -f docker-compose.local.yml logs -f web
```

### Production Issues

```bash
# Check status
./scripts/start.sh
curl -v https://thefocuspad.com/health

# View logs
docker-compose -f docker-compose.prod.yml --env-file .env.production logs

# Restart
./scripts/stop.sh && ./scripts/deploy.sh
```

### Encryption Problems

```bash
# Verify encryption setup
docker-compose -f docker-compose.local.yml exec web python3 scripts/setup_encryption.py --verify-only

# Check encryption status
docker-compose -f docker-compose.local.yml exec web python3 scripts/encrypt_existing_data.py --status
```

### Common Issues

1. **Port Conflicts**: Ensure ports 5000, 5432, 6379, 8080 are available
2. **Google OAuth**: Verify redirect URIs in Google Cloud Console
3. **Environment Files**: Check .env.local or .env.production configuration
4. **Docker Resources**: Ensure sufficient memory/disk space
5. **Encryption Issues**: Verify FOCUSPAD_MASTER_KEY is properly configured

---

## 📊 Features Comparison

| Feature | Local Development | Production |
|---------|------------------|------------|
| **Server** | Flask dev server | Gunicorn WSGI |
| **Debug** | Enabled | Disabled |
| **Hot Reload** | Yes | No |
| **Database Admin** | PgAdmin included | External tools |
| **SSL** | No | Yes (Let's Encrypt) |
| **Resource Limits** | None | Memory/CPU limits |
| **Health Checks** | Basic | Comprehensive |
| **Logging** | Console | Files + Console |
| **User** | Root | Non-root (security) |

---

## 🛠️ Development Guide

### Running Tests

```bash
# Local environment
docker-compose -f docker-compose.local.yml exec web python -m pytest tests/

# With coverage
docker-compose -f docker-compose.local.yml exec web python -m pytest tests/ --cov=app

# Run specific test file
docker-compose -f docker-compose.local.yml exec web python -m pytest tests/test_encryption.py -v
```

### Database Migrations

```bash
# Setup encryption (first time)
docker-compose -f docker-compose.local.yml exec web python3 scripts/setup_encryption.py

# Add new migrations
docker-compose -f docker-compose.local.yml exec web python3 scripts/add_encryption_fields.py

# Encrypt existing data
docker-compose -f docker-compose.local.yml exec web python3 scripts/encrypt_existing_data.py
```

### Accessing Services

```bash
# Web application shell
docker-compose -f docker-compose.local.yml exec web bash

# Database shell
docker-compose -f docker-compose.local.yml exec db psql -U focuspad_user focuspad

# Redis CLI
docker-compose -f docker-compose.local.yml exec redis redis-cli

# View specific logs
docker-compose -f docker-compose.local.yml logs web
docker-compose -f docker-compose.local.yml logs db
```

---

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Set up local development environment (`./scripts/start-local.sh`)
4. Make your changes and test thoroughly
5. Run tests (`docker-compose -f docker-compose.local.yml exec web python -m pytest`)
6. Commit your changes (`git commit -m 'Add amazing feature'`)
7. Push to the branch (`git push origin feature/amazing-feature`)
8. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

**Ready to build secure, intelligent notes! 🎉**

*Built with ❤️ for developers who value security and performance* 

## 🚀 Admin Tools

### Query to get the user stats
```
docker-compose -f docker-compose.prod.yml exec web python3 -c "
import os, sys
sys.path.insert(0, '/app')
from app import create_app, db
from app.models.user import User
from app.models.note import Note
from datetime import datetime, timedelta

os.environ['FLASK_ENV'] = 'production'
app = create_app('production')

with app.app_context():
    total_users = User.query.count()
    seven_days_ago = datetime.utcnow() - timedelta(days=7)
    recent_users = User.query.filter(User.created_at >= seven_days_ago).count()
    total_notes = Note.query.count()
    
    print('=' * 50)
    print('📊 FOCUSPAD DATA STATISTICS (Production)')
    print('=' * 50)
    print(f'👥 Total number of users: {total_users}')
    print(f'📅 Users created in last 7 days: {recent_users}')
    print(f'📝 Total number of notes created: {total_notes}')
    print('=' * 50)
"
```