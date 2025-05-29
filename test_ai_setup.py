#!/usr/bin/env python3
"""
Simple test to verify FocusPad AI setup.
"""

import os
import sys

def test_env_variables():
    """Test if environment variables are set."""
    print("🔧 Testing Environment Variables...")
    
    # Check if .env file exists
    if os.path.exists('.env'):
        print("✅ .env file exists")
        
        # Read .env file
        with open('.env', 'r') as f:
            content = f.read()
            
        if 'OPENAI_API_KEY' in content:
            print("✅ OPENAI_API_KEY found in .env file")
            return True
        else:
            print("❌ OPENAI_API_KEY not found in .env file")
            return False
    else:
        print("❌ .env file not found")
        return False

def test_docker_setup():
    """Test if Docker setup is correct."""
    print("\n🐳 Testing Docker Setup...")
    
    if os.path.exists('docker-compose.yml'):
        print("✅ docker-compose.yml exists")
        
        if os.path.exists('Dockerfile'):
            print("✅ Dockerfile exists")
            return True
        else:
            print("❌ Dockerfile not found")
            return False
    else:
        print("❌ docker-compose.yml not found")
        return False

def main():
    """Run setup tests."""
    print("🚀 FocusPad AI Setup Verification")
    print("=" * 40)
    
    tests = [test_env_variables, test_docker_setup]
    passed = 0
    
    for test in tests:
        if test():
            passed += 1
    
    print("\n" + "=" * 40)
    print(f"📊 Setup Check: {passed}/{len(tests)} components ready")
    
    if passed == len(tests):
        print("🎉 Setup is complete!")
        print("\n📋 Ready to start FocusPad:")
        print("1. Replace 'your-openai-api-key-here' with your actual OpenAI API key")
        print("2. Run: docker-compose up -d")
        print("3. Visit: http://localhost:5000")
        return True
    else:
        print("❌ Setup incomplete. Please fix the issues above.")
        return False

if __name__ == '__main__':
    success = main()
    sys.exit(0 if success else 1) 