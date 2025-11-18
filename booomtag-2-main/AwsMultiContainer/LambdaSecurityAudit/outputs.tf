output "lambda_function_name" {
  description = "Naam van de Lambda-functie"
  value       = aws_lambda_function.security_audit.function_name
}

output "lambda_function_arn" {
  description = "ARN van de Lambda-functie"
  value       = aws_lambda_function.security_audit.arn
}
