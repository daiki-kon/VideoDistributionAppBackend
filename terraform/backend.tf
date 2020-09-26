terraform {
  backend "s3" {
    bucket = "video-distribution-app-tfstate"
    region = "us-east-1"
    key    = "aws.tfstate"
  }
}