# AWS Implementation Guide - Instagram-like Business Ad Platform

## Overview
This guide provides step-by-step instructions to update your AWS services to support the Instagram-like Business Ad Platform with user management and enhanced features.

## ✅ COMPLETED TASKS
- ✅ Delete functionality (`deleteBusinessAd` Lambda + API Gateway DELETE method)  
- ✅ DELETE endpoint working with soft/hard delete options at root (`/`)
- ✅ **ALL OLD ADS DELETED** - Clean database ready for user features
- ✅ API Gateway properly configured with DELETE method on root resource

---

## 🔄 CURRENT SYSTEM STATUS (Based on AWS Infrastructure Documentation)

### **What's Actually Working:**
- ✅ API Gateway: BusinessAdAPI with proper resource structure
- ✅ Lambda Functions: 4 functions (submitAd, getAds, generatePresignedUrl, deleteBusinessAd)
- ✅ DynamoDB: BusinessAds table (clean, 0 items)
- ✅ S3: business-ad-images-1 bucket (clean, ready for new images)
- ✅ CloudFront: Distribution working for image delivery
- ✅ Delete functionality: Fully operational with confirmation dialogs
- ✅ **submitAd Lambda: ENHANCED VERSION DEPLOYED** - User support with featured logic
- ✅ **getAds Lambda: ENHANCED VERSION DEPLOYED** - User filtering capabilities

### **What Still Needs Implementation:**
- ⏭️ **NEXT**: Test Enhanced System End-to-End
- ⏭️ Verify Flutter App Integration with enhanced backend
- ⏭️ Social media features implementation in Flutter UI
- ⏭️ Enhanced Instagram-like UI transformation

---

## IMPLEMENTATION PRIORITIES

### ✅ Priority 1: Update submitAd Lambda for User Support (COMPLETED)
### ✅ Priority 2: Update getAds Lambda for User Filtering (COMPLETED)
### 🎯 Priority 3: Test Enhanced System End-to-End (CURRENT)
### ⏭️ Priority 4: Verify Flutter App Integration

---

## Required AWS Changes

### 1. Update submitAd Lambda for User Support (CRITICAL FIRST STEP)

#### ✅ Current Status: **READY FOR ENHANCEMENT**
Your current submitAd Lambda function exists but needs user support features added.

#### Step 1.1: Find Your submitAd Function

**EXACT STEPS:**

1. **Open AWS Console**: Go to https://console.aws.amazon.com
2. **Navigate to Lambda**: Search "Lambda" in the services search bar
3. **Find Your submitAd Function**: 
   - Look for the function connected to your POST method
   - Based on your infrastructure: Check API Gateway → BusinessAdAPI → `/` (mvteyq48ic) → POST method
   - The function should be named `submitAd` and handle business ad creation

#### Step 1.2: Update submitAd Lambda Code

**EXACT STEPS:**

1. **Open Your submitAd Function**: Click on the function name in Lambda console
2. **Backup Current Code**: 
   - Scroll to "Code source" section
   - Select all code (Ctrl+A) and copy it
   - Paste into a text file and save as backup
3. **Replace with Enhanced Code**:
   - Delete all existing code in the editor
   - Copy and paste this EXACT enhanced code:

```python
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

# Configuration (use your actual CloudFront domain)
CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'

def lambda_handler(event, context):
    """
    Enhanced Lambda function to create business ads with user support
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
        
        print(f"📝 Received request body: {json.dumps(body, indent=2)}")
        
        # Extract and validate ad data with enhanced user support
        ad_data = {
            'id': body.get('id', str(uuid.uuid4())),
            'title': body.get('title', '').strip(),
            'description': body.get('description', '').strip(),
            'imageUrls': body.get('imageUrls', []),
            'userName': body.get('userName', 'Unknown User').strip(),
            'userId': body.get('userId', '').strip(),
            'userProfileImage': body.get('userProfileImage', ''),
            'createdAt': datetime.now().isoformat(),
            'updatedAt': datetime.now().isoformat(),
            'status': 'active',
            'likes': 0,
            'viewCount': 0,
            'comments': []
        }
        
        # Generate userId if not provided
        if not ad_data['userId']:
            ad_data['userId'] = ad_data['userName'].lower().replace(' ', '_').replace('-', '_')
            print(f"🔑 Generated userId: {ad_data['userId']} from userName: {ad_data['userName']}")
        
        # Add optional fields if they exist
        optional_fields = ['businessName', 'contactInfo', 'location', 'category', 'isActive', 'isFeatured']
        for field in optional_fields:
            if field in body:
                ad_data[field] = body[field]
                print(f"➕ Added optional field {field}: {body[field]}")
        
        # Validate required fields
        validation_errors = []
        
        if not ad_data['title']:
            validation_errors.append('Title is required')
        
        if not ad_data['description']:
            validation_errors.append('Description is required')
        
        if not ad_data['imageUrls']:
            validation_errors.append('At least one image URL is required')
        
        if not ad_data['userName']:
            validation_errors.append('User name is required')
        
        if validation_errors:
            print(f"❌ Validation errors: {validation_errors}")
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({
                    'error': 'Validation failed',
                    'details': validation_errors
                })
            }
        
        # Validate and normalize image URLs
        normalized_urls = []
        for url in ad_data['imageUrls']:
            if url.startswith('data:'):
                print(f"⚠️ Skipping data URL in production")
                continue  # Skip data URLs in production
            elif url.startswith('https://'):
                normalized_urls.append(url)
                print(f"✅ Using HTTPS URL: {url}")
            elif url.startswith('http://'):
                https_url = url.replace('http://', 'https://')
                normalized_urls.append(https_url)
                print(f"🔄 Converted to HTTPS: {https_url}")
            else:
                # Assume it's an S3 key
                cloudfront_url = f"https://{CLOUDFRONT_DOMAIN}/{url.lstrip('/')}"
                normalized_urls.append(cloudfront_url)
                print(f"🌐 Generated CloudFront URL: {cloudfront_url}")
        
        if not normalized_urls:
            print("❌ No valid image URLs after normalization")
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'No valid image URLs provided'})
            }
        
        ad_data['imageUrls'] = normalized_urls
        ad_data['imageCount'] = len(normalized_urls)
        ad_data['featured'] = determine_featured_status(ad_data)
        
        print(f"📊 Ad will be featured: {ad_data['featured']}")
        print(f"👤 User info - Name: {ad_data['userName']}, ID: {ad_data['userId']}")
        
        # Convert to DynamoDB format
        dynamodb_item = json.loads(json.dumps(ad_data), parse_float=Decimal)
        
        # Save to DynamoDB
        try:
            table.put_item(Item=dynamodb_item)
            print(f"✅ Successfully saved ad {ad_data['id']} by user {ad_data['userName']}")
            
        except ClientError as e:
            logger.error(f"💥 DynamoDB error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({'error': 'Failed to save ad to database'})
            }
        
        # Return enhanced success response
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'success': True,
                'message': 'Ad created successfully with user information',
                'adId': ad_data['id'],
                'featured': ad_data['featured'],
                'userName': ad_data['userName'],
                'userId': ad_data['userId'],
                'imageCount': ad_data['imageCount'],
                'createdAt': ad_data['createdAt']
            })
        }
        
    except json.JSONDecodeError as e:
        logger.error(f"💥 JSON decode error: {str(e)}")
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except Exception as e:
        logger.error(f"💥 Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }

def determine_featured_status(ad_data):
    """
    Determine if an ad should be featured based on quality criteria
    """
    score = 0
    
    # More images = higher score
    if ad_data['imageCount'] >= 3:
        score += 2
        print("🌟 +2 points: 3+ images")
    elif ad_data['imageCount'] >= 2:
        score += 1
        print("⭐ +1 point: 2+ images")
    
    # Detailed description = higher score
    if len(ad_data['description']) >= 100:
        score += 2
        print("🌟 +2 points: detailed description (100+ chars)")
    elif len(ad_data['description']) >= 50:
        score += 1
        print("⭐ +1 point: good description (50+ chars)")
    
    # Quality title = higher score
    if len(ad_data['title']) >= 20:
        score += 1
        print("⭐ +1 point: quality title (20+ chars)")
    
    # User has profile image
    if ad_data.get('userProfileImage'):
        score += 1
        print("⭐ +1 point: user has profile image")
    
    # User has detailed name (not "Unknown User")
    if ad_data['userName'] != 'Unknown User' and len(ad_data['userName']) > 5:
        score += 1
        print("⭐ +1 point: detailed user name")
    
    is_featured = score >= 3
    print(f"📊 Total score: {score}/7 - Featured: {is_featured}")
    
    return is_featured
```

4. **Deploy the Enhanced Function**:
   - Click **"Deploy"** button (orange button)
   - Wait for "Changes deployed" confirmation message
```python
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
CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'

def lambda_handler(event, context):
    """
    Enhanced Lambda function to create business ads with user support
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
        
        print(f"📝 Received request body: {json.dumps(body, indent=2)}")
        
        # Extract and validate ad data with enhanced user support
        ad_data = {
            'id': body.get('id', str(uuid.uuid4())),
            'title': body.get('title', '').strip(),
            'description': body.get('description', '').strip(),
            'imageUrls': body.get('imageUrls', []),
            'userName': body.get('userName', 'Unknown User').strip(),
            'userId': body.get('userId', '').strip(),
            'userProfileImage': body.get('userProfileImage', ''),
            'createdAt': datetime.now().isoformat(),
            'updatedAt': datetime.now().isoformat(),
            'status': 'active',
            'likes': 0,
            'viewCount': 0,
            'comments': []
        }
        
        # Generate userId if not provided
        if not ad_data['userId']:
            ad_data['userId'] = ad_data['userName'].lower().replace(' ', '_').replace('-', '_')
            print(f"🔑 Generated userId: {ad_data['userId']} from userName: {ad_data['userName']}")
        
        # Add optional fields if they exist
        optional_fields = ['businessName', 'contactInfo', 'location', 'category', 'isActive', 'isFeatured']
        for field in optional_fields:
            if field in body:
                ad_data[field] = body[field]
                print(f"➕ Added optional field {field}: {body[field]}")
        
        # Validate required fields
        validation_errors = []
        
        if not ad_data['title']:
            validation_errors.append('Title is required')
        
        if not ad_data['description']:
            validation_errors.append('Description is required')
        
        if not ad_data['imageUrls']:
            validation_errors.append('At least one image URL is required')
        
        if not ad_data['userName']:
            validation_errors.append('User name is required')
        
        if validation_errors:
            print(f"❌ Validation errors: {validation_errors}")
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({
                    'error': 'Validation failed',
                    'details': validation_errors
                })
            }
        
        # Validate and normalize image URLs
        normalized_urls = []
        for url in ad_data['imageUrls']:
            if url.startswith('data:'):
                print(f"⚠️ Skipping data URL in production")
                continue  # Skip data URLs in production
            elif url.startswith('https://'):
                normalized_urls.append(url)
                print(f"✅ Using HTTPS URL: {url}")
            elif url.startswith('http://'):
                https_url = url.replace('http://', 'https://')
                normalized_urls.append(https_url)
                print(f"🔄 Converted to HTTPS: {https_url}")
            else:
                # Assume it's an S3 key
                cloudfront_url = f"https://{CLOUDFRONT_DOMAIN}/{url.lstrip('/')}"
                normalized_urls.append(cloudfront_url)
                print(f"🌐 Generated CloudFront URL: {cloudfront_url}")
        
        if not normalized_urls:
            print("❌ No valid image URLs after normalization")
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'No valid image URLs provided'})
            }
        
        ad_data['imageUrls'] = normalized_urls
        ad_data['imageCount'] = len(normalized_urls)
        ad_data['featured'] = determine_featured_status(ad_data)
        
        print(f"📊 Ad will be featured: {ad_data['featured']}")
        print(f"👤 User info - Name: {ad_data['userName']}, ID: {ad_data['userId']}")
        
        # Convert to DynamoDB format
        dynamodb_item = json.loads(json.dumps(ad_data), parse_float=Decimal)
        
        # Save to DynamoDB
        try:
            table.put_item(Item=dynamodb_item)
            print(f"✅ Successfully saved ad {ad_data['id']} by user {ad_data['userName']}")
            
        except ClientError as e:
            logger.error(f"💥 DynamoDB error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({'error': 'Failed to save ad to database'})
            }
        
        # Return enhanced success response
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'success': True,
                'message': 'Ad created successfully with user information',
                'adId': ad_data['id'],
                'featured': ad_data['featured'],
                'userName': ad_data['userName'],
                'userId': ad_data['userId'],
                'imageCount': ad_data['imageCount'],
                'createdAt': ad_data['createdAt']
            })
        }
        
    except json.JSONDecodeError as e:
        logger.error(f"💥 JSON decode error: {str(e)}")
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except Exception as e:
        logger.error(f"💥 Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }

def determine_featured_status(ad_data):
    """
    Determine if an ad should be featured based on quality criteria
    """
    score = 0
    
    # More images = higher score
    if ad_data['imageCount'] >= 3:
        score += 2
        print("🌟 +2 points: 3+ images")
    elif ad_data['imageCount'] >= 2:
        score += 1
        print("⭐ +1 point: 2+ images")
    
    # Detailed description = higher score
    if len(ad_data['description']) >= 100:
        score += 2
        print("🌟 +2 points: detailed description (100+ chars)")
    elif len(ad_data['description']) >= 50:
        score += 1
        print("⭐ +1 point: good description (50+ chars)")
    
    # Quality title = higher score
    if len(ad_data['title']) >= 20:
        score += 1
        print("⭐ +1 point: quality title (20+ chars)")
    
    # User has profile image
    if ad_data.get('userProfileImage'):
        score += 1
        print("⭐ +1 point: user has profile image")
    
    # User has detailed name (not "Unknown User")
    if ad_data['userName'] != 'Unknown User' and len(ad_data['userName']) > 5:
        score += 1
        print("⭐ +1 point: detailed user name")
    
    is_featured = score >= 3
    print(f"📊 Total score: {score}/7 - Featured: {is_featured}")
    
    return is_featured
```

4. **Deploy the Enhanced Function**:
   - Click **"Deploy"** button (orange button)
   - Wait for "Changes deployed" confirmation message

#### Step 1.3: Test Enhanced submitAd Function

**IMMEDIATELY test the updated function:**

1. **Test via AWS Console**:
   - Click **"Test"** tab in Lambda console
   - Create new test event named `test-enhanced-submit`
   - Use this test JSON:

```json
{
  "httpMethod": "POST",
  "body": "{\"title\":\"Test Enhanced Ad\",\"description\":\"Testing enhanced user support with detailed description over 100 characters to trigger featured status. This ad should include proper user information.\",\"imageUrls\":[\"https://example.com/image1.jpg\",\"https://example.com/image2.jpg\"],\"userName\":\"Test User Enhanced\",\"userProfileImage\":\"https://example.com/profile.jpg\"}"
}
```

   - Click **"Test"** button
   - **Expected Result**: Status 200 with enhanced response including user info

2. **Test via Your Flutter App**:
   - Create a new business ad through your app
   - Verify it includes proper userName and userId
   - Check that featured logic works correctly

---

### 2. Update getAds Lambda for User Filtering Support

#### ✅ Current Status: **READY FOR ENHANCEMENT**  
Your current getAds function exists but needs user filtering capabilities.

#### Step 2.1: Find Your Current getAds Function

1. **Navigate to Lambda**: In AWS Console, go to Lambda service  
2. **Find getAds Function**: Look for function that handles GET requests
   - Based on your infrastructure: Check API Gateway → BusinessAdAPI → `/ads` → GET method
   - The function should be named `getAds` and connected to the /ads endpoint

#### Step 2.2: Update getAds Lambda Code

**EXACT STEPS:**

1. **Open Your getAds Function**: Click on the function name
2. **Backup Current Code**: Copy existing code and save as backup
3. **Replace with Enhanced Code**:

```python
import json
import boto3
from boto3.dynamodb.conditions import Key, Attr
from decimal import Decimal
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS services  
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('BusinessAds')

def lambda_handler(event, context):
    """
    Enhanced Lambda function to retrieve business ads with user filtering support
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
        # Extract query parameters
        query_params = event.get('queryStringParameters') or {}
        
        # User filtering
        filter_user_id = query_params.get('userId')
        filter_user_name = query_params.get('userName')
        
        # Status filtering (default to active only)
        status_filter = query_params.get('status', 'active')
        
        # Featured filtering
        featured_only = query_params.get('featured') == 'true'
        
        # Pagination
        limit = int(query_params.get('limit', '50'))
        limit = min(limit, 100)  # Cap at 100 items per request
        
        # Build scan parameters
        scan_params = {
            'FilterExpression': Attr('status').eq(status_filter)
        }
        
        if limit:
            scan_params['Limit'] = limit
        
        # Add user filtering if specified
        if filter_user_id:
            scan_params['FilterExpression'] = scan_params['FilterExpression'] & Attr('userId').eq(filter_user_id)
            print(f"🔍 Filtering by userId: {filter_user_id}")
            
        elif filter_user_name:
            scan_params['FilterExpression'] = scan_params['FilterExpression'] & Attr('userName').eq(filter_user_name)
            print(f"🔍 Filtering by userName: {filter_user_name}")
        
        # Add featured filtering if specified
        if featured_only:
            scan_params['FilterExpression'] = scan_params['FilterExpression'] & Attr('featured').eq(True)
            print("⭐ Filtering for featured ads only")
        
        print(f"📊 Scanning with parameters: {json.dumps(scan_params, default=str)}")
        
        # Execute scan
        response = table.scan(**scan_params)
        items = response.get('Items', [])
        
        print(f"📝 Found {len(items)} matching ads")
        
        # Convert Decimal types to float/int for JSON serialization
        serialized_items = []
        for item in items:
            serialized_item = json.loads(json.dumps(item, default=decimal_default))
            
            # Ensure all required fields exist with defaults
            serialized_item.setdefault('userName', 'Unknown User')
            serialized_item.setdefault('userId', 'unknown_user')
            serialized_item.setdefault('userProfileImage', '')
            serialized_item.setdefault('status', 'active')
            serialized_item.setdefault('likes', 0)
            serialized_item.setdefault('viewCount', 0)
            serialized_item.setdefault('comments', [])
            serialized_item.setdefault('featured', False)
            
            # Increment view count (if not filtered by user - don't count user viewing own posts)
            if not filter_user_id and not filter_user_name:
                try:
                    table.update_item(
                        Key={'id': item['id']},
                        UpdateExpression='ADD viewCount :inc',
                        ExpressionAttributeValues={':inc': 1}
                    )
                    serialized_item['viewCount'] = serialized_item.get('viewCount', 0) + 1
                except Exception as e:
                    print(f"⚠️ Failed to increment view count for {item['id']}: {str(e)}")
            
            serialized_items.append(serialized_item)
        
        # Sort by creation date (newest first) and featured status
        serialized_items.sort(key=lambda x: (
            x.get('featured', False),  # Featured first
            x.get('createdAt', '')     # Then by creation date
        ), reverse=True)
        
        # Build response summary
        response_summary = {
            'total_count': len(serialized_items),
            'filtered_by': {},
            'has_more': 'LastEvaluatedKey' in response
        }
        
        if filter_user_id:
            response_summary['filtered_by']['userId'] = filter_user_id
        if filter_user_name:
            response_summary['filtered_by']['userName'] = filter_user_name
        if featured_only:
            response_summary['filtered_by']['featured'] = True
        if status_filter != 'active':
            response_summary['filtered_by']['status'] = status_filter
        
        print(f"✅ Returning {len(serialized_items)} ads")
        print(f"📊 Response summary: {json.dumps(response_summary)}")
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'success': True,
                'ads': serialized_items,
                'summary': response_summary,
                'timestamp': response.get('ResponseMetadata', {}).get('HTTPHeaders', {}).get('date', '')
            })
        }
        
    except Exception as e:
        logger.error(f"💥 Error retrieving ads: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'error': f'Failed to retrieve ads: {str(e)}',
                'success': False
            })
        }

def decimal_default(obj):
    """Convert Decimal objects to int or float for JSON serialization"""
    if isinstance(obj, Decimal):
        if obj % 1 == 0:
            return int(obj)
        else:
            return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
```

4. **Deploy the Enhanced Function**:
   - Click **"Deploy"** button
   - Wait for "Changes deployed" confirmation

```python
import json
import boto3
from boto3.dynamodb.conditions import Key, Attr
from decimal import Decimal
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS services  
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('BusinessAds')

def lambda_handler(event, context):
    """
    Enhanced Lambda function to retrieve business ads with user filtering support
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
        # Extract query parameters
        query_params = event.get('queryStringParameters') or {}
        
        # User filtering
        filter_user_id = query_params.get('userId')
        filter_user_name = query_params.get('userName')
        
        # Status filtering (default to active only)
        status_filter = query_params.get('status', 'active')
        
        # Featured filtering
        featured_only = query_params.get('featured') == 'true'
        
        # Pagination
        limit = int(query_params.get('limit', '50'))
        limit = min(limit, 100)  # Cap at 100 items per request
        
        # Build scan parameters
        scan_params = {
            'FilterExpression': Attr('status').eq(status_filter)
        }
        
        if limit:
            scan_params['Limit'] = limit
        
        # Add user filtering if specified
        if filter_user_id:
            scan_params['FilterExpression'] = scan_params['FilterExpression'] & Attr('userId').eq(filter_user_id)
            print(f"🔍 Filtering by userId: {filter_user_id}")
            
        elif filter_user_name:
            scan_params['FilterExpression'] = scan_params['FilterExpression'] & Attr('userName').eq(filter_user_name)
            print(f"🔍 Filtering by userName: {filter_user_name}")
        
        # Add featured filtering if specified
        if featured_only:
            scan_params['FilterExpression'] = scan_params['FilterExpression'] & Attr('featured').eq(True)
            print("⭐ Filtering for featured ads only")
        
        print(f"📊 Scanning with parameters: {json.dumps(scan_params, default=str)}")
        
        # Execute scan
        response = table.scan(**scan_params)
        items = response.get('Items', [])
        
        print(f"📝 Found {len(items)} matching ads")
        
        # Convert Decimal types to float/int for JSON serialization
        serialized_items = []
        for item in items:
            serialized_item = json.loads(json.dumps(item, default=decimal_default))
            
            # Ensure all required fields exist with defaults
            serialized_item.setdefault('userName', 'Unknown User')
            serialized_item.setdefault('userId', 'unknown_user')
            serialized_item.setdefault('userProfileImage', '')
            serialized_item.setdefault('status', 'active')
            serialized_item.setdefault('likes', 0)
            serialized_item.setdefault('viewCount', 0)
            serialized_item.setdefault('comments', [])
            serialized_item.setdefault('featured', False)
            
            # Increment view count (if not filtered by user - don't count user viewing own posts)
            if not filter_user_id and not filter_user_name:
                try:
                    table.update_item(
                        Key={'id': item['id']},
                        UpdateExpression='ADD viewCount :inc',
                        ExpressionAttributeValues={':inc': 1}
                    )
                    serialized_item['viewCount'] = serialized_item.get('viewCount', 0) + 1
                except Exception as e:
                    print(f"⚠️ Failed to increment view count for {item['id']}: {str(e)}")
            
            serialized_items.append(serialized_item)
        
        # Sort by creation date (newest first) and featured status
        serialized_items.sort(key=lambda x: (
            x.get('featured', False),  # Featured first
            x.get('createdAt', '')     # Then by creation date
        ), reverse=True)
        
        # Build response summary
        response_summary = {
            'total_count': len(serialized_items),
            'filtered_by': {},
            'has_more': 'LastEvaluatedKey' in response
        }
        
        if filter_user_id:
            response_summary['filtered_by']['userId'] = filter_user_id
        if filter_user_name:
            response_summary['filtered_by']['userName'] = filter_user_name
        if featured_only:
            response_summary['filtered_by']['featured'] = True
        if status_filter != 'active':
            response_summary['filtered_by']['status'] = status_filter
        
        print(f"✅ Returning {len(serialized_items)} ads")
        print(f"📊 Response summary: {json.dumps(response_summary)}")
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'success': True,
                'ads': serialized_items,
                'summary': response_summary,
                'timestamp': response.get('ResponseMetadata', {}).get('HTTPHeaders', {}).get('date', '')
            })
        }
        
    except Exception as e:
        logger.error(f"💥 Error retrieving ads: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'error': f'Failed to retrieve ads: {str(e)}',
                'success': False
            })
        }

def decimal_default(obj):
    """Convert Decimal objects to int or float for JSON serialization"""
    if isinstance(obj, Decimal):
        if obj % 1 == 0:
            return int(obj)
        else:
            return float(obj)
    raise TypeError(f"Object of type {type(obj)} is not JSON serializable")
```

4. **Deploy the Enhanced Function**:
   - Click **"Deploy"** button
   - Wait for "Changes deployed" confirmation

#### Step 2.3: Test Enhanced getAds Function

**Test the user filtering functionality:**

1. **Test All Ads** (no filter):
   - Test event JSON: `{"httpMethod": "GET"}`
   - Should return all active ads

2. **Test User Filter**:
   - Test event JSON: `{"httpMethod": "GET", "queryStringParameters": {"userId": "test_user_enhanced"}}`
   - Should return only ads by that specific user

3. **Test Featured Filter**:
   - Test event JSON: `{"httpMethod": "GET", "queryStringParameters": {"featured": "true"}}`
   - Should return only featured ads

---

### 3. Test Enhanced System End-to-End

#### Step 3.1: Test Enhanced submitAd Function

**Test the updated function immediately:**

1. **Test via AWS Console**:
   - In Lambda console, click **"Test"** tab
   - Create new test event named `test-enhanced-submit`
   - Use this test JSON:

```json
{
  "httpMethod": "POST",
  "body": "{\"title\":\"Test Enhanced Ad\",\"description\":\"Testing enhanced user support with detailed description over 100 characters to trigger featured status. This ad should include proper user information and demonstrate the enhanced quality scoring system.\",\"imageUrls\":[\"https://example.com/image1.jpg\",\"https://example.com/image2.jpg\",\"https://example.com/image3.jpg\"],\"userName\":\"Test User Enhanced\",\"userProfileImage\":\"https://example.com/profile.jpg\"}"
}
```

   - Click **"Test"** button
   - **Expected Result**: Status 200 with enhanced response including user info and featured=true

2. **Test via API Endpoint**:
   - Use this PowerShell command to test your actual endpoint:

```powershell
$body = @{
    title = "Real Test Ad"
    description = "This is a comprehensive test of the enhanced ad creation system with full user support and detailed metadata to ensure proper featured status calculation."
    imageUrls = @("https://d11c102y3uxwr7.cloudfront.net/ads/test1.jpg", "https://d11c102y3uxwr7.cloudfront.net/ads/test2.jpg")
    userName = "John Doe Business"
    userProfileImage = "https://d11c102y3uxwr7.cloudfront.net/profiles/john.jpg"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/" -Method POST -Body $body -ContentType "application/json"
```

#### Step 3.2: Test Enhanced getAds Function

**Test the user filtering functionality:**

1. **Test All Ads** (no filter):
   - Test event JSON: `{"httpMethod": "GET"}`
   - Should return all active ads with enhanced user information

2. **Test User Filter**:
   - Test event JSON: `{"httpMethod": "GET", "queryStringParameters": {"userId": "john_doe_business"}}`
   - Should return only ads by that specific user

3. **Test Featured Filter**:
   - Test event JSON: `{"httpMethod": "GET", "queryStringParameters": {"featured": "true"}}`
   - Should return only featured ads

4. **Test via API Endpoints**:

```powershell
# Get all ads
Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads" -Method GET

# Get ads by specific user
Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads?userId=john_doe_business" -Method GET

# Get only featured ads
Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads?featured=true" -Method GET
```

#### Step 3.3: Verify Delete Functionality Still Works

**Ensure delete functionality remains operational:**

```powershell
# Create a test ad to delete
$testAd = @{
    title = "Test Ad for Deletion"
    description = "This ad will be deleted to test functionality after enhancements"
    imageUrls = @("https://d11c102y3uxwr7.cloudfront.net/ads/test.jpg")
    userName = "Test User Delete"
} | ConvertTo-Json

$createResult = Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/" -Method POST -Body $testAd -ContentType "application/json"

# Delete the test ad (soft delete)
$deleteBody = @{
    id = $createResult.adId
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/" -Method DELETE -Body $deleteBody -ContentType "application/json"
```

---

### 4. Verify Flutter App Integration

#### ✅ Current Status: SHOULD WORK WITH MINIMAL CHANGES
Your Flutter app API service should already be compatible with the enhanced backend.

#### Step 4.1: Check Current Implementation

1. **Verify API Service**: Open `lib/services/api_service.dart`
2. **Check submitBusinessAd Method**: Ensure it can send user information
3. **Check User Fields**: Verify these fields are being sent:
   - `userName` 
   - `userId` (can be auto-generated)
   - `userProfileImage` (optional)

#### Step 4.2: Test Flutter App

1. **Create New Business Ad**:
   - Use your Flutter app to create a new business ad
   - Verify userName appears correctly (not "Unknown User")
   - Check if the ad gets featured status for high-quality content

2. **Test User Features**:
   - Navigate to user profiles
   - Verify user filtering works in ImageDetailScreen
   - Test delete functionality with confirmation dialogs

#### Step 4.3: Monitor Backend Logs

1. **Check Lambda Logs**:
   - Go to AWS CloudWatch → Log groups
   - Monitor `/aws/lambda/submitAd` logs
   - Monitor `/aws/lambda/getAds` logs
   - Look for user information being processed correctly

---

### 5. API Endpoint Testing Reference

#### Your Current API Endpoints:

```bash
# Base URL
BASE_URL="https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod"

# 1. Create Business Ad (Enhanced)
curl -X POST "$BASE_URL/" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My Business Ad",
    "description": "A detailed description of my business offering with comprehensive information to ensure high quality scoring and featured status potential.",
    "imageUrls": ["https://d11c102y3uxwr7.cloudfront.net/ads/image1.jpg"],
    "userName": "Business Owner Name",
    "userProfileImage": "https://d11c102y3uxwr7.cloudfront.net/profiles/owner.jpg"
  }'

# 2. Get All Business Ads (Enhanced)
curl -X GET "$BASE_URL/ads"

# 3. Get User-Specific Ads
curl -X GET "$BASE_URL/ads?userId=business_owner_name"

# 4. Get Featured Ads Only
curl -X GET "$BASE_URL/ads?featured=true"

# 5. Delete Business Ad
curl -X DELETE "$BASE_URL/" \
  -H "Content-Type: application/json" \
  -d '{
    "id": "ad-id-here"
  }'

# 6. Generate Presigned URL
curl -X GET "$BASE_URL/presigned-url?filename=image.jpg&contentType=image/jpeg"
```

---

## ✅ Implementation Checklist

### **Phase 1: Lambda Function Updates**
- [ ] Update submitAd Lambda with user support code
- [ ] Deploy submitAd function and verify deployment
- [ ] Test submitAd with enhanced user information
- [ ] Update getAds Lambda with user filtering code  
- [ ] Deploy getAds function and verify deployment
- [ ] Test getAds with user filtering capabilities

### **Phase 2: System Integration Testing**
- [ ] Test enhanced ad creation via API endpoints
- [ ] Verify user filtering works correctly
- [ ] Test featured ad logic and scoring
- [ ] Confirm delete functionality still operational
- [ ] Test Flutter app integration

### **Phase 3: Production Validation**
- [ ] Create real ads with proper user information
- [ ] Verify usernames display correctly in Flutter app
- [ ] Test user profile filtering in app
- [ ] Monitor CloudWatch logs for any errors
- [ ] Validate end-to-end user experience

---

## 🎯 Success Criteria

### **Enhanced submitAd Function:**
✅ Creates ads with userName, userId, userProfileImage  
✅ Generates userId from userName if not provided  
✅ Calculates featured status based on quality criteria  
✅ Returns enhanced response with user information  

### **Enhanced getAds Function:**
✅ Filters ads by userId or userName  
✅ Supports featured-only filtering  
✅ Increments view counts automatically  
✅ Returns ads with full user information  

### **System Integration:**
✅ Flutter app displays usernames correctly  
✅ User profile screens show filtered content  
✅ Delete functionality remains operational  
✅ All API endpoints respond with proper CORS headers  

---

## 🔧 Troubleshooting Guide

### **Common Issues and Solutions:**

**Issue**: submitAd returns "userName required" error  
**Solution**: Ensure your Flutter app sends userName in POST requests

**Issue**: getAds returns empty results with userId filter  
**Solution**: Check that ads were created with proper userId after enhancement

**Issue**: Featured ads not showing correctly  
**Solution**: Verify ads meet quality criteria:
- 3+ images OR detailed description (100+ chars) OR quality title (20+ chars) OR user profile image OR detailed user name

**Issue**: Delete functionality stops working  
**Solution**: Verify deleteBusinessAd Lambda still has correct permissions and API Gateway integration

**Issue**: Flutter app shows "Unknown User"  
**Solution**: Check that enhanced submitAd Lambda is deployed and userName is being sent from app

---

## 📊 Expected Results After Implementation

### **Database State:**
- All new ads will have complete user information
- Featured ads will be automatically identified based on quality
- Social media fields (likes, viewCount, comments) will be initialized

### **API Behavior:**
- POST `/` creates ads with enhanced user support
- GET `/ads` returns ads with user filtering capabilities  
- DELETE `/` continues to work for ad deletion
- All endpoints support proper CORS

### **Flutter App:**
- Usernames display correctly throughout the app
- User profiles show only that user's ads
- Delete confirmation dialogs work properly
- Featured ads appear prominently in feeds

---

## 🚀 Next Steps After Completion

Once you've successfully implemented these changes:

1. **Create Quality Test Content**: Add several test ads with good descriptions and multiple images
2. **Verify Featured Logic**: Confirm high-quality ads get featured status automatically  
3. **Test User Journeys**: Navigate through user profiles and verify filtering works
4. **Monitor Performance**: Check CloudWatch logs for any errors or performance issues
5. **Plan Social Features**: Consider implementing likes, comments, and follow functionality
6. **Instagram-like UI**: Follow your Instagram UI implementation guide for visual enhancements

---

*🎯 Remember: Test each step thoroughly before proceeding to the next. The enhanced system will provide the foundation for your Instagram-like social media platform with proper user management.*

```python
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
CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'

def lambda_handler(event, context):
    """
    Enhanced Lambda function to create business ads with user support
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
        
        print(f"📝 Received request body: {json.dumps(body, indent=2)}")
        
        # Extract and validate ad data with enhanced user support
        ad_data = {
            'id': body.get('id', str(uuid.uuid4())),
            'title': body.get('title', '').strip(),
            'description': body.get('description', '').strip(),
            'imageUrls': body.get('imageUrls', []),
            'userName': body.get('userName', 'Unknown User').strip(),
            'userId': body.get('userId', '').strip(),
            'userProfileImage': body.get('userProfileImage', ''),
            'createdAt': datetime.now().isoformat(),
            'updatedAt': datetime.now().isoformat(),
            'status': 'active',
            'likes': 0,
            'viewCount': 0,
            'comments': []
        }
        
        # Generate userId if not provided
        if not ad_data['userId']:
            ad_data['userId'] = ad_data['userName'].lower().replace(' ', '_').replace('-', '_')
            print(f"🔑 Generated userId: {ad_data['userId']} from userName: {ad_data['userName']}")
        
        # Add optional fields if they exist
        optional_fields = ['businessName', 'contactInfo', 'location', 'category', 'isActive', 'isFeatured']
        for field in optional_fields:
            if field in body:
                ad_data[field] = body[field]
                print(f"➕ Added optional field {field}: {body[field]}")
        
        # Validate required fields
        validation_errors = []
        
        if not ad_data['title']:
            validation_errors.append('Title is required')
        
        if not ad_data['description']:
            validation_errors.append('Description is required')
        
        if not ad_data['imageUrls']:
            validation_errors.append('At least one image URL is required')
        
        if not ad_data['userName']:
            validation_errors.append('User name is required')
        
        if validation_errors:
            print(f"❌ Validation errors: {validation_errors}")
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({
                    'error': 'Validation failed',
                    'details': validation_errors
                })
            }
        
        # Validate and normalize image URLs
        normalized_urls = []
        for url in ad_data['imageUrls']:
            if url.startswith('data:'):
                print(f"⚠️ Skipping data URL in production")
                continue  # Skip data URLs in production
            elif url.startswith('https://'):
                normalized_urls.append(url)
                print(f"✅ Using HTTPS URL: {url}")
            elif url.startswith('http://'):
                https_url = url.replace('http://', 'https://')
                normalized_urls.append(https_url)
                print(f"🔄 Converted to HTTPS: {https_url}")
            else:
                # Assume it's an S3 key
                cloudfront_url = f"https://{CLOUDFRONT_DOMAIN}/{url.lstrip('/')}"
                normalized_urls.append(cloudfront_url)
                print(f"🌐 Generated CloudFront URL: {cloudfront_url}")
        
        if not normalized_urls:
            print("❌ No valid image URLs after normalization")
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'No valid image URLs provided'})
            }
        
        ad_data['imageUrls'] = normalized_urls
        ad_data['imageCount'] = len(normalized_urls)
        ad_data['featured'] = determine_featured_status(ad_data)
        
        print(f"📊 Ad will be featured: {ad_data['featured']}")
        print(f"👤 User info - Name: {ad_data['userName']}, ID: {ad_data['userId']}")
        
        # Convert to DynamoDB format
        dynamodb_item = json.loads(json.dumps(ad_data), parse_float=Decimal)
        
        # Save to DynamoDB
        try:
            table.put_item(Item=dynamodb_item)
            print(f"✅ Successfully saved ad {ad_data['id']} by user {ad_data['userName']}")
            
        except ClientError as e:
            logger.error(f"💥 DynamoDB error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({'error': 'Failed to save ad to database'})
            }
        
        # Return enhanced success response
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'success': True,
                'message': 'Ad created successfully with user information',
                'adId': ad_data['id'],
                'featured': ad_data['featured'],
                'userName': ad_data['userName'],
                'userId': ad_data['userId'],
                'imageCount': ad_data['imageCount'],
                'createdAt': ad_data['createdAt']
            })
        }
        
    except json.JSONDecodeError as e:
        logger.error(f"💥 JSON decode error: {str(e)}")
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except Exception as e:
        logger.error(f"💥 Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': f'Internal server error: {str(e)}'})
        }

def determine_featured_status(ad_data):
    """
    Determine if an ad should be featured based on quality criteria
    """
    score = 0
    
    # More images = higher score
    if ad_data['imageCount'] >= 3:
        score += 2
        print("🌟 +2 points: 3+ images")
    elif ad_data['imageCount'] >= 2:
        score += 1
        print("⭐ +1 point: 2+ images")
    
    # Detailed description = higher score
    if len(ad_data['description']) >= 100:
        score += 2
        print("🌟 +2 points: detailed description (100+ chars)")
    elif len(ad_data['description']) >= 50:
        score += 1
        print("⭐ +1 point: good description (50+ chars)")
    
    # Quality title = higher score
    if len(ad_data['title']) >= 20:
        score += 1
        print("⭐ +1 point: quality title (20+ chars)")
    
    # User has profile image
    if ad_data.get('userProfileImage'):
        score += 1
        print("⭐ +1 point: user has profile image")
    
    # User has detailed name (not "Unknown User")
    if ad_data['userName'] != 'Unknown User' and len(ad_data['userName']) > 5:
        score += 1
        print("⭐ +1 point: detailed user name")
    
    is_featured = score >= 3
    print(f"📊 Total score: {score}/7 - Featured: {is_featured}")
    
    return is_featured
```

4. **Deploy the Enhanced Function**:
   - Click **"Deploy"** button
   - Wait for "Changes deployed" confirmation

#### Step 2.3: Test Enhanced submitAd Function

**Test with user information:**

---

### 3. Update getAds Lambda for User Filtering

#### ✅ Current Status: NEEDS IMPLEMENTATION
Your current getAds function doesn't support user filtering. You need to enhance it.

#### Step 3.1: Find Your Current getAds Function

1. **Navigate to Lambda**: In AWS Console, go to Lambda service
2. **Find getAds Function**: Look for the function that handles GET requests
   - Check your API Gateway /ads GET method to see which Lambda it calls
   - It might be named: `getAds`, `retrieveAds`, `businessAdGet`, or similar

#### Step 3.2: Update getAds Lambda Code

**EXACT STEPS:**

1. **Open Your getAds Function**: Click on the function name
2. **Backup Current Code**: Copy existing code and save as backup
3. **Replace with Enhanced Code**:

```python
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

def lambda_handler(event, context):
    """
    Enhanced Lambda function to retrieve business ads with user filtering
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
        # Parse query parameters
        query_params = event.get('queryStringParameters') or {}
        
        print(f"📥 Query parameters: {json.dumps(query_params, indent=2)}")
        
        # Get filtering parameters
        is_featured = query_params.get('featured') == 'true'
        user_id = query_params.get('userId')
        user_name = query_params.get('userName')
        limit = min(int(query_params.get('limit', 50)), 100)
        
        print(f"🔍 Filters - Featured: {is_featured}, UserID: {user_id}, UserName: {user_name}, Limit: {limit}")
        
        # Build filter expression
        filter_expressions = []
        
        # Always filter for active ads (exclude deleted ones)
        filter_expressions.append(boto3.dynamodb.conditions.Attr('status').eq('active'))
        
        if is_featured:
            filter_expressions.append(boto3.dynamodb.conditions.Attr('featured').eq(True))
            print("⭐ Filtering for featured ads only")
        
        if user_id:
            filter_expressions.append(boto3.dynamodb.conditions.Attr('userId').eq(user_id))
            print(f"👤 Filtering for userId: {user_id}")
        
        if user_name:
            filter_expressions.append(boto3.dynamodb.conditions.Attr('userName').eq(user_name))
            print(f"👤 Filtering for userName: {user_name}")
        
        # Combine filter expressions
        combined_filter = filter_expressions[0]
        for expr in filter_expressions[1:]:
            combined_filter = combined_filter & expr
        
        # Build scan parameters
        scan_params = {
            'Limit': limit,
            'FilterExpression': combined_filter
        }
        
        # Handle pagination
        if 'lastKey' in query_params:
            try:
                last_key = json.loads(query_params['lastKey'])
                scan_params['ExclusiveStartKey'] = last_key
                print(f"📄 Continuing from last key: {last_key}")
            except Exception as e:
                logger.warning(f"⚠️ Invalid lastKey parameter: {e}")
        
        # Scan the table
        try:
            print(f"🔍 Scanning table with params: {scan_params}")
            response = table.scan(**scan_params)
            items = response.get('Items', [])
            
            print(f"📊 Raw scan returned {len(items)} items")
            
            # Convert and process ads
            ads = []
            for item in items:
                ad = convert_decimal_to_float(item)
                
                # Ensure required fields exist with defaults
                ad.setdefault('id', '')
                ad.setdefault('title', 'Untitled')
                ad.setdefault('description', '')
                ad.setdefault('userName', 'Unknown User')
                ad.setdefault('userId', 'unknown')
                ad.setdefault('likes', 0)
                ad.setdefault('viewCount', 0)
                ad.setdefault('imageUrls', [])
                ad.setdefault('status', 'active')
                ad.setdefault('featured', False)
                ad.setdefault('createdAt', '')
                ad.setdefault('updatedAt', '')
                ad.setdefault('userProfileImage', '')
                ad.setdefault('comments', [])
                
                ads.append(ad)
            
            # Sort by creation date (newest first)
            ads.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
            
            print(f"✅ Processed {len(ads)} ads successfully")
            
            # Prepare response
            result = {
                'success': True,
                'ads': ads,
                'count': len(ads),
                'hasMore': 'LastEvaluatedKey' in response,
                'filters': {
                    'featured': is_featured,
                    'userId': user_id,
                    'userName': user_name,
                    'limit': limit
                },
                'metadata': {
                    'timestamp': datetime.now().isoformat(),
                    'totalScanned': len(items),
                    'totalReturned': len(ads)
                }
            }
            
            if 'LastEvaluatedKey' in response:
                result['lastKey'] = json.dumps(response['LastEvaluatedKey'], default=str)
                print(f"📄 Has more data, lastKey provided")
            
            logger.info(f"🎉 Retrieved {len(ads)} ads with filters: featured={is_featured}, userId={user_id}")
            
            return {
                'statusCode': 200,
                'headers': headers,
                'body': json.dumps(result)
            }
            
        except ClientError as e:
            logger.error(f"💥 DynamoDB error: {str(e)}")
            return {
                'statusCode': 500,
                'headers': headers,
                'body': json.dumps({
                    'success': False,
                    'error': 'Database error',
                    'details': str(e)
                })
            }
        
    except Exception as e:
        logger.error(f"💥 Unexpected error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({
                'success': False,
                'error': f'Internal server error: {str(e)}'
            })
        }

def convert_decimal_to_float(obj):
    """
    Convert Decimal objects to float for JSON serialization
    """
    if isinstance(obj, list):
        return [convert_decimal_to_float(item) for item in obj]
    elif isinstance(obj, dict):
        return {key: convert_decimal_to_float(value) for key, value in obj.items()}
    elif isinstance(obj, Decimal):
        return float(obj)
    else:
        return obj
```

4. **Deploy the Enhanced Function**:
   - Click **"Deploy"** button
   - Wait for confirmation

#### Step 3.3: Test Enhanced getAds Function

**Test the new filtering capabilities:**

---

### 4. Comprehensive Testing

#### Step 4.1: Test DynamoDB Migration Results

**Run this PowerShell command to verify migration:**

```python
```powershell
# Check if ads now have user information
Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads" -Method GET | Select-Object -ExpandProperty ads | Select-Object id, title, userName, userId, status, likes -First 5
```

**Expected Result**: Should show userName, userId, status, likes fields

#### Step 4.2: Test Enhanced Ad Creation

**Test creating an ad with user information:**

```powershell
$body = @{
    title = "Test Ad with User Info"
    description = "This is a comprehensive test of the enhanced ad creation system with full user support and detailed metadata"
    imageUrls = @("https://d11c102y3uxwr7.cloudfront.net/ads/test.jpg")
    userName = "John Doe Business"
    userId = "john_doe_business"
    userProfileImage = "https://d11c102y3uxwr7.cloudfront.net/profiles/john.jpg"
    businessName = "John's Amazing Business"
    location = "New York, NY"
    category = "Food & Beverage"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/" -Method POST -Body $body -ContentType "application/json"
```

**Expected Result**: Should return success with user information and featured status

#### Step 4.3: Test User Filtering

**Test filtering ads by user:**

```powershell
# Get ads by specific user
Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads?userId=john_doe_business" -Method GET

# Get only featured ads
Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads?featured=true" -Method GET

# Get ads by username
Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads?userName=John%20Doe%20Business" -Method GET
```

#### Step 4.4: Test Delete Functionality (Already Working)

**Verify delete still works after updates:**

```powershell
# Create a test ad to delete
$testAd = @{
    title = "Test Ad for Deletion"
    description = "This ad will be deleted to test functionality"
    imageUrls = @("https://d11c102y3uxwr7.cloudfront.net/ads/test.jpg")
    userName = "Test User"
} | ConvertTo-Json

$createResult = Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/" -Method POST -Body $testAd -ContentType "application/json"

# Delete the test ad
$deleteBody = @{
    action = "delete"
    adId = $createResult.adId
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/" -Method DELETE -Body $deleteBody -ContentType "application/json"
```

---

### 5. Verification Checklist

#### ✅ Tasks to Complete:

**Phase 1: DynamoDB Migration**
- [ ] Create `migrateBusinessAdsSchema` Lambda function
- [ ] Run migration and verify all ads have user fields
- [ ] Check migration logs for success

**Phase 2: Enhanced Ad Creation**
- [ ] Update `submitAd` Lambda function with user support
- [ ] Test creating ads with user information
- [ ] Verify featured status calculation works

**Phase 3: Enhanced Ad Retrieval**
- [ ] Update `getAds` Lambda function with filtering
- [ ] Test user filtering by userId and userName
- [ ] Test featured ads filtering

**Phase 4: Integration Testing**
- [ ] Verify delete functionality still works
- [ ] Test your Flutter app with new features
- [ ] Confirm usernames display properly in app

#### 🎯 Success Criteria:

1. **User Information**: All ads have userName, userId, status fields
2. **Filtering**: Can get ads by specific user or featured status
3. **Featured Logic**: High-quality ads automatically marked as featured
4. **Delete Works**: Soft and hard delete functionality operational
5. **Flutter Integration**: App displays usernames correctly

---

### 6. Troubleshooting

#### Common Issues and Solutions:

**Issue**: Migration fails with permissions error
**Solution**: Ensure Lambda execution role has `AmazonDynamoDBFullAccess`

**Issue**: submitAd function returns "userName required" error
**Solution**: Update your Flutter app to send userName in requests

**Issue**: getAds returns empty results with userId filter
**Solution**: Check that migration added userId fields to all existing ads

**Issue**: Featured ads not working
**Solution**: Verify ads meet quality criteria (detailed description, multiple images, etc.)

---

### 7. Next Steps After Completion

Once all AWS changes are complete:

1. **Test Flutter App**: Verify usernames display correctly
2. **User Profile Features**: Implement user profile screens
3. **Instagram-like UI**: Follow INSTAGRAM_UI_IMPLEMENTATION_GUIDE.md
4. **Social Features**: Add likes, comments, and follow functionality

---

*🚀 Complete these tasks in order, testing each step before proceeding to the next!*

```python
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

def lambda_handler(event, context):
    """
    Enhanced Lambda function to retrieve business ads with user filtering
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
        # Parse query parameters
        query_params = event.get('queryStringParameters') or {}
        
        # Get filtering parameters
        is_featured = query_params.get('featured') == 'true'
        user_id = query_params.get('userId')
        user_name = query_params.get('userName')
        limit = min(int(query_params.get('limit', 50)), 100)
        
        # Build filter expression
        filter_expressions = [boto3.dynamodb.conditions.Attr('status').eq('active')]
        
        if is_featured:
            filter_expressions.append(boto3.dynamodb.conditions.Attr('featured').eq(True))
        
        if user_id:
            filter_expressions.append(boto3.dynamodb.conditions.Attr('userId').eq(user_id))
        
        if user_name:
            filter_expressions.append(boto3.dynamodb.conditions.Attr('userName').eq(user_name))
        
        # Combine filter expressions
        combined_filter = filter_expressions[0]
        for expr in filter_expressions[1:]:
            combined_filter = combined_filter & expr
        
        # Build scan parameters
        scan_params = {
            'Limit': limit,
            'FilterExpression': combined_filter
        }
        
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
            
            # Convert and process ads
            ads = []
            for item in items:
                ad = convert_decimal_to_float(item)
                
                # Ensure required fields
                ad.setdefault('id', '')
                ad.setdefault('title', '')
                ad.setdefault('userName', 'Unknown User')
                ad.setdefault('userId', 'unknown')
                ad.setdefault('likes', 0)
                ad.setdefault('viewCount', 0)
                ad.setdefault('imageUrls', [])
                
                ads.append(ad)
            
            # Sort by creation date (newest first)
            ads.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
            
            # Prepare response
            result = {
                'success': True,
                'ads': ads,
                'count': len(ads),
                'hasMore': 'LastEvaluatedKey' in response,
                'filters': {
                    'featured': is_featured,
                    'userId': user_id,
                    'userName': user_name
                }
            }
            
            if 'LastEvaluatedKey' in response:
                result['lastKey'] = json.dumps(response['LastEvaluatedKey'], default=str)
            
            logger.info(f"Retrieved {len(ads)} ads with filters: featured={is_featured}, userId={user_id}")
            
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
                'body': json.dumps({'error': 'Database error'})
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
```

---

### 5. Update API Gateway Resources

#### Step 5.1: Add Delete Endpoint

1. Go to AWS Console → API Gateway → BusinessAdAPI
2. Select the root resource `/`
3. Click "Actions" → "Create Method"
4. Choose "DELETE" from dropdown
5. Click the checkmark
6. Configure:
   - Integration type: Lambda Function
   - Lambda Function: `deleteBusinessAd`
   - Use Lambda Proxy integration: ✓
7. Click "Save"
8. Grant permission when prompted

#### Step 5.2: Enable CORS for DELETE

1. Select the DELETE method
2. Click "Actions" → "Enable CORS"
3. Configure:
   - Access-Control-Allow-Origin: `*`
   - Access-Control-Allow-Headers: `Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token`
   - Access-Control-Allow-Methods: Select `DELETE, OPTIONS, POST`
4. Click "Enable CORS and replace existing CORS headers"

#### Step 5.3: Deploy API Changes

1. Click "Actions" → "Deploy API"
2. Select deployment stage: `prod`
3. Add deployment description: "Added delete functionality and user support"
4. Click "Deploy"

---

### 6. Test Your Updates

#### Step 6.1: Test Delete Functionality

```bash
curl -X POST https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ \
  -H "Content-Type: application/json" \
  -d '{
    "action": "delete",
    "adId": "your-ad-id-here",
    "hardDelete": false
  }'
```

#### Step 6.2: Test User Filtering

```bash
# Get ads by specific user
curl "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads?userId=john_doe"

# Get featured ads only
curl "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ads?featured=true"
```

#### Step 6.3: Test Enhanced Ad Creation

```bash
curl -X POST https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/ \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Business Ad",
    "description": "This is a test ad with user information",
    "imageUrls": ["https://d11c102y3uxwr7.cloudfront.net/ads/test.jpg"],
    "userName": "John Doe",
    "userId": "john_doe",
    "userProfileImage": "https://d11c102y3uxwr7.cloudfront.net/profiles/john.jpg"
  }'
```

---

### 7. Monitor and Maintain

#### Step 7.1: Set Up CloudWatch Alarms

1. Go to CloudWatch → Alarms
2. Create alarms for:
   - Lambda function errors
   - DynamoDB throttling
   - API Gateway 4xx/5xx errors

#### Step 7.2: Monitor Costs

1. Set up billing alerts
2. Monitor DynamoDB consumed capacity
3. Track S3 storage usage
4. Monitor CloudFront data transfer

---

### 8. Security Considerations

#### Step 8.1: Add Request Validation

Consider adding request validation to API Gateway:

1. Go to API Gateway → Models
2. Create validation models for your requests
3. Add request validators to methods

#### Step 8.2: Rate Limiting

1. Go to API Gateway → Usage Plans
2. Create usage plans with throttling limits
3. Associate with API keys if needed

---

## Summary of Changes

✅ **DynamoDB**: Updated schema for user support
✅ **Lambda Functions**: Enhanced submitAd, getAds, and created deleteBusinessAd
✅ **API Gateway**: Added DELETE endpoint with proper CORS
✅ **Security**: Maintained existing security model
✅ **Testing**: Provided test commands for validation

## Next Steps

1. **Execute all AWS changes** following this guide
2. **Test each endpoint** using provided curl commands
3. **Update Flutter app** to use new user features
4. **Implement Instagram-like UI** with WeDeshi branding
5. **Deploy and monitor** your enhanced platform

---

*Remember to update the AWS_INFRASTRUCTURE_DOCUMENTATION.md file after completing these changes.*
