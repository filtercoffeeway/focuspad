"""
Template model for FocusPad API.
"""

from datetime import datetime
from app import db
import json

class Template(db.Model):
    """Template model for note organization templates."""
    
    __tablename__ = 'templates'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    description = db.Column(db.Text, nullable=True)
    categories = db.Column(db.Text, nullable=False)  # JSON string of categories
    is_default = db.Column(db.Boolean, default=False)
    is_system = db.Column(db.Boolean, default=False)  # System templates can't be deleted
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=True)  # Null for system templates
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    notes = db.relationship('Note', backref='template', lazy='dynamic')
    
    def __repr__(self):
        return f'<Template {self.name}>'
    
    def get_categories(self):
        """Get categories as a list."""
        try:
            return json.loads(self.categories)
        except (json.JSONDecodeError, TypeError):
            return []
    
    def set_categories(self, categories_list):
        """Set categories from a list."""
        self.categories = json.dumps(categories_list)
    
    def to_dict(self):
        """Convert template object to dictionary."""
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'categories': self.get_categories(),
            'is_default': self.is_default,
            'is_system': self.is_system,
            'user_id': self.user_id,
            'created_at': self.created_at.isoformat() if self.created_at else None,
            'updated_at': self.updated_at.isoformat() if self.updated_at else None
        }
    
    @classmethod
    def get_default_template(cls):
        """Get the default system template."""
        return cls.query.filter_by(is_default=True, is_system=True).first()
    
    @classmethod
    def create_default_template(cls):
        """Create the default system template."""
        default_categories = [
            {
                'name': 'Key Points',
                'description': 'Important highlights and insights',
                'icon': '💡'
            },
            {
                'name': 'Action Items',
                'description': 'Tasks and follow-up actions',
                'icon': '✅'
            },
            {
                'name': 'References',
                'description': 'Links, sources, and related materials',
                'icon': '🔗'
            },
            {
                'name': 'Ideas',
                'description': 'Creative thoughts and brainstorming',
                'icon': '💭'
            }
        ]
        
        # Check if default template already exists
        existing = cls.get_default_template()
        if existing:
            return existing
        
        template = cls(
            name='Default Note Template',
            description='Standard template with Key Points, Action Items, References, and Ideas',
            is_default=True,
            is_system=True,
            user_id=None
        )
        template.set_categories(default_categories)
        
        db.session.add(template)
        db.session.commit()
        
        return template
    
    @classmethod
    def get_user_templates(cls, user_id):
        """Get all templates accessible to a user (system + user's own)."""
        return cls.query.filter(
            db.or_(
                cls.is_system == True,
                cls.user_id == user_id
            )
        ).order_by(cls.is_system.desc(), cls.name).all() 