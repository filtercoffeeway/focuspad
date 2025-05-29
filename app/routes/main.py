"""
Main routes for FocusPad API utility endpoints.
"""

from flask import Blueprint, jsonify, redirect, url_for, render_template, session
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
    """Redirect to the login page."""
    return redirect(url_for('auth.login_page'))

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
    """API documentation endpoint."""
    return jsonify({
        'message': 'Welcome to FocusPad AI-Powered Note Taking API',
        'version': '2.0.0',
        'description': 'AI-powered note taking with automatic content categorization',
        'login_url': '/login',
        'dashboard_url': '/dashboard',
        'endpoints': {
            'health': '/health',
            'login_page': '/login',
            'dashboard': '/dashboard',
            'authentication': {
                'google_login': '/api/auth/login/google',
                'google_callback': '/api/auth/callback/google',
                'google_token': '/api/auth/google-token',
                'refresh': '/api/auth/refresh',
                'me': '/api/auth/me',
                'logout': '/api/auth/logout',
                'login_page': '/api/auth/login'
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