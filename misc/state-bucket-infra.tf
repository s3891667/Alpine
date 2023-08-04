terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
  backend "local" {}
}

resource "aws_dynamodb_table" "foo_state_bucket_table" {
  name           = "state_lock_table"
  read_capacity  = 20
  write_capacity = 20
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}
resource "aws_s3_bucket" "foo_bucket" {
  bucket = "s3891667-state-bucket"
}
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.foo_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}
provider "aws" {
  region = "us-east-1"
  
}
