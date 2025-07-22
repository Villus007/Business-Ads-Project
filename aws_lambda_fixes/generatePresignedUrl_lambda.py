import json
import boto3
import uuid
from datetime import datetime
from urllib.parse import unquote

def lambda_handler(event, context):
    """
    generatePresignedUrl Lambda Function
    Generates presigned URLs for S3 image uploads
    """
    
    # Configuration
    S3_BUCKET = 'business-ad-images-1'
    CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'
    
    # Initialize S3 client
    s3_client = boto3.client('s3')
    
    try:
        # Parse query parameters
        query_params = event.get('queryStringParameters') or {}
        print(f"📥 Query parameters: {json.dumps(query_params)}")
        
        # Get parameters
        filename = query_params.get('filename')
        content_type = query_params.get('contentType', 'image/jpeg')
        
        if not filename:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                    'Access-Control-Allow-Methods': 'GET,OPTIONS'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Missing required parameter: filename',
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
        
        # Validate content type
        allowed_types = {
            'image/jpeg': 'jpg',
            'image/jpg': 'jpg',
            'image/png': 'png',
            'image/gif': 'gif',
            'image/webp': 'webp'
        }
        
        if content_type not in allowed_types:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                    'Access-Control-Allow-Methods': 'GET,OPTIONS'
                },
                'body': json.dumps({
                    'success': False,
                    'error': f'Unsupported content type: {content_type}',
                    'supported_types': list(allowed_types.keys()),
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
        
        # Generate unique filename
        file_extension = allowed_types[content_type]
        base_name = filename.rsplit('.', 1)[0] if '.' in filename else filename
        timestamp = datetime.utcnow().strftime('%Y%m%d_%H%M%S')
        unique_id = str(uuid.uuid4())[:8]
        
        unique_filename = f"{timestamp}_{unique_id}_{base_name}.{file_extension}"
        s3_key = f"ads/{unique_filename}"
        
        print(f"🔑 Generated S3 key: {s3_key}")
        
        # Generate presigned URL for PUT operation
        presigned_url = s3_client.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': S3_BUCKET,
                'Key': s3_key,
                'ContentType': content_type
            },
            ExpiresIn=3600  # 1 hour
        )
        
        # Generate CloudFront URL for accessing the uploaded image
        cloudfront_url = f"https://{CLOUDFRONT_DOMAIN}/{s3_key}"
        
        print(f"✅ Generated presigned URL for: {unique_filename}")
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps({
                'success': True,
                'uploadUrl': presigned_url,
                'cloudFrontUrl': cloudfront_url,
                'imageUrl': cloudfront_url,  # Keep both for compatibility
                'filename': unique_filename,
                'key': s3_key,
                'contentType': content_type,
                'expiresIn': 3600,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        print(f"❌ Error generating presigned URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'GET,OPTIONS'
            },
            'body': json.dumps({
                'success': False,
                'error': f'Failed to generate presigned URL: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            })
        }
