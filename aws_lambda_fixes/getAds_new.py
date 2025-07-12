import json
import boto3
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
    Enhanced Lambda function to retrieve business ads with CloudFront image URLs.
    Supports both general ads and featured ads retrieval.
    """
    
    # Set up CORS headers
    headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,OPTIONS'
    }
    
    # Handle CORS preflight request
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'CORS preflight successful'})
        }
    
    try:
        # Parse the request - handle both API Gateway and direct invocation
        http_method = event.get('httpMethod', 'GET')
        path = event.get('path', '/ads')
        query_params = event.get('queryStringParameters') or {}
        
        # Handle case where event might not have proper API Gateway structure
        if not http_method and not path:
            # Direct Lambda invocation or test
            http_method = 'GET'
            path = '/ads'
            query_params = event.get('queryStringParameters', {}) or {}
        
        # Log the incoming request for debugging
        logger.info(f"Processing {http_method} request for path: {path}")
        logger.info(f"Query params: {query_params}")
        
        # Determine if requesting featured ads
        is_featured_request = '/featured' in path or query_params.get('featured') == 'true'
        
        # Get pagination parameters
        limit = int(query_params.get('limit', 50))
        limit = min(limit, 100)  # Cap at 100 items
        
        # Build scan parameters with status filter
        scan_params = {
            'Limit': limit,
            'FilterExpression': boto3.dynamodb.conditions.Attr('status').eq('active')
        }
        
        # Add featured filter if requested
        if is_featured_request:
            scan_params['FilterExpression'] = scan_params['FilterExpression'] & boto3.dynamodb.conditions.Attr('featured').eq(True)
        
        # Handle pagination
        if 'lastKey' in query_params:
            try:
                last_key = json.loads(query_params['lastKey'])
                scan_params['ExclusiveStartKey'] = last_key
            except:
                logger.warning("Invalid lastKey parameter")
        
        # Scan the table
        try:
            response = table.scan(**scan_params)
            items = response.get('Items', [])
            
            # Convert Decimal to float and ensure CloudFront URLs
            ads = []
            for item in items:
                ad = convert_decimal_to_float(item)
                
                # Ensure all image URLs are CloudFront URLs
                if 'imageUrls' in ad:
                    ad['imageUrls'] = ensure_cloudfront_urls(ad['imageUrls'])
                
                # Ensure required fields exist
                ad.setdefault('id', '')
                ad.setdefault('title', '')
                ad.setdefault('description', '')
                ad.setdefault('imageUrls', [])
                ad.setdefault('createdAt', '')
                
                # Add optional fields if they exist
                optional_fields = ['businessName', 'contactInfo', 'location', 'category', 'isActive', 'isFeatured', 'featured', 'imageCount']
                for field in optional_fields:
                    if field in item:
                        ad[field] = convert_decimal_to_float(item[field])
                
                ads.append(ad)
            
            # Sort ads by creation date (newest first)
            ads.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
            
            # Prepare response
            result = {
                'ads': ads,
                'count': len(ads),
                'featured': is_featured_request
            }
            
            # Add pagination info
            if 'LastEvaluatedKey' in response:
                result['lastKey'] = response['LastEvaluatedKey']
                result['hasMore'] = True
            else:
                result['hasMore'] = False
            
            logger.info(f"Retrieved {len(ads)} {'featured' if is_featured_request else 'general'} ads")
            
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps(result)
            }
            
        except ClientError as e:
            logger.error(f"Error scanning DynamoDB: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({'error': 'Failed to retrieve ads from database'})
            }
        
    except Exception as e:
        logger.error(f"Error retrieving ads: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }

def convert_decimal_to_float(obj):
    """Convert Decimal objects to float for JSON serialization"""
    if isinstance(obj, list):
        return [convert_decimal_to_float(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_decimal_to_float(value) for key, value in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    else:
        return obj

def ensure_cloudfront_urls(image_urls):
    """Ensure all image URLs are properly formatted CloudFront URLs"""
    if not image_urls:
        return []
    
    normalized_urls = []
    for url in image_urls:
        if url.startswith('data:'):
            # Skip data URLs in production
            continue
        elif url.startswith('https://'):
            # Keep existing HTTPS URLs
            normalized_urls.append(url)
        elif url.startswith('http://'):
            # Convert HTTP to HTTPS
            normalized_urls.append(url.replace('http://', 'https://'))
        else:
            # Assume it's an S3 key and convert to CloudFront URL
            cloudfront_url = f"https://{CLOUDFRONT_DOMAIN}/{url.lstrip('/')}"
            normalized_urls.append(cloudfront_url)
    
    return normalized_urls
