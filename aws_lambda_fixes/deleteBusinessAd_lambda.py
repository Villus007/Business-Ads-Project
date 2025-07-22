import json
import boto3
import uuid
from datetime import datetime
from decimal import Decimal
import re

def lambda_handler(event, context):
    """
    Enhanced deleteBusinessAd Lambda Function
    Deletes business ads from DynamoDB and optionally from S3
    Supports both soft delete (status change) and hard delete (complete removal)
    """
    
    # Initialize AWS services
    dynamodb = boto3.resource('dynamodb')
    s3_client = boto3.client('s3')
    table = dynamodb.Table('BusinessAds')
    
    # Configuration
    S3_BUCKET = 'business-ad-images-1'
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
        
        print(f"📥 Delete request body: {json.dumps(body)}")
        
        # Validate required parameters
        if 'id' not in body:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                    'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                },
                'body': json.dumps({
                    'success': False,
                    'error': 'Missing required parameter: id',
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
        
        ad_id = body['id']
        hard_delete = body.get('hard', False)  # Default to soft delete
        user_id = body.get('userId', None)  # Optional user validation
        
        print(f"🗑️ Processing delete request - ID: {ad_id}, Hard: {hard_delete}, User: {user_id}")
        
        # Check if ad exists
        try:
            response = table.get_item(Key={'id': ad_id})
            if 'Item' not in response:
                return {
                    'statusCode': 404,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                        'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': f'Ad with ID {ad_id} not found',
                        'adId': ad_id,
                        'timestamp': datetime.utcnow().isoformat()
                    })
                }
            
            ad_item = response['Item']
            print(f"✅ Found ad: {ad_item.get('title', 'Unknown Title')}")
            
            # Optional: Validate user ownership
            if user_id and ad_item.get('userId') != user_id:
                return {
                    'statusCode': 403,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                        'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': 'Permission denied: You can only delete your own ads',
                        'adId': ad_id,
                        'timestamp': datetime.utcnow().isoformat()
                    })
                }
            
        except Exception as e:
            print(f"❌ Error checking ad existence: {str(e)}")
            return {
                'statusCode': 500,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                    'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                },
                'body': json.dumps({
                    'success': False,
                    'error': f'Database error: {str(e)}',
                    'adId': ad_id,
                    'timestamp': datetime.utcnow().isoformat()
                })
            }
        
        images_removed = 0
        
        if hard_delete:
            # Hard delete: Remove from DynamoDB and S3
            print(f"💥 Performing HARD DELETE for ad: {ad_id}")
            
            # Delete images from S3 if they exist
            image_urls = ad_item.get('imageUrls', [])
            for image_url in image_urls:
                try:
                    # Extract S3 key from CloudFront or S3 URL
                    if CLOUDFRONT_DOMAIN in image_url:
                        s3_key = image_url.split(CLOUDFRONT_DOMAIN + '/')[-1]
                    elif 's3.amazonaws.com' in image_url:
                        s3_key = image_url.split(S3_BUCKET + '/')[-1]
                    else:
                        # Assume it's already a key
                        s3_key = image_url.replace('/', '', 1) if image_url.startswith('/') else image_url
                    
                    # Delete from S3
                    s3_client.delete_object(Bucket=S3_BUCKET, Key=s3_key)
                    images_removed += 1
                    print(f"🗂️ Deleted image from S3: {s3_key}")
                    
                except Exception as s3_error:
                    print(f"⚠️ Failed to delete image {image_url}: {str(s3_error)}")
                    # Continue with other images
            
            # Delete from DynamoDB
            try:
                table.delete_item(Key={'id': ad_id})
                print(f"✅ HARD DELETE completed for ad: {ad_id}")
                
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                        'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                    },
                    'body': json.dumps({
                        'success': True,
                        'message': 'Ad deleted successfully (hard delete)',
                        'adId': ad_id,
                        'deleteType': 'hard',
                        'imagesRemoved': images_removed,
                        'timestamp': datetime.utcnow().isoformat()
                    })
                }
                
            except Exception as e:
                print(f"❌ Error during hard delete: {str(e)}")
                return {
                    'statusCode': 500,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                        'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': f'Failed to perform hard delete: {str(e)}',
                        'adId': ad_id,
                        'timestamp': datetime.utcnow().isoformat()
                    })
                }
        
        else:
            # Soft delete: Change status to 'deleted'
            print(f"🔄 Performing SOFT DELETE for ad: {ad_id}")
            
            try:
                # Update the status to 'deleted' and set updatedAt timestamp
                update_response = table.update_item(
                    Key={'id': ad_id},
                    UpdateExpression='SET #status = :deleted_status, updatedAt = :updated_at',
                    ExpressionAttributeNames={
                        '#status': 'status'
                    },
                    ExpressionAttributeValues={
                        ':deleted_status': 'deleted',
                        ':updated_at': datetime.utcnow().isoformat()
                    },
                    ReturnValues='UPDATED_NEW'
                )
                
                print(f"✅ SOFT DELETE completed for ad: {ad_id}")
                
                return {
                    'statusCode': 200,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                        'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                    },
                    'body': json.dumps({
                        'success': True,
                        'message': 'Ad deleted successfully (soft delete)',
                        'adId': ad_id,
                        'deleteType': 'soft',
                        'imagesRemoved': 0,  # Images preserved in soft delete
                        'timestamp': datetime.utcnow().isoformat()
                    })
                }
                
            except Exception as e:
                print(f"❌ Error during soft delete: {str(e)}")
                return {
                    'statusCode': 500,
                    'headers': {
                        'Content-Type': 'application/json',
                        'Access-Control-Allow-Origin': '*',
                        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                        'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
                    },
                    'body': json.dumps({
                        'success': False,
                        'error': f'Failed to perform soft delete: {str(e)}',
                        'adId': ad_id,
                        'timestamp': datetime.utcnow().isoformat()
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
                'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
            },
            'body': json.dumps({
                'success': False,
                'error': f'Invalid JSON in request body: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            })
        }
    
    except Exception as e:
        print(f"❌ Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type,Authorization',
                'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
            },
            'body': json.dumps({
                'success': False,
                'error': f'Internal server error: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            })
        }


# Handler for OPTIONS requests (CORS preflight)
def handle_options():
    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Headers': 'Content-Type,Authorization',
            'Access-Control-Allow-Methods': 'DELETE,OPTIONS'
        },
        'body': ''
    }
