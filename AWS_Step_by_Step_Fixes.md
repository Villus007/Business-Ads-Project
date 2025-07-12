# AWS Fix Guide: Step-by-Step Instructions

## 🚨 CRITICAL FIXES NEEDED

### 1. Fix Lambda Function: `submitAd`

**Current Issue:** Your Lambda function has incomplete return statement and missing CORS headers.

**Steps to Fix:**
1. Go to AWS Lambda Console
2. Find your `submitAd` function
3. Replace the entire function code with this:

```python
import json
import boto3
from datetime import datetime

def lambda_handler(event, context):
    # Set up CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'POST,OPTIONS'
    }
    
    # Handle CORS preflight request
    if event['httpMethod'] == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'CORS preflight successful'})
        }
    
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('BusinessAds')
        
        # Parse the request body
        body = json.loads(event['body'])
        
        # Validate required fields
        required_fields = ['id', 'title', 'description', 'imageUrls']
        for field in required_fields:
            if field not in body:
                return {
                    'statusCode': 400,
                    'headers': headers,
                    'body': json.dumps({'error': f'Missing required field: {field}'})
                }
        
        # Create the item for DynamoDB
        item = {
            'id': body['id'],
            'title': body['title'],
            'description': body['description'],
            'imageUrls': body['imageUrls'],
            'createdAt': datetime.now().isoformat()
        }
        
        # Add optional fields if they exist
        optional_fields = ['businessName', 'contactInfo', 'location', 'category', 'isActive', 'isFeatured']
        for field in optional_fields:
            if field in body:
                item[field] = body[field]
        
        # Put item in DynamoDB
        table.put_item(Item=item)
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'message': 'Ad submitted successfully',
                'id': body['id']
            })
        }
        
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Internal server error'})
        }
```

4. Click "Deploy" to save changes

---

### 2. Fix Lambda Function: `generatePresignedUrl`

**Current Issue:** Incomplete return statement and missing CORS headers.

**Steps to Fix:**
1. Go to AWS Lambda Console
2. Find your `generatePresignedUrl` function
3. Replace the entire function code with this:

```python
import boto3
import json
from datetime import datetime

def lambda_handler(event, context):
    # Set up CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,OPTIONS'
    }
    
    # Handle CORS preflight request
    if event['httpMethod'] == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'CORS preflight successful'})
        }
    
    try:
        s3 = boto3.client('s3')
        
        # Get filename from query parameters
        if 'queryStringParameters' not in event or event['queryStringParameters'] is None:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'Missing filename parameter'})
            }
        
        filename = event['queryStringParameters'].get('filename')
        if not filename:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'Filename parameter is required'})
            }
        
        # Generate presigned URL for PUT operation
        presigned_url = s3.generate_presigned_url(
            'put_object',
            Params={
                'Bucket': 'business-ad-images-1',
                'Key': filename,
                'ContentType': 'image/jpeg'
            },
            ExpiresIn=3600  # URL expires in 1 hour
        )
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'url': presigned_url,
                'expires': 3600
            })
        }
        
    except Exception as e:
        print(f"Error generating presigned URL: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Failed to generate presigned URL'})
        }
```

4. Click "Deploy" to save changes

---

### 3. Create New Lambda Function: `getAds`

**Why Needed:** Your app needs to fetch ads from DynamoDB for display.

**Steps to Create:**
1. Go to AWS Lambda Console
2. Click "Create Function"
3. Choose "Author from scratch"
4. Function name: `getAds`
5. Runtime: Python 3.11
6. Create function
7. Replace the default code with:

```python
import json
import boto3
from boto3.dynamodb.conditions import Key

def lambda_handler(event, context):
    # Set up CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'GET,OPTIONS'
    }
    
    # Handle CORS preflight request
    if event['httpMethod'] == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'CORS preflight successful'})
        }
    
    try:
        dynamodb = boto3.resource('dynamodb')
        table = dynamodb.Table('BusinessAds')
        
        # Get query parameters for filtering/pagination
        query_params = event.get('queryStringParameters', {}) or {}
        
        # Scan the table to get all ads
        scan_kwargs = {}
        
        # Add limit if specified
        if 'limit' in query_params:
            try:
                scan_kwargs['Limit'] = int(query_params['limit'])
            except ValueError:
                pass
        
        # Perform the scan
        response = table.scan(**scan_kwargs)
        
        # Convert DynamoDB response to our format
        ads = []
        for item in response.get('Items', []):
            ad = {
                'id': item.get('id', ''),
                'title': item.get('title', ''),
                'description': item.get('description', ''),
                'imageUrls': item.get('imageUrls', []),
                'createdAt': item.get('createdAt', '')
            }
            
            # Add optional fields if they exist
            optional_fields = ['businessName', 'contactInfo', 'location', 'category', 'isActive', 'isFeatured']
            for field in optional_fields:
                if field in item:
                    ad[field] = item[field]
            
            ads.append(ad)
        
        # Sort by creation date (newest first)
        ads.sort(key=lambda x: x.get('createdAt', ''), reverse=True)
        
        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'ads': ads,
                'count': len(ads)
            })
        }
        
    except Exception as e:
        print(f"Error fetching ads: {str(e)}")
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': 'Failed to fetch ads'})
        }
```

8. Click "Deploy"

#### Add DynamoDB Permissions (DETAILED STEPS):
9. **Go to Configuration → Permissions:**
   - In your `getAds` Lambda function, click the "Configuration" tab at the top
   - Then click "Permissions" in the left sidebar

10. **Add DynamoDB read permissions:**
    - You'll see an "Execution role" section with a role name (like `getAds-role-xxxxx`)
    - Click on the role name link - this opens IAM in a new tab
    - In the IAM console, you'll see the role details
    - Click "Add permissions" → "Attach policies"
    - Search for `AmazonDynamoDBReadOnlyAccess`
    - Check the box next to it
    - Click "Add permissions"

**Alternative Method (If you prefer inline policy):**
- Instead of attaching a policy, click "Add permissions" → "Create inline policy"
- Choose "JSON" tab and paste:
```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:Scan",
                "dynamodb:GetItem",
                "dynamodb:Query"
            ],
            "Resource": "arn:aws:dynamodb:us-east-1:715221148508:table/BusinessAds"
        }
    ]
}
```
- Name it `DynamoDBReadAccess` and create the policy

---

### 4. Fix API Gateway Resources

**Current Issue:** Missing `/ads` and `/presigned-url` endpoints.

**Steps to Fix:**

#### A. Add `/ads` Resource
1. Go to API Gateway Console
2. Find your API: `BusinessAdAPI`
3. Click on the root resource `/`
4. Click "Actions" → "Create Resource"
5. Resource Name: `ads`
6. Resource Path: `/ads`
7. Enable CORS: ✅ Check this box
8. Click "Create Resource"

#### B. Add GET Method to `/ads`
1. Select the `/ads` resource
2. Click "Actions" → "Create Method"
3. Choose `GET` from dropdown
4. Click the checkmark
5. Integration type: Lambda Function
6. Lambda Region: us-east-1
7. Lambda Function: `getAds`
8. Click "Save"
9. Click "OK" to give API Gateway permission

#### C. Add `/presigned-url` Resource
1. Click on root resource `/`
2. Click "Actions" → "Create Resource"
3. Resource Name: `presigned-url`
4. Resource Path: `/presigned-url`
5. Enable CORS: ✅ Check this box
6. Click "Create Resource"

#### D. Add GET Method to `/presigned-url`
1. Select the `/presigned-url` resource
2. Click "Actions" → "Create Method"
3. Choose `GET` from dropdown
4. Click the checkmark
5. Integration type: Lambda Function
6. Lambda Region: us-east-1
7. Lambda Function: `generatePresignedUrl`
8. Click "Save"
9. Click "OK" to give API Gateway permission

#### E. Deploy API Gateway
1. Click "Actions" → "Deploy API"
2. Deployment stage: `prod`
3. Click "Deploy"

---

### 5. Test Your Setup

#### A. Test in Development Mode (Current)
Your app should work perfectly as-is with local storage.

#### B. Test in Production Mode
1. In your Flutter code, change:
```dart
static const bool _isDevelopmentMode = false;
```

2. Test the flow:
   - Create a new ad with image
   - Check if it appears in the feed
   - Restart the app and verify persistence

---

### 6. Verify Each Component

#### Test Lambda Functions Individually:
1. **submitAd**: Test with sample JSON payload
2. **generatePresignedUrl**: Test with filename parameter
3. **getAds**: Test without parameters

#### Test API Gateway Endpoints:
1. `POST /` - Submit ad
2. `GET /ads` - Fetch ads
3. `GET /presigned-url?filename=test.jpg` - Get presigned URL

---

### 7. Common Issues & Solutions

#### If you get CORS errors:
1. Ensure all Lambda functions have CORS headers
2. Enable CORS on all API Gateway resources
3. Redeploy API Gateway

#### If DynamoDB access fails:
1. Check Lambda execution role has DynamoDB permissions
2. Verify table name is exactly `BusinessAds`

#### If S3 upload fails:
1. Verify bucket name is `business-ad-images-1`
2. Check S3 bucket permissions
3. Ensure presigned URL is for PUT operation

---

#### 📋 **Quick Permission Check for ALL Lambda Functions:**

Your Lambda functions need these permissions:

1. **`submitAd` function needs:**
   - DynamoDB write permissions for `BusinessAds` table
   - Follow same steps but use `AmazonDynamoDBFullAccess` or inline policy with `dynamodb:PutItem`

2. **`generatePresignedUrl` function needs:**
   - S3 permissions for `business-ad-images-1` bucket
   - Attach `AmazonS3FullAccess` or create inline policy with `s3:PutObject`

3. **`getAds` function needs:**
   - DynamoDB read permissions (you just added this)

#### 🧪 **Test Your Setup:**
After adding permissions, test each Lambda function:
1. Go to Lambda console → your function → "Test" tab
2. Create test events to verify they work
3. Check CloudWatch Logs for any permission errors

---

## 🎯 Success Criteria

After completing these fixes:
- ✅ Ads submit successfully to DynamoDB
- ✅ Images upload to S3 and display via CloudFront
- ✅ Ads persist and display after app restart
- ✅ No CORS errors in browser console
- ✅ All API endpoints return proper responses

Would you like me to help you with any specific step, or shall we test the current development mode first?
