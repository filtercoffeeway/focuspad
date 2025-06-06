"""
Note model for FocusPad API.
"""

from datetime import datetime
from app import db
import json
import logging

logger = logging.getLogger(__name__)

class Note(db.Model):
    """Note model for user notes."""
    
    __tablename__ = 'notes'
    
    id = db.Column(db.Integer, primary_key=True)
    title = db.Column(db.String(200), nullable=False)
    description = db.Column(db.Text, nullable=True)
    content = db.Column(db.Text, nullable=True)  # JSON string of categorized content (legacy)
    raw_content = db.Column(db.Text, nullable=True)  # Original uncategorized content
    markdown_content = db.Column(db.Text, nullable=True)  # Main markdown content
    attendees = db.Column(db.Text, nullable=True)  # Meeting attendees
    template_id = db.Column(db.Integer, db.ForeignKey('templates.id'), nullable=False)
    user_id = db.Column(db.Integer, db.ForeignKey('users.id'), nullable=False)
    is_archived = db.Column(db.Boolean, default=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    updated_at = db.Column(db.DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    # Add these fields after the existing fields in the Note class
    title_encrypted = db.Column(db.Text, nullable=True)
    title_salt = db.Column(db.String(255), nullable=True) 
    title_is_encrypted = db.Column(db.Boolean, default=False)

    content_encrypted = db.Column(db.Text, nullable=True)
    content_salt = db.Column(db.String(255), nullable=True)
    content_is_encrypted = db.Column(db.Boolean, default=False)

    # Encryption fields for markdown_content
    markdown_content_encrypted = db.Column(db.Text, nullable=True)
    markdown_content_salt = db.Column(db.String(255), nullable=True)
    markdown_content_is_encrypted = db.Column(db.Boolean, default=False)

    raw_content_encrypted = db.Column(db.Text, nullable=True)
    raw_content_salt = db.Column(db.String(255), nullable=True)
    raw_content_is_encrypted = db.Column(db.Boolean, default=False)

    attendees_encrypted = db.Column(db.Text, nullable=True)
    attendees_salt = db.Column(db.String(255), nullable=True)
    attendees_is_encrypted = db.Column(db.Boolean, default=False)

    description_encrypted = db.Column(db.Text, nullable=True)
    description_salt = db.Column(db.String(255), nullable=True)
    description_is_encrypted = db.Column(db.Boolean, default=False)
    
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
    
    def get_markdown_content(self):
        """Get markdown content."""
        return self.markdown_content or ''
    
    def set_markdown_content(self, markdown_text):
        """Set markdown content."""
        self.markdown_content = markdown_text
        self.updated_at = datetime.utcnow()
    
    def get_categorized_content(self):
        """Get content organized by categories."""
        try:
            # Safely get template categories with fallback
            if self.template:
                template_categories = self.template.get_categories()
            else:
                # Fallback: create default categories if template is missing
                template_categories = [
                    {'name': 'Key Points', 'description': 'Important information and highlights'},
                    {'name': 'Action Items', 'description': 'Tasks and actions to be completed'},
                    {'name': 'Ideas', 'description': 'Creative thoughts and brainstorming'},
                    {'name': 'References', 'description': 'Links, sources, and external references'}
                ]
            
            content_dict = self.get_content()
            
            organized_content = {}
            for category in template_categories:
                category_name = category['name']
                organized_content[category_name] = {
                    'category_info': category,
                    'items': content_dict.get(category_name, [])
                }
            
            return organized_content
        except Exception as e:
            logger.error(f"Error getting categorized content for note {self.id}: {e}")
            # Return basic structure as fallback
            return {
                'Key Points': {'category_info': {'name': 'Key Points', 'description': 'Important information'}, 'items': []},
                'Action Items': {'category_info': {'name': 'Action Items', 'description': 'Tasks to complete'}, 'items': []},
                'Ideas': {'category_info': {'name': 'Ideas', 'description': 'Creative thoughts'}, 'items': []},
                'References': {'category_info': {'name': 'References', 'description': 'Links and sources'}, 'items': []}
            }
    
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
        # Safely get template name with fallback
        try:
            template_name = self.template.name if self.template else 'Default Template'
        except Exception as e:
            logger.error(f"Error accessing template for note {self.id}: {e}")
            template_name = 'Default Template'
        
        result = {
            'id': self.id,
            'title': self.title,
            'description': self.description,
            'attendees': self.attendees,
            'template_id': self.template_id,
            'template_name': template_name,
            'user_id': self.user_id,
            'is_archived': self.is_archived,
            'created_at': self.created_at.isoformat() + 'Z' if self.created_at else None,
            'updated_at': self.updated_at.isoformat() + 'Z' if self.updated_at else None
        }
        
        if include_content:
            try:
                result['content'] = self.get_categorized_content()
                result['raw_content'] = self.raw_content
                result['markdown_content'] = self.get_markdown_content()
            except Exception as e:
                logger.error(f"Error getting content for note {self.id}: {e}")
                # Provide safe fallbacks
                result['content'] = {}
                result['raw_content'] = self.raw_content or ''
                result['markdown_content'] = self.markdown_content or ''
        else:
            # Even when not including full content, provide content fields for sidebar title generation
            try:
                result['preview'] = self.get_preview_text()
                # Include minimal content for sidebar title generation
                result['markdown_content'] = self.get_markdown_content()
                result['raw_content'] = self.raw_content or ''
                # Don't include the full categorized content structure to keep response lightweight
            except Exception as e:
                logger.error(f"Error getting preview for note {self.id}: {e}")
                result['preview'] = 'Preview unavailable'
                result['markdown_content'] = ''
                result['raw_content'] = ''
        
        return result
    
    def get_preview_text(self, max_length=100):
        """Get a preview text for the note."""
        # First try markdown_content as it's the primary content
        if self.markdown_content and self.markdown_content.strip():
            # Remove markdown formatting for preview
            import re
            text = re.sub(r'#+ ', '', self.markdown_content)  # Remove headers
            text = re.sub(r'\*\*([^*]+)\*\*', r'\1', text)  # Remove bold
            text = re.sub(r'\*([^*]+)\*', r'\1', text)  # Remove italic
            text = re.sub(r'`([^`]+)`', r'\1', text)  # Remove code
            text = re.sub(r'- ', '', text)  # Remove bullet points
            text = text.strip()
            if text:
                return text[:max_length] + ('...' if len(text) > max_length else '')
        
        # Fallback to raw_content
        if self.raw_content and self.raw_content.strip():
            text = self.raw_content.strip()
            return text[:max_length] + ('...' if len(text) > max_length else '')
        
        # Last resort: try categorized content
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
            raw_content='',
            markdown_content=''
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

    def encrypt_sensitive_data(self, user_id: int):
        """Encrypt sensitive fields in this note."""
        from app.utils.encryption_service import encryption_service
        
        fields_to_encrypt = {
            'title': self.title,
            'content': self.content,
            'raw_content': self.raw_content,
            'markdown_content': self.markdown_content,
            'attendees': self.attendees,
            'description': self.description
        }
        
        for field, value in fields_to_encrypt.items():
            if value:
                if isinstance(value, (dict, list)):
                    import json
                    value = json.dumps(value)
                
                result = encryption_service.encrypt_text(value, user_id)
                setattr(self, f'{field}_encrypted', result['encrypted_data'])
                setattr(self, f'{field}_salt', result['salt'])
                setattr(self, f'{field}_is_encrypted', result['is_encrypted'])

    def decrypt_sensitive_data(self, user_id: int):
        """Decrypt sensitive fields in this note."""
        from app.utils.encryption_service import encryption_service
        
        fields_to_decrypt = ['title', 'content', 'raw_content', 'markdown_content', 'attendees', 'description']
        
        for field in fields_to_decrypt:
            encrypted_field = getattr(self, f'{field}_encrypted', None)
            salt_field = getattr(self, f'{field}_salt', None)
            is_encrypted = getattr(self, f'{field}_is_encrypted', False)
            
            if encrypted_field and salt_field and is_encrypted:
                try:
                    decrypted = encryption_service.decrypt_text(encrypted_field, salt_field, user_id)
                    setattr(self, field, decrypted)
                except Exception as e:
                    logger.error(f"Failed to decrypt {field}: {e}")

    def to_dict_decrypted(self, user_id: int, include_content=True):
        """Convert note to dict with decrypted data."""
        self.decrypt_sensitive_data(user_id)
        return self.to_dict(include_content=include_content)

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