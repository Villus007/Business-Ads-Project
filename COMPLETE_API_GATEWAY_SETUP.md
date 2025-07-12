# 🚀 Complete API Gateway Setup from Scratch

## 📋 **STEP 1: Delete Existing API Gateway (If Any)**
1. Go to **AWS API Gateway Console**
2. Find your existing API: `BusinessAdAPI (uwmvuql9m7)`
3. Select it and click **"Delete"**
4. Confirm deletion

---

## 🏗️ **STEP 2: Create New API Gateway**

### 2.1 Create the API:
1. Go to **AWS API Gateway Console**
2. Click **"Create API"**
3. Choose **"REST API"** (not REST API Private)
4. Click **"Build"**
5. Fill in details:
   - **API name**: `BusinessAdAPI`
   - **Description**: `API for Business Ad Platform`
   - **Endpoint Type**: `Regional`
6. Click **"Create API"**

### 2.2 Note Your New API Details:
- Your new API ID will be different (like `abc123def4`)
- Your new URL will be: `https://[NEW-API-ID].execute-api.us-east-1.amazonaws.com/prod`

---

## 🛠️ **STEP 3: Create Resources and Methods**

### 3.1 Configure Root Resource ("/") for Ad Submission

#### Add POST Method to Root:
1. Click on the **"/"** resource (root)
2. Click **"Actions"** → **"Create Method"**
3. Select **"POST"** from dropdown
4. Click the **checkmark ✓**
5. Configure integration:
   - **Integration type**: `Lambda Function`
   - **Use Lambda Proxy integration**: ✅ **Check this box**
   - **Lambda Region**: `us-east-1`
   - **Lambda Function**: `submitAd`
6. Click **"Save"**
7. Click **"OK"** to grant permissions

#### Add OPTIONS Method to Root (for CORS):

**🔍 IMPORTANT: Make sure you're on the ROOT resource first!**

1. **Verify you're on the root resource:**
   - In the left sidebar under "Resources", click on **"/"** (the root resource)
   - You should see it's highlighted/selected
   - The resource path should show just **"/"** at the top

2. **Now add the OPTIONS method:**
   - With **"/"** still selected, click **"Actions"** → **"Create Method"**
   - Select **"OPTIONS"** from the dropdown menu
   - Click the **checkmark ✓**

3. **Configure the OPTIONS integration:**
   - **Integration type**: `Mock`
   - Leave other fields as default
   - Click **"Save"**

#### 📸 **Visual Guide - What You Should See:**

After adding both POST and OPTIONS methods to root "/", your Resources panel should look like this:

```
Resources
└── / 
    ├── POST (connected to submitAd Lambda)
    └── OPTIONS (Mock integration)
```

**If you're having trouble:**

1. **Reset and try again:**
   - Click on the **"/"** resource name in the left sidebar (not on POST method)
   - You should see the resource details, not method details
   - Then follow the OPTIONS steps above

2. **Alternative approach:**
   - Right-click on the **"/"** resource
   - Select "Create Method" from context menu
   - Choose OPTIONS and continue

3. **Double-check you're in the right place:**
   - The breadcrumb at the top should show: `BusinessAdAPI > /`
   - Not: `BusinessAdAPI > / > POST`

#### Configure OPTIONS Response:
1. Click on **"OPTIONS"** method under **"/"**
2. Click **"Method Response"**
3. Click **"Add Response"** → enter `200` → click ✓
4. Expand **"200"** response
5. Under **"Response Headers"**, add these headers:
   - Click **"Add Header"**: `Access-Control-Allow-Origin`
   - Click **"Add Header"**: `Access-Control-Allow-Headers`
   - Click **"Add Header"**: `Access-Control-Allow-Methods`
6. Click **"Integration Response"**
7. Expand **"200"** response
8. Under **"Header Mappings"**, add:
   - `Access-Control-Allow-Origin`: `'*'`
   - `Access-Control-Allow-Headers`: `'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'`
   - `Access-Control-Allow-Methods`: `'POST,OPTIONS'`

---

### 3.2 Create "/ads" Resource for Fetching Ads

#### Create the Resource:
1. Click on **"/"** (root resource)
2. Click **"Actions"** → **"Create Resource"**
3. Fill in:
   - **Resource Name**: `ads`
   - **Resource Path**: `ads`
   - **Enable API Gateway CORS**: ✅ **Check this box**
4. Click **"Create Resource"**

#### Add GET Method to /ads:
1. Click on the **"/ads"** resource
2. Click **"Actions"** → **"Create Method"**
3. Select **"GET"** from dropdown
4. Click the **checkmark ✓**
5. Configure integration:
   - **Integration type**: `Lambda Function`
   - **Use Lambda Proxy integration**: ✅ **Check this box**
   - **Lambda Region**: `us-east-1`
   - **Lambda Function**: `getAds`
6. Click **"Save"**
7. Click **"OK"** to grant permissions

---

### 3.3 Create "/presigned-url" Resource for Image Uploads

#### Create the Resource:
1. Click on **"/"** (root resource)
2. Click **"Actions"** → **"Create Resource"**
3. Fill in:
   - **Resource Name**: `presigned-url`
   - **Resource Path**: `presigned-url`
   - **Enable API Gateway CORS**: ✅ **Check this box**
4. Click **"Create Resource"**

#### Add GET Method to /presigned-url:
1. Click on the **"/presigned-url"** resource
2. Click **"Actions"** → **"Create Method"**
3. Select **"GET"** from dropdown
4. Click the **checkmark ✓**
5. Configure integration:
   - **Integration type**: `Lambda Function`
   - **Use Lambda Proxy integration**: ✅ **Check this box**
   - **Lambda Region**: `us-east-1`
   - **Lambda Function**: `generatePresignedUrl`
6. Click **"Save"**
7. Click **"OK"** to grant permissions

---

## 🚀 **STEP 4: Deploy the API**

### 4.1 Create Deployment:
1. Click **"Actions"** → **"Deploy API"**
2. **Deployment stage**: Select **"New Stage"**
3. **Stage name**: `prod`
4. **Stage description**: `Production stage`
5. **Deployment description**: `Initial deployment`
6. Click **"Deploy"**

### 4.2 Get Your New API URL:
1. Click on **"Stages"** in the left sidebar
2. Click on **"prod"** stage
3. Copy the **"Invoke URL"** - this is your new base URL
4. It will look like: `https://[NEW-API-ID].execute-api.us-east-1.amazonaws.com/prod`

---

## 🔧 **STEP 5: Update Your Flutter Code**

### 5.1 Update the Base URL:
1. Open your Flutter project
2. Go to `lib/services/api_service.dart`
3. Update the `_baseUrl` with your NEW API URL:

```dart
static const String _baseUrl = "https://[YOUR-NEW-API-ID].execute-api.us-east-1.amazonaws.com/prod";
```

**Replace `[YOUR-NEW-API-ID]` with your actual new API ID!**

---

## 📊 **STEP 6: Test Your API Structure**

### Your API should now have this structure:
```
BusinessAdAPI
├── / (POST, OPTIONS) → submitAd Lambda
├── /ads (GET, OPTIONS) → getAds Lambda  
└── /presigned-url (GET, OPTIONS) → generatePresignedUrl Lambda
```

### Test URLs:
- **Submit Ad**: `POST https://[YOUR-API-ID].execute-api.us-east-1.amazonaws.com/prod/`
- **Get Ads**: `GET https://[YOUR-API-ID].execute-api.us-east-1.amazonaws.com/prod/ads`
- **Get Presigned URL**: `GET https://[YOUR-API-ID].execute-api.us-east-1.amazonaws.com/prod/presigned-url?filename=test.jpg`

---

## ✅ **STEP 7: Verification Checklist**

Before testing your Flutter app:

### API Gateway Checklist:
- [ ] Root "/" has POST method connected to `submitAd` Lambda
- [ ] Root "/" has OPTIONS method for CORS
- [ ] "/ads" resource has GET method connected to `getAds` Lambda
- [ ] "/presigned-url" resource has GET method connected to `generatePresignedUrl` Lambda
- [ ] All resources have CORS enabled
- [ ] API is deployed to "prod" stage
- [ ] You have the new API URL

### Lambda Functions Checklist:
- [ ] `submitAd` has DynamoDB write permissions
- [ ] `getAds` has DynamoDB read permissions  
- [ ] `generatePresignedUrl` has S3 permissions
- [ ] All Lambda functions use the fixed code with CORS headers

### Flutter Code Checklist:
- [ ] Updated `_baseUrl` in `api_service.dart` with new API URL
- [ ] Ready to test with `_isDevelopmentMode = false`

---

## 🧪 **STEP 8: Ready to Test!**

Once you complete all steps:
1. Update your Flutter code with the new API URL
2. Test in development mode first (`_isDevelopmentMode = true`)
3. Then test production mode (`_isDevelopmentMode = false`)
4. Check AWS console for data in DynamoDB and S3

**Your new API Gateway is now ready! 🎉**
