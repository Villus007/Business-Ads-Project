#!/usr/bin/env python3
"""
Cleanup Script for Business Ad Platform
Removes test ads created by the verification script from DynamoDB.
"""

import requests
import json
import boto3
from botocore.exceptions import ClientError

# Your API Gateway base URL
BASE_URL = "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod"

def get_all_ads():
    """Get all ads from DynamoDB via API Gateway"""
    try:
        response = requests.get(f"{BASE_URL}/ads")
        if response.status_code == 200:
            data = response.json()
            return data.get('ads', [])
        else:
            print(f"❌ Failed to fetch ads: {response.status_code}")
            return []
    except Exception as e:
        print(f"❌ Error fetching ads: {e}")
        return []

def delete_ad_from_dynamodb(ad_id):
    """Delete a specific ad from DynamoDB"""
    try:
        dynamodb = boto3.client('dynamodb', region_name='us-east-1')
        
        response = dynamodb.delete_item(
            TableName='BusinessAds',
            Key={
                'id': {
                    'S': ad_id
                }
            }
        )
        
        print(f"✅ Deleted ad with ID: {ad_id}")
        return True
        
    except ClientError as e:
        print(f"❌ Error deleting ad {ad_id}: {e}")
        return False
    except Exception as e:
        print(f"❌ Unexpected error deleting ad {ad_id}: {e}")
        return False

def delete_test_ads():
    """Identify and delete test ads from DynamoDB"""
    print("🧹 Identifying test ads in DynamoDB...")
    
    # Get all ads
    ads = get_all_ads()
    
    if not ads:
        print("❌ No ads found or failed to retrieve ads")
        return
    
    print(f"📄 Found {len(ads)} total ads")
    
    # Filter test ads
    test_ads = []
    real_ads = []
    
    for ad in ads:
        title = ad.get('title', '')
        description = ad.get('description', '')
        
        # Identify test ads by title or description
        if ('Test Ad from Script' in title or 
            'This is a test ad created by the verification script' in description):
            test_ads.append(ad)
        else:
            real_ads.append(ad)
    
    print(f"\n🎯 Found {len(test_ads)} test ads to remove:")
    for ad in test_ads:
        print(f"   - {ad.get('title', 'No title')} (ID: {ad.get('id', 'No ID')})")
    
    print(f"\n✅ Found {len(real_ads)} real ads to keep:")
    for ad in real_ads:
        print(f"   - {ad.get('title', 'No title')} (ID: {ad.get('id', 'No ID')})")
    
    if test_ads:
        print(f"\n🗑️  Deleting {len(test_ads)} test ads...")
        deleted_count = 0
        
        for ad in test_ads:
            ad_id = ad.get('id', '')
            if ad_id:
                if delete_ad_from_dynamodb(ad_id):
                    deleted_count += 1
        
        print(f"\n✅ Successfully deleted {deleted_count} out of {len(test_ads)} test ads!")
        
        if deleted_count < len(test_ads):
            print("\n⚠️  Some ads couldn't be deleted. Check AWS credentials and permissions.")
    else:
        print("\n✅ No test ads found to remove!")

def main():
    """Main cleanup function"""
    print("🧹 Business Ad Platform - Test Data Cleanup")
    print("=" * 50)
    
    delete_test_ads()
    
    print(f"\n💡 Test ads have been removed! Your app will now only show real ads!")

if __name__ == "__main__":
    main()