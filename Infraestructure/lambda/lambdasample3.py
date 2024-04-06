import json

import boto3


def lambda_handler(event, context):
    bucket_name = "taskstorage"
    print("Evento recibido:", json.dumps(event))

    event_type = event.get("detail-type")

    if event_type is not None:
        # EventBridge Invocation
        task = event.get("detail")

        if event_type == "TaskDescribed":
            customer_id = task.get("customerId")
            if customer_id:
                pass

    # Contenido del ítem que deseas crear (aquí puedes personalizar según tus necesidades)
    item_content = {"key": "valor", "otra_key": "otro_valor"}

    # Convertir el contenido del ítem a formato JSON
    item_json = json.dumps(item_content)

    # Inicializar el cliente de S3
    s3 = boto3.client("s3")

    try:
        # Subir el ítem al bucket S3
        s3.put_object(Bucket=bucket_name, Key="nombre_del_item.json", Body=item_json)

        # Respuesta exitosa
        response = {
            "statusCode": 200,
            "body": json.dumps(
                {"message": "Ítem creado satisfactoriamente en el bucket S3."}
            ),
        }

        return response

    except Exception as e:
        # Si ocurre un error, devolver una respuesta de error
        response = {
            "statusCode": 500,
            "body": json.dumps(
                {"error": f"Error al crear el ítem en el bucket S3: {str(e)}"}
            ),
        }

    return response
