"""
Flask application factory for FocusPad API.
"""

import os
from flask import Flask, jsonify
from flask_cors import CORS
from flask_sqlalchemy import SQLAlchemy
from flask_migrate import Migrate
from flask_jwt_extended import JWTManager
from authlib.integrations.flask_client import OAuth

# Initialize extensions
db = SQLAlchemy()
migrate = Migrate()
jwt = JWTManager()
cors = CORS()
oauth = OAuth()

def create_app(config_name=None):
    """
    Application factory pattern to create Flask app.
    
    Args:
        config_name (str): Configuration environment name
        
    Returns:
        Flask: Configured Flask application
    """
    app = Flask(__name__)
    
    # Load configuration
    from app.config import get_config
    config_class = get_config(config_name)
    app.config.from_object(config_class)
    
    # Initialize configuration
    config_class.init_app(app)
    
    # Initialize extensions with app
    db.init_app(app)
    migrate.init_app(app, db)
    jwt.init_app(app)
    cors.init_app(app)
    oauth.init_app(app)
    
    # Import models to ensure they are registered with SQLAlchemy
    from app.models import User, Template, Note, Content
    
    # Initialize OAuth providers and error handlers
    from app.utils import init_oauth_providers, register_error_handlers
    init_oauth_providers(app, oauth)
    register_error_handlers(app)
    
    # Register blueprints
    from app.routes import register_blueprints
    register_blueprints(app)
    
    # Health check endpoint
    @app.route('/health')
    def health_check():
        """Health check endpoint for load balancers and monitoring."""
        try:
            # Test database connection
            db.session.execute('SELECT 1')
            return jsonify({
                'status': 'healthy',
                'service': 'focuspad',
                'database': 'connected',
                'version': '1.0.0'
            }), 200
        except Exception as e:
            return jsonify({
                'status': 'unhealthy',
                'service': 'focuspad',
                'database': 'disconnected',
                'error': str(e)
            }), 503
    
    return app 