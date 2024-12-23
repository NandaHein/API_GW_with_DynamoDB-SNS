variable "config_file" {
  description = "config_file."
  type        = list(string)
  default     = ["/home/nanda/.aws/config"]
}

variable "creds_file" {
  description = "creds_file."
  type        = list(string)
  default     = ["/home/nanda/.aws/credentials"]
}

variable "aws_profile" {
  description = "this is aws profile"
  type        = string
  default     = "grit-cloudnanda"
}

variable "aws_region" {
  description = "this is aws region to provision your infrasture with terraform"
  type        = string
  default     = "ap-southeast-1"
}

variable "email_address" {
  description = "this is your email address"
  type        = string
  default     = "devopsnandahein28@gmail.com"
}

variable "stage_name" {
  description = "this is your stage name"
  type        = string
  default     = "dev"
}

variable "table_name" {
  description = "this is your dynamodb table name"
  type        = string
  default     = "employee_info"
}

variable "read_capacity" {
  description = "this is your dynamodb read capacity"
  type        = number
  default     = 1
}

variable "write_capacity" {
  description = "this is your dynamodb write capacity"
  type        = number
  default     = 1
}

variable "table_class_type" {
  description = "this is your dynamodb table class type"
  type        = string
  default     = "STANDARD_INFREQUENT_ACCESS"
}

variable "lambda_execution_role_name" {
  description = "this is your lambda execution role name"
  type        = string
  default     = "lambda_execution_role_dynamodb"
}

variable "lambda_function_name" {
  description = "this is your lambda function name"
  type        = string
  default     = "lambda_function_dynamodb"
}

variable "api_gw_name" {
  description = "this is your api gateway name"
  type        = string
  default     = "rest_apigw"
}

variable "sns_topic_name" {
  description = "this is your sns topic name"
  type        = string
  default     = "API_to_SNS"
}

variable "sns_role_name" {
  description = "this is your sns role name"
  type        = string
  default     = "API_to_SNS_role"
}

variable "sns_custom_policy_name" {
  description = "this is your sns custom policy name"
  type        = string
  default     = "API_to_SNS_inlinepolicy"
}

variable "aws_account_id" {
  description = "this is your aws account id"
  type        = string
  default     = "112281322679"
}


