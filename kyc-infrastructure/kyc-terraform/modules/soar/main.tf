data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.root}/../../aws-soar/src"
  output_path = "${path.root}/../../aws-soar/lambda_function.zip"
}

resource "aws_iam_role" "lambda_exec" {
  name = "kyc_soar_lambda_exec_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "soar" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "kyc-soar-formatter"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "lambda_function.lambda_handler"
  runtime          = "python3.12"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      TENANT_ID = var.tenant_id
    }
  }
}

# Create a Function URL so JIRA/Sentinel can call it directly without API Gateway
resource "aws_lambda_function_url" "soar_url" {
  function_name      = aws_lambda_function.soar.function_name
  authorization_type = "NONE" # You should secure this in production
}
