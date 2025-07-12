import json
import boto3
import base64
import uuid
from datetime import datetime
from botocore.exceptions import ClientError
import logging
from PIL import Image
import io

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS services
s3_client = boto3.client('s3')

# Configuration
S3_BUCKET = 'business-ad-platform-images'  # Replace with your bucket name
CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'  # Replace with your CloudFront domain

def lambda_handler(event, context):
    """
    AWS Lambda function for direct image upload to S3.
    Alternative approach where the Flutter app sends image bytes directly to Lambda.
    """
    
    try:
        # Parse the request
        if 'body' in event:
            body = json.loads(event['body'])
        else:
            body = event
        
        filename = body.get('filename')
        image_data = body.get('imageData')  # Base64 encoded image
        content_type = body.get('contentType', 'image/jpeg')
        
        if not filename or not image_data:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': json.dumps({'error': 'filename and imageData are required'})
            }
        
        # Decode base64 image
        try:
            image_bytes = base64.b64decode(image_data)
        except Exception as e:
            logger.error(f"Error decoding base64 image: {str(e)}")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': json.dumps({'error': 'Invalid base64 image data'})
            }
        
        # Validate image size (max 10MB)
        max_size = 10 * 1024 * 1024  # 10MB
        if len(image_bytes) > max_size:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': json.dumps({'error': 'Image size exceeds maximum limit of 10MB'})
            }
        
        # Optional: Optimize image using PIL
        try:
            optimized_bytes = optimize_image(image_bytes, content_type)
            image_bytes = optimized_bytes
            logger.info(f"Image optimized: {len(image_bytes)} bytes")
        except Exception as e:
            logger.warning(f"Image optimization failed, using original: {str(e)}")
        
        # Generate unique filename
        timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
        unique_id = str(uuid.uuid4())[:8]
        file_extension = filename.split('.')[-1] if '.' in filename else 'jpg'
        s3_key = f"ads/{timestamp}_{unique_id}.{file_extension}"
        
        # Upload to S3
        try:
            s3_client.put_object(
                Bucket=S3_BUCKET,
                Key=s3_key,
                Body=image_bytes,
                ContentType=content_type,
                ContentDisposition='inline',
                CacheControl='max-age=31536000',  # 1 year cache
                Metadata={
                    'original-filename': filename,
                    'upload-timestamp': timestamp
                }
            )
            
            logger.info(f"Successfully uploaded {filename} to S3 as {s3_key}")
            
        except ClientError as e:
            logger.error(f"Error uploading to S3: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': json.dumps({'error': 'Failed to upload image to S3'})
            }
        
        # Generate CloudFront URL
        cloudfront_url = f"https://{CLOUDFRONT_DOMAIN}/{s3_key}"
        
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            },
            'body': json.dumps({
                'cloudFrontUrl': cloudfront_url,
                's3Key': s3_key,
                'originalSize': len(base64.b64decode(image_data)),
                'optimizedSize': len(image_bytes),
                'message': 'Image uploaded successfully'
            })
        }
        
    except Exception as e:
        logger.error(f"Error in direct upload: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'POST, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            },
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }

def optimize_image(image_bytes, content_type):
    """
    Optimize image for web delivery using PIL.
    Resize large images and adjust quality for better performance.
    """
    try:
        # Open image
        image = Image.open(io.BytesIO(image_bytes))
        
        # Convert to RGB if necessary (for JPEG)
        if image.mode in ('RGBA', 'LA', 'P') and content_type == 'image/jpeg':
            rgb_image = Image.new('RGB', image.size, (255, 255, 255))
            rgb_image.paste(image, mask=image.split()[-1] if image.mode == 'RGBA' else None)
            image = rgb_image
        
        # Resize if too large
        max_dimension = 1920
        if image.width > max_dimension or image.height > max_dimension:
            image.thumbnail((max_dimension, max_dimension), Image.Resampling.LANCZOS)
            logger.info(f"Resized image to {image.width}x{image.height}")
        
        # Save optimized image
        output = io.BytesIO()
        format_map = {
            'image/jpeg': 'JPEG',
            'image/png': 'PNG',
            'image/webp': 'WEBP'
        }
        
        format_name = format_map.get(content_type, 'JPEG')
        
        if format_name == 'JPEG':
            image.save(output, format=format_name, quality=85, optimize=True)
        elif format_name == 'PNG':
            image.save(output, format=format_name, optimize=True)
        elif format_name == 'WEBP':
            image.save(output, format=format_name, quality=80, optimize=True)
        
        return output.getvalue()
        
    except Exception as e:
        logger.error(f"Image optimization failed: {str(e)}")
        return image_bytes  # Return original if optimization fails