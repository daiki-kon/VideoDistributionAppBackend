import json
import boto3
from boto3.dynamodb.conditions import Key, Attr
import os

INVERTED_TABLE_NAME   = os.environ['INVERTED_TABLE_NAME']
VIDEO_INFO_TABLE_NAME = os.environ['VIDEO_INFO_TABLE_NAME']

def lambda_handler(event: dict, context):
    
    search_string_list = event['queryStringParameters']['searchString'].split()
    
    print(search_string_list)
    
    dynamodb = boto3.resource('dynamodb')
    
    invertedTable = dynamodb.Table(INVERTED_TABLE_NAME)
    
    video_ids = set()
    
    for word in search_string_list:
        res = invertedTable.query(
            KeyConditionExpression=Key('Key').eq(word)
        )
        print(res)
        if 0 != len(res['Items']):
        
            print(res['Items'][0]['VideoIds'])
            video_ids = video_ids.union(res['Items'][0]['VideoIds'])

    print(video_ids)
    
    
    video_info_table = dynamodb.Table(VIDEO_INFO_TABLE_NAME)
    
    video_info_list = []
    for id in video_ids:
        res = video_info_table.query(
            KeyConditionExpression=Key('VideoId').eq(id)
        )
        print(res)

    
    return {
          'statusCode': 200,
          'headers': {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*' 
          },
          'body': json.dumps(event)
      }