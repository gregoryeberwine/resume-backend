import json
import boto3

client = boto3.client('dynamodb')

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
            'Access-Control-Allow-Origin': 'https://gregoryeberwine.com'
        },
        'body': json.dumps({'numberVisitors': increment})
    }