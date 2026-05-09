output "soar_lambda_function_url" {
  description = "The public HTTP endpoint for the SOAR function"
  value       = aws_lambda_function_url.soar_url.function_url
}
