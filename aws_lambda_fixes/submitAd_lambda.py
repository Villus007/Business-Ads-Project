import json
import boto3
import uuid
from datetime import datetime, timedelta
from decimal import Decimal

def lambda_handler(event, context):
    """
    Enhanced submitAd Lambda Function with TTL Support - Version 2.2
    Creates business ads in DynamoDB with 30-day automatic expiration
    """
    
    # Initialize DynamoDB
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('BusinessAds')
    
    # Configuration
    CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'
    TTL_DAYS = 30  # Time to live in days
    
    try:
        # Parse request body
        if event.get('body'):
            if isinstance(event['body'], str):
                body = json.loads(event['body'])
            else:
                body = event['body']
        else:
            body = event
        
        print(f"📥 Submit request: {json.dumps(body, default=str)}")
        
        # Validate required fields
        required_fields = ['title', 'description', 'imageUrls', 'userName']
        for field in required_fields:
            if not body.get(field):
                return {
                    'statusCode': 400,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                        'Access-Control-Allow-Methods': 'POST,OPTIONS'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': f'Missing required field: {field}',
                        'timestamp': datetime.utcnow().isoformat()
                    })
                }
        
        # Generate unique ad ID
        ad_id = str(uuid.uuid4())
        
        # Auto-generate userId from userName if not provided
        user_name = body['userName']
        user_id = body.get('userId', user_name.lower().replace(' ', '_').replace('-', '_'))
        
        # Normalize image URLs to CloudFront
        image_urls = body['imageUrls']
        if isinstance(image_urls, str):
            image_urls = [image_urls]
        
        normalized_urls = []
        for url in image_urls:
            if url.startswith('http'):
                # Convert S3 URLs to CloudFront
                if 's3.amazonaws.com' in url:
                    # Extract the path after the bucket name
                    path = url.split('/')[-1]  # Get filename
                    normalized_url = f"https://{CLOUDFRONT_DOMAIN}/ads/{path}"
                elif CLOUDFRONT_DOMAIN in url:
                    normalized_url = url  # Already CloudFront
                else:
                    normalized_url = url  # Keep as is
            else:
                # Assume it's a path, prepend CloudFront domain
                normalized_url = f"https://{CLOUDFRONT_DOMAIN}/{url}"
            
            normalized_urls.append(normalized_url)
        
        # Calculate quality score for featured determination (7-point system)
        quality_score = 0
        
        # Image quality (0-3 points)
        image_count = len(normalized_urls)
        if image_count >= 3:
            quality_score += 3
        elif image_count == 2:
            quality_score += 2
        elif image_count == 1:
            quality_score += 1
        
        # Description quality (0-2 points)
        description = body['description']
        if len(description) >= 100:
            quality_score += 2
        elif len(description) >= 50:
            quality_score += 1
        
        # User profile completeness (0-2 points)
        if body.get('userProfileImage'):
            quality_score += 1
        if body.get('businessName') or body.get('contactInfo') or body.get('location'):
            quality_score += 1
        
        # Determine if featured (score >= 5 out of 7)
        is_featured = quality_score >= 5
        
        print(f"📊 Quality score: {quality_score}/7, Featured: {is_featured}")
        
        # Create timestamps
        current_time = datetime.utcnow()
        current_time_iso = current_time.isoformat()
        
        # Calculate TTL expiration date (30 days from now)
        expiration_date = current_time + timedelta(days=TTL_DAYS)
        expiration_timestamp = int(expiration_date.timestamp())  # Unix timestamp for DynamoDB TTL
        expiration_iso = expiration_date.isoformat()
        
        print(f"⏰ Ad will expire on: {expiration_iso} (TTL: {expiration_timestamp})")
        
        # Build the ad item with TTL support
        ad_item = {
            'id': ad_id,
            'title': body['title'],
            'description': description,
            'imageUrls': normalized_urls,
            'userName': user_name,
            'userId': user_id,
            'createdAt': current_time_iso,
            'updatedAt': current_time_iso,
            'expiresAt': expiration_iso,  # Human-readable expiration
            'ttl': expiration_timestamp,  # DynamoDB TTL attribute (Unix timestamp)
            'status': 'active',
            'featured': is_featured,
            'imageCount': image_count,
            'likes': 0,
            'viewCount': 0,
            'comments': []
        }
        
        # Add optional fields if provided
        optional_fields = ['userProfileImage', 'businessName', 'contactInfo', 'location', 'category']
        for field in optional_fields:
            if body.get(field):
                ad_item[field] = body[field]
        
        print(f"💾 Saving ad item with TTL: {json.dumps(ad_item, default=str)}")
        
        # Save to DynamoDB
        table.put_item(Item=ad_item)
        
        print(f"✅ Ad created successfully: {ad_id}")
        print(f"⏰ Automatic deletion scheduled for: {expiration_iso}")
        
        # Return success response with TTL information
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({
                'success': True,
                'message': f'Ad created successfully with {TTL_DAYS}-day automatic expiration',
                'adId': ad_id,
                'featured': is_featured,
                'userName': user_name,
                'userId': user_id,
                'imageCount': image_count,
                'createdAt': current_time_iso,
                'expiresAt': expiration_iso,
                'ttlDays': TTL_DAYS
            })
        }
        
    except Exception as e:
        print(f"❌ Error creating ad: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'POST,OPTIONS'
            },
            'body': json.dumps({
                'success': False,
                'error': f'Failed to create ad: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            })
        }
