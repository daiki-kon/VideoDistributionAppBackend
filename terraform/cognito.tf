resource "aws_cognito_user_pool" "user_manage" {
  name = "VideoDistributionApp"

  password_policy {
    minimum_length                   = 6
    require_lowercase                = false
    require_numbers                  = false
    require_symbols                  = false
    require_uppercase                = false
    temporary_password_validity_days = 7
  }
}

resource "aws_cognito_user_pool_client" "user_manage_secret" {
  name = "VideoDistributionAppClientSecret"

  generate_secret     = true
  user_pool_id = aws_cognito_user_pool.user_manage.id
}

resource "aws_cognito_user_pool_client" "user_manage" {
  name = "VideoDistributionAppClient"
  
  generate_secret     = false
  user_pool_id = aws_cognito_user_pool.user_manage.id
}

resource "aws_cognito_identity_pool" "user_manage" {
  identity_pool_name               = "VideoDistributionApp"
  allow_unauthenticated_identities = true

  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.user_manage.id
    provider_name = aws_cognito_user_pool.user_manage.endpoint
  }

  cognito_identity_providers {
    client_id     = aws_cognito_user_pool_client.user_manage_secret.id
    provider_name = aws_cognito_user_pool.user_manage.endpoint
  }

}

resource "aws_cognito_identity_pool_roles_attachment" "user_manage" {
  identity_pool_id = aws_cognito_identity_pool.user_manage.id

  roles = {
    "authenticated"   = aws_iam_role.authenticated.arn
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

output "cognito_user_pool_id" {
  value = aws_cognito_user_pool_client.user_manage.id
}