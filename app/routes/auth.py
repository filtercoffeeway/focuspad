"""
Authentication routes for Google OAuth and JWT token management.
"""

import secrets
import requests
from flask import Blueprint, request, jsonify, session, current_app, redirect, render_template
from flask_jwt_extended import (
    create_access_token, create_refresh_token, 
    jwt_required, get_jwt_identity
)
from app import oauth, db
from app.models import User

# Create authentication blueprint
auth_bp = Blueprint('auth', __name__)

@auth_bp.route('/login')
def login_page():
    """Serve the HTML login page."""
    return render_template('login.html')

@auth_bp.route('/login/google')
def google_login():
    """Initiate Google OAuth login flow."""
    if not current_app.config.get('GOOGLE_CLIENT_ID'):
        return jsonify({'error': 'Google OAuth not configured'}), 500
    
    # Generate state parameter for security
    state = secrets.token_urlsafe(32)
    session['oauth_state'] = state
    
    # Build redirect URI
    redirect_uri = request.host_url.rstrip('/') + '/api/auth/callback/google'
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

@auth_bp.route('/callback/google')
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
        
        # Check if request wants JSON response (API usage)
        if request.headers.get('Accept') == 'application/json' or request.args.get('format') == 'json':
            return jsonify({
                'message': 'Login successful',
                'access_token': access_token,
                'refresh_token': refresh_token,
                'user': user.to_dict()
            })
        
        # Otherwise, render success page (web usage)
        return render_template('success.html', 
                             user=user, 
                             access_token=access_token, 
                             refresh_token=refresh_token)
        
    except Exception as e:
        current_app.logger.error(f"Google OAuth callback error: {str(e)}")
        
        # Return JSON error for API requests
        if request.headers.get('Accept') == 'application/json' or request.args.get('format') == 'json':
            return jsonify({
                'error': 'Authentication failed',
                'details': str(e)
            }), 500
        
        # Return HTML error page for web requests
        return render_template('login.html'), 500

@auth_bp.route('/google-token', methods=['POST'])
def google_token_login():
    """
    Login with Google ID token (for mobile apps or single-page applications).
    Expects a JSON payload with 'id_token' field.
    """
    try:
        data = request.get_json()
        if not data or 'id_token' not in data:
            return jsonify({'error': 'ID token is required'}), 400
        
        id_token = data['id_token']
        
        # Verify the ID token with Google
        response = requests.get(
            f'https://oauth2.googleapis.com/tokeninfo?id_token={id_token}',
            timeout=10
        )
        
        if response.status_code != 200:
            return jsonify({'error': 'Invalid ID token'}), 400
        
        user_info = response.json()
        
        # Verify the token is for our app
        if user_info.get('aud') != current_app.config['GOOGLE_CLIENT_ID']:
            return jsonify({'error': 'Invalid token audience'}), 400
        
        # Create or update user
        user = User.create_or_update_from_google(user_info)
        
        # Generate JWT tokens
        access_token = create_access_token(identity=user.id)
        refresh_token = create_refresh_token(identity=user.id)
        
        return jsonify({
            'message': 'Login successful',
            'access_token': access_token,
            'refresh_token': refresh_token,
            'user': user.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Google token login error: {str(e)}")
        return jsonify({
            'error': 'Authentication failed',
            'details': str(e)
        }), 500

@auth_bp.route('/refresh', methods=['POST'])
@jwt_required(refresh=True)
def refresh_token():
    """Refresh access token using refresh token."""
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        # Generate new access token
        new_access_token = create_access_token(identity=current_user_id)
        
        return jsonify({
            'access_token': new_access_token,
            'user': user.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Token refresh error: {str(e)}")
        return jsonify({'error': 'Token refresh failed'}), 500

@auth_bp.route('/me', methods=['GET'])
@jwt_required()
def get_current_user():
    """Get current user information."""
    try:
        current_user_id = get_jwt_identity()
        user = User.query.get(current_user_id)
        
        if not user:
            return jsonify({'error': 'User not found'}), 404
        
        return jsonify({
            'user': user.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Get current user error: {str(e)}")
        return jsonify({'error': 'Failed to get user information'}), 500

@auth_bp.route('/logout', methods=['POST'])
@jwt_required()
def logout():
    """Logout user (client should discard tokens)."""
    return jsonify({'message': 'Logout successful. Please discard your tokens.'})

@auth_bp.route('/debug/config', methods=['GET'])
def debug_config():
    """Debug endpoint to check OAuth configuration."""
    return jsonify({
        'google_client_id_configured': bool(current_app.config.get('GOOGLE_CLIENT_ID')),
        'google_client_secret_configured': bool(current_app.config.get('GOOGLE_CLIENT_SECRET')),
        'client_id_preview': current_app.config.get('GOOGLE_CLIENT_ID', '')[:20] + '...' if current_app.config.get('GOOGLE_CLIENT_ID') else 'Not set',
        'redirect_uri': request.host_url.rstrip('/') + '/api/auth/callback/google',
        'oauth_provider_registered': 'google' in oauth._registry
    }) 