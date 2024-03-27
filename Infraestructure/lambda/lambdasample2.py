import json
import boto3
import os

TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME")

dynamodb = boto3.resource("dynamodb")

table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    listScheduledTask()


def listScheduledTask(item):

    response = table.scan()
    tasks = response["Items"]

    return {"statusCode": 200, "body": json.dumps(tasks)}
