data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_dynamodb_table" "website_table" {
  name         = "websiteTable"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "counter"

  attribute {
    name = "counter"
    type = "S"
  }
}

resource "aws_dynamodb_table_item" "visitors" {
  lifecycle {
    ignore_changes = [item]
  }
  table_name = aws_dynamodb_table.website_table.name
  hash_key   = aws_dynamodb_table.website_table.hash_key

  item = <<ITEM
{
  "counter": {"S": "visitors"},
  "numberVisitors": {"N": "0"}
}
ITEM
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/../lambda_function.py"
  output_path = "${path.module}/lambda_function.zip"
}

resource "aws_lambda_function" "visitorCounter" {
  function_name    = "visitorCounter"
  role             = "arn:aws:iam::876762732886:role/service-role/visitorCounter-role-gsg1ln16"
  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.14"
}

resource "aws_api_gateway_rest_api" "restTest" {
  name = "restTest"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_method" "myPOST" {
  rest_api_id   = aws_api_gateway_rest_api.restTest.id
  resource_id   = aws_api_gateway_rest_api.restTest.root_resource_id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "postIntegration" {
  rest_api_id = aws_api_gateway_rest_api.restTest.id
  resource_id = aws_api_gateway_rest_api.restTest.root_resource_id
  http_method = aws_api_gateway_method.myPOST.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.visitorCounter.invoke_arn
}

resource "aws_api_gateway_method" "myOPTIONS" {
  rest_api_id   = aws_api_gateway_rest_api.restTest.id
  resource_id   = aws_api_gateway_rest_api.restTest.root_resource_id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "optionsIntegration" {
  rest_api_id = aws_api_gateway_rest_api.restTest.id
  resource_id = aws_api_gateway_rest_api.restTest.root_resource_id
  http_method = "OPTIONS"
  type        = "MOCK"
  request_templates = {
    "application/json" = "{\"statusCode\": 200}"
  }
}

resource "aws_api_gateway_method_response" "optionsStatus" {
  rest_api_id = aws_api_gateway_rest_api.restTest.id
  resource_id = aws_api_gateway_rest_api.restTest.root_resource_id
  http_method = aws_api_gateway_method.myOPTIONS.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration_response" "options" {
  depends_on  = [aws_api_gateway_method_response.optionsStatus]
  rest_api_id = aws_api_gateway_rest_api.restTest.id
  resource_id = aws_api_gateway_rest_api.restTest.root_resource_id
  http_method = aws_api_gateway_method.myOPTIONS.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Origin"  = "'https://gregoryeberwine.com'"
  }
}

resource "aws_api_gateway_deployment" "myDeployment" {
  depends_on  = [aws_api_gateway_integration.postIntegration, aws_api_gateway_integration.optionsIntegration]
  rest_api_id = aws_api_gateway_rest_api.restTest.id
}

resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.myDeployment.id
  rest_api_id   = aws_api_gateway_rest_api.restTest.id
  stage_name    = "Prod"
}

resource "aws_lambda_permission" "lambdaAPIPermission" {
  statement_id  = "allowAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitorCounter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.restTest.execution_arn}/*/*"
}

resource "aws_cloudwatch_metric_alarm" "invocationFailure" {
  alarm_name          = "invocationFailure"
  evaluation_periods  = "1"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1"
  statistic           = "Sum"
  period              = "300"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  dimensions = {
    function_name = aws_lambda_function.visitorCounter.function_name
  }
  alarm_actions = [aws_sns_topic.alarmNotifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "invocations" {
  alarm_name          = "invocations"
  evaluation_periods  = "1"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "50"
  statistic           = "Sum"
  period              = "300"
  namespace           = "AWS/Lambda"
  metric_name         = "Invocations"
  dimensions = {
    function_name = aws_lambda_function.visitorCounter.function_name
  }
  alarm_actions = [aws_sns_topic.alarmNotifications.arn]
}

resource "aws_cloudwatch_metric_alarm" "apiLatency" {
  alarm_name          = "apiLatency"
  evaluation_periods  = "1"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  threshold           = "1000"
  statistic           = "Average"
  period              = "300"
  namespace           = "AWS/ApiGateway"
  metric_name         = "Latency"
  dimensions = {
    ApiName = aws_api_gateway_rest_api.restTest.name
  }
  alarm_actions = [aws_sns_topic.alarmNotifications.arn]
}

resource "aws_sns_topic" "alarmNotifications" {
  name = "alarmNotifications"
}

variable "notification_email" {
  type      = string
  sensitive = true
}

resource "aws_sns_topic_subscription" "emailNotifications" {
  endpoint  = var.notification_email
  protocol  = "email"
  topic_arn = aws_sns_topic.alarmNotifications.arn
}