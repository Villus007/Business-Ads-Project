import json
import boto3
from datetime import datetime, timedelta
from decimal import Decimal
import re

def lambda_handler(event, context):
    """
    TTL Cleanup Lambda Function - Automatic 30-day Ad Expiration
    
    This function is triggered by EventBridge on a schedule and:
    1. Scans DynamoDB for ads older than 30 days
    2. Deletes expired ads from DynamoDB
    3. Removes associated images from S3
    4. Provides cleanup statistics
    
    Expected to run daily at 2:00 AM UTC
    """
    
    # Initialize AWS services
    dynamodb = boto3.resource('dynamodb')
    s3_client = boto3.client('s3')
    table = dynamodb.Table('BusinessAds')
    
    # Configuration
    S3_BUCKET = 'business-ad-images-1'
    CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'
    TTL_DAYS = 30  # Time to live in days
    
    print(f"🕒 TTL Cleanup started at {datetime.utcnow().isoformat()}")
    print(f"📅 Cleaning up ads older than {TTL_DAYS} days")
    
    try:
        # Calculate cutoff date (30 days ago)
        cutoff_date = datetime.utcnow() - timedelta(days=TTL_DAYS)
        cutoff_iso = cutoff_date.isoformat()
        
        print(f"⏰ Cutoff date: {cutoff_iso}")
        
        # Scan DynamoDB for expired ads
        # Note: This scans all items - for large tables, consider using GSI with TTL
        scan_params = {
            'FilterExpression': 'createdAt < :cutoff_date AND #status <> :deleted_status',
            'ExpressionAttributeValues': {
                ':cutoff_date': cutoff_iso,
                ':deleted_status': 'deleted'
            },
            'ExpressionAttributeNames': {
                '#status': 'status'
            }
        }
        
        expired_ads = []
        last_evaluated_key = None
        
        # Paginate through all results
        while True:
            if last_evaluated_key:
                scan_params['ExclusiveStartKey'] = last_evaluated_key
            
            response = table.scan(**scan_params)
            expired_ads.extend(response.get('Items', []))
            
            last_evaluated_key = response.get('LastEvaluatedKey')
            if not last_evaluated_key:
                break
        
        print(f"🔍 Found {len(expired_ads)} expired ads to clean up")
        
        if not expired_ads:
            print("✅ No expired ads found - cleanup complete")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'success': True,
                    'message': 'TTL cleanup completed - no expired ads found',
                    'ads_deleted': 0,
                    'images_removed': 0,
                    'cutoff_date': cutoff_iso,
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
        
        # Track cleanup statistics
        ads_deleted = 0
        images_removed = 0
        errors = []
        
        # Process each expired ad
        for ad in expired_ads:
            ad_id = ad.get('id', 'unknown')
            ad_title = ad.get('title', 'Unknown Title')
            created_at = ad.get('createdAt', 'Unknown Date')
            
            print(f"🗑️ Processing expired ad: {ad_id} - '{ad_title}' (created: {created_at})")
            
            try:
                # Extract and delete S3 images
                image_urls = ad.get('imageUrls', [])
                ad_images_removed = 0
                
                if image_urls:
                    print(f"🖼️ Removing {len(image_urls)} images from S3...")
                    
                    for image_url in image_urls:
                        try:
                            # Extract S3 key from CloudFront URL
                            s3_key = extract_s3_key_from_url(image_url, CLOUDFRONT_DOMAIN)
                            
                            if s3_key:
                                # Delete from S3
                                s3_client.delete_object(Bucket=S3_BUCKET, Key=s3_key)
                                ad_images_removed += 1
                                print(f"✅ Deleted S3 object: {s3_key}")
                            else:
                                print(f"⚠️ Could not extract S3 key from URL: {image_url}")
                                
                        except Exception as s3_error:
                            error_msg = f"Failed to delete image {image_url}: {str(s3_error)}"
                            print(f"❌ {error_msg}")
                            errors.append(error_msg)
                
                # Delete from DynamoDB
                table.delete_item(Key={'id': ad_id})
                ads_deleted += 1
                images_removed += ad_images_removed
                
                print(f"✅ Successfully deleted ad {ad_id} with {ad_images_removed} images")
                
            except Exception as e:
                error_msg = f"Failed to delete ad {ad_id}: {str(e)}"
                print(f"❌ {error_msg}")
                errors.append(error_msg)
                continue
        
        # Cleanup summary
        print(f"🎉 TTL Cleanup completed:")
        print(f"   📊 Ads deleted: {ads_deleted}")
        print(f"   🖼️ Images removed: {images_removed}")
        print(f"   ❌ Errors: {len(errors)}")
        
        # Prepare response
        response_body = {
            'success': True,
            'message': f'TTL cleanup completed successfully',
            'ads_deleted': ads_deleted,
            'images_removed': images_removed,
            'cutoff_date': cutoff_iso,
            'ttl_days': TTL_DAYS,
            'errors': errors,
            'timestamp': datetime.utcnow().isoformat()
        }
        
        # Add warning if there were errors
        if errors:
            response_body['warning'] = f'{len(errors)} errors occurred during cleanup'
        
        return {
            'statusCode': 200,
            'body': json.dumps(response_body, default=str)
        }
        
    except Exception as e:
        error_msg = f"TTL cleanup failed: {str(e)}"
        print(f"💥 {error_msg}")
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'success': False,
                'error': error_msg,
                'timestamp': datetime.utcnow().isoformat()
            })
        }

def extract_s3_key_from_url(url, cloudfront_domain):
    """
    Extract S3 key from CloudFront URL
    Example: https://d11c102y3uxwr7.cloudfront.net/ads/image.jpg -> ads/image.jpg
    """
    try:
        if cloudfront_domain in url:
            # Extract the path after the domain
            pattern = f"https://{re.escape(cloudfront_domain)}/(.*)"
            match = re.search(pattern, url)
            
            if match:
                s3_key = match.group(1)
                print(f"🔑 Extracted S3 key: {s3_key} from URL: {url}")
                return s3_key
            else:
                print(f"⚠️ Could not extract S3 key from URL: {url}")
                return None
        else:
            print(f"⚠️ URL does not contain CloudFront domain: {url}")
            return None
            
    except Exception as e:
        print(f"❌ Error extracting S3 key from URL {url}: {str(e)}")
        return None

# Test function for manual execution
def test_ttl_cleanup():
    """
    Test function to manually trigger TTL cleanup
    """
    print("🧪 Testing TTL cleanup function...")
    
    test_event = {
        "source": "aws.events",
        "detail-type": "Scheduled Event",
        "detail": {}
    }
    
    result = lambda_handler(test_event, {})
    print(f"📋 Test result: {json.dumps(result, indent=2)}")
    
    return result

if __name__ == "__main__":
    # For local testing
    test_ttl_cleanup()
