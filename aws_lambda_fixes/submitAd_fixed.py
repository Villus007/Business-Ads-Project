import json
import boto3
import uuid
from datetime import datetime
from decimal import Decimal
from botocore.exceptions import ClientError
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS services
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('BusinessAds')

# Configuration
CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'  # Your CloudFront domain

def lambda_handler(event, context):
    """
    Enhanced Lambda function to create business ads with CloudFront image URLs.
    Handles CORS, validates data, and ensures proper image URL formatting.
    """
    
    # Set up CORS headers
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
    }
    
    # Handle CORS preflight request
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'CORS preflight successful'})
        }
    
    try:
        # Parse the request body
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event
        
        # Extract and validate ad data
        ad_data = {
            'id': body.get('id', str(uuid.uuid4())),
            'title': body.get('title', '').strip(),
            'description': body.get('description', '').strip(),
            'imageUrls': body.get('imageUrls', []),
            'createdAt': datetime.now().isoformat(),
            'updatedAt': datetime.now().isoformat(),
            'status': 'active'
        }
        
        # Add optional fields if they exist
        optional_fields = ['businessName', 'contactInfo', 'location', 'category', 'isActive', 'isFeatured']
        for field in optional_fields:
            if field in body:
                ad_data[field] = body[field]
        
        # Validate required fields
        if not ad_data['title']:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'Title is required'})
            }
        
        if not ad_data['description']:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'Description is required'})
            }
        
        if not ad_data['imageUrls']:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'At least one image URL is required'})
            }
        
        # Validate and normalize image URLs to CloudFront URLs
        normalized_urls = []
        for url in ad_data['imageUrls']:
            if url.startswith('data:'):
                # Skip data URLs in production
                logger.warning(f"Skipping data URL in production: {url[:50]}...")
                continue
            elif url.startswith('https://'):
                # Keep HTTPS URLs, prefer CloudFront URLs
                if CLOUDFRONT_DOMAIN in url:
                    normalized_urls.append(url)
                else:
                    logger.warning(f"Non-CloudFront URL: {url}")
                    normalized_urls.append(url)  # Keep it but log warning
            elif url.startswith('http://'):
                # Convert HTTP to HTTPS
                https_url = url.replace('http://', 'https://')
                normalized_urls.append(https_url)
            else:
                # Assume it's an S3 key and convert to CloudFront URL
                cloudfront_url = f"https://{CLOUDFRONT_DOMAIN}/{url.lstrip('/')}"
                normalized_urls.append(cloudfront_url)
        
        if not normalized_urls:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'No valid image URLs provided'})
            }
        
        ad_data['imageUrls'] = normalized_urls
        
        # Add metadata
        ad_data['imageCount'] = len(normalized_urls)
        ad_data['featured'] = determine_featured_status(ad_data)
        
        # Convert to DynamoDB format (handle Decimal conversion)
        dynamodb_item = json.loads(json.dumps(ad_data), parse_float=Decimal)
        
        # Save to DynamoDB
        try:
            table.put_item(Item=dynamodb_item)
            logger.info(f"Successfully created ad: {ad_data['id']}")
            
        except ClientError as e:
            logger.error(f"Error saving to DynamoDB: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({'error': 'Failed to save ad to database'})
            }
        
        # Return success response
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'message': 'Ad submitted successfully',
                'ad': {
                    'id': ad_data['id'],
                    'title': ad_data['title'],
                    'description': ad_data['description'],
                    'imageUrls': ad_data['imageUrls'],
                    'imageCount': ad_data['imageCount'],
                    'featured': ad_data['featured'],
                    'createdAt': ad_data['createdAt']
                }
            })
        }
        
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except Exception as e:
        logger.error(f"Error creating ad: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }

def determine_featured_status(ad_data):
    """
    Determine if an ad should be featured based on quality criteria.
    """
    score = 0
    
    # More images = higher score
    if ad_data['imageCount'] >= 3:
        score += 2
    elif ad_data['imageCount'] >= 2:
        score += 1
    
    # Detailed description = higher score
    if len(ad_data['description']) >= 100:
        score += 2
    elif len(ad_data['description']) >= 50:
        score += 1
    
    # Quality title = higher score
    if len(ad_data['title']) >= 20:
        score += 1
    
    # Return true if score meets threshold
    return score >= 3
