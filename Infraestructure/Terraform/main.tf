# provider "aws" {
#   access_key                  = "test"
#   secret_key                  = "test"
#   region                      = "us-east-1"
#   skip_credentials_validation = true
#   skip_metadata_api_check     = true
#   s3_use_path_style           = false
#   skip_requesting_account_id  = true

#   endpoints {
#     apigateway     = "http://localhost:4566"
#     cloudwatch     = "http://localhost:4566"
#     lambda         = "http://localhost:4566"
#     dynamodb       = "http://localhost:4566"
#     events         = "http://localhost:4566"
#     iam            = "http://localhost:4566"
#     sts            = "http://localhost:4566"
#     s3             = "http://s3.localhost.localstack.cloud:4566"
#   }
# }


terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 5.31.0"
    }
  }
}

resource "aws_dynamodb_table" "tasks" {
  name           = "tasks"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "task_id"
  attribute {
    name = "task_id"
    type = "S"
  }
}


resource "aws_api_gateway_rest_api" "task_api" {
  name        = "TaskAPI"
  description = "API for managing tasks"
}

resource "aws_api_gateway_resource" "create_task_resource" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "createtask"
}

resource "aws_api_gateway_method" "create_task_method" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.create_task_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "create_task_integration" {
  type                    = "AWS_PROXY"
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.create_task_resource.id
  http_method             = aws_api_gateway_method.create_task_method.http_method
  integration_http_method = "POST"
  passthrough_behavior = "WHEN_NO_TEMPLATES"
  content_handling = "CONVERT_TO_TEXT"
  uri                     = aws_lambda_function.create_scheduled_task.invoke_arn
  
}

resource "aws_lambda_permission" "apigw_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_scheduled_task.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "arn:aws:execute-api:us-east-1:000000000000:${aws_api_gateway_rest_api.task_api.id}/*/*/*"
}

resource "aws_api_gateway_method_response" "create_task_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.create_task_resource.id
  http_method = aws_api_gateway_method.create_task_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" : true,
    "method.response.header.Content-Type" : true
  }
}

resource "aws_api_gateway_integration_response" "create_task_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.create_task_resource.id
  http_method = aws_api_gateway_method.create_task_method.http_method
  status_code = aws_api_gateway_method_response.create_task_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" : "'*'",
    "method.response.header.Content-Type" : "'text/html'"
  }

  response_templates = {
    "json/application" : "$input.json('$')"
  }

  depends_on = [aws_api_gateway_integration.create_task_integration]
  
}

resource "aws_s3_bucket" "lambda_layer_bucket" {
  bucket        = "create-schedule-task-bucket-jk70i0layer"
  force_destroy = true
  lifecycle {
    prevent_destroy = false
  }
}

# # Generar un entorno virtual e instalar las dependencias
# resource "null_resource" "generate_lambda_layer" {
#   triggers = {
#     always_run = timestamp()
#   }

#   provisioner "local-exec" {
#     command = "${path.module}/../../lambda/sh layer.sh"
#   }
# }

# Empaquetar la capa Lambda
data "archive_file" "lambda_layer_file" {
  type        = "zip"
  source_dir  = "${path.module}/../lambda/env"
  output_path = "${path.module}/../lambda/lambda_layer.zip"
}

# Subir el archivo de la capa Lambda a S3
resource "aws_s3_object" "lambda_layer_object" {
  bucket = aws_s3_bucket.lambda_layer_bucket.bucket
  key    = "lambda_layer.zip"
  source = data.archive_file.lambda_layer_file.output_path
  etag   = data.archive_file.lambda_layer_file.output_base64sha256

  depends_on = [
	    data.archive_file.lambda_layer_file,
	    # null_resource.generate_lambda_layer,
	  ]
}

# Crear la capa Lambda
resource "aws_lambda_layer_version" "lambda_layer" {
  layer_name = "lambda_layer"
  s3_bucket  = aws_s3_bucket.lambda_layer_bucket.bucket
  s3_key     = aws_s3_object.lambda_layer_object.key
  source_code_hash = data.archive_file.lambda_layer_file.output_base64sha256

  compatible_runtimes = ["python3.10"]
	  depends_on = [
	    aws_s3_object.lambda_layer_object,
	  ]
}

data "archive_file" "lambda_create_scheduled_task_file"{
  type = "zip"

  source_file = "${path.module}/../lambda/lambdasample.py"
  output_path = "${path.module}/../lambda/create_scheduled_task.zip"
}

# resource "aws_s3_bucket" "lambda_create_scheduled_task_bucket" {
#   bucket        = "create-schedule-task-bucket-bklambdaftcreate"
#   force_destroy = true
#   lifecycle {
#     prevent_destroy = false
#   }
# }

# resource "aws_s3_object" "lambda_create_scheduled_task_code" {
#   bucket = aws_s3_bucket.lambda_create_scheduled_task_bucket.id
#   key    = "create_scheduled_task.zip"
#   source = data.archive_file.lambda_create_scheduled_task_file.output_path

#   etag = filemd5(data.archive_file.lambda_create_scheduled_task_file.output_path)
# }

resource "aws_lambda_function" "create_scheduled_task" {
  filename = data.archive_file.lambda_create_scheduled_task_file.output_path
  function_name = "createScheduledTask"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambdasample.lambda_handler"
  runtime       = "python3.10"
  layers        = [aws_lambda_layer_version.lambda_layer.arn]
  # s3_bucket     = aws_s3_bucket.lambda_layer_bucket.id
  # s3_key        = aws_s3_object.lambda_layer_object.key
  source_code_hash = data.archive_file.lambda_create_scheduled_task_file.output_base64sha256
  memory_size   = 512
  timeout       = 60

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
    }
  }
}
 
resource "aws_cloudwatch_log_group" "create_scheduled_task" {
  name = "/aws/lambda/${aws_lambda_function.create_scheduled_task.function_name}"

  retention_in_days = 30
}

resource "aws_api_gateway_resource" "list_task_resource" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
  path_part   = "listtask"
}

resource "aws_api_gateway_method" "list_task_method" {
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  resource_id   = aws_api_gateway_resource.list_task_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "list_task_integration" {
  rest_api_id             = aws_api_gateway_rest_api.task_api.id
  resource_id             = aws_api_gateway_resource.list_task_resource.id
  http_method             = aws_api_gateway_method.list_task_method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.list_scheduled_task.invoke_arn
}

resource "aws_api_gateway_method_response" "list_task_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.list_task_resource.id
  http_method = aws_api_gateway_method.list_task_method.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" : true,
    "method.response.header.Content-Type" : true
  }
}

resource "aws_api_gateway_integration_response" "list_task_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id
  resource_id = aws_api_gateway_resource.list_task_resource.id
  http_method = aws_api_gateway_method.list_task_method.http_method
  status_code = aws_api_gateway_method_response.list_task_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" : "'*'",
    "method.response.header.Content-Type" : "'text/html'"
  }

  response_templates = {
    "text/html" : "$input.path('$')"
  }

  depends_on = [aws_api_gateway_integration.list_task_integration]
}

data "archive_file" "lambda_list_scheduled_task_file"{
  type = "zip"

  source_file = "${path.module}/../lambda/lambdasample2.py"
  output_path = "${path.module}/../lambda/list_scheduled_task.zip "
}

# resource "aws_s3_bucket" "lambda_list_scheduled_task_bucket" {
#   bucket        = "list-schedule-task-bucket-bklambdaftlist"
#   force_destroy = true
#   lifecycle {
#     prevent_destroy = false
#   }
# }

# resource "aws_s3_object" "lambda_list_scheduled_task_code" {
#   bucket = aws_s3_bucket.lambda_list_scheduled_task_bucket.id
#   key    = "list_scheduled_task.zip"
#   source = data.archive_file.lambda_list_scheduled_task_file.output_path

#   etag = filemd5(data.archive_file.lambda_list_scheduled_task_file.output_path)
# }

resource "aws_lambda_function" "list_scheduled_task" {
  filename = data.archive_file.lambda_list_scheduled_task_file.output_path
  function_name = "listScheduledTask"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "lambdasample2.lambda_handler"
  runtime       = "python3.10"
  # s3_bucket     = aws_s3_bucket.lambda_list_scheduled_task_bucket.id
  # s3_key        = aws_s3_object.lambda_list_scheduled_task_code.key
  source_code_hash = data.archive_file.lambda_list_scheduled_task_file.output_base64sha256
  memory_size   = 512
  timeout       = 60

  environment {
    variables = {
      DYNAMODB_TABLE_NAME = aws_dynamodb_table.tasks.name
    }
  }
}

resource "aws_cloudwatch_log_group" "list_scheduled_task" {
  name = "/aws/lambda/${aws_lambda_function.list_scheduled_task.function_name}"

  retention_in_days = 30
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.task_api.id
  stage_name    = "dev"


  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigateway.arn
    format = jsonencode({
      "requestId" : "$context.requestId",
      "ip" : "$context.identity.sourceIp",
      "caller" : "$context.identity.caller",
      "user" : "$context.identity.user",
      "requestTime" : "$context.requestTime",
      "httpMethod" : "$context.httpMethod",
      "resourcePath" : "$context.resourcePath",
      "status" : "$context.status",
      "protocol" : "$context.protocol",
      "responseLength" : "$context.responseLength"
    })
  }

  depends_on = [
    aws_api_gateway_method.create_task_method,
    aws_api_gateway_method.list_task_method
  ]
}

resource "aws_cloudwatch_log_group" "apigateway" {
  name              = "/aws/apigateway/${aws_api_gateway_rest_api.task_api.name}"
  retention_in_days = 3
}

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.task_api.id

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_method.create_task_method,
    aws_api_gateway_integration.create_task_integration,
    aws_api_gateway_method.list_task_method,
    aws_api_gateway_integration.list_task_integration
  ]
}

# resource "aws_api_gateway_method_settings" "create_task_settings" {
#   rest_api_id = aws_api_gateway_rest_api.task_api.id
#   stage_name  = "dev"
#   method_path = join("", ["", aws_api_gateway_resource.create_task_resource.path_part, "/", aws_api_gateway_method.create_task_method.http_method])
  
#   settings {
#     logging_level = "INFO"
#   }
# }

# resource "aws_api_gateway_method_settings" "list_task_settings" {
#   rest_api_id = aws_api_gateway_rest_api.task_api.id
#   stage_name  = "dev"
#   method_path = join("", ["", aws_api_gateway_resource.list_task_resource.path_part, "/", aws_api_gateway_method.list_task_method.http_method])
  
#   settings {
#     logging_level = "INFO"
#   }
# }

# resource "aws_iam_role" "lambda_exec" {
#   name = "lambda_exec_role"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Effect": "Allow",
#       "Principal": {
#         "Service": "lambda.amazonaws.com"
#       },
#       "Action": "sts:AssumeRole"
#     }
#   ]
# }
# EOF
# }

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role"
  
  assume_role_policy = jsonencode({
    Version: "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_exec_policy" {
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  name       = "lambda_exec_policy"
  
}

resource "aws_iam_role_policy" "lambda_basic_policy" {
	  name = "lambda_create_scheduled_task_basic_policy"
	  role = aws_iam_role.lambda_exec.id
	

	  policy = jsonencode({
	  Version: "2012-10-17",
	  Statement: [
      {
			  Effect: "Allow",
			  Action: "logs:CreateLogGroup",
			  Resource: "arn:aws:logs:us-east-1:000000000000:*"
		  },
	    {
	      Effect: "Allow",
	      Action: [
	        "logs:CreateLogStream",
	        "logs:PutLogEvents"
	      ],
	      Resource: [
	        "arn:aws:logs:us-east-1:000000000000:log-group:/aws/lambda/create_scheduled_task:*"
	      ]
	    },
      {
        Effect: "Allow",
        Action: [
          "dynamodb:PutItem"
        ],
        Resource: "arn:aws:dynamodb:us-east-1:000000000000:table/tasks"
      }
	  ]
	})
}    

# resource "aws_s3_bucket" "taskstorage" {
#   bucket = "taskstorage"
# }

# resource "aws_lambda_function" "execute_scheduled_task" {
#   filename      = "../lambda/execute_scheduled_task.zip"
#   function_name = "executeScheduledTask"
#   role          = aws_iam_role.lambda_exec.arn
#   handler       = "lambdasample3.lambda_handler"
#   runtime       = "python3.10"

#   environment {
#     variables = {
#       S3_BUCKET_NAME = aws_s3_bucket.taskstorage.bucket
#     }
#   }
# }

# resource "aws_cloudwatch_event_rule" "every_minute" {
#   name                = "every_minute"
#   schedule_expression = "rate(1 minute)"
# }

# resource "aws_cloudwatch_event_target" "lambda_target" {
#   rule      = aws_cloudwatch_event_rule.every_minute.name
#   target_id = "execute_scheduled_task"
#   arn       = aws_lambda_function.execute_scheduled_task.arn
# }
