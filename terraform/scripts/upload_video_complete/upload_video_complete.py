import boto3
import urllib.parse
import os
import datetime
import pytz
import re
import unicodedata

VIDEO_INFO_TABLE_NAME = os.environ['VIDEO_INFO_TABLE_NAME']

def lambda_handler(event: dict, context):
    print(event)

    video_path = urllib.parse.unquote(event['Records'][0]['s3']['object']['key'])

    # 'file name' has 'video id'
    video_id = video_path.split('/')[-1].split('.')[0]
    print(video_path)
    print(video_id)

    uploaded_time = get_current_time('Asia/Tokyo')

    print(uploaded_time)

    to_upload_complete(video_path, video_id, uploaded_time)
    # forDev(video_id, video_path, uploaded_time)

def to_upload_complete(video_path: str, video_id: str, uploaded_time: str):

    dynamodb = boto3.resource('dynamodb')

    table = dynamodb.Table(VIDEO_INFO_TABLE_NAME)

    response = table.update_item(
        Key={
            'videoId': video_id,
        },
        UpdateExpression="set videoPath=:p, isUploaded=:i, uploadedTIme=:u",
        ExpressionAttributeValues={
            ':p': video_path,
            ':i': True,
            ':u': uploaded_time
        }
    )

    return

def forDev(video_id: str, video_path: str, uploaded_time: str):

    dynamodb = boto3.resource('dynamodb')

    table = dynamodb.Table(VIDEO_INFO_TABLE_NAME)

    response = table.put_item(
        Item={
            'videoId': video_id,
            'videoTitle': join_diacritic(video_id),
            'videoPath': video_path,
            'uploadedTIme': uploaded_time,
            'userName': 'kenta',
            'goodNum': 0,
            'badNum': 0,
            'isUploaded': True
        }
    )
    return response

def get_current_time(time_zone: str):
    dt_now = datetime.datetime.now(pytz.timezone(time_zone))

    date_time =  dt_now.isoformat().split('.')[0].replace('-', '').replace(':', '')
    time_zone = dt_now.isoformat().split('.')[1].split('+')[1]

    return date_time + '+' + time_zone

import re
import unicodedata

def join_diacritic(text, mode="NFC"):

    # str -> bytes
    bytes_text = text.encode()

    # 濁点Unicode結合文字置換
    bytes_text = re.sub(b"\xe3\x82\x9b", b'\xe3\x82\x99', bytes_text)
    bytes_text = re.sub(b"\xef\xbe\x9e", b'\xe3\x82\x99', bytes_text)

    # 半濁点Unicode結合文字置換
    bytes_text = re.sub(b"\xe3\x82\x9c", b'\xe3\x82\x9a', bytes_text)
    bytes_text = re.sub(b"\xef\xbe\x9f", b'\xe3\x82\x9a', bytes_text)

    # bytet -> str
    text = bytes_text.decode()

    # 正規化
    text = unicodedata.normalize(mode, text)

    return text