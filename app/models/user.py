"""
User model for FocusPad API.
"""

from datetime import datetime
from app import db

class User(db.Model):
    """User model for storing Google OAuth user information."""
    
    __tablename__ = 'users'
    
    id = db.Column(db.Integer, primary_key=True)
    google_id = db.Column(db.String(100), unique=True, nullable=False, index=True)
    email = db.Column(db.String(120), unique=True, nullable=False, index=True)
    name = db.Column(db.String(100), nullable=False)
    picture = db.Column(db.String(255), nullable=True)
    verified_email = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f'<User {self.email}>'
    
    def to_dict(self):
        """Convert user object to dictionary."""
        return {
            'id': self.id,
            'google_id': self.google_id,
            'email': self.email,
            'name': self.name,
            'picture': self.picture,
            'verified_email': self.verified_email,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
    
    @classmethod
    def find_by_google_id(cls, google_id):
        """Find user by Google ID."""
        return cls.query.filter_by(google_id=google_id).first()
    
    @classmethod
    def find_by_email(cls, email):
        """Find user by email."""
        return cls.query.filter_by(email=email).first()
    
    @classmethod
    def create_or_update_from_google(cls, google_user_info):
        """
        Create a new user or update existing user with Google OAuth info.
        
        Args:
            google_user_info (dict): User information from Google OAuth
            
        Returns:
            User: The created or updated user object
        """
        google_id = google_user_info.get('id') or google_user_info.get('sub')
        email = google_user_info.get('email')
        name = google_user_info.get('name')
        picture = google_user_info.get('picture')
        verified_email = google_user_info.get('verified_email', False) or google_user_info.get('email_verified', False)
        
        # Check if user exists by Google ID
        user = cls.find_by_google_id(google_id)
        
        if user:
            # Update existing user
            user.email = email
            user.name = name
            user.picture = picture
            user.verified_email = verified_email
            user.updated_at = datetime.utcnow()
        else:
            # Check if user exists by email (in case they signed up differently before)
            user = cls.find_by_email(email)
            if user:
                # Update with Google info
                user.google_id = google_id
                user.name = name
                user.picture = picture
                user.verified_email = verified_email
                user.updated_at = datetime.utcnow()
            else:
                # Create new user
                user = cls(
                    google_id=google_id,
                    email=email,
                    name=name,
                    picture=picture,
                    verified_email=verified_email
                )
                db.session.add(user)
        
        db.session.commit()
        return user 