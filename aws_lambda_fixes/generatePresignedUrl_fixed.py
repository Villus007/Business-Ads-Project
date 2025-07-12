import json
import boto3
import uuid
from datetime import datetime
from botocore.exceptions import ClientError
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS services
s3_client = boto3.client('s3')

# Configuration
S3_BUCKET = 'business-ad-images-1'  # Your S3 bucket name
CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'  # Your CloudFront domain

def lambda_handler(event, context):
    """
    Enhanced Lambda function to generate pre-signed URLs for S3 image uploads.
    Returns both upload URL and CloudFront URL for proper image handling.
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
        # Parse the request - handle both query parameters and body
        filename = None
        content_type = 'image/jpeg'
        
        # Try to get filename from query parameters (GET request)
        if 'queryStringParameters' in event and event['queryStringParameters']:
            filename = event['queryStringParameters'].get('filename')
            content_type = event['queryStringParameters'].get('contentType', 'image/jpeg')
        
        # Try to get filename from request body (POST request)
        if not filename and 'body' in event and event['body']:
            try:
                body = json.loads(event['body'])
                filename = body.get('filename')
                content_type = body.get('contentType', 'image/jpeg')
            except:
                pass
        
        # Validate filename
        if not filename:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'filename parameter is required'})
            }
        
        # Determine content type from filename if not provided
        if content_type == 'image/jpeg':
            file_extension = filename.lower().split('.')[-1] if '.' in filename else 'jpg'
            content_type_map = {
                'jpg': 'image/jpeg',
                'jpeg': 'image/jpeg',
                'png': 'image/png',
                'gif': 'image/gif',
                'webp': 'image/webp'
            }
            content_type = content_type_map.get(file_extension, 'image/jpeg')
        
        # Generate unique filename to prevent conflicts
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        unique_id = str(uuid.uuid4())[:8]
        file_extension = filename.split('.')[-1] if '.' in filename else 'jpg'
        s3_key = f"ads/{timestamp}_{unique_id}.{file_extension}"
        
        # Generate pre-signed URL for PUT operation
        try:
            presigned_url = s3_client.generate_presigned_url(
                'put_object',
                Params={
                    'Bucket': S3_BUCKET,
                    'Key': s3_key,
                    'ContentType': content_type,
                    'ContentDisposition': 'inline'
                },
                ExpiresIn=3600  # 1 hour
            )
        except ClientError as e:
            logger.error(f"Error generating presigned URL: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({'error': 'Failed to generate presigned URL'})
            }
        
        # Generate CloudFront URL for the image
        cloudfront_url = f"https://{CLOUDFRONT_DOMAIN}/{s3_key}"
        
        logger.info(f"Generated pre-signed URL for {filename} -> {s3_key}")
        
        # Return both URLs as expected by the Flutter app
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'uploadUrl': presigned_url,
                'cloudFrontUrl': cloudfront_url,
                's3Key': s3_key,
                'contentType': content_type,
                'expiresIn': 3600,
                'message': 'Pre-signed URL generated successfully'
            })
        }
        
    except Exception as e:
        logger.error(f"Error generating pre-signed URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }
