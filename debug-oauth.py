#!/usr/bin/env python3

"""
Debug script to test OAuth configuration and session handling
Run this to check if OAuth settings are correct
"""

import os
import sys
sys.path.insert(0, '/app')

from app import create_app
from flask import session

def test_oauth_config():
    """Test OAuth configuration"""
    app = create_app()
    
    with app.app_context():
        print("🔍 OAuth Configuration Debug")
        print("=" * 40)
        
        # Check Google OAuth settings
        google_client_id = app.config.get('GOOGLE_CLIENT_ID')
        google_client_secret = app.config.get('GOOGLE_CLIENT_SECRET')
        base_url = app.config.get('BASE_URL')
        
        print(f"📍 BASE_URL: {base_url}")
        print(f"🔑 GOOGLE_CLIENT_ID: {google_client_id[:20]}..." if google_client_id else "❌ GOOGLE_CLIENT_ID: Not set")
        print(f"🔐 GOOGLE_CLIENT_SECRET: {'✅ Set' if google_client_secret else '❌ Not set'}")
        
        # Check session configuration
        print(f"\n🍪 Session Configuration:")
        print(f"SECRET_KEY: {'✅ Set' if app.config.get('SECRET_KEY') else '❌ Not set'}")
        print(f"SESSION_COOKIE_HTTPONLY: {app.config.get('SESSION_COOKIE_HTTPONLY', 'Not set')}")
        print(f"SESSION_COOKIE_SECURE: {app.config.get('SESSION_COOKIE_SECURE', 'Not set')}")
        print(f"SESSION_COOKIE_SAMESITE: {app.config.get('SESSION_COOKIE_SAMESITE', 'Not set')}")
        
        # Expected OAuth redirect URI
        if base_url:
            expected_redirect_uri = f"{base_url.rstrip('/')}/auth/callback/google"
            print(f"\n🔄 Expected OAuth Redirect URI:")
            print(f"   {expected_redirect_uri}")
            
            print(f"\n💡 Google Cloud Console Settings Required:")
            print(f"   Authorized JavaScript origins: {base_url}")
            print(f"   Authorized redirect URIs: {expected_redirect_uri}")
        else:
            print(f"\n⚠️ BASE_URL not set - OAuth redirects will use request host")
            print(f"   This should work but may cause HTTP/HTTPS issues")
        
        # Test session functionality
        print(f"\n🧪 Testing Session Functionality:")
        with app.test_request_context():
            try:
                session['test'] = 'value'
                if session.get('test') == 'value':
                    print("✅ Sessions working correctly")
                else:
                    print("❌ Session read/write failed")
            except Exception as e:
                print(f"❌ Session error: {e}")
                
        # Check environment variables in container
        print(f"\n🔍 Environment Variables Check:")
        print(f"BASE_URL env var: {os.environ.get('BASE_URL', 'Not set')}")
        print(f"GOOGLE_CLIENT_ID env var: {os.environ.get('GOOGLE_CLIENT_ID', 'Not set')[:20]}...")

if __name__ == '__main__':
    test_oauth_config() 