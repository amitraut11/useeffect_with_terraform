resource "aws_s3_bucket" "codepipeline-artifacts-firstreactapp" {
  bucket = "codepipeline-artifacts-firstreactapp"
  acl    = "private"
}
