# FocusPad API 🎯

A modern Flask API with Google OAuth authentication, JWT tokens, and PostgreSQL database running in Docker.

## 🚀 Quick Start with Docker

### Prerequisites

- Docker and Docker Compose installed
- Google OAuth credentials (see [Google OAuth Setup](#google-oauth-setup))

### 1. Clone and Setup

```bash
git clone <your-repo-url>
cd focuspad
```

### 2. Configure Environment Variables

Copy the Docker environment template:

```bash
cp env_docker.txt .env
```

Edit `.env` file and add your Google OAuth credentials:

```bash
# Replace with your actual Google OAuth credentials
GOOGLE_CLIENT_ID=your-google-client-id.apps.googleusercontent.com
GOOGLE_CLIENT_SECRET=your-google-client-secret

# Generate secure keys for production
SECRET_KEY=your-super-secret-key-change-in-production
JWT_SECRET_KEY=your-jwt-secret-key-change-in-production
```

### 3. Start the Application

Start all services (Flask app + PostgreSQL):

```bash
docker-compose up --build
```

Or run in detached mode:

```bash
docker-compose up -d --build
```

### 4. Access the Application

- **API**: http://localhost:5000
- **Login Page**: http://localhost:5000/login
- **Health Check**: http://localhost:5000/health
- **PgAdmin** (optional): http://localhost:8080

### 5. Stop the Application

```bash
docker-compose down
```

To remove volumes (database data):

```bash
docker-compose down -v
```

## 🗄️ Database Management

### Access PostgreSQL Database

```bash
# Connect to PostgreSQL container
docker exec -it focuspad_db psql -U focuspad_user -d focuspad
```

### Run PgAdmin (Database GUI)

Start PgAdmin for database management:

```bash
docker-compose --profile admin up -d pgadmin
```

Access PgAdmin at http://localhost:8080:
- Email: `admin@focuspad.com`
- Password: `admin`

Add server in PgAdmin:
- Host: `db`
- Port: `5432`
- Database: `focuspad`
- Username: `focuspad_user`
- Password: `focuspad_password`

## 🔧 Development Setup

### Local Development (without Docker)

1. **Install PostgreSQL locally** or use Docker for just the database:

```bash
# Start only PostgreSQL
docker-compose up -d db
```

2. **Create virtual environment**:

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

3. **Install dependencies**:

```bash
pip install -r requirements.txt
```

4. **Set environment variables**:

```bash
export DATABASE_URL=postgresql://focuspad_user:focuspad_password@localhost:5432/focuspad
export GOOGLE_CLIENT_ID=your-google-client-id
export GOOGLE_CLIENT_SECRET=your-google-client-secret
```

5. **Run the application**:

```bash
python run.py
```

## 🔐 Google OAuth Setup

### 1. Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google+ API and Google OAuth2 API

### 2. Create OAuth 2.0 Credentials

1. Go to **Credentials** → **Create Credentials** → **OAuth 2.0 Client IDs**
2. Choose **Web application**
3. Add authorized redirect URIs:
   - `http://localhost:5000/api/auth/callback/google`
   - `https://yourdomain.com/api/auth/callback/google` (for production)

### 3. Configure OAuth Consent Screen

1. Go to **OAuth consent screen**
2. Choose **External** user type
3. Fill required fields:
   - App name: FocusPad
   - User support email: your-email@example.com
   - Developer contact: your-email@example.com
4. Add test users during development

## 📡 API Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/login` | Login page (HTML) |
| GET | `/api/auth/login/google` | Initiate Google OAuth |
| GET | `/api/auth/callback/google` | Google OAuth callback |
| POST | `/api/auth/google-token` | Login with Google ID token |
| POST | `/api/auth/refresh` | Refresh access token |
| GET | `/api/auth/me` | Get current user info |
| POST | `/api/auth/logout` | Logout user |

### Utility

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/` | API documentation |

## 🧪 Testing the API

### Using the Web Interface

1. Visit http://localhost:5000/login
2. Click "Continue with Google"
3. Complete OAuth flow
4. Get JWT tokens on success page

### Using Postman/curl

1. **Get tokens via OAuth:**

```bash
curl http://localhost:5000/api/auth/login/google
# Follow redirect to Google, complete OAuth
```

2. **Test API with token:**

```bash
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
     http://localhost:5000/api/auth/me
```

3. **Refresh token:**

```bash
curl -X POST \
     -H "Authorization: Bearer YOUR_REFRESH_TOKEN" \
     http://localhost:5000/api/auth/refresh
```

## 🔍 Troubleshooting

### Common Issues

1. **OAuth Error: "redirect_uri_mismatch"**
   - Check Google Cloud Console redirect URIs
   - Ensure `http://localhost:5000/api/auth/callback/google` is added

2. **Database Connection Error**
   - Ensure PostgreSQL container is running
   - Check `DATABASE_URL` environment variable

3. **Google OAuth not configured**
   - Verify `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` are set
   - Check `.env` file has correct values

### View Logs

```bash
# View all logs
docker-compose logs

# View specific service logs
docker-compose logs web
docker-compose logs db

# Follow logs
docker-compose logs -f web
```

### Debug API Configuration

```bash
curl http://localhost:5000/api/auth/debug/config
```

## 🚢 Production Deployment

### Environment Variables for Production

```bash
# Security
SECRET_KEY=your-strong-secret-key
JWT_SECRET_KEY=your-strong-jwt-secret

# Database
DATABASE_URL=postgresql://user:password@host:port/database

# OAuth
GOOGLE_CLIENT_ID=your-production-client-id
GOOGLE_CLIENT_SECRET=your-production-client-secret

# Server
FLASK_ENV=production
HOST=0.0.0.0
PORT=5000
```

### Production Docker Build

```bash
# Build production image
docker build -t focuspad:latest .

# Run with production config
docker run -d \
  --name focuspad \
  -p 5000:5000 \
  -e FLASK_ENV=production \
  -e DATABASE_URL=postgresql://... \
  -e GOOGLE_CLIENT_ID=... \
  -e GOOGLE_CLIENT_SECRET=... \
  focuspad:latest
```

## 📁 Project Structure

```
focuspad/
├── app/
│   ├── __init__.py          # App factory
│   ├── auth.py              # Authentication blueprint
│   ├── models.py            # Database models
│   └── templates/           # HTML templates
│       ├── login.html       # Login page
│       └── success.html     # Success page
├── config.py                # Configuration classes
├── run.py                   # Local entry point
├── run_docker.py           # Docker entry point
├── requirements.txt        # Python dependencies
├── Dockerfile              # Docker build instructions
├── docker-compose.yml      # Multi-container setup
├── init.sql               # PostgreSQL initialization
└── README.md              # This file
```

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License.

---

**Happy coding! 🎯** 