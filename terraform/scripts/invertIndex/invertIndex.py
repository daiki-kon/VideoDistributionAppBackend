import boto3
from boto3.dynamodb.types import TypeDeserializer
from boto3.dynamodb.conditions import Key
from janome.tokenizer import Tokenizer
import os 

VIDEO_TITLE_TABLE_NAME = os.environ['VIDEO_TITLE_TABLE_NAME']

def lambda_handler(event: dict, context):
    print(event)
    for record in event['Records']:

        print('eventName: ', record['eventName'])

        posted_record      = record['dynamodb'].get('NewImage')
        old_posted_record  = record['dynamodb'].get('OldImage')

        event_name    = record['eventName']

        if None != posted_record:
            converted_dict     = conv_ddb_to_dict(posted_record)
            video_id           = converted_dict['VideoId']
            video_title        = converted_dict['VideoTitle']
        if None != old_posted_record:
            old_converted_dict = conv_ddb_to_dict(old_posted_record)
            old_video_id       = old_converted_dict['VideoId']
            old_video_title    = old_converted_dict['VideoTitle']

        if event_name == 'INSERT':
            register_title_to_inverted_index(video_id, video_title)

        elif event_name == 'REMOVE':
            delete_title_from_inverted_index(old_video_id, old_video_title)

        elif event_name == 'MODIFY':

            old_video_title    = old_converted_dict['VideoTitle'] 

            delete_title_from_inverted_index(old_video_id, old_video_title)
            register_title_to_inverted_index(video_id, video_title)

    return

def delete_title_from_inverted_index(video_id: str, video_title: str):
    token_list = sectence_to_token(video_title)

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(VIDEO_TITLE_TABLE_NAME)

    for token in token_list:
        response = table.query(
                KeyConditionExpression=Key('Key').eq(token)
        )

        video_ids = response['Items'][0]['VideoIds']

        if 1 == len(video_ids):
            print('delete Key:{}'.format(token))
            table.delete_item(
                Key = {'Key': token}
            )
        else:
            print('delete {} from {}'.format(video_id,token))
            table.put_item(
                Item = {'Key': token, 'VideoIds': [i for i in video_ids if i != video_id]}
            )



def register_title_to_inverted_index(video_id: str, video_title: str):
    token_list = sectence_to_token(video_title)

    print(token_list)

    dynamodb = boto3.resource('dynamodb')
    table = dynamodb.Table(VIDEO_TITLE_TABLE_NAME)

    for token in token_list:
        response = table.query(
                KeyConditionExpression=Key('Key').eq(token)
        )

        put_ids = []
        if 0 == len(response['Items']):
            put_ids = [video_id]
            print('create {}'.format(token))
        else:
            put_ids = response['Items'][0]['VideoIds']
            if video_id  in put_ids:
                print('already exist!!  Key:{} Value:{}'.format(token,video_id))
                continue
            put_ids.append(video_id)

        # NOTE:一つのカラムにリストで追記していくとdynamoDBの上限に引っかかる可能性がある。
        table.put_item(
                Item = {'Key': token, 'VideoIds': put_ids}
        )

def conv_ddb_to_dict(posted_record: dict):

    converted_dict = {}
    deser = TypeDeserializer()

    for key in posted_record:
        converted_dict[key] = deser.deserialize(posted_record[key])

    return converted_dict

def sectence_to_token(sentence: str):
    tokenizer = Tokenizer(wakati=True)
    token_list = {token for token in tokenizer.tokenize(sentence)}
    return token_list