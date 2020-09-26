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