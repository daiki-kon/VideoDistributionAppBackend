resource "aws_api_gateway_deployment" "VideoDistribution" {
  depends_on = [aws_api_gateway_integration.search_video]

  rest_api_id = aws_api_gateway_rest_api.VideoDistribution.id
  stage_name  = "api"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_rest_api" "VideoDistribution" {
  name        = "VideoDistribution"
  description = "for VideoDistribution app"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_api_gateway_resource" "search_video" {
  rest_api_id = aws_api_gateway_rest_api.VideoDistribution.id
  parent_id   = aws_api_gateway_rest_api.VideoDistribution.root_resource_id
  path_part   = "searchVideo"
}

resource "aws_api_gateway_method" "search_video" {
  rest_api_id   = aws_api_gateway_rest_api.VideoDistribution.id
  resource_id   = aws_api_gateway_resource.search_video.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "search_video" {
  rest_api_id             = aws_api_gateway_rest_api.VideoDistribution.id
  resource_id             = aws_api_gateway_resource.search_video.id
  http_method             = aws_api_gateway_method.search_video.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.search_video.invoke_arn
}

# Lambda
data "archive_file" "search_video" {
  type        = "zip"
  source_dir  = "terraform/scripts/search_video/"
  output_path = "terraform/scripts/search_video.zip"
}

resource "aws_lambda_permission" "search_video" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.search_video.function_name
  principal     = "apigateway.amazonaws.com"

  # More: http://docs.aws.amazon.com/apigateway/latest/developerguide/api-gateway-control-access-using-iam-policies-to-invoke-api.html
  source_arn = "${aws_api_gateway_rest_api.VideoDistribution.execution_arn}/*/*"
}

resource "aws_lambda_function" "search_video" {
  function_name = "search_video"
  handler       = "search_video.lambda_handler"
  role          = aws_iam_role.search_video.arn
  runtime       = "python3.8"

  filename         = data.archive_file.search_video.output_path
  source_code_hash = data.archive_file.search_video.output_base64sha256

  environment {
    variables = {
      INVERTED_TABLE_NAME = "${aws_dynamodb_table.inverted_index.name}"
      VIDEO_INFO_TABLE_NAME = "${aws_dynamodb_table.video_info.name}"
    }
  }

  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_cloudwatch_log_group" "search_video_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.search_video.function_name}"
  retention_in_days = 3
  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_iam_role" "search_video" {
  name = "search_video_lambda"

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

resource "aws_iam_role_policy_attachment" "search_videoe_attatch_LambdaBasicExecution" {
  role       = aws_iam_role.search_video.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

// DynamoDB へのアクセス権限
resource "aws_iam_role_policy" "search_video" {
  role = aws_iam_role.search_video.id
  name = "search_videoe_policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "dynamodb:GetItem",
                "dynamodb:Query"
            ],
            "Resource": [
                "${aws_dynamodb_table.inverted_index.arn}",
                "${aws_dynamodb_table.video_info.arn}"
            ],
            "Effect": "Allow"
        }
    ]
}
EOF
}