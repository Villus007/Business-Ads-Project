import json
import boto3
import uuid
from datetime import datetime
from decimal import Decimal
import re

def lambda_handler(event, context):
    """
    Enhanced submitAd Lambda Function - Version 2.0
    Creates business ads in DynamoDB with full user support system
    """
    
    # Initialize DynamoDB
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('BusinessAds')
    
    # Configuration
    CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'
    
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
        
        # Create timestamp
        current_time = datetime.utcnow().isoformat()
        
        # Build the ad item
        ad_item = {
            'id': ad_id,
            'title': body['title'],
            'description': description,
            'imageUrls': normalized_urls,
            'userName': user_name,
            'userId': user_id,
            'createdAt': current_time,
            'updatedAt': current_time,
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
        
        print(f"💾 Saving ad item: {json.dumps(ad_item, default=str)}")
        
        # Save to DynamoDB
        table.put_item(Item=ad_item)
        
        print(f"✅ Ad created successfully: {ad_id}")
        
        # Return success response
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
                'message': 'Ad created successfully with user information',
                'adId': ad_id,
                'featured': is_featured,
                'userName': user_name,
                'userId': user_id,
                'imageCount': image_count,
                'qualityScore': quality_score,
                'createdAt': current_time
            })
        }
        
    except json.JSONDecodeError as e:
        print(f"❌ JSON decode error: {str(e)}")
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
                'error': f'Invalid JSON: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
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
