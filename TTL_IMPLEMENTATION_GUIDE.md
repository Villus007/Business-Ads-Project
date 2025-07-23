# TTL (Time To Live) Implementation Guide - 30-Day Automatic Ad Expiration

## Overview
This guide implements a comprehensive TTL (Time To Live) system that automatically deletes business ads and their associated S3 images after 30 days, ensuring cost optimization and data management.

## 🎯 TTL System Components

### 1. DynamoDB TTL Configuration
- **Native TTL**: Uses DynamoDB's built-in TTL feature for automatic item deletion
- **Backup Cleanup**: Lambda function for S3 image cleanup (since DynamoDB TTL doesn't handle S3)
- **Hybrid Approach**: Combines both methods for complete data cleanup

### 2. Enhanced Lambda Functions
- **submitAd with TTL**: Adds expiration timestamps to new ads
- **TTL Cleanup Lambda**: Handles S3 image cleanup for expired ads
- **Monitoring**: Provides cleanup statistics and error handling

---

## 🚀 Implementation Steps

### Step 1: Enable DynamoDB TTL

#### 1.1: Enable TTL on BusinessAds Table

1. **Open AWS Console** → DynamoDB → Tables → BusinessAds
2. **Go to Additional settings tab**
3. **Click "Edit" next to Time to live (TTL)**
4. **Enable TTL**:
   - TTL attribute name: `ttl`
   - ✅ Check "Enable TTL"
5. **Save changes**

**What this does:**
- DynamoDB will automatically delete items when the `ttl` attribute (Unix timestamp) is reached
- No charges for TTL deletions
- Items typically deleted within 48 hours of expiration

#### 1.2: Verify TTL Configuration ✅ **COMPLETED**

**✅ SUCCESS!** Based on your AWS Console screenshot, TTL has been successfully enabled with:
- **TTL Status**: ✓ **On** (Green checkmark)
- **TTL Attribute**: `ttl` (correctly configured)
- **Items deleted in last 24 hours**: 0 (expected - no expired ads yet)

**Method 1: AWS CLI (if you have DynamoDB permissions)**
```bash
aws dynamodb describe-table --table-name BusinessAds --query 'Table.TimeToLiveDescription'
```

Expected output:
```json
{
    "TimeToLiveStatus": "ENABLED",
    "AttributeName": "ttl"
}
```

**Method 2: AWS Console ✅ VERIFIED**

Your console shows exactly what we need:
- **Status**: `Enabled` ✅
- **TTL attribute**: `ttl` ✅
- **Automatic deletion**: Ready for 30-day expiration ✅

**Method 3: Test via Your Application**

You can also verify TTL is working by:
1. Creating a test ad using your Flutter app
2. Checking the API response includes `expiresAt` and `ttlDays` fields
3. Using DynamoDB console to view the item and confirm `ttl` field exists

**🎉 STEP 1 COMPLETE! TTL is now enabled and ready for automatic 30-day ad expiration.**

---

### Step 2: Create TTL Cleanup Lambda Function

#### 2.1: Create the Lambda Function

1. **AWS Console → Lambda → Create function**

2. **Configure Function**:
   - Function name: `ttlCleanupBusinessAds`
   - Runtime: Python 3.11
   - Architecture: x86_64

3. **Set Execution Role**:
   - Use existing role with these permissions:
     - `AmazonDynamoDBFullAccess`
     - `AmazonS3FullAccess`
     - `CloudWatchLogsFullAccess`

4. **Replace Function Code** with the TTL cleanup code (from `ttl_cleanup_lambda.py`)

#### 2.2: Configure Lambda Settings

**Memory and Timeout:**
- Memory: 256 MB (sufficient for S3 operations)
- Timeout: 5 minutes (enough for cleanup operations)

**Environment Variables:**
```
S3_BUCKET = business-ad-images-1
CLOUDFRONT_DOMAIN = d11c102y3uxwr7.cloudfront.net
TTL_DAYS = 30
```

#### 2.3: Deploy the Function

Click **Deploy** and wait for "Changes deployed" confirmation.

---

### Step 3: Update submitAd Lambda for TTL Support

#### 3.1: Backup Current Function

1. Open `submitAd` Lambda function
2. Copy existing code to a backup file
3. Replace with TTL-enhanced version

#### 3.2: Deploy Enhanced submitAd Code

Replace your current `submitAd` Lambda code with the TTL-enhanced version from `submitAd_lambda_with_ttl.py`.

**Key TTL Enhancements:**
- Adds `ttl` field (Unix timestamp for DynamoDB TTL)
- Adds `expiresAt` field (human-readable expiration date)
- Calculates 30-day expiration from creation time
- Returns TTL information in response

#### 3.3: Test TTL Creation

Test with this curl command:
```bash
curl -X POST "https://um7x7rirpc.execute-api.us-east-1.amazonaws.com/prod/" \
-H "Content-Type: application/json" \
-d '{
  "title": "TTL Test Ad",
  "description": "Testing 30-day automatic expiration",
  "imageUrls": ["https://d11c102y3uxwr7.cloudfront.net/ads/test.jpg"],
  "userName": "TTL Tester"
}'
```

Expected response should include:
```json
{
  "success": true,
  "message": "Ad created successfully with 30-day automatic expiration",
  "expiresAt": "2025-08-22T...",
  "ttlDays": 30
}
```

---

### Step 4: Create EventBridge Schedule for Cleanup

#### 4.1: Create EventBridge Rule

1. **AWS Console → EventBridge → Rules → Create rule**

2. **Configure Rule**:
   - Name: `ttl-cleanup-daily`
   - Description: `Daily cleanup of expired business ad images`
   - Rule type: Schedule

3. **Set Schedule**:
   - Schedule pattern: Rate-based schedule
   - Rate expression: `rate(1 day)`
   - Or use cron: `cron(0 2 * * ? *)` (daily at 2:00 AM UTC)

4. **Select Target**:
   - Target type: AWS service
   - Service: Lambda function
   - Function: `ttlCleanupBusinessAds`

5. **Create rule**

#### 4.2: Test EventBridge Integration

You can manually trigger the rule:
1. Go to EventBridge → Rules
2. Select `ttl-cleanup-daily`
3. Click **Actions → Test rule**

---

### Step 5: Update Flutter App (Optional)

#### 5.1: Show Expiration Information

Update your Flutter `BusinessAd` model to include TTL fields:

```dart
class BusinessAd {
  // ... existing fields ...
  final DateTime? expiresAt;
  final int? ttlDays;
  
  BusinessAd({
    // ... existing parameters ...
    this.expiresAt,
    this.ttlDays,
  });
  
  factory BusinessAd.fromJson(Map<String, dynamic> json) {
    return BusinessAd(
      // ... existing mappings ...
      expiresAt: json['expiresAt'] != null 
          ? DateTime.tryParse(json['expiresAt']) 
          : null,
      ttlDays: json['ttlDays'],
    );
  }
}
```

#### 5.2: Display Expiration in UI

Add expiration information to your ad cards:

```dart
// In ad_card.dart or similar
if (ad.expiresAt != null)
  Text(
    'Expires: ${DateFormat('MMM dd, yyyy').format(ad.expiresAt!)}',
    style: TextStyle(
      fontSize: 12,
      color: Colors.grey[600],
    ),
  ),
```

---

## 🔧 TTL System Configuration

### DynamoDB TTL Settings
```json
{
  "TimeToLiveDescription": {
    "TimeToLiveStatus": "ENABLED",
    "AttributeName": "ttl"
  }
}
```

### Lambda Configuration
```python
# TTL Settings
TTL_DAYS = 30  # Time to live in days
S3_BUCKET = 'business-ad-images-1'
CLOUDFRONT_DOMAIN = 'd11c102y3uxwr7.cloudfront.net'

# Schedule: Daily at 2:00 AM UTC
CLEANUP_SCHEDULE = "cron(0 2 * * ? *)"
```

### EventBridge Schedule
- **Frequency**: Daily
- **Time**: 2:00 AM UTC
- **Target**: `ttlCleanupBusinessAds` Lambda function

---

## 📊 Enhanced Database Schema with TTL

### Updated BusinessAds Schema
```json
{
  "id": "String (Primary Key - UUID)",
  "title": "String (required)",
  "description": "String (required)",
  "imageUrls": "List (required)",
  "userName": "String (required)",
  "userId": "String (required)",
  "userProfileImage": "String (optional)",
  "createdAt": "String (ISO datetime)",
  "updatedAt": "String (ISO datetime)",
  "expiresAt": "String (ISO datetime) - NEW",
  "ttl": "Number (Unix timestamp) - NEW TTL ATTRIBUTE",
  "status": "String (active/inactive/deleted)",
  "featured": "Boolean",
  "imageCount": "Number",
  "likes": "Number (default: 0)",
  "viewCount": "Number (default: 0)",
  "comments": "List (default: empty array)",
  "businessName": "String (optional)",
  "contactInfo": "String (optional)",
  "location": "String (optional)",
  "category": "String (optional)"
}
```

### TTL Field Explanations
- **`ttl`**: Unix timestamp for DynamoDB native TTL (automatic deletion)
- **`expiresAt`**: Human-readable ISO datetime for display/debugging
- **TTL Calculation**: `current_time + 30 days = expiration_time`

---

## 🔍 Monitoring and Testing

### Manual Testing Commands

#### Test TTL Lambda Function
```bash
aws lambda invoke \
  --function-name ttlCleanupBusinessAds \
  --payload '{}' \
  response.json
```

#### Check TTL Status of Ads
```python
import boto3
from datetime import datetime

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('BusinessAds')

# Scan for ads with TTL information
response = table.scan(
    ProjectionExpression='id,title,createdAt,expiresAt,ttl'
)

for ad in response['Items']:
    print(f"Ad: {ad['title']}")
    print(f"Created: {ad['createdAt']}")
    print(f"Expires: {ad.get('expiresAt', 'No expiration')}")
    print(f"TTL: {ad.get('ttl', 'No TTL set')}")
    print("---")
```

#### Monitor Cleanup Statistics
Check CloudWatch logs for the `ttlCleanupBusinessAds` function:
```bash
aws logs filter-log-events \
  --log-group-name /aws/lambda/ttlCleanupBusinessAds \
  --start-time $(date -d '1 day ago' +%s)000
```

---

## 📈 Cost Optimization Benefits

### Storage Cost Reduction
- **Automatic cleanup**: No manual intervention required
- **S3 cost savings**: Images automatically deleted after 30 days
- **DynamoDB cost savings**: Items automatically deleted (no read/write costs)

### Operational Benefits
- **Data compliance**: Automatic data retention management
- **Storage management**: Prevents unlimited growth
- **Performance**: Maintains optimal table size

### Cost Estimates
```
Before TTL:
- DynamoDB: Growing storage costs
- S3: Accumulating image storage costs
- Manual cleanup: Development time costs

After TTL:
- DynamoDB: Fixed storage costs (30-day rotation)
- S3: Fixed storage costs (30-day rotation)
- Automation: Zero manual maintenance
- Estimated savings: 60-80% on storage costs
```

---

## 🚨 Important Notes

### TTL Behavior
1. **DynamoDB TTL**: Deletes items within 48 hours of expiration (not exact)
2. **S3 Cleanup**: Requires Lambda function (DynamoDB TTL doesn't trigger S3 cleanup)
3. **Timing**: Use Lambda cleanup for precise timing requirements

### Data Recovery
- **No recovery**: Once TTL deletes data, it's permanent
- **Backup strategy**: Consider DynamoDB point-in-time recovery if needed
- **Archive option**: Modify Lambda to archive instead of delete

### Migration of Existing Ads
Run this script to add TTL to existing ads without expiration:

```python
import boto3
from datetime import datetime, timedelta

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('BusinessAds')

# Scan for ads without TTL
response = table.scan(
    FilterExpression='attribute_not_exists(ttl)'
)

for ad in response['Items']:
    # Add 30-day TTL from creation date
    created_at = datetime.fromisoformat(ad['createdAt'].replace('Z', '+00:00'))
    expiration = created_at + timedelta(days=30)
    ttl_timestamp = int(expiration.timestamp())
    
    # Update the ad with TTL
    table.update_item(
        Key={'id': ad['id']},
        UpdateExpression='SET ttl = :ttl, expiresAt = :expires',
        ExpressionAttributeValues={
            ':ttl': ttl_timestamp,
            ':expires': expiration.isoformat()
        }
    )
    
    print(f"Added TTL to ad: {ad['id']}")
```

---

## 🎉 Deployment Verification

### Verification Checklist

1. **✅ DynamoDB TTL Enabled**
   ```bash
   aws dynamodb describe-table --table-name BusinessAds --query 'Table.TimeToLiveDescription'
   ```

2. **✅ TTL Cleanup Lambda Deployed**
   ```bash
   aws lambda get-function --function-name ttlCleanupBusinessAds
   ```

3. **✅ Enhanced submitAd Deployed**
   - Test ad creation includes TTL fields
   - Response includes expiration information

4. **✅ EventBridge Schedule Active**
   ```bash
   aws events list-rules --name-prefix ttl-cleanup
   ```

5. **✅ Test Complete System**
   - Create test ad with short TTL (1 day)
   - Verify automatic deletion after expiration

### Success Metrics
- ✅ New ads automatically include TTL fields
- ✅ DynamoDB TTL deletes expired items
- ✅ S3 images cleaned up by Lambda function
- ✅ EventBridge triggers daily cleanup
- ✅ No manual intervention required

---

## 📱 Flutter App Compatibility

The TTL system is fully backward compatible:
- Existing ads without TTL continue to work
- New ads include expiration information
- UI can optionally display expiration dates
- No breaking changes to existing functionality

---

*🎯 Complete these steps in order to implement the 30-day TTL system for automatic ad expiration and cleanup!*
