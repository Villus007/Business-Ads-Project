import json
import boto3
from decimal import Decimal

def lambda_handler(event, context):
    """
    Lambda function to delete test ads from DynamoDB
    """
    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table('BusinessAds')
    
    # List of test ad IDs to delete
    test_ad_ids = [
        "test-04dd2607-9215-4a72-945b-1ff56024d1cf",
        "test-801442b5-e733-426e-bbdd-810ed2704460", 
        "test-ac51ebb1-e758-4872-bbc3-0e07cc97fa64",
        "test-6ce9e2a3-1953-4ba4-99ab-23229f868a14",
        "test-a1fe3ff6-f07d-47a7-96d4-a55668d535ca",
        "test-d3a3fbc0-4dfa-4e8c-9efc-e73e2244c926"
    ]
    
    deleted_count = 0
    errors = []
    
    try:
        for ad_id in test_ad_ids:
            try:
                # Delete the item
                response = table.delete_item(
                    Key={'id': ad_id},
                    ReturnValues='ALL_OLD'
                )
                
                if 'Attributes' in response:
                    deleted_count += 1
                    print(f"✅ Deleted test ad: {ad_id}")
                else:
                    print(f"⚠️  Test ad not found: {ad_id}")
                    
            except Exception as e:
                error_msg = f"Error deleting {ad_id}: {str(e)}"
                errors.append(error_msg)
                print(f"❌ {error_msg}")
        
        # Return success response
        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Headers': 'Content-Type',
                'Access-Control-Allow-Methods': 'DELETE, OPTIONS'
            },
            'body': json.dumps({
                'message': f'Successfully deleted {deleted_count} test ads',
                'deleted_count': deleted_count,
                'total_attempted': len(test_ad_ids),
                'errors': errors
            })
        }
        
    except Exception as e:
        print(f"❌ Error in cleanup: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                'error': f'Failed to cleanup test ads: {str(e)}'
            })
        }