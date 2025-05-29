"""
Main routes for FocusPad API utility endpoints.
"""

from flask import Blueprint, jsonify, redirect, url_for

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

@main_bp.route('/')
def root():
    """API documentation endpoint."""
    return jsonify({
        'message': 'Welcome to FocusPad API',
        'version': '1.0.0',
        'login_url': '/login',
        'endpoints': {
            'health': '/health',
            'login_page': '/login',
            'auth': {
                'google_login': '/api/auth/login/google',
                'google_callback': '/api/auth/callback/google',
                'google_token': '/api/auth/google-token',
                'refresh': '/api/auth/refresh',
                'me': '/api/auth/me',
                'logout': '/api/auth/logout',
                'login_page': '/api/auth/login'
            }
        }
    }) 