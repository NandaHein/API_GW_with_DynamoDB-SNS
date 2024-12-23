data "aws_region" "current" {}

###################### Create Dynamodb table with provisioned mode ######################
resource "aws_dynamodb_table" "this" {
  name           = var.table_name
  billing_mode   = "PROVISIONED"
  hash_key       = "employeeid"
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  table_class    = var.table_class_type

  attribute {
    name = "employeeid"
    type = "S"
  }

  tags = {
    Name = var.table_name
  }
}

######################## lambda function and required permissions #######################
resource "aws_iam_role" "lambda_execution_role" {
  name = var.lambda_execution_role_name
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sts:AssumeRole"
          ],
          "Principal" : {
            "Service" : [
              "lambda.amazonaws.com"
            ]
          }
        }
      ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_policy" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_policy_to_dynamodb" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_execution_role_policy_to_cloudwatchlogs" {
  role       = aws_iam_role.lambda_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

resource "aws_lambda_function" "lambda_function" {
  function_name    = var.lambda_function_name
  role             = aws_iam_role.lambda_execution_role.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  architectures    = ["x86_64"]
  filename         = "lambda_python.zip"
  source_code_hash = filebase64sha256("lambda_python.zip")
  environment {
    variables = {
      DYNAMODB_TABLE = var.table_name
    }
  }
}

######################## SNS and required permissions ##########################
resource "aws_sns_topic" "API_to_SNS" {
  name = var.sns_topic_name
  policy = jsonencode(
    {
      "Version" : "2008-10-17",
      "Id" : "__default_policy_ID",
      "Statement" : [
        {
          "Sid" : "__default_statement_ID",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : "*"
          },
          "Action" : [
            "SNS:Publish",
            "SNS:RemovePermission",
            "SNS:SetTopicAttributes",
            "SNS:DeleteTopic",
            "SNS:ListSubscriptionsByTopic",
            "SNS:GetTopicAttributes",
            "SNS:AddPermission",
            "SNS:Subscribe"
          ],
          "Resource" : "arn:aws:sns:ap-southeast-1:${var.aws_account_id}:API_to_SNS",
          "Condition" : {
            "StringEquals" : {
              "AWS:SourceOwner" : var.aws_account_id
            }
          }
        },
        {
          "Sid" : "__console_pub_0",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : [
              var.aws_account_id
            ]
          },
          "Action" : "SNS:Publish",
          "Resource" : "arn:aws:sns:ap-southeast-1:${var.aws_account_id}:API_to_SNS"
        },
        {
          "Sid" : "__console_sub_0",
          "Effect" : "Allow",
          "Principal" : {
            "AWS" : [
              var.aws_account_id
            ]
          },
          "Action" : [
            "SNS:Subscribe"
          ],
          "Resource" : "arn:aws:sns:ap-southeast-1:${var.aws_account_id}:API_to_SNS"
        }
      ]
    }
  )
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
}
EOF
}

resource "aws_sns_topic_subscription" "Subscribe_to_API_SNS_topic" {
  topic_arn = aws_sns_topic.API_to_SNS.arn
  protocol  = "email"
  endpoint  = var.email_address
}


resource "aws_iam_role" "API_to_SNS_role" {
  name = var.sns_role_name
  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Sid" : "",
          "Effect" : "Allow",
          "Principal" : {
            "Service" : [
              "apigateway.amazonaws.com"
            ]
          },
          "Action" : [
            "sts:AssumeRole"
          ]
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "API_to_SNS_default_role_policy" {
  role       = aws_iam_role.API_to_SNS_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
}

resource "aws_iam_policy" "API_to_SNS_inlinepolicy" {
  name = var.sns_custom_policy_name
  policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : "sns:Publish",
          "Resource" : "*"
        }
      ]
    }
  )
}

resource "aws_iam_role_policy_attachment" "API_to_SNS_inline_role_policy" {
  role       = aws_iam_role.API_to_SNS_role.name
  policy_arn = aws_iam_policy.API_to_SNS_inlinepolicy.arn
}

######################## API Gateway ###########################
resource "aws_api_gateway_rest_api" "rest_apigw" {
  name = var.api_gw_name
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

############################ Mock API Resource ###############################
resource "aws_api_gateway_resource" "mock_http_enp_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "mock"
}

resource "aws_api_gateway_method" "Mock_Method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.mock_http_enp_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "mock_integration" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.mock_http_enp_resource.id
  http_method = aws_api_gateway_method.Mock_Method.http_method
  type        = "MOCK"
  request_templates = {
    "application/json" = <<EOF
{
   "statusCode": 200
}
EOF
  }
}

resource "aws_api_gateway_method_response" "mock_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.mock_http_enp_resource.id
  http_method = aws_api_gateway_method.Mock_Method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "mock_intergration_respone" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.mock_http_enp_resource.id
  http_method = aws_api_gateway_method.Mock_Method.http_method
  status_code = aws_api_gateway_method_response.mock_response_200.status_code
  response_templates = {
    "application/json" = <<EOF
{
    "statusCode": 200,
    "message": "APIs are awesome",
    "details": {
        "Name": "REST API GW",
        "id": 1,
        "status": true
    }
}
EOF
  }
  depends_on = [aws_api_gateway_integration.mock_integration]
}

##################### Lambda API Resource ############################
# lambda status resource 
resource "aws_api_gateway_resource" "lambda_resource_status" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "status"
}

# lambda employees resource
resource "aws_api_gateway_resource" "lambda_resource_employees" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "employees"
}

# lambda employee resource
resource "aws_api_gateway_resource" "lambda_resource_employee" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "employee"
}

# Method and Integration for /status (GET)
resource "aws_api_gateway_method" "Lambda_Method_01" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.lambda_resource_status.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_status_resource" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.lambda_resource_status.id
  http_method             = aws_api_gateway_method.Lambda_Method_01.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "lambda_response_200_status_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.lambda_resource_status.id
  http_method = aws_api_gateway_method.Lambda_Method_01.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# Method and Integration for /employees (GET)
resource "aws_api_gateway_method" "Lambda_Method_02" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.lambda_resource_employees.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_employees_resource" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.lambda_resource_employees.id
  http_method             = aws_api_gateway_method.Lambda_Method_02.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "lambda_response_200_employees_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.lambda_resource_employees.id
  http_method = aws_api_gateway_method.Lambda_Method_02.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# Method and Integration for /employee (GET)
resource "aws_api_gateway_method" "Lambda_Method_03" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.lambda_resource_employee.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_employee_resource" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.lambda_resource_employee.id
  http_method             = aws_api_gateway_method.Lambda_Method_03.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "lambda_response_200_employee_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.lambda_resource_employee.id
  http_method = aws_api_gateway_method.Lambda_Method_03.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# Method and Integration for /employee (POST)
resource "aws_api_gateway_method" "Lambda_Method_04" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.lambda_resource_employee.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_employee_resource_post" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.lambda_resource_employee.id
  http_method             = aws_api_gateway_method.Lambda_Method_04.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "lambda_response_200_employee_resource_post" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.lambda_resource_employee.id
  http_method = aws_api_gateway_method.Lambda_Method_04.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# Method and Integration for /employee (PATCH)
resource "aws_api_gateway_method" "Lambda_Method_05" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.lambda_resource_employee.id
  http_method   = "PATCH"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_employee_resource_patch" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.lambda_resource_employee.id
  http_method             = aws_api_gateway_method.Lambda_Method_05.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "lambda_response_200_employee_resource_patch" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.lambda_resource_employee.id
  http_method = aws_api_gateway_method.Lambda_Method_05.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

# Method and Integration for /employee (DELETE)
resource "aws_api_gateway_method" "Lambda_Method_06" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.lambda_resource_employee.id
  http_method   = "DELETE"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_integration_employee_resource_delete" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.lambda_resource_employee.id
  http_method             = aws_api_gateway_method.Lambda_Method_06.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}

resource "aws_api_gateway_method_response" "lambda_response_200_employee_resource_delete" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.lambda_resource_employee.id
  http_method = aws_api_gateway_method.Lambda_Method_06.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

############# SNS API Resource ##############
resource "aws_api_gateway_resource" "sns_resource" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  parent_id   = aws_api_gateway_rest_api.rest_apigw.root_resource_id
  path_part   = "sns"
}

resource "aws_api_gateway_method" "SNS_Method" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  resource_id   = aws_api_gateway_resource.sns_resource.id
  http_method   = "POST"
  authorization = "NONE"
  request_parameters = {
    "method.request.querystring.TopicArn" = true
    "method.request.querystring.Message"  = true
  }
}

resource "aws_api_gateway_integration" "sns_integration" {
  rest_api_id             = aws_api_gateway_rest_api.rest_apigw.id
  resource_id             = aws_api_gateway_resource.sns_resource.id
  http_method             = aws_api_gateway_method.SNS_Method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sns:action/Publish"
  credentials             = aws_iam_role.API_to_SNS_role.arn
  timeout_milliseconds    = 29000
  request_parameters = {
    "integration.request.querystring.TopicArn" = "method.request.querystring.TopicArn"
    "integration.request.querystring.Message"  = "method.request.querystring.Message"
  }
}

resource "aws_api_gateway_method_response" "sns_response_200" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.sns_resource.id
  http_method = aws_api_gateway_method.SNS_Method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "sns_intergration_respone" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  resource_id = aws_api_gateway_resource.sns_resource.id
  http_method = aws_api_gateway_method.SNS_Method.http_method
  status_code = aws_api_gateway_method_response.sns_response_200.status_code
  response_templates = {
    "application/json" = ""
  }
  depends_on = [aws_api_gateway_integration.sns_integration]
}

############################ API GW Lambda Permission ###########################################
#Gives an external source (like an EventBridge Rule, SNS, or S3 or API GW) permission to access the Lambda function.
resource "aws_lambda_permission" "lambda_permission_to_APIGW" {
  statement_id  = "AllowRestAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"

  # The /* part allows invocation from any stage, method and resource path
  # within API Gateway.
  source_arn = "${aws_api_gateway_rest_api.rest_apigw.execution_arn}/*"
  depends_on = [
    aws_api_gateway_rest_api.rest_apigw
  ]
}

############################ API GW Deployment ###############################
resource "aws_api_gateway_deployment" "api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.rest_apigw.id
  depends_on = [
    aws_api_gateway_integration.lambda_integration_status_resource,
    aws_api_gateway_integration.lambda_integration_employees_resource,
    aws_api_gateway_integration.lambda_integration_employee_resource,
    aws_api_gateway_integration.lambda_integration_employee_resource_post,
    aws_api_gateway_integration.lambda_integration_employee_resource_patch,
    aws_api_gateway_integration.lambda_integration_employee_resource_delete,
    aws_api_gateway_integration.mock_integration,
    aws_api_gateway_integration.sns_integration,
    aws_api_gateway_rest_api.rest_apigw
  ]
}

resource "aws_api_gateway_stage" "api_stage_deployment" {
  rest_api_id   = aws_api_gateway_rest_api.rest_apigw.id
  deployment_id = aws_api_gateway_deployment.api_deployment.id
  stage_name    = var.stage_name
}