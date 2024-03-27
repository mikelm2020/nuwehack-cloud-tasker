import json
import uuid
import boto3
import os

TABLE_NAME = os.environ.get("DYNAMODB_TABLE_NAME")

dynamodb = boto3.resource("dynamodb")

table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):

    try:
        request_body = json.loads(event["body"])
        task_name = request_body["task_name"]
        cron_expression = request_body["cron_expression"]

        task_id = str(uuid.uuid4())
        response = table.put_item(
            Item={
                "task_id": task_id,
                "task_name": task_name,
                "cron_expression": cron_expression,
            }
        )

        return {
            "statusCode": 200,
            "body": json.dumps("Tarea creada satisfactoriamente"),
        }

    except Exception as e:
        # Manejo de errores
        return {
            "statusCode": 500,
            "body": json.dumps(f"Error en la creación de la tarea: {str(e)}"),
        }
