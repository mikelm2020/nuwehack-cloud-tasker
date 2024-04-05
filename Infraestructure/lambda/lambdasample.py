import json
import uuid

import boto3


def lambda_handler(event, context):
    """
    This function is the entry point for the AWS Lambda function.
    It receives an event object containing the request body and context information.

    Parameters:
    - event (dict): The input event data from AWS Lambda. It contains the request body.
    - context (dict): The context object provides information about the execution environment.

    Returns:
    - dict: A dictionary containing the HTTP response headers and body.

    Raises:
    - Exception: If an error occurs during task creation.

    The function extracts the task name and cron expression from the request body,
    generates a unique task ID, and stores the task details in a DynamoDB table.
    If successful, it returns a 200 status code and a success message.
    If an error occurs, it returns a 500 status code and an error message.
    """

    TABLE_NAME = "tasks"

    dynamodb = boto3.resource("dynamodb")

    table = dynamodb.Table(TABLE_NAME)

    try:
        request_body = json.loads(event["body"])
        task_name = request_body["task_name"]
        cron_expression = request_body["cron_expression"]

        task_id = str(uuid.uuid4())

        table.put_item(
            Item={
                "task_id": task_id,
                "task_name": task_name,
                "cron_expression": cron_expression,
            }
        )

        response = {
            "statusCode": 200,
            "body": json.dumps({"message": "Tarea creada satisfactoriamente"}),
        }

        return response

    except Exception as e:
        # Manejo de errores

        response = {
            "statusCode": 500,
            "body": json.dumps(
                {"error": f"Error en la creación de la tarea: {str(e)}"}
            ),
        }
        return response
