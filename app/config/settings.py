"""
Configuration settings for FocusPad API.
"""

import os
from datetime import timedelta
from dotenv import load_dotenv

# Load environment variables from .env file
load_dotenv()

class BaseConfig:
    """Base configuration class."""
    
    # Flask Configuration
    SECRET_KEY = os.environ.get('SECRET_KEY') or 'dev-secret-key-change-in-production'
    
    # Database Configuration - Default to PostgreSQL
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'postgresql://focuspad_user:focuspad_password@localhost:5432/focuspad'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    SQLALCHEMY_ENGINE_OPTIONS = {
        'pool_pre_ping': True,
        'pool_recycle': 300,
    }
    
    # JWT Configuration
    JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY') or 'jwt-secret-key-change-in-production'
    JWT_ACCESS_TOKEN_EXPIRES = timedelta(hours=1)
    JWT_REFRESH_TOKEN_EXPIRES = timedelta(days=30)
    
    # Google OAuth Configuration
    GOOGLE_CLIENT_ID = os.environ.get('GOOGLE_CLIENT_ID')
    GOOGLE_CLIENT_SECRET = os.environ.get('GOOGLE_CLIENT_SECRET')
    
    # CORS Configuration
    CORS_ORIGINS = os.environ.get('CORS_ORIGINS', '*').split(',')
    
    @staticmethod
    def init_app(app):
        """Initialize configuration with app."""
        pass

class DevelopmentConfig(BaseConfig):
    """Development configuration."""
    
    DEBUG = True
    TESTING = False
    
    # Development database fallback to SQLite if PostgreSQL not available
    @classmethod
    def init_app(cls, app):
        BaseConfig.init_app(app)
        
        # Test PostgreSQL connection, fallback to SQLite
        database_url = os.environ.get('DATABASE_URL')
        if not database_url or not database_url.startswith('postgresql'):
            app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///focuspad_dev.db'
            print("⚠️  Using SQLite for development. Set DATABASE_URL for PostgreSQL.")

class TestingConfig(BaseConfig):
    """Testing configuration."""
    
    DEBUG = False
    TESTING = True
    SQLALCHEMY_DATABASE_URI = 'sqlite:///:memory:'
    WTF_CSRF_ENABLED = False

class ProductionConfig(BaseConfig):
    """Production configuration."""
    
    DEBUG = False
    TESTING = False
    
    @classmethod
    def init_app(cls, app):
        """Initialize production configuration."""
        BaseConfig.init_app(app)
        
        # Ensure PostgreSQL in production
        database_url = app.config.get('SQLALCHEMY_DATABASE_URI')
        if not database_url or not database_url.startswith('postgresql'):
            raise ValueError("PostgreSQL database required for production")
        
        # Log to stderr in production
        import logging
        from logging import StreamHandler
        file_handler = StreamHandler()
        file_handler.setLevel(logging.INFO)
        app.logger.addHandler(file_handler)

class DockerConfig(BaseConfig):
    """Docker-specific configuration."""
    
    DEBUG = True
    TESTING = False
    
    # Force PostgreSQL in Docker
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'postgresql://focuspad_user:focuspad_password@db:5432/focuspad'

# Configuration dictionary
config = {
    'development': DevelopmentConfig,
    'testing': TestingConfig,
    'production': ProductionConfig,
    'docker': DockerConfig,
    'default': DevelopmentConfig
}

def get_config(config_name=None):
    """Get configuration class by name."""
    if config_name is None:
        config_name = os.environ.get('FLASK_ENV', 'development')
    
    return config.get(config_name, DevelopmentConfig) 