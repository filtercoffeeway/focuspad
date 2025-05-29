"""
Notes routes for FocusPad API.
"""

from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from app import db
from app.models import Note, Template
from app.utils.ai_service import ai_service

# Create notes blueprint
notes_bp = Blueprint('notes', __name__)

@notes_bp.route('/', methods=['GET'])
@jwt_required()
def get_notes():
    """Get all notes for the current user."""
    try:
        current_user_id = get_jwt_identity()
        include_archived = request.args.get('include_archived', 'false').lower() == 'true'
        
        notes = Note.get_user_notes(current_user_id, include_archived=include_archived)
        
        return jsonify({
            'notes': [note.to_dict(include_content=False) for note in notes],
            'count': len(notes)
        })
        
    except Exception as e:
        current_app.logger.error(f"Get notes error: {str(e)}")
        return jsonify({'error': 'Failed to retrieve notes'}), 500

@notes_bp.route('/', methods=['POST'])
@jwt_required()
def create_note():
    """Create a new note."""
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        
        if not data or 'title' not in data:
            return jsonify({'error': 'Title is required'}), 400
        
        title = data['title']
        description = data.get('description')
        attendees = data.get('attendees')
        template_id = data.get('template_id')
        
        # Validate template if specified
        if template_id:
            template = Template.query.get(template_id)
            if not template:
                return jsonify({'error': 'Template not found'}), 404
            
            # Check if user has access to template
            if not template.is_system and template.user_id != current_user_id:
                return jsonify({'error': 'Access denied to template'}), 403
        
        # Create note
        note = Note.create_note(
            title=title,
            user_id=current_user_id,
            template_id=template_id,
            description=description,
            attendees=attendees
        )
        
        return jsonify({
            'message': 'Note created successfully',
            'note': note.to_dict()
        }), 201
        
    except Exception as e:
        current_app.logger.error(f"Create note error: {str(e)}")
        return jsonify({'error': 'Failed to create note'}), 500

@notes_bp.route('/<int:note_id>', methods=['GET'])
@jwt_required()
def get_note(note_id):
    """Get a specific note."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        return jsonify({'note': note.to_dict()})
        
    except Exception as e:
        current_app.logger.error(f"Get note error: {str(e)}")
        return jsonify({'error': 'Failed to retrieve note'}), 500

@notes_bp.route('/<int:note_id>', methods=['PUT'])
@jwt_required()
def update_note(note_id):
    """Update a note."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Update fields
        if 'title' in data:
            note.title = data['title']
        if 'description' in data:
            note.description = data['description']
        if 'attendees' in data:
            note.attendees = data['attendees']
        if 'is_archived' in data:
            note.is_archived = data['is_archived']
        if 'created_at' in data:
            # Allow updating the created_at timestamp
            try:
                from datetime import datetime
                if isinstance(data['created_at'], str):
                    note.created_at = datetime.fromisoformat(data['created_at'].replace('Z', '+00:00'))
                else:
                    note.created_at = data['created_at']
            except (ValueError, TypeError) as e:
                return jsonify({'error': 'Invalid date format'}), 400
        if 'content' in data:
            # Allow updating the content directly
            if isinstance(data['content'], str):
                note.content = data['content']
            else:
                note.set_content(data['content'])
        
        db.session.commit()
        
        return jsonify({
            'message': 'Note updated successfully',
            'note': note.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Update note error: {str(e)}")
        return jsonify({'error': 'Failed to update note'}), 500

@notes_bp.route('/<int:note_id>', methods=['DELETE'])
@jwt_required()
def delete_note(note_id):
    """Delete a note."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        db.session.delete(note)
        db.session.commit()
        
        return jsonify({'message': 'Note deleted successfully'})
        
    except Exception as e:
        current_app.logger.error(f"Delete note error: {str(e)}")
        return jsonify({'error': 'Failed to delete note'}), 500

@notes_bp.route('/<int:note_id>/content', methods=['POST'])
@jwt_required()
def add_content(note_id):
    """Add content to a note with AI categorization."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        data = request.get_json()
        if not data or 'text' not in data:
            return jsonify({'error': 'Text content is required'}), 400
        
        text = data['text'].strip()
        if not text:
            return jsonify({'error': 'Text content cannot be empty'}), 400
        
        # Get manual category if specified
        manual_category = data.get('category')
        
        if manual_category:
            # Manual categorization
            try:
                note.add_content_to_category(manual_category, text)
            except Exception as manual_error:
                current_app.logger.error(f"Manual categorization error: {str(manual_error)}")
                return jsonify({'error': 'Failed to add content to category'}), 500
        else:
            # AI categorization with fallback
            template_categories = note.template.get_categories()
            content_added = False
            
            try:
                categorized_content = ai_service.categorize_content(text, template_categories)
                current_app.logger.info(f"AI categorization result: {categorized_content}")
                
                # Add categorized content to note
                for category_name, content_items in categorized_content.items():
                    if content_items:  # Only process non-empty lists
                        for content_item in content_items:
                            if content_item and content_item.strip():  # Only add non-empty content
                                try:
                                    note.add_content_to_category(category_name, content_item.strip())
                                    content_added = True
                                except Exception as add_error:
                                    current_app.logger.error(f"Error adding to category {category_name}: {str(add_error)}")
                
            except Exception as ai_error:
                current_app.logger.error(f"AI categorization error: {str(ai_error)}")
            
            # Fallback: add to "Key Points" category if nothing was added
            if not content_added:
                current_app.logger.info("Using fallback categorization to Key Points")
                try:
                    note.add_content_to_category('Key Points', text)
                except Exception as fallback_error:
                    current_app.logger.error(f"Fallback categorization error: {str(fallback_error)}")
                    return jsonify({'error': 'Failed to add content even with fallback'}), 500
        
        # Update raw content
        if note.raw_content:
            note.raw_content += "\n\n" + text
        else:
            note.raw_content = text
        
        db.session.commit()
        
        return jsonify({
            'message': 'Content added successfully',
            'note': note.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Add content error: {str(e)}")
        return jsonify({'error': 'Failed to add content'}), 500

@notes_bp.route('/<int:note_id>/content/<category>/remove', methods=['DELETE'])
@jwt_required()
def remove_content(note_id, category):
    """Remove specific content from a category."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        data = request.get_json()
        if not data or 'content_id' not in data:
            return jsonify({'error': 'Content ID is required'}), 400
        
        content_id = data['content_id']
        note.remove_content_from_category(category, content_id)
        
        db.session.commit()
        
        return jsonify({
            'message': 'Content removed successfully',
            'note': note.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Remove content error: {str(e)}")
        return jsonify({'error': 'Failed to remove content'}), 500

@notes_bp.route('/<int:note_id>/suggest-title', methods=['POST'])
@jwt_required()
def suggest_title(note_id):
    """Suggest a title based on note content."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        if not note.raw_content:
            return jsonify({'error': 'No content available for title suggestion'}), 400
        
        try:
            suggested_title = ai_service.suggest_title(note.raw_content)
            
            return jsonify({
                'suggested_title': suggested_title,
                'current_title': note.title
            })
            
        except Exception as ai_error:
            current_app.logger.error(f"AI title suggestion error: {str(ai_error)}")
            return jsonify({'error': 'Failed to generate title suggestion'}), 500
        
    except Exception as e:
        current_app.logger.error(f"Suggest title error: {str(e)}")
        return jsonify({'error': 'Failed to suggest title'}), 500

@notes_bp.route('/<int:note_id>/recategorize', methods=['POST'])
@jwt_required()
def recategorize_note(note_id):
    """Recategorize all content in a note using AI."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        if not note.raw_content:
            return jsonify({'error': 'No content available for recategorization'}), 400
        
        try:
            # Clear existing categorized content
            note.set_content({})
            
            # Recategorize using AI
            template_categories = note.template.get_categories()
            categorized_content = ai_service.categorize_content(note.raw_content, template_categories)
            
            # Add recategorized content
            for category_name, content_items in categorized_content.items():
                for content_item in content_items:
                    if content_item.strip():
                        note.add_content_to_category(category_name, content_item.strip())
            
            db.session.commit()
            
            return jsonify({
                'message': 'Note recategorized successfully',
                'note': note.to_dict()
            })
            
        except Exception as ai_error:
            current_app.logger.error(f"AI recategorization error: {str(ai_error)}")
            return jsonify({'error': 'Failed to recategorize content'}), 500
        
    except Exception as e:
        current_app.logger.error(f"Recategorize note error: {str(e)}")
        return jsonify({'error': 'Failed to recategorize note'}), 500 