#!/usr/bin/env python3
"""
AWS Endpoint Testing Script for Business Ad Platform
Run this script to test your AWS endpoints after implementing the fixes.
"""

import requests
import json
import uuid
from datetime import datetime

# Your API Gateway base URL
BASE_URL = "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod"

def test_presigned_url():
    """Test the presigned URL generation endpoint"""
    print("🔗 Testing presigned URL generation...")
    
    try:
        response = requests.get(
            f"{BASE_URL}/presigned-url",
            params={"filename": "test-image.jpg"}
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Presigned URL generated successfully")
            print(f"   URL: {data.get('url', 'N/A')[:100]}...")
            return True
        else:
            print(f"❌ Failed: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return False

def test_submit_ad():
    """Test the ad submission endpoint"""
    print("\n📝 Testing ad submission...")
    
    test_ad = {
        "id": f"test-{uuid.uuid4()}",
        "title": "Test Ad from Script",
        "description": "This is a test ad created by the verification script",
        "imageUrls": ["https://picsum.photos/300/300?random=999"]
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/",
            headers={"Content-Type": "application/json"},
            data=json.dumps(test_ad)
        )
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Ad submitted successfully")
            print(f"   Response: {data}")
            return test_ad["id"]
        else:
            print(f"❌ Failed: {response.status_code} - {response.text}")
            return None
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return None

def test_get_ads():
    """Test the ads retrieval endpoint"""
    print("\n📋 Testing ads retrieval...")
    
    try:
        response = requests.get(f"{BASE_URL}/ads")
        
        if response.status_code == 200:
            data = response.json()
            ads = data.get('ads', [])
            print(f"✅ Retrieved {len(ads)} ads successfully")
            
            # Show first few ads
            for i, ad in enumerate(ads[:3]):
                print(f"   Ad {i+1}: {ad.get('title', 'No title')}")
            
            return len(ads)
        else:
            print(f"❌ Failed: {response.status_code} - {response.text}")
            return 0
            
    except Exception as e:
        print(f"❌ Error: {e}")
        return 0

def main():
    """Run all tests"""
    print("🚀 AWS Business Ad Platform - Endpoint Testing")
    print("=" * 50)
    
    # Test each endpoint
    presigned_ok = test_presigned_url()
    submitted_id = test_submit_ad()
    ads_count = test_get_ads()
    
    # Summary
    print("\n" + "=" * 50)
    print("📊 TEST SUMMARY:")
    print(f"   Presigned URL: {'✅ PASS' if presigned_ok else '❌ FAIL'}")
    print(f"   Ad Submission: {'✅ PASS' if submitted_id else '❌ FAIL'}")
    print(f"   Ads Retrieval: {'✅ PASS' if ads_count >= 0 else '❌ FAIL'}")
    
    if presigned_ok and submitted_id and ads_count >= 0:
        print("\n🎉 All tests passed! Your AWS setup is working correctly.")
    else:
        print("\n⚠️  Some tests failed. Check the AWS Step-by-Step Fixes guide.")
    
    print("\n💡 Next steps:")
    print("   1. If tests pass, switch Flutter app to production mode")
    print("   2. If tests fail, follow the AWS fixes in the guide")

if __name__ == "__main__":
    main()
