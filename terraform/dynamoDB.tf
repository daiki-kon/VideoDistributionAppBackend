resource "aws_dynamodb_table" "video_info" {
  name           = "VideoDistributionVideoInfo"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "VideoId"

  attribute {
    name = "VideoId"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  tags = {
    App = "VideoDistribution"
  }
}

resource "aws_dynamodb_table" "inverted_index" {
  name           = "VideoDistributionInvertedIndex"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "Key"
  range_key      = "VideoId"

  attribute {
    name = "Key"
    type = "S"
  }

  attribute {
    name = "VideoId"
    type = "S"
  }

  tags = {
    App = "VideoDistribution"
  }
}

resource "aws_lambda_event_source_mapping" "invert_index" {
  event_source_arn  = aws_dynamodb_table.video_info.stream_arn
  function_name     = aws_lambda_function.invert_index_ddb_stream.arn
  starting_position = "LATEST"
}

# Lambda
data "archive_file" "invert_index_ddb_stream" {
  type        = "zip"
  source_dir  = "terraform/scripts/invertIndex/"
  output_path = "terraform/scripts/invertIndex.zip"
}

resource "aws_lambda_function" "invert_index_ddb_stream" {
  function_name = "invert_index_ddb_stream"
  handler       = "invertIndex.lambda_handler"
  role          = aws_iam_role.invert_index_ddb_stream.arn
  runtime       = "python3.8"

  filename         = data.archive_file.invert_index_ddb_stream.output_path
  source_code_hash = data.archive_file.invert_index_ddb_stream.output_base64sha256
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.invert_index_ddb_stream.function_name}"
  retention_in_days = 3
}

resource "aws_iam_role" "invert_index_ddb_stream" {
  name = "invert_index_ddb_stream_lambda"

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

resource "aws_iam_role_policy_attachment" "invert_index_ddb_stream_attatch_LambdaBasicExecution" {
  role       = aws_iam_role.invert_index_ddb_stream.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

// DynamoDB Stream の読み込み権限
resource "aws_iam_role_policy" "invert_index_ddb_stream_allow_stream" {
  role   = aws_iam_role.invert_index_ddb_stream.id
  name   = "invert_index_ddb_stream_"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "dynamodb:DescribeStream",
                "dynamodb:GetRecords",
                "dynamodb:GetShardIterator",
                "dynamodb:ListStreams"
            ],
            "Resource": "${aws_dynamodb_table.video_info.stream_arn}",
            "Effect": "Allow"
        }
    ]
}
EOF
}