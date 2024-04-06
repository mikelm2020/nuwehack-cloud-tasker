import json

import boto3


def lambda_handler(event, context):
    """
    Lambda function to handle HTTP requests for listing tasks.

    Parameters
    ----------
    event: dict, required
        API Gateway Lambda Proxy Input Format



    context: object, required
        Lambda Context runtime methods and attributes



    Returns
    ------
    API Gateway Lambda Proxy Output Format: dict


    """
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
                {"error": f"An error occurred while retrieving tasks: {str(e)}"}
            ),
        }
        return response
