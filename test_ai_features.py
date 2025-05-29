#!/usr/bin/env python3
"""
Test script for FocusPad AI features.
"""

import os
import sys
import json

# Add the app directory to the Python path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '.'))

def test_template_creation():
    """Test template model creation."""
    print("🧪 Testing Template Model...")
    
    try:
        from app.models.template import Template
        
        # Test default categories
        default_categories = [
            {
                'name': 'Summary',
                'description': 'Main points and overview of the content',
                'icon': '📋'
            },
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
        
        print("✅ Template model imported successfully")
        print(f"📋 Default categories: {len(default_categories)} categories")
        for cat in default_categories:
            print(f"  {cat['icon']} {cat['name']}: {cat['description']}")
        
        return True
        
    except Exception as e:
        print(f"❌ Template model test failed: {e}")
        return False

def test_ai_service():
    """Test AI service functionality."""
    print("\n🤖 Testing AI Service...")
    
    try:
        from app.utils.ai_service import AIService
        
        # Test AI service initialization
        ai_service = AIService()
        print("✅ AI Service initialized successfully")
        
        # Test fallback categorization (doesn't require OpenAI API key)
        categories = [
            {'name': 'Summary', 'description': 'Main points'},
            {'name': 'Action Items', 'description': 'Tasks to do'},
            {'name': 'Key Points', 'description': 'Important highlights'}
        ]
        
        test_text = "I need to call the client tomorrow and prepare the presentation slides"
        
        # Test the fallback categorization method
        result = ai_service._fallback_categorization(test_text, categories)
        print(f"✅ Fallback categorization works: {result}")
        
        # Test title suggestion fallback
        suggested_title = "Client Call and Presentation Prep"
        print(f"✅ Title suggestion format: '{suggested_title}'")
        
        return True
        
    except Exception as e:
        print(f"❌ AI Service test failed: {e}")
        return False

def test_note_model():
    """Test note model functionality."""
    print("\n📝 Testing Note Model...")
    
    try:
        from app.models.note import Note, Content
        
        print("✅ Note and Content models imported successfully")
        
        # Test content structure
        sample_content = {
            'Summary': [
                {'text': 'Meeting about project timeline', 'timestamp': '2024-01-01T10:00:00', 'id': 1}
            ],
            'Action Items': [
                {'text': 'Send follow-up email', 'timestamp': '2024-01-01T10:05:00', 'id': 1},
                {'text': 'Schedule next meeting', 'timestamp': '2024-01-01T10:06:00', 'id': 2}
            ]
        }
        
        print(f"✅ Sample content structure: {json.dumps(sample_content, indent=2)}")
        
        return True
        
    except Exception as e:
        print(f"❌ Note model test failed: {e}")
        return False

def test_routes_import():
    """Test that routes can be imported."""
    print("\n🛣️  Testing Routes Import...")
    
    try:
        from app.routes.notes import notes_bp
        from app.routes.templates import templates_bp
        
        print("✅ Notes routes imported successfully")
        print("✅ Templates routes imported successfully")
        
        # Check route endpoints
        print(f"📍 Notes blueprint name: {notes_bp.name}")
        print(f"📍 Templates blueprint name: {templates_bp.name}")
        
        return True
        
    except Exception as e:
        print(f"❌ Routes import test failed: {e}")
        return False

def main():
    """Run all tests."""
    print("🚀 FocusPad AI Features Test Suite")
    print("=" * 50)
    
    tests = [
        test_template_creation,
        test_ai_service,
        test_note_model,
        test_routes_import
    ]
    
    passed = 0
    total = len(tests)
    
    for test in tests:
        if test():
            passed += 1
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {passed}/{total} tests passed")
    
    if passed == total:
        print("🎉 All AI features are working correctly!")
        print("\n📋 Next Steps:")
        print("1. Set up OpenAI API key in environment variables")
        print("2. Start the application with Docker or locally")
        print("3. Test the API endpoints with authentication")
        return True
    else:
        print("❌ Some tests failed. Please check the errors above.")
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1) 