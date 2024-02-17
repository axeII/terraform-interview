terraform {
  cloud {
    organization = "akira128"

    workspaces {
      name = "github-terraform-interview"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.36.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_amplify_app" "webapp" {
  name       = "GettingStartedTF"
  repository = "https://github.com/axeII/terraform-interview"
}

resource "aws_amplify_branch" "html" {
  app_id      = aws_amplify_app.webapp.id
  branch_name = "html"
}


resource "aws_iam_role" "iam_for_lambda" {

  name               = "Spacelift_Test_Lambda_Function_Role"
  assume_role_policy = <<EOF
{

 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_policy" "iam_policy_for_lambda" {
  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda_function.py"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "lambdafce-hellow" {
  filename      = "lambda_function_payload.zip"
  function_name = "HelloWorldFunctionTF"
  role          = aws_iam_role.iam_for_lambda.arn

  source_code_hash = data.archive_file.lambda.output_base64sha256
  runtime          = "python3.8"
  # depends_on       = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

resource "aws_api_gateway_rest_api" "HelloWorldAPITF" {
  name        = "HelloWorldAPITF"
  description = "Hello World API"
}

resource "aws_api_gateway_resource" "Resource" {
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPITF.id
  parent_id   = aws_api_gateway_rest_api.HelloWorldAPITF.root_resource_id
  path_part   = "/"
}

resource "aws_api_gateway_method" "Method" {
  rest_api_id   = aws_api_gateway_rest_api.HelloWorldAPITF.id
  resource_id   = aws_api_gateway_resource.Resource.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_method_response" "CORS" {
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPITF.id
  resource_id = aws_api_gateway_resource.Resource.id
  http_method = aws_api_gateway_method.Method.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = true
    "method.response.header.Access-Control-Allow-Credentials" = true
  }
}

resource "aws_api_gateway_integration" "MyDemoIntegration" {
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPITF.id
  resource_id = aws_api_gateway_resource.Resource.id
  http_method = aws_api_gateway_method.Method.http_method

  type = "MOCK"
}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" {
  depends_on  = [aws_api_gateway_integration.MyDemoIntegration]
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPITF.id
  resource_id = aws_api_gateway_resource.Resource.id
  http_method = aws_api_gateway_method.Method.http_method
  status_code = "200"

  response_templates = {
    "application/json" = ""
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"      = "'*'"
    "method.response.header.Access-Control-Allow-Credentials" = "'true'"
  }
}

resource "aws_api_gateway_integration" "LambdaIntegration" {
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPITF.id
  resource_id = aws_api_gateway_resource.Resource.id
  http_method = aws_api_gateway_method.Method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambdafce-hellow.invoke_arn
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambdafce-hellow.function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_api_gateway_rest_api.HelloWorldAPITF.execution_arn}/*/${aws_api_gateway_method.Method.http_method}${aws_api_gateway_resource.Resource.path}"
}

resource "aws_api_gateway_deployment" "MyDemoDeployment" {
  depends_on  = [aws_api_gateway_integration.MyDemoIntegration]
  rest_api_id = aws_api_gateway_rest_api.HelloWorldAPITF.id
  stage_name  = "dev"
}

output "invoke_url" {
  value = "https://${aws_api_gateway_rest_api.HelloWorldAPITF.id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.MyDemoDeployment.stage_name}/${aws_api_gateway_resource.Resource.path_part}"
}

resource "aws_dynamodb_table" "HelloWorldDatabase" {
  name           = "HelloWorldDatabase"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "UserId"

  attribute {
    name = "UserId"
    type = "N"
  }
}

resource "aws_iam_policy" "dynamodb_policy" {
  name        = "HelloWorldDynamoPolicy"
  path        = "/"
  description = "IAM policy for DynamoDB"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Sid    = "VisualEditor0"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem",
        ]
        Resource = aws_dynamodb_table.HelloWorldDatabase.arn
      },
    ]
  })
}

# resource "aws_iam_role" "iam_database_role" {
#   name               = "iam_database_role"
#   assume_role_policy = file("assume_role_policy.json")
# }

# resource "aws_iam_role_policy_attachment" "iam_database_role_attach" {
#   role       = aws_iam_role.iam_database_role.name
#   policy_arn = aws_iam_policy.dynamodb_policy.arn
# }
