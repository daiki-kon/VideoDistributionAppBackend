resource "aws_s3_bucket" "video_repo" {
  bucket = "video-distribution-video-repo"
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "video_repo" {
  bucket                  = aws_s3_bucket.video_repo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lambda
data "archive_file" "upload_video_complete" {
  type        = "zip"
  source_dir  = "terraform/scripts/upload_video_complete/"
  output_path = "terraform/scripts/upload_video_complete.zip"
}

resource "aws_lambda_function" "upload_video_complete" {
  function_name = "upload_video_complete"
  handler       = "upload_video_complete.lambda_handler"
  role          = aws_iam_role.upload_video_complete.arn
  runtime       = "python3.8"

  filename         = data.archive_file.upload_video_complete.output_path
  source_code_hash = data.archive_file.upload_video_complete.output_base64sha256

  timeout     = 3
  memory_size = 256

  environment {
    variables = {
      VIDEO_INFO_TABLE_NAME = "${aws_dynamodb_table.video_info.name}"
    }
  }

  layers = [aws_lambda_layer_version.pytz.arn]

  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_cloudwatch_log_group" "upload_video_complete_lambda_log_group" {
  name              = "/aws/lambda/${aws_lambda_function.upload_video_complete.function_name}"
  retention_in_days = 3
  tags = {
    AppName = "VideoDistribution"
  }
}

resource "aws_lambda_permission" "upload_video_complete" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.upload_video_complete.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.video_repo.arn
}

resource "aws_s3_bucket_notification" "upload_video_complete" {
  bucket = aws_s3_bucket.video_repo.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.upload_video_complete.arn
    events              = ["s3:ObjectCreated:*"]
  }
}

resource "aws_iam_role" "upload_video_complete" {
  name = "upload_video_complete_lambda"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "upload_video_complete" {
  role = aws_iam_role.upload_video_complete.id
  name = "upload_video_complete_lamdba"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": [
                "dynamodb:PutItem",
                "dynamodb:UpdateItem"
            ],
            "Resource": "${aws_dynamodb_table.video_info.arn}",
            "Effect": "Allow"
        },
        {
            "Action": [
                "s3:*"
            ],
            "Resource": [
              "${aws_s3_bucket.video_repo.arn}",
              "${aws_s3_bucket.video_repo.arn}/*"
            ],
            "Effect": "Allow"
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "upload_video_complete_attatch_LambdaBasicExecution" {
  role       = aws_iam_role.upload_video_complete.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}