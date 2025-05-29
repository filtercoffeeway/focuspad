"""
Routes package for FocusPad API.
"""

from .auth import auth_bp
from .main import main_bp
from .notes import notes_bp
from .templates import templates_bp

def register_blueprints(app):
    """Register all blueprints with the Flask app."""
    app.register_blueprint(auth_bp, url_prefix='/api/auth')
    app.register_blueprint(main_bp)
    app.register_blueprint(notes_bp, url_prefix='/api/notes')
    app.register_blueprint(templates_bp, url_prefix='/api/templates')

__all__ = ['auth_bp', 'main_bp', 'notes_bp', 'templates_bp', 'register_blueprints'] 