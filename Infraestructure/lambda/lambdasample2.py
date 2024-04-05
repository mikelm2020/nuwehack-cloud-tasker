import json

import boto3


def lambda_handler(event, context):
    TABLE_NAME = "tasks"

    dynamodb = boto3.resource("dynamodb")

    table = dynamodb.Table(TABLE_NAME)

    try:
        scanned = table.scan()
        tasks = scanned["Items"]

        response = {
            "statusCode": 200,
            "body": json.dumps(tasks),
        }

        return response
    except Exception as e:
        response = {
            "statusCode": 500,
            "body": json.dumps(
                {"error": f"Ha ocurrido un error al listar las tareas: {str(e)}"}
            ),
        }
        return response
