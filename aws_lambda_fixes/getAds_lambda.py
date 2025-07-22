import json
import boto3
from datetime import datetime
from decimal import Decimal
from urllib.parse import parse_qs

def lambda_handler(event, context):
    """
    Enhanced getAds Lambda Function - Version 2.1
    Retrieves business ads from DynamoDB with advanced filtering capabilities
    """
    
    # Initialize DynamoDB
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('BusinessAds')
    
    # Configuration
    CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'
    
    try:
        # Parse query parameters
        query_params = event.get('queryStringParameters') or {}
        print(f"📥 Query parameters: {json.dumps(query_params)}")
        
        # Get filter parameters
        user_id_filter = query_params.get('userId')
        user_name_filter = query_params.get('userName')
        featured_filter = query_params.get('featured')
        status_filter = query_params.get('status', 'active')  # Default to active ads
        limit = min(int(query_params.get('limit', 50)), 100)  # Max 100, default 50
        
        # Build scan parameters
        scan_params = {
            'Limit': limit
        }
        
        # Build filter expression
        filter_expressions = []
        expression_attribute_names = {}
        expression_attribute_values = {}
        
        # Status filter (exclude deleted by default)
        if status_filter:
            filter_expressions.append('#status = :status_val')
            expression_attribute_names['#status'] = 'status'
            expression_attribute_values[':status_val'] = status_filter
        
        # User filters
        if user_id_filter:
            filter_expressions.append('userId = :user_id_val')
            expression_attribute_values[':user_id_val'] = user_id_filter
        
        if user_name_filter:
            filter_expressions.append('userName = :user_name_val')
            expression_attribute_values[':user_name_val'] = user_name_filter
        
        # Featured filter
        if featured_filter and featured_filter.lower() == 'true':
            filter_expressions.append('featured = :featured_val')
            expression_attribute_values[':featured_val'] = True
        
        # Add filter expression to scan params
        if filter_expressions:
            scan_params['FilterExpression'] = ' AND '.join(filter_expressions)
        
        if expression_attribute_names:
            scan_params['ExpressionAttributeNames'] = expression_attribute_names
        
        if expression_attribute_values:
            scan_params['ExpressionAttributeValues'] = expression_attribute_values
        
        print(f"🔍 Scan parameters: {json.dumps(scan_params, default=str)}")
        
        # Perform scan
        response = table.scan(**scan_params)
        items = response.get('Items', [])
        
        print(f"📊 Found {len(items)} ads")
        
        # Convert Decimal to float for JSON serialization
        def decimal_to_float(obj):
            if isinstance(obj, Decimal):
                return float(obj)
            return obj
        
        # Process items
        processed_ads = []
        for item in items:
            # Convert Decimals to floats
            processed_item = json.loads(json.dumps(item, default=decimal_to_float))
            
            # Ensure social media fields have defaults
            processed_item.setdefault('likes', 0)
            processed_item.setdefault('viewCount', 0)
            processed_item.setdefault('comments', [])
            processed_item.setdefault('featured', False)
            processed_item.setdefault('status', 'active')
            
            # Increment view count (exclude user viewing own ads)
            if not user_id_filter or processed_item.get('userId') != user_id_filter:
                try:
                    # Increment view count in database
                    table.update_item(
                        Key={'id': processed_item['id']},
                        UpdateExpression='ADD viewCount :inc',
                        ExpressionAttributeValues={':inc': 1}
                    )
                    processed_item['viewCount'] = processed_item.get('viewCount', 0) + 1
                except Exception as e:
                    print(f"⚠️ Failed to increment view count for {processed_item['id']}: {str(e)}")
            
            processed_ads.append(processed_item)
        
        # Sort: featured ads first, then by creation date (newest first)
        processed_ads.sort(key=lambda x: (
            not x.get('featured', False),  # Featured first (False sorts before True)
            -(datetime.fromisoformat(x.get('createdAt', '1970-01-01T00:00:00')).timestamp())
        ))
        
        # Build summary
        summary = {
            'total_count': len(processed_ads),
            'filtered_by': {},
            'has_more': len(items) == limit  # Indicates if there might be more results
        }
        
        # Add filter info to summary
        if user_id_filter:
            summary['filtered_by']['userId'] = user_id_filter
        if user_name_filter:
            summary['filtered_by']['userName'] = user_name_filter
        if featured_filter:
            summary['filtered_by']['featured'] = featured_filter.lower() == 'true'
        if status_filter:
            summary['filtered_by']['status'] = status_filter
        
        print(f"✅ Returning {len(processed_ads)} ads with summary: {json.dumps(summary)}")
        
        # Return success response
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
                'ads': processed_ads,
                'summary': summary,
                'timestamp': datetime.utcnow().isoformat()
            })
        }
        
    except Exception as e:
        print(f"❌ Error fetching ads: {str(e)}")
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
                'error': f'Failed to fetch ads: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            })
        }
