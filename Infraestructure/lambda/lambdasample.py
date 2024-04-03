import os
import uuid

import boto3
from dotenv import load_dotenv

load_dotenv()

TABLE_NAME = os.getenv("DYNAMODB_TABLE_NAME")

dynamodb = boto3.resource("dynamodb")


table = dynamodb.Table(TABLE_NAME)


def lambda_handler(event, context):
    try:
        request_body = event["body"]
        task_name = request_body["task_name"]
        cron_expression = request_body["cron_expression"]

        print(request_body)
        print(task_name, cron_expression)

        task_id = str(uuid.uuid4())

        print(f"El id de la tarea es: {task_id}")

        table.put_item(
            Item={
                "task_id": task_id,
                "task_name": task_name,
                "cron_expression": cron_expression,
            }
        )

        response = {
            "isBase64Encoded": False,
            "statusCode": 200,
            "headers": {},
            "body": "Tarea creada satisfactoriamente",
        }

        return response

    except Exception as e:
        # Manejo de errores

        response = {
            "isBase64Encoded": False,
            "statusCode": 500,
            "headers": {},
            "body": f"Error en la creación de la tarea: {str(e)}",
        }
        return response


# if __name__ == "__main__":
#     event = {
#         "body": {"task_name": "tarea1 de prueba", "cron_expression": "cron 0 0 * * *"}
#     }

#     print(TABLE_NAME)
#     response = lambda_handler(event, context={})
#     print(response)
#     print(table)
