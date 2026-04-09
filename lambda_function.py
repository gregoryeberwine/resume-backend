import json
import boto3
import os

client = boto3.client('dynamodb')
ALLOWED_ORIGIN = os.environ["ALLOWED_ORIGIN"]

def lambda_handler(event, context):
    get = client.get_item(
        TableName='websiteTable',
        Key={
            'counter': {
                'S':'visitors'
            }
        },
        ProjectionExpression='numberVisitors'
    )

    increment = int(get['Item']['numberVisitors']['N']) + 1

    put = client.put_item(
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