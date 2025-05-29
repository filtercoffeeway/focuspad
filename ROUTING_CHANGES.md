# Routing Changes for thefocuspad.com

## Summary of Changes

The routing structure has been updated to provide a cleaner user experience for thefocuspad.com:

## New URL Structure

### **Home Page**
- **URL**: `https://thefocuspad.com/`
- **Function**: Serves the dashboard if user is authenticated, otherwise redirects to login
- **Previous**: Dashboard was at `/dashboard`, root served API documentation

### **Login Page**
- **URL**: `https://thefocuspad.com/login`
- **Function**: Displays the login page with Google OAuth
- **Previous**: Login was at `/api/auth/login`

### **Logout**
- **URL**: `https://thefocuspad.com/logout`
- **Function**: Clears session and redirects to login
- **Previous**: Logout was at `/api/auth/logout/web`

### **Google OAuth**
- **Login URL**: `https://thefocuspad.com/login/google`
- **Callback URL**: `https://thefocuspad.com/auth/callback/google`
- **Previous**: OAuth was under `/api/auth/` prefix

## Technical Changes Made

### 1. **Main Routes (`app/routes/main.py`)**
- Modified root route (`/`) to serve dashboard instead of API docs
- Added direct login route (`/login`) instead of redirect
- Added Google OAuth routes to main blueprint
- Added logout route (`/logout`)
- Moved API documentation to `/api`

### 2. **Template Updates**
- Updated login template (`login.html`) to use `/login/google` instead of `/api/auth/login/google`
- Updated dashboard template (`dashboard.html`) to use `/logout` instead of `/api/auth/logout/web`

### 3. **Environment Configuration**
- Updated `BASE_URL` to use `https://thefocuspad.com` instead of EC2 IP
- Updated setup scripts to use production domain

## API Endpoints (Still Available)

The API endpoints remain available under their original paths for programmatic access:

- **API Documentation**: `https://thefocuspad.com/api`
- **Auth API**: `https://thefocuspad.com/api/auth/*`
- **Notes API**: `https://thefocuspad.com/api/notes/*`
- **Templates API**: `https://thefocuspad.com/api/templates/*`

## User Experience Flow

1. **First Visit**: `thefocuspad.com` → redirects to `/login`
2. **Login**: User clicks "Sign in with Google" → goes to `/login/google`
3. **OAuth Callback**: Google redirects to `/auth/callback/google`
4. **Success**: User redirected to `thefocuspad.com` (dashboard)
5. **Logout**: User clicks logout → goes to `/logout` → redirected to `/login`

## Deployment Notes

- The `/dashboard` route still exists for backward compatibility
- Google OAuth redirect URI should be set to: `https://thefocuspad.com/auth/callback/google`
- All scripts updated to use the new domain name
- SSL/HTTPS should be configured for production use

## Required Google OAuth Configuration

In your Google Cloud Console, update the OAuth 2.0 credentials:

- **Authorized JavaScript origins**: `https://thefocuspad.com`
- **Authorized redirect URIs**: `https://thefocuspad.com/auth/callback/google`

## Files Modified

1. `app/routes/main.py` - Updated routing structure
2. `app/templates/login.html` - Updated OAuth URL
3. `app/templates/dashboard.html` - Updated logout URL
4. `setup-env-micro.sh` - Updated BASE_URL
5. `fix-deployment-issues.sh` - Updated BASE_URL
6. `restart-with-fix.sh` - Updated success message 