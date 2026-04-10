import json
import boto3
import os

client = boto3.client('dynamodb')
ALLOWED_ORIGIN = os.environ["ALLOWED_ORIGIN"]

def lambda_handler(event, context):
    response = client.get_item(
        TableName='websiteTable',
        Key={
            'counter': {
                'S':'visitors'
            }
        },
        ProjectionExpression='numberVisitors'
    )

    item = response.get('Item', {})
    current = int(item.get('numberVisitors', {}).get('N', 0))
    increment = current + 1

    client.put_item(
        TableName='websiteTable',
        Item={
            'counter': {'S': 'visitors'},
            'numberVisitors': {'N': str(increment)}
        }
    )

    return {
        'statusCode': 200,
        'headers': {
            'Access-Control-Allow-Origin': ALLOWED_ORIGIN
        },
        'body': json.dumps({'numberVisitors': increment})
    }