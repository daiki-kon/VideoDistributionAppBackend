resource "aws_s3_bucket" "b" {
  bucket = "video-distribution-video-repo"
  acl    = "private"
}