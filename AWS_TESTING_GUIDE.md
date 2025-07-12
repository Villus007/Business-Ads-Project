# 🎉 AWS Setup Complete - Testing Guide

## ✅ What You've Completed:
- ✅ Fixed `submitAd` Lambda function with CORS headers
- ✅ Fixed `generatePresignedUrl` Lambda function with CORS headers  
- ✅ Created `getAds` Lambda function
- ✅ Added `/ads` and `/presigned-url` resources to API Gateway
- ✅ Added DynamoDB permissions to `submitAd` and `getAds` functions
- ✅ Added S3 permissions to `generatePresignedUrl` function
- ✅ Deployed API Gateway changes

## 🧪 Testing Time!

### Step 1: Test Development Mode (Should Still Work)
1. Make sure your Flutter app has `_isDevelopmentMode = true`
2. Run your Flutter app
3. Test creating ads with images
4. Verify they appear in the feed and persist after restart

### Step 2: Test Production Mode (NEW - AWS Integration)
1. In your Flutter code, change:
```dart
static const bool _isDevelopmentMode = false; // Enable AWS integration
```

2. Run your Flutter app again
3. Try creating a new ad with an image
4. Check if it appears in the feed
5. Restart the app and verify it loads from AWS

### Step 3: Verify AWS Integration is Working
Check your AWS console:
- **DynamoDB**: Go to BusinessAds table → Items to see if ads are being stored
- **S3**: Go to business-ad-images-1 bucket to see if images are being uploaded
- **CloudWatch Logs**: Check Lambda function logs for any errors

## 🔍 Quick Test Endpoints

You can also test your API endpoints directly:

### Test GET /ads:
```
https://uwmvuql9m7.execute-api.us-east-1.amazonaws.com/prod/ads
```

### Test GET /presigned-url:
```
https://uwmvuql9m7.execute-api.us-east-1.amazonaws.com/prod/presigned-url?filename=test.jpg
```

## 🐛 If Something Doesn't Work:

### Common Issues:
1. **CORS Errors**: Check browser console, redeploy API Gateway
2. **403 Errors**: Check Lambda function permissions
3. **500 Errors**: Check CloudWatch Logs for Lambda errors
4. **Images not uploading**: Check S3 permissions and bucket policy

### Quick Debug Steps:
1. Check CloudWatch Logs for each Lambda function
2. Test each Lambda function individually in AWS console
3. Verify API Gateway deployment is active
4. Check that all resources have CORS enabled

## 🎯 Success Indicators:

When everything works correctly, you should see:
- ✅ Ads successfully submitted to DynamoDB
- ✅ Images uploaded to S3 and served via CloudFront
- ✅ Ads persist and load from AWS after app restart
- ✅ No CORS errors in browser console (if using web)
- ✅ CloudWatch logs show successful Lambda executions

Ready to test? Start with Step 1 to make sure development mode still works, then try Step 2 for the full AWS integration!
