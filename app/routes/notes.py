"""
Notes routes for FocusPad API.
"""

from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from app import db
from app.models import Note, Template
from app.utils.ai_service import ai_service
from app.utils.encryption_service import encryption_service
import json
import re
from datetime import datetime

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
        
        # Decrypt and return notes (work with fresh copies to avoid session issues)
        decrypted_notes = []
        for note in notes:
            try:
                # Get fresh copy to avoid session conflicts
                fresh_note = Note.query.get(note.id)
                # Decrypt each note before returning
                fresh_note.decrypt_sensitive_data(current_user_id)
                decrypted_notes.append(fresh_note.to_dict(include_content=False))
            except Exception as e:
                current_app.logger.error(f"Failed to decrypt note {note.id}: {e}")
                # Fallback to returning unencrypted data if decryption fails
                decrypted_notes.append(note.to_dict(include_content=False))
        
        return jsonify({
            'notes': decrypted_notes,
            'count': len(decrypted_notes)
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
        
        # Create note (this automatically commits to database)
        note = Note.create_note(
            title=title,
            user_id=current_user_id,
            template_id=template_id,
            description=description,
            attendees=attendees
        )
        
        # Encrypt sensitive data after creation
        try:
            note.encrypt_sensitive_data(current_user_id)
            db.session.commit()
            current_app.logger.info(f"Note {note.id} encrypted and saved for user {current_user_id}")
        except Exception as e:
            current_app.logger.error(f"Failed to encrypt note {note.id}: {e}")
            # Note was already created, encryption failure is not critical
        
        # Get fresh copy of note for response to avoid session issues
        fresh_note = Note.query.get(note.id)
        try:
            fresh_note.decrypt_sensitive_data(current_user_id)
        except Exception as e:
            current_app.logger.error(f"Failed to decrypt note {note.id} for response: {e}")
        
        return jsonify({
            'message': 'Note created successfully',
            'note': fresh_note.to_dict()
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
        
        # Get fresh copy and decrypt sensitive data before returning
        fresh_note = Note.query.get(note_id)
        try:
            fresh_note.decrypt_sensitive_data(current_user_id)
        except Exception as e:
            current_app.logger.error(f"Failed to decrypt note {note_id}: {e}")
            # Continue with potentially encrypted data if decryption fails
        
        return jsonify({'note': fresh_note.to_dict()})
        
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
        
        # Decrypt current data first
        try:
            note.decrypt_sensitive_data(current_user_id)
        except Exception as e:
            current_app.logger.error(f"Failed to decrypt note {note_id} for update: {e}")
        
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
                if isinstance(data['created_at'], str):
                    note.created_at = datetime.fromisoformat(data['created_at'].replace('Z', '+00:00'))
                else:
                    note.created_at = data['created_at']
            except (ValueError, TypeError) as e:
                return jsonify({'error': 'Invalid date format'}), 400
        if 'content' in data:
            # Allow updating the content directly (legacy JSON format)
            if isinstance(data['content'], str):
                note.content = data['content']
            else:
                note.set_content(data['content'])
        if 'markdown_content' in data:
            # Update markdown content (new primary format)
            note.set_markdown_content(data['markdown_content'])
        
        # Encrypt updated data
        try:
            note.encrypt_sensitive_data(current_user_id)
            db.session.commit()
            current_app.logger.info(f"Note {note.id} updated and encrypted for user {current_user_id}")
        except Exception as e:
            current_app.logger.error(f"Failed to encrypt updated note {note.id}: {e}")
            # Save without encryption if it fails
            db.session.commit()
        
        # Decrypt for response
        note.decrypt_sensitive_data(current_user_id)
        
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
        
        # Decrypt note data first
        try:
            note.decrypt_sensitive_data(current_user_id)
        except Exception as e:
            current_app.logger.error(f"Failed to decrypt note {note_id} for content addition: {e}")
        
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
        
        # Encrypt the updated data
        try:
            note.encrypt_sensitive_data(current_user_id)
            db.session.commit()
            current_app.logger.info(f"Note {note.id} content updated and encrypted for user {current_user_id}")
        except Exception as e:
            current_app.logger.error(f"Failed to encrypt updated note {note.id}: {e}")
            # Save without encryption if it fails
            db.session.commit()
        
        # Decrypt for response
        note.decrypt_sensitive_data(current_user_id)
        
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
        
        # Decrypt note data first
        try:
            note.decrypt_sensitive_data(current_user_id)
        except Exception as e:
            current_app.logger.error(f"Failed to decrypt note {note_id} for content removal: {e}")
        
        content_id = data['content_id']
        note.remove_content_from_category(category, content_id)
        
        # Encrypt the updated data
        try:
            note.encrypt_sensitive_data(current_user_id)
            db.session.commit()
            current_app.logger.info(f"Note {note.id} content removed and encrypted for user {current_user_id}")
        except Exception as e:
            current_app.logger.error(f"Failed to encrypt updated note {note.id}: {e}")
            # Save without encryption if it fails
            db.session.commit()
        
        # Decrypt for response
        note.decrypt_sensitive_data(current_user_id)
        
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
        
        # Decrypt note data first
        try:
            note.decrypt_sensitive_data(current_user_id)
        except Exception as e:
            current_app.logger.error(f"Failed to decrypt note {note_id} for title suggestion: {e}")
        
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
        
        # Decrypt note data first
        try:
            note.decrypt_sensitive_data(current_user_id)
        except Exception as e:
            current_app.logger.error(f"Failed to decrypt note {note_id} for recategorization: {e}")
        
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
            
            # Encrypt the updated data
            try:
                note.encrypt_sensitive_data(current_user_id)
                db.session.commit()
                current_app.logger.info(f"Note {note.id} recategorized and encrypted for user {current_user_id}")
            except Exception as e:
                current_app.logger.error(f"Failed to encrypt recategorized note {note.id}: {e}")
                # Save without encryption if it fails
                db.session.commit()
            
            # Decrypt for response
            note.decrypt_sensitive_data(current_user_id)
            
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

@notes_bp.route('/search', methods=['GET'])
@jwt_required()
def search_notes():
    """Search for text across all user notes."""
    try:
        current_user_id = get_jwt_identity()
        query = request.args.get('q', '').strip()
        include_archived = request.args.get('include_archived', 'false').lower() == 'true'
        
        current_app.logger.info(f"Search request - User: {current_user_id}, Query: '{query}', Include archived: {include_archived}")
        
        if not query:
            return jsonify({'error': 'Search query is required'}), 400
        
        if len(query) < 2:
            return jsonify({'error': 'Search query must be at least 2 characters'}), 400
        
        # Get all user notes
        notes = Note.get_user_notes(current_user_id, include_archived=include_archived)
        current_app.logger.info(f"Found {len(notes)} notes for user {current_user_id}")
        
        search_results = []
        query_lower = query.lower()
        
        for note in notes:
            try:
                # Get fresh copy and decrypt for searching
                fresh_note = Note.query.get(note.id)
                if not fresh_note:
                    current_app.logger.warning(f"Could not find note {note.id}")
                    continue
                    
                fresh_note.decrypt_sensitive_data(current_user_id)
                
                # Search in various fields
                matches = []
                
                # Search in title
                if fresh_note.title and query_lower in fresh_note.title.lower():
                    matches.append({
                        'field': 'title',
                        'text': fresh_note.title,
                        'highlight': _highlight_text(fresh_note.title, query)
                    })
                
                # Search in description
                if fresh_note.description and query_lower in fresh_note.description.lower():
                    matches.append({
                        'field': 'description', 
                        'text': fresh_note.description,
                        'highlight': _highlight_text(fresh_note.description, query)
                    })
                
                # Search in raw content
                if fresh_note.raw_content and query_lower in fresh_note.raw_content.lower():
                    matches.append({
                        'field': 'raw_content',
                        'text': fresh_note.raw_content,
                        'highlight': _highlight_text(fresh_note.raw_content, query)
                    })
                
                # Search in markdown content
                if fresh_note.markdown_content and query_lower in fresh_note.markdown_content.lower():
                    matches.append({
                        'field': 'markdown_content',
                        'text': fresh_note.markdown_content,
                        'highlight': _highlight_text(fresh_note.markdown_content, query)
                    })
                
                # Search in categorized content
                content_dict = fresh_note.get_content()
                for category_name, items in content_dict.items():
                    if isinstance(items, list):
                        for item in items:
                            if isinstance(item, dict) and 'text' in item:
                                if query_lower in item['text'].lower():
                                    matches.append({
                                        'field': 'content',
                                        'category': category_name,
                                        'text': item['text'],
                                        'highlight': _highlight_text(item['text'], query),
                                        'item_id': item.get('id'),
                                        'timestamp': item.get('timestamp')
                                    })
                
                # Search in attendees
                if fresh_note.attendees and query_lower in fresh_note.attendees.lower():
                    matches.append({
                        'field': 'attendees',
                        'text': fresh_note.attendees,
                        'highlight': _highlight_text(fresh_note.attendees, query)
                    })
                
                # If any matches found, add to results
                if matches:
                    search_results.append({
                        'note': {
                            'id': fresh_note.id,
                            'title': fresh_note.title,
                            'description': fresh_note.description,
                            'created_at': fresh_note.created_at.isoformat() + 'Z' if fresh_note.created_at else None,
                            'updated_at': fresh_note.updated_at.isoformat() + 'Z' if fresh_note.updated_at else None,
                            'is_archived': fresh_note.is_archived,
                            'template_name': fresh_note.template.name if fresh_note.template else None
                        },
                        'matches': matches,
                        'match_count': len(matches)
                    })
                    
            except Exception as e:
                current_app.logger.error(f"Error searching note {note.id}: {e}")
                continue
        
        # Sort results by relevance (number of matches, then by update date)
        search_results.sort(key=lambda x: (
            -x['match_count'], 
            -(datetime.fromisoformat(x['note']['updated_at'].replace('Z', '+00:00')).timestamp() if x['note']['updated_at'] else 0)
        ))
        
        current_app.logger.info(f"Search completed - {len(search_results)} results found")
        
        return jsonify({
            'query': query,
            'results': search_results,
            'total_results': len(search_results),
            'total_matches': sum(result['match_count'] for result in search_results)
        })
        
    except Exception as e:
        current_app.logger.error(f"Search error: {str(e)}")
        return jsonify({'error': 'Search failed'}), 500

def _highlight_text(text, query, max_length=200):
    """Highlight search query in text and return a snippet."""
    if not text or not query:
        return text[:max_length] if text else ""
    
    # Convert to string if not already
    text = str(text)
    query = str(query)
    
    text_lower = text.lower()
    query_lower = query.lower()
    
    # Find the position of the query
    pos = text_lower.find(query_lower)
    if pos == -1:
        return text[:max_length]
    
    # Calculate snippet boundaries
    start = max(0, pos - 50)
    end = min(len(text), pos + len(query) + 150)
    
    # Extract snippet
    snippet = text[start:end]
    
    # Add ellipsis if needed
    if start > 0:
        snippet = "..." + snippet
    if end < len(text):
        snippet = snippet + "..."
    
    # Highlight the query (case-insensitive)
    try:
        pattern = re.compile(re.escape(query), re.IGNORECASE)
        highlighted = pattern.sub(f'<mark>{query}</mark>', snippet)
        return highlighted
    except Exception as e:
        current_app.logger.error(f"Error highlighting text: {e}")
        return snippet  # Return unhighlighted snippet if highlighting fails

@notes_bp.route('/<int:note_id>/markdown', methods=['PUT'])
@jwt_required()
def update_markdown_content(note_id):
    """Update the markdown content of a note."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        data = request.get_json()
        if not data or 'markdown_content' not in data:
            return jsonify({'error': 'Markdown content is required'}), 400
        
        # Decrypt current data first
        try:
            note.decrypt_sensitive_data(current_user_id)
        except Exception as e:
            current_app.logger.error(f"Failed to decrypt note {note_id} for markdown update: {e}")
        
        # Update markdown content
        note.set_markdown_content(data['markdown_content'])
        
        # Encrypt updated data
        try:
            note.encrypt_sensitive_data(current_user_id)
            db.session.commit()
            current_app.logger.info(f"Note {note.id} markdown updated and encrypted for user {current_user_id}")
        except Exception as e:
            current_app.logger.error(f"Failed to encrypt updated note {note.id}: {e}")
            # Save without encryption if it fails
            db.session.commit()
        
        # Decrypt for response
        note.decrypt_sensitive_data(current_user_id)
        
        return jsonify({
            'message': 'Markdown content updated successfully',
            'note': note.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Update markdown content error: {str(e)}")
        return jsonify({'error': 'Failed to update markdown content'}), 500

@notes_bp.route('/<int:note_id>/ai-summarize', methods=['POST'])
@jwt_required()
def ai_summarize_note(note_id):
    """AI summarize and organize note content."""
    try:
        current_user_id = get_jwt_identity()
        note = Note.query.get(note_id)
        
        if not note:
            return jsonify({'error': 'Note not found'}), 404
        
        if note.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        data = request.get_json()
        if not data or 'content' not in data:
            return jsonify({'error': 'Content is required'}), 400
        
        content = data['content'].strip()
        if not content:
            return jsonify({'error': 'Content cannot be empty'}), 400
        
        # Check if AI service is available
        if not ai_service.is_available():
            return jsonify({'error': 'AI service is not available. Please check your OpenAI API key configuration.'}), 503
        
        current_app.logger.info(f"AI summarizing note {note_id} for user {current_user_id}")
        
        # Create AI prompt for summarization and organization
        prompt = f"""Please analyze and organize the following note content. Create a well-structured markdown document with appropriate headings and sections. 

The content should be organized logically with relevant headings such as:
- Key Points
- Action Items  
- Ideas
- Important Details
- References
- Summary

Use markdown formatting including:
- # for main headings
- ## for subheadings
- ### for smaller sections
- - for bullet points
- **bold** for emphasis
- `code` for technical terms if relevant

Here's the content to organize:

{content}

Please return a well-organized markdown document that makes the content easy to read and understand."""

        try:
            # Call AI service to summarize and organize content
            summarized_content = ai_service.generate_text(prompt)
            
            if not summarized_content:
                return jsonify({'error': 'AI service returned empty response'}), 500
            
            # Decrypt current note data
            try:
                note.decrypt_sensitive_data(current_user_id)
            except Exception as e:
                current_app.logger.error(f"Failed to decrypt note {note_id} for AI summarization: {e}")
            
            # Update the note with AI-generated content
            note.set_markdown_content(summarized_content)
            
            # Encrypt and save
            try:
                note.encrypt_sensitive_data(current_user_id)
                db.session.commit()
                current_app.logger.info(f"Note {note_id} AI-summarized and saved for user {current_user_id}")
            except Exception as e:
                current_app.logger.error(f"Failed to encrypt AI-summarized note {note_id}: {e}")
                # Save without encryption if it fails
                db.session.commit()
            
            # Return the summarized content
            return jsonify({
                'message': 'Note summarized successfully',
                'summarized_content': summarized_content,
                'note': note.to_dict()
            })
            
        except Exception as ai_error:
            current_app.logger.error(f"AI summarization failed for note {note_id}: {str(ai_error)}")
            return jsonify({'error': f'AI summarization failed: {str(ai_error)}'}), 500
        
    except Exception as e:
        current_app.logger.error(f"AI summarize note error: {str(e)}")
        return jsonify({'error': 'Failed to summarize note'}), 500 