output "api_create_scheduled_task_invoke_url" {
  description = "URL para la api de createtask"
  value = "http://${aws_api_gateway_stage.example.rest_api_id}.execute-api.localhost.localstack.cloud:4566/${aws_api_gateway_stage.example.stage_name}/createtask"
}

output "api_list_scheduled_task_invoke_url" {
  description = "URL para la api de listtask"
  value = "http://${aws_api_gateway_stage.example.rest_api_id}.execute-api.localhost.localstack.cloud:4566/${aws_api_gateway_stage.example.stage_name}/listtask"
}
