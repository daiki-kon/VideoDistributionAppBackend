## data store
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

## auth
resource "aws_cognito_user_pool" "user_manage" {
  name = "VideoDistributionApp"

  password_policy {
    minimum_length    = 6
    require_lowercase = false
    require_numbers   = false
    require_symbols   = false
    require_uppercase = false
  }
}

resource "aws_cognito_user_pool_client" "user_manage" {
  name = "VideoDistributionAppClient"

  user_pool_id = aws_cognito_user_pool.user_manage.id
}

resource "aws_cognito_identity_pool" "user_manage" {
  identity_pool_name               = "VideoDistributionApp"
  allow_unauthenticated_identities = false

  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.user_manage.id
    provider_name = aws_cognito_user_pool.user_manage.endpoint
  }

}

resource "aws_cognito_identity_pool_roles_attachment" "user_manage" {
  identity_pool_id = aws_cognito_identity_pool.user_manage.id

  roles = {
    "authenticated" = aws_iam_role.authenticated.arn
    "unauthenticated" = aws_iam_role.unauthenticated.arn
  }
}

resource "aws_iam_role" "authenticated" {
  name = "video_distribution_app_client_cognito_authenticated"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.user_manage.id}"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "authenticated"
        }
      }
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "authenticated" {
  name = "video_distribution_app_client_cognito_authenticated_policy"
  role = aws_iam_role.authenticated.id

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role" "unauthenticated" {
  name = "video_distribution_app_client_cognito_unauthenticated"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "cognito-identity.amazonaws.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "cognito-identity.amazonaws.com:aud": "${aws_cognito_identity_pool.user_manage.id}"
        },
        "ForAnyValue:StringLike": {
          "cognito-identity.amazonaws.com:amr": "unauthenticated"
        }
      }
    }
  ]
}
EOF
}

output "name" {
  value = aws_cognito_user_pool_client.user_manage.id
}