resource "aws_dynamodb_table" "video_info" {
  name           = "VideoDistributionVideoInfo"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "videoId"

  attribute {
    name = "videoId"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_dynamodb_table" "inverted_index" {
  name           = "VideoDistributionInvertedIndex"
  billing_mode   = "PROVISIONED"
  read_capacity  = 5
  write_capacity = 5
  hash_key       = "Key"

  attribute {
    name = "Key"
    type = "S"
  }

  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_lambda_event_source_mapping" "invert_index" {
  event_source_arn  = aws_dynamodb_table.video_info.stream_arn
  function_name     = aws_lambda_function.invert_index_ddb_stream.arn
  starting_position = "LATEST"
  batch_size = 1
}

# Lambda
data "archive_file" "invert_index_ddb_stream" {
  type        = "zip"
  source_dir  = "terraform/scripts/invertIndex/"
  output_path = "terraform/scripts/invertIndex.zip"
}

data "archive_file" "janome_lambda_layer" {
  type        = "zip"
  source_dir  = "terraform/modules/janome"
  output_path = "terraform/janome_lib.zip"
}

resource "aws_lambda_layer_version" "janome" {
  filename            = data.archive_file.janome_lambda_layer.output_path
  layer_name          = "janome"
  compatible_runtimes = ["python3.8"]
  source_code_hash    = data.archive_file.janome_lambda_layer.output_base64sha256
  depends_on          = [data.archive_file.janome_lambda_layer]
}

resource "aws_lambda_function" "invert_index_ddb_stream" {
  function_name = "invert_index_ddb_stream"
  handler       = "invertIndex.lambda_handler"
  role          = aws_iam_role.invert_index_ddb_stream.arn
  runtime       = "python3.8"

  filename         = data.archive_file.invert_index_ddb_stream.output_path
  source_code_hash = data.archive_file.invert_index_ddb_stream.output_base64sha256

  timeout     = 10
  memory_size = 1256

  layers = [aws_lambda_layer_version.janome.arn]

  environment {
    variables = {
      VIDEO_TITLE_TABLE_NAME = "${aws_dynamodb_table.inverted_index.name}"
    }
  }

  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_cloudwatch_log_group" "lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.invert_index_ddb_stream.function_name}"
  retention_in_days = 3
  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_iam_role" "invert_index_ddb_stream" {
  name = "invert_index_ddb_stream_lambda"

  tags = {
    AppName = "VideoDistribution"
  }

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
  role = aws_iam_role.invert_index_ddb_stream.id
  name = "invert_index_ddb_stream_lambda"

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

// DynamoDB へのアクセス権限
resource "aws_iam_role_policy" "invert_index_ddb_stream_allow_access" {
  role = aws_iam_role.invert_index_ddb_stream.id
  name = "invert_index_table_lamdba"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "dynamodb:DeleteItem",
                "dynamodb:GetItem",
                "dynamodb:Query",
                "dynamodb:PutItem"
            ],
            "Resource": "${aws_dynamodb_table.inverted_index.arn}",
            "Effect": "Allow"
        }
    ]
}
EOF
}