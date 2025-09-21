"""Lambda function to fetch the last item from a list stored in DynamoDB"""
import json
import os
import boto3
from botocore.exceptions import ClientError

dynamodb = boto3.resource('dynamodb')
table_name = os.environ.get('TABLE_NAME')
if not table_name:
    raise RuntimeError("TABLE_NAME environment variable not set")
table = dynamodb.Table(table_name)

LIST_ID = "main_list"

def make_response(status_code, body, headers=None):
    """ Helper function to create HTTP responses"""
    default_headers = {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
    }
    if headers:
        default_headers.update(headers)
    return {
        'statusCode': status_code,
        'headers': default_headers,
        'body': json.dumps(body)
    }

def lambda_handler(_event, _context):
    """
    Fetch the last item from the list
    """
    try:
        # Get the main list from DynamoDB
        response = table.get_item(
            Key={'list_id': LIST_ID}
        )
        
        if 'Item' not in response:
            return make_response(404, {'error': 'Main list not found'})
        
        items = response['Item'].get('items', [])
        
        if not items:
            return make_response(404, {'error': 'List is empty'})
        
        # Return the last item
        return make_response(200, {
            'operation': 'tail',
            'item': items[-1],
            'total_items': len(items)
        })
        
    except ClientError as e:
        print(f"DynamoDB error: {e}")
        return make_response(500, {'error': 'Internal server error'})
    except (ValueError, KeyError, TypeError) as e:
        print(f"Unexpected error: {e}")
        return make_response(500, {'error': 'Internal server error'})
