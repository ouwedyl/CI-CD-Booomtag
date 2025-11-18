variable "region" {
  description = "AWS-regio waar de resources worden aangemaakt"
  type        = string
  default     = "eu-central-1"
}

variable "result_bucket" {
  description = "S3 bucket waar de auditresultaten opgeslagen worden"
  type        = string
  default     = "gitlabcli-test-fdmci2"
}

variable "lambda_function_name" {
  description = "Naam van de Lambda-functie"
  type        = string
  default     = "SecurityAuditLambda"
}

variable "s3_bucket" {
  description = "S3 bucket waar de Lambda ZIP staat"
  type        = string
  default     = "gitlabcli-test-fdmci2"
}

variable "s3_key" {
  description = "Pad/naam van de Lambda ZIP in S3"
  type        = string
  default     = "security_audit_lambda.zip"
}

variable "lambda_handler" {
  description = "Handler van de Lambda"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "lambda_runtime" {
  description = "Runtime voor de Lambda"
  type        = string
  default     = "python3.13"
}

variable "lambda_role_arn" {
  description = "IAM Role ARN die Lambda mag gebruiken"
  type        = string
  default     = "arn:aws:iam::205930632714:role/SecurityAuditLambdaRole"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  default     = "205930632714"
}