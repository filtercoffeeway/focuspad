"""
Routes package for FocusPad API.
"""

from .auth import auth_bp
from .main import main_bp

def register_blueprints(app):
    """Register all blueprints with the Flask app."""
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(main_bp)

__all__ = ['auth_bp', 'main_bp', 'register_blueprints'] 