"""
Note model for FocusPad API.
"""

from datetime import datetime
from app import db
import json

class Note(db.Model):
    """Note model for user notes."""
    
    __tablename__ = 'notes'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=True)
    content = db.Column(db.Text, nullable=True)  # JSON string of categorized content
    raw_content = db.Column(db.Text, nullable=True)  # Original uncategorized content
    attendees = db.Column(db.Text, nullable=True)  # Meeting attendees
    template_id = db.Column(db.Integer, db.ForeignKey('templates.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    is_archived = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # Relationships
    contents = db.relationship('Content', backref='note', lazy='dynamic', cascade='all, delete-orphan')
    
    def __repr__(self):
        return f'<Note {self.title}>'
    
    def get_content(self):
        """Get content as a dictionary."""
        try:
            return json.loads(self.content) if self.content else {}
        except (json.JSONDecodeError, TypeError):
            return {}
    
    def set_content(self, content_dict):
        """Set content from a dictionary."""
        self.content = json.dumps(content_dict, indent=2)
    
    def get_categorized_content(self):
        """Get content organized by categories."""
        template_categories = self.template.get_categories()
        content_dict = self.get_content()
        
        organized_content = {}
        for category in template_categories:
            category_name = category['name']
            organized_content[category_name] = {
                'category_info': category,
                'items': content_dict.get(category_name, [])
            }
        
        return organized_content
    
    def add_content_to_category(self, category_name, content_text):
        """Add content to a specific category."""
        content_dict = self.get_content()
        
        # Helper function to extract the actual items list from deeply nested structures
        def extract_items_list(data):
            if isinstance(data, list):
                return data
            elif isinstance(data, dict):
                if 'items' in data:
                    return extract_items_list(data['items'])
                else:
                    return []
            else:
                return []
        
        # Ensure the category exists and extract/clean its items
        if category_name not in content_dict:
            content_dict[category_name] = []
        else:
            # Extract the actual items list from whatever structure exists
            items_list = extract_items_list(content_dict[category_name])
            content_dict[category_name] = items_list
        
        # Create the content item
        content_item = {
            'text': content_text,
            'timestamp': datetime.utcnow().isoformat(),
            'id': len(content_dict[category_name]) + 1
        }
        
        # Append to the list (now guaranteed to be a clean list)
        content_dict[category_name].append(content_item)
        self.set_content(content_dict)
        self.updated_at = datetime.utcnow()
    
    def remove_content_from_category(self, category_name, content_id):
        """Remove specific content from a category."""
        content_dict = self.get_content()
        if category_name in content_dict:
            content_dict[category_name] = [
                item for item in content_dict[category_name] 
                if item.get('id') != content_id
            ]
            self.set_content(content_dict)
            self.updated_at = datetime.utcnow()
    
    def to_dict(self, include_content=True):
        """Convert note object to dictionary."""
        result = {
            'id': self.id,
            'title': self.title,
            'description': self.description,
            'attendees': self.attendees,
            'template_id': self.template_id,
            'template_name': self.template.name if self.template else None,
            'user_id': self.user_id,
            'is_archived': self.is_archived,
            'created_at': self.created_at.isoformat() + 'Z' if self.created_at else None,
            'updated_at': self.updated_at.isoformat() + 'Z' if self.updated_at else None
        }
        
        if include_content:
            result['content'] = self.get_categorized_content()
            result['raw_content'] = self.raw_content
        else:
            # Even when not including full content, provide a preview for the sidebar
            result['preview'] = self.get_preview_text()
        
        return result
    
    def get_preview_text(self, max_length=100):
        """Get a preview text for the note."""
        # First try raw_content as it's the most direct representation
        if self.raw_content and self.raw_content.strip():
            text = self.raw_content.strip()
            return text[:max_length] + ('...' if len(text) > max_length else '')
        
        # Try to get content from categorized content
        content_dict = self.get_content()
        for category_name, items in content_dict.items():
            if isinstance(items, list) and items:
                for item in items:
                    if isinstance(item, dict) and 'text' in item:
                        text = item['text'].strip()
                        if text:
                            return text[:max_length] + ('...' if len(text) > max_length else '')
                    elif isinstance(item, str) and item.strip():
                        text = item.strip()
                        return text[:max_length] + ('...' if len(text) > max_length else '')
        
        return 'No content yet...'
    
    @classmethod
    def create_note(cls, title, user_id, template_id=None, description=None, attendees=None):
        """Create a new note with default template if none specified."""
        if not template_id:
            from app.models.template import Template
            default_template = Template.get_default_template()
            if not default_template:
                default_template = Template.create_default_template()
            template_id = default_template.id
        
        note = cls(
            title=title,
            description=description,
            attendees=attendees,
            template_id=template_id,
            user_id=user_id,
            content='{}',
            raw_content=''
        )
        
        db.session.add(note)
        db.session.commit()
        
        return note
    
    @classmethod
    def get_user_notes(cls, user_id, include_archived=False):
        """Get all notes for a user."""
        query = cls.query.filter_by(user_id=user_id)
        if not include_archived:
            query = query.filter_by(is_archived=False)
        return query.order_by(cls.updated_at.desc()).all()


class Content(db.Model):
    """Individual content items within notes."""
    
    __tablename__ = 'contents'
    
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.Text, nullable=False)
    category = db.Column(db.String(100), nullable=False)
    note_id = db.Column(db.Integer, db.ForeignKey('notes.id'), nullable=False)
    order_index = db.Column(db.Integer, default=0)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    def __repr__(self):
        return f'<Content {self.category}: {self.text[:50]}...>'
    
    def to_dict(self):
        """Convert content object to dictionary."""
        return {
            'id': self.id,
            'text': self.text,
            'category': self.category,
            'note_id': self.note_id,
            'order_index': self.order_index,
            'created_at': self.created_at.isoformat() + 'Z' if self.created_at else None,
            'updated_at': self.updated_at.isoformat() + 'Z' if self.updated_at else None
        } 