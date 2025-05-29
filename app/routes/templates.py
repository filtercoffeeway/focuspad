"""
Templates routes for FocusPad API.
"""

from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import jwt_required, get_jwt_identity
from app import db
from app.models import Template

# Create templates blueprint
templates_bp = Blueprint('templates', __name__)

@templates_bp.route('/', methods=['GET'])
@jwt_required()
def get_templates():
    """Get all templates accessible to the current user."""
    try:
        current_user_id = get_jwt_identity()
        templates = Template.get_user_templates(current_user_id)
        
        return jsonify({
            'templates': [template.to_dict() for template in templates],
            'count': len(templates)
        })
        
    except Exception as e:
        current_app.logger.error(f"Get templates error: {str(e)}")
        return jsonify({'error': 'Failed to retrieve templates'}), 500

@templates_bp.route('/default', methods=['GET'])
def get_default_template():
    """Get the default system template."""
    try:
        default_template = Template.get_default_template()
        
        if not default_template:
            # Create default template if it doesn't exist
            default_template = Template.create_default_template()
        
        return jsonify({
            'template': default_template.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Get default template error: {str(e)}")
        return jsonify({'error': 'Failed to retrieve default template'}), 500

@templates_bp.route('/', methods=['POST'])
@jwt_required()
def create_template():
    """Create a new custom template."""
    try:
        current_user_id = get_jwt_identity()
        data = request.get_json()
        
        if not data or 'name' not in data or 'categories' not in data:
            return jsonify({'error': 'Name and categories are required'}), 400
        
        name = data['name']
        description = data.get('description')
        categories = data['categories']
        
        # Validate categories format
        if not isinstance(categories, list) or len(categories) == 0:
            return jsonify({'error': 'Categories must be a non-empty list'}), 400
        
        for category in categories:
            if not isinstance(category, dict) or 'name' not in category:
                return jsonify({'error': 'Each category must have a name'}), 400
        
        # Check if template name already exists for this user
        existing_template = Template.query.filter_by(
            name=name, 
            user_id=current_user_id
        ).first()
        
        if existing_template:
            return jsonify({'error': 'Template name already exists'}), 400
        
        # Create template
        template = Template(
            name=name,
            description=description,
            user_id=current_user_id,
            is_system=False,
            is_default=False
        )
        template.set_categories(categories)
        
        db.session.add(template)
        db.session.commit()
        
        return jsonify({
            'message': 'Template created successfully',
            'template': template.to_dict()
        }), 201
        
    except Exception as e:
        current_app.logger.error(f"Create template error: {str(e)}")
        return jsonify({'error': 'Failed to create template'}), 500

@templates_bp.route('/<int:template_id>', methods=['GET'])
@jwt_required()
def get_template(template_id):
    """Get a specific template."""
    try:
        current_user_id = get_jwt_identity()
        template = Template.query.get(template_id)
        
        if not template:
            return jsonify({'error': 'Template not found'}), 404
        
        # Check access permissions
        if not template.is_system and template.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        return jsonify({'template': template.to_dict()})
        
    except Exception as e:
        current_app.logger.error(f"Get template error: {str(e)}")
        return jsonify({'error': 'Failed to retrieve template'}), 500

@templates_bp.route('/<int:template_id>', methods=['PUT'])
@jwt_required()
def update_template(template_id):
    """Update a custom template."""
    try:
        current_user_id = get_jwt_identity()
        template = Template.query.get(template_id)
        
        if not template:
            return jsonify({'error': 'Template not found'}), 404
        
        # Only allow users to update their own templates (not system templates)
        if template.is_system or template.user_id != current_user_id:
            return jsonify({'error': 'Cannot modify this template'}), 403
        
        data = request.get_json()
        if not data:
            return jsonify({'error': 'No data provided'}), 400
        
        # Update fields
        if 'name' in data:
            # Check for name conflicts
            existing_template = Template.query.filter_by(
                name=data['name'], 
                user_id=current_user_id
            ).filter(Template.id != template_id).first()
            
            if existing_template:
                return jsonify({'error': 'Template name already exists'}), 400
            
            template.name = data['name']
        
        if 'description' in data:
            template.description = data['description']
        
        if 'categories' in data:
            categories = data['categories']
            
            # Validate categories format
            if not isinstance(categories, list) or len(categories) == 0:
                return jsonify({'error': 'Categories must be a non-empty list'}), 400
            
            for category in categories:
                if not isinstance(category, dict) or 'name' not in category:
                    return jsonify({'error': 'Each category must have a name'}), 400
            
            template.set_categories(categories)
        
        db.session.commit()
        
        return jsonify({
            'message': 'Template updated successfully',
            'template': template.to_dict()
        })
        
    except Exception as e:
        current_app.logger.error(f"Update template error: {str(e)}")
        return jsonify({'error': 'Failed to update template'}), 500

@templates_bp.route('/<int:template_id>', methods=['DELETE'])
@jwt_required()
def delete_template(template_id):
    """Delete a custom template."""
    try:
        current_user_id = get_jwt_identity()
        template = Template.query.get(template_id)
        
        if not template:
            return jsonify({'error': 'Template not found'}), 404
        
        # Only allow users to delete their own templates (not system templates)
        if template.is_system or template.user_id != current_user_id:
            return jsonify({'error': 'Cannot delete this template'}), 403
        
        # Check if template is being used by any notes
        if template.notes.count() > 0:
            return jsonify({
                'error': 'Cannot delete template that is being used by notes',
                'notes_count': template.notes.count()
            }), 400
        
        db.session.delete(template)
        db.session.commit()
        
        return jsonify({'message': 'Template deleted successfully'})
        
    except Exception as e:
        current_app.logger.error(f"Delete template error: {str(e)}")
        return jsonify({'error': 'Failed to delete template'}), 500

@templates_bp.route('/<int:template_id>/duplicate', methods=['POST'])
@jwt_required()
def duplicate_template(template_id):
    """Duplicate a template (useful for customizing system templates)."""
    try:
        current_user_id = get_jwt_identity()
        original_template = Template.query.get(template_id)
        
        if not original_template:
            return jsonify({'error': 'Template not found'}), 404
        
        # Check access permissions
        if not original_template.is_system and original_template.user_id != current_user_id:
            return jsonify({'error': 'Access denied'}), 403
        
        data = request.get_json() or {}
        new_name = data.get('name', f"{original_template.name} (Copy)")
        
        # Check for name conflicts
        existing_template = Template.query.filter_by(
            name=new_name, 
            user_id=current_user_id
        ).first()
        
        if existing_template:
            return jsonify({'error': 'Template name already exists'}), 400
        
        # Create duplicate
        new_template = Template(
            name=new_name,
            description=original_template.description,
            user_id=current_user_id,
            is_system=False,
            is_default=False
        )
        new_template.set_categories(original_template.get_categories())
        
        db.session.add(new_template)
        db.session.commit()
        
        return jsonify({
            'message': 'Template duplicated successfully',
            'template': new_template.to_dict()
        }), 201
        
    except Exception as e:
        current_app.logger.error(f"Duplicate template error: {str(e)}")
        return jsonify({'error': 'Failed to duplicate template'}), 500 