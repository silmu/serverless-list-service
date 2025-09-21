terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

# DynamoDB table with a single list
resource "aws_dynamodb_table" "list_table" {
  name         = "ListServiceMainList"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "list_id"

  attribute {
    name = "list_id"
    type = "S"
  }

  tags = {
    Name        = "ListService"
    Environment = "Production"
  }
}

# IAM role for Lambda functions
resource "aws_iam_role" "lambda_role" {
  name = "ListServiceLambdaRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for Lambda to access DynamoDB
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name        = "ListServiceLambdaDynamoDBPolicy"
  description = "Policy for Lambda to access DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = aws_dynamodb_table.list_table.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Lambda function for head operation
resource "aws_lambda_function" "head_function" {
  filename      = "head.zip"
  function_name = "ListServiceHead"
  role          = aws_iam_role.lambda_role.arn
  handler       = "head.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.list_table.name
    }
  }

  source_code_hash = filebase64sha256("head.zip")
}

# Lambda function for tail operation
resource "aws_lambda_function" "tail_function" {
  filename      = "tail.zip"
  function_name = "ListServiceTail"
  role          = aws_iam_role.lambda_role.arn
  handler       = "tail.lambda_handler"
  runtime       = "python3.9"
  timeout       = 30

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.list_table.name
    }
  }

  source_code_hash = filebase64sha256("tail.zip")
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "list_service_api" {
  name        = "ListServiceAPI"
  description = "API for ListService operations"
}

# Head endpoint at root level
resource "aws_api_gateway_resource" "head_resource" {
  rest_api_id = aws_api_gateway_rest_api.list_service_api.id
  parent_id   = aws_api_gateway_rest_api.list_service_api.root_resource_id
  path_part   = "head"
}

resource "aws_api_gateway_method" "head_method" {
  rest_api_id   = aws_api_gateway_rest_api.list_service_api.id
  resource_id   = aws_api_gateway_resource.head_resource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "head_integration" {
  rest_api_id = aws_api_gateway_rest_api.list_service_api.id
  resource_id = aws_api_gateway_resource.head_resource.id
  http_method = aws_api_gateway_method.head_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.head_function.invoke_arn
}

# Tail endpoint at root level
resource "aws_api_gateway_resource" "tail_resource" {
  rest_api_id = aws_api_gateway_rest_api.list_service_api.id
  parent_id   = aws_api_gateway_rest_api.list_service_api.root_resource_id
  path_part   = "tail"
}

resource "aws_api_gateway_method" "tail_method" {
  rest_api_id   = aws_api_gateway_rest_api.list_service_api.id
  resource_id   = aws_api_gateway_resource.tail_resource.id
  http_method   = "GET"
  authorization = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_integration" "tail_integration" {
  rest_api_id = aws_api_gateway_rest_api.list_service_api.id
  resource_id = aws_api_gateway_resource.tail_resource.id
  http_method = aws_api_gateway_method.tail_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.tail_function.invoke_arn
}

# Lambda permissions for API Gateway
resource "aws_lambda_permission" "apigw_head" {
  statement_id  = "AllowAPIGatewayInvokeHead"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.head_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.list_service_api.execution_arn}/*/GET/head"
}

resource "aws_lambda_permission" "apigw_tail" {
  statement_id  = "AllowAPIGatewayInvokeTail"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.tail_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.list_service_api.execution_arn}/*/GET/tail"
}

# API Gateway deployment
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    aws_api_gateway_integration.head_integration,
    aws_api_gateway_integration.tail_integration
  ]

  rest_api_id = aws_api_gateway_rest_api.list_service_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_method.head_method.id,
      aws_api_gateway_method.tail_method.id,
      aws_api_gateway_integration.head_integration.id,
      aws_api_gateway_integration.tail_integration.id
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "production" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.list_service_api.id
  stage_name    = "prod"
}

# API Key for ListService
resource "aws_api_gateway_api_key" "list_service_key" {
  name        = "ListServiceApiKey"
  description = "API key for ListService"
  enabled     = true
}

resource "aws_api_gateway_usage_plan" "list_service_usage_plan" {
  name = "ListServiceUsagePlan"

  api_stages {
    api_id = aws_api_gateway_rest_api.list_service_api.id
    stage  = aws_api_gateway_stage.production.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "list_service_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.list_service_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.list_service_usage_plan.id
}

# Output the API endpoint URL
output "api_url" {
  value = aws_api_gateway_stage.production.invoke_url
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.list_table.name
}

output "api_key_value" {
  value     = aws_api_gateway_api_key.list_service_key.value
  sensitive = true
}

# Initialize the single list in DynamoDB
resource "null_resource" "initialize_list" {
  depends_on = [aws_dynamodb_table.list_table]

  provisioner "local-exec" {
    command = <<EOT
      aws dynamodb put-item \
        --table-name ${aws_dynamodb_table.list_table.name} \
        --item '{"list_id": {"S": "main_list"}, "items": {"L": [{"S": "item1"}, {"S": "item2"}, {"S": "item3"}, {"S": "item4"}, {"S": "item5"}]}}' \
        --region eu-north-1
    EOT
  }

  triggers = {
    always_run = timestamp()
  }
}