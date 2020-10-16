provider "aws" {
    region = "us-east-2"
}

# Create S3 bucket
resource "aws_s3_bucket" "terraform-state" {
    bucket = "jairo-terraform-up-and-running-state" # Must be globally unique name.

    # Prevent accidental deletion of this S3 bucket.
    lifecycle {
        prevent_destroy = true
    }

    # Enable versioning so we can see the full revision history of your state files.
    versioning {
        enabled = true # Every update to file creates new version.
    }

    # Enable server-side encryption by default
    server_side_encryption_configuration {
        rule {
            apply_server_side_encryption_by_default {
                sse_algorithm ="AES256"
            }
        }
    }
}

# Create DynanmoDB(Amazon's distributed key-value store) to use for locking
resource "aws_dynamodb_table" "terraform_locks" {
    name = "terraform-up-and-running-locks"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "LockID" # Primary key

    attribute {
        name = "LockID"
        type = "S"
    }
}

# Tell Terraform to store state in S3 bucket previously defined
# Requires running terraform init again once this is coded for the first time.
terraform {
    backend "s3" { # aka "remote backend"
        # Replace this with your bucket name!
        bucket = "jairo-terraform-up-and-running-state" # bucket created earlier
        key = "global/s3/terraform.tfstate" # S3 bucket file path for terraform.tfstate file.
        region = "us-east-2"

        # Replace this with your DynamoDB table name!
        dynamodb_table = "terraform-up-and-running-locks" # Created earlier to be used for locking.
        encrypt = true # Already done earlier but you can do again.
    }
}

# Used to test seeing locking message when running terraform apply.
output "s3_bucket_arn" {
    value = aws_s3_bucket.terraform-state.arn
    description = "The ARN of the S3 bucket"
}

output "dynamodb_table_name" {
    value = aws_dynamodb_table.terraform_locks.name
    description = "The name of the DynamoDB table"
}