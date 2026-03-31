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