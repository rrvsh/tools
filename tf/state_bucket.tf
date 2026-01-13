resource "aws_s3_bucket" "tfstate" {
  bucket = "rrvsh-tfstate-dev"
}

resource "aws_s3_bucket_versioning" "versioning_tfstate" {
  bucket = aws_s3_bucket.tfstate.id
  versioning_configuration {
    status = "Enabled"
  }
}
