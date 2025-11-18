provider "aws" {
  region = var.region
}

resource "aws_lambda_function" "security_audit" {
  function_name = var.lambda_function_name
  s3_bucket     = var.s3_bucket
  s3_key        = var.s3_key
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  role          = var.lambda_role_arn

  environment {
  variables = {
    LOG_LEVEL     = "INFO"
    RESULT_BUCKET = var.result_bucket
    ACCOUNT_ID     = var.account_id
  }
}

  # Optioneel: verhoog geheugen/tijdslimiet
  memory_size      = 128
  timeout          = 30
  publish          = true
}

# Eventuele permissies, bv. CloudWatch logs
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.security_audit.function_name
  principal     = "events.amazonaws.com"
}
