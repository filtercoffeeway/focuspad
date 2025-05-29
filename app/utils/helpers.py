"""
Helper utilities for FocusPad API.
"""

from flask import jsonify

def init_oauth_providers(app, oauth):
    """Initialize OAuth providers with the app."""
    with app.app_context():
        # Configure Google OAuth
        if app.config.get('GOOGLE_CLIENT_ID') and app.config.get('GOOGLE_CLIENT_SECRET'):
            oauth.register(
                name='google',
                client_id=app.config['GOOGLE_CLIENT_ID'],
                client_secret=app.config['GOOGLE_CLIENT_SECRET'],
                server_metadata_url='https://accounts.google.com/.well-known/openid-configuration',
                client_kwargs={
                    'scope': 'openid email profile'
                }
            )
            print("✅ Google OAuth provider configured")
        else:
            print("⚠️  Google OAuth credentials not found in configuration")

def register_error_handlers(app):
    """Register global error handlers."""
    
    @app.errorhandler(404)
    def not_found(error):
        return jsonify({'error': 'Endpoint not found'}), 404
    
    @app.errorhandler(500)
    def internal_error(error):
        return jsonify({'error': 'Internal server error'}), 500
    
    @app.errorhandler(400)
    def bad_request(error):
        return jsonify({'error': 'Bad request'}), 400

    @app.errorhandler(401)
    def unauthorized(error):
        return jsonify({'error': 'Unauthorized access'}), 401

    @app.errorhandler(403)
    def forbidden(error):
        return jsonify({'error': 'Forbidden access'}), 403 