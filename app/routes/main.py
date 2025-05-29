"""
Main routes for FocusPad API utility endpoints.
"""

import secrets
import requests
from flask import Blueprint, jsonify, redirect, url_for, render_template, session, current_app, request
from flask_jwt_extended import create_access_token, create_refresh_token
from app import oauth
from app.models import User

# Create main blueprint
main_bp = Blueprint('main', __name__)

@main_bp.route('/health')
def health_check():
    """Health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'message': 'FocusPad API is running'
    })

@main_bp.route('/login')
def login():
    """Login page."""
    return render_template('login.html')

@main_bp.route('/logout')
def logout():
    """Web logout that clears session and redirects to login."""
    session.clear()
    return redirect('/login')

@main_bp.route('/login/google')
def google_login():
    """Initiate Google OAuth login flow."""
    if not current_app.config.get('GOOGLE_CLIENT_ID'):
        return jsonify({'error': 'Google OAuth not configured'}), 500
    
    # Generate state parameter for security
    state = secrets.token_urlsafe(32)
    session['oauth_state'] = state
    
    # Build redirect URI
    redirect_uri = request.host_url.rstrip('/') + '/auth/callback/google'
    print(f"Redirect URI: {redirect_uri}")
    
    # Log for debugging
    current_app.logger.info(f"Google OAuth redirect URI: {redirect_uri}")
    
    try:
        # Get Google OAuth client
        google = oauth.create_client('google')
        return google.authorize_redirect(redirect_uri, state=state)
    except Exception as e:
        current_app.logger.error(f"Google OAuth error: {str(e)}")
        return jsonify({
            'error': 'Failed to initiate Google OAuth',
            'details': str(e)
        }), 500

@main_bp.route('/auth/callback/google')
def google_callback():
    """Handle Google OAuth callback."""
    try:
        # Verify state parameter
        state = request.args.get('state')
        if not state or state != session.get('oauth_state'):
            return jsonify({'error': 'Invalid state parameter'}), 400
        
        # Check for error in callback
        if 'error' in request.args:
            error = request.args.get('error')
            error_description = request.args.get('error_description', '')
            return jsonify({
                'error': f'Google OAuth error: {error}',
                'description': error_description
            }), 400
        
        # Get authorization code
        code = request.args.get('code')
        if not code:
            return jsonify({'error': 'Authorization code not provided'}), 400
        
        # Exchange code for tokens
        google = oauth.create_client('google')
        token = google.authorize_access_token()
        
        # Get user info from Google
        user_info = token.get('userinfo')
        if not user_info:
            return jsonify({'error': 'Failed to get user information from Google'}), 400
        
        # Create or update user
        user = User.create_or_update_from_google(user_info)
        
        # Generate JWT tokens
        access_token = create_access_token(identity=user.id)
        refresh_token = create_refresh_token(identity=user.id)
        
        # Clean up session
        session.pop('oauth_state', None)
        
        # Store tokens in session for dashboard use
        session['access_token'] = access_token
        session['refresh_token'] = refresh_token
        session['user_id'] = user.id
        
        # Check if request wants JSON response (API usage)
        if request.headers.get('Accept') == 'application/json' or request.args.get('format') == 'json':
            return jsonify({
                'message': 'Login successful',
                'access_token': access_token,
                'refresh_token': refresh_token,
                'user': user.to_dict()
            })
        
        # Redirect to home page (dashboard) for web users
        return redirect('/')
        
    except Exception as e:
        current_app.logger.error(f"Google OAuth callback error: {str(e)}")
        
        # Return JSON error for API requests
        if request.headers.get('Accept') == 'application/json' or request.args.get('format') == 'json':
            return jsonify({
                'error': 'Authentication failed',
                'details': str(e)
            }), 500
        
        # Return HTML error page for web requests
        return render_template('login.html', error="Authentication failed. Please try again."), 500

@main_bp.route('/dashboard')
def dashboard():
    """Dashboard page for authenticated users."""
    # Check if user is authenticated (has tokens in session)
    if 'access_token' not in session or 'user_id' not in session:
        return redirect('/login')
    
    # Get user information
    user = User.query.get(session['user_id'])
    if not user:
        # Clear invalid session and redirect to login
        session.clear()
        return redirect('/login')
    
    return render_template('dashboard.html', 
                         user=user, 
                         access_token=session['access_token'],
                         refresh_token=session['refresh_token'])

@main_bp.route('/')
def root():
    """Home page - serves dashboard if authenticated, otherwise redirects to login."""
    # Check if user is authenticated (has tokens in session)
    if 'access_token' not in session or 'user_id' not in session:
        return redirect('/login')
    
    # Get user information
    user = User.query.get(session['user_id'])
    if not user:
        # Clear invalid session and redirect to login
        session.clear()
        return redirect('/login')
    
    # Serve the dashboard as the home page
    return render_template('dashboard.html', 
                         user=user, 
                         access_token=session['access_token'],
                         refresh_token=session['refresh_token'])

@main_bp.route('/api')
def api_docs():
    """API documentation endpoint."""
    return jsonify({
        'message': 'Welcome to FocusPad AI-Powered Note Taking API',
        'version': '2.0.0',
        'description': 'AI-powered note taking with automatic content categorization',
        'login_url': '/login',
        'dashboard_url': '/',
        'endpoints': {
            'health': '/health',
            'login_page': '/login',
            'dashboard': '/',
            'authentication': {
                'google_login': '/login/google',
                'google_callback': '/auth/callback/google',
                'google_token': '/api/auth/google-token',
                'refresh': '/api/auth/refresh',
                'me': '/api/auth/me',
                'logout': '/api/auth/logout',
                'login_page': '/login'
            },
            'notes': {
                'list_notes': 'GET /api/notes/',
                'create_note': 'POST /api/notes/',
                'get_note': 'GET /api/notes/{id}',
                'update_note': 'PUT /api/notes/{id}',
                'delete_note': 'DELETE /api/notes/{id}',
                'add_content': 'POST /api/notes/{id}/content',
                'remove_content': 'DELETE /api/notes/{id}/content/{category}/remove',
                'suggest_title': 'POST /api/notes/{id}/suggest-title',
                'recategorize': 'POST /api/notes/{id}/recategorize'
            },
            'templates': {
                'list_templates': 'GET /api/templates/',
                'get_default': 'GET /api/templates/default',
                'create_template': 'POST /api/templates/',
                'get_template': 'GET /api/templates/{id}',
                'update_template': 'PUT /api/templates/{id}',
                'delete_template': 'DELETE /api/templates/{id}',
                'duplicate_template': 'POST /api/templates/{id}/duplicate'
            }
        },
        'features': {
            'ai_categorization': 'Automatic content categorization using OpenAI',
            'custom_templates': 'Create and manage custom note templates',
            'smart_suggestions': 'AI-powered title suggestions',
            'content_management': 'Add, edit, and organize note content',
            'google_oauth': 'Secure authentication with Google OAuth 2.0',
            'dashboard': 'User-friendly dashboard interface'
        }
    }) 