import boto3
import os
import uuid

s3 = boto3.client("s3")


def lambda_handler(event, context):
    executeScheduledTask()


def executeScheduledTask(item):
    s3_bucket_name = os.environ["S3_BUCKET_NAME"]

    # se crea un archivo vacío con un nombre generado aleatoriamente
    filename = str(uuid.uuid4()) + ".txt"
    s3.put_object(Bucket=s3_bucket_name, Key=filename)

    return {"statusCode": 200, "body": "Object created in S3 bucket"}
