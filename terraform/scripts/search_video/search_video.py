import json
import boto3
from boto3.dynamodb.conditions import Key, Attr
from decimal import Decimal
from boto3.dynamodb.types import TypeDeserializer
import os

INVERTED_TABLE_NAME   = os.environ['INVERTED_TABLE_NAME']
VIDEO_INFO_TABLE_NAME = os.environ['VIDEO_INFO_TABLE_NAME']

# NOTE: ページネーションについては考えられていない

# NOTE: 戻り地がURLエンコードされているので
#       フロント側でデコードする必要がある

def lambda_handler(event: dict, context):

    search_string_list = event['queryStringParameters']['searchString'].split()

    dynamodb = boto3.resource('dynamodb')

    invertedTable = dynamodb.Table(INVERTED_TABLE_NAME)

    video_ids = set()

    for word in search_string_list:
        res = invertedTable.query(
            KeyConditionExpression=Key('Key').eq(word)
        )
        if 0 != len(res['Items']):

            video_ids = video_ids.union(res['Items'][0]['VideoIds'])

    print('video_ids: ',video_ids)
    
    
    video_info_table = dynamodb.Table(VIDEO_INFO_TABLE_NAME)
    
    video_info_list = []
    for id in video_ids:
        res = video_info_table.query(
            KeyConditionExpression=Key('videoId').eq(id)
        )

        if 0 != len(res['Items']):

            print(res['Items'][0])
            
            video_info_list.append(res['Items'][0])

    print(video_info_list)
    
    ret_dict = {
        "videos":video_info_list
    }
    return {
          'statusCode': 200,
          'headers': {
              'Content-Type': 'application/json',
              'Access-Control-Allow-Origin': '*' 
          },
          'body': json.dumps(ret_dict, default = default)
      }
      
def default(obj):
    if isinstance(obj, Decimal):
        if int(obj) == obj:
            return int(obj)
        else:
            return float(obj) 