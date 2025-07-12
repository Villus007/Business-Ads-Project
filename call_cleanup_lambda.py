#!/usr/bin/env python3
"""
Script to call the cleanup Lambda function via API Gateway
"""

import requests
import json

# Your API Gateway base URL
BASE_URL = "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod"

def cleanup_test_ads():
    """Call the cleanup Lambda function"""
    try:
        print("🧹 Calling cleanup Lambda function...")
        
        # Make DELETE request to cleanup endpoint
        response = requests.delete(f"{BASE_URL}/cleanup-test-ads")
        
        if response.status_code == 200:
            data = response.json()
            print(f"✅ {data.get('message', 'Cleanup completed')}")
            print(f"📊 Deleted: {data.get('deleted_count', 0)} ads")
            print(f"📊 Total attempted: {data.get('total_attempted', 0)} ads")
            
            errors = data.get('errors', [])
            if errors:
                print("\n⚠️  Some errors occurred:")
                for error in errors:
                    print(f"   - {error}")
        else:
            print(f"❌ Failed to cleanup: {response.status_code}")
            print(f"Response: {response.text}")
            
    except Exception as e:
        print(f"❌ Error calling cleanup function: {e}")

def main():
    """Main function"""
    print("🧹 Business Ad Platform - Test Data Cleanup")
    print("=" * 50)
    
    cleanup_test_ads()
    
    print("\n💡 Check your app - test ads should now be removed!")

if __name__ == "__main__":
    main()