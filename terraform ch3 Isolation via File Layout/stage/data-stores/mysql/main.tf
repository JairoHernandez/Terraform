provider "aws" {
    region = "us-east-2"
}

resource "aws_db_instance" "example" {
    identifier_prefix = "terraform-up-and-running"
    engine = "mysql"
    allocated_storage = 10
    instance_class = "db.t2.micro"
    name = "example_database"
    username = "admin"
    skip_final_snapshot = true # Otherwise you will see --> Error: DB Instance FinalSnapshotIdentifier is required when a final snapshot is required

    # # Other option is to use an export entry as a varible(pg. 101)
    # password = data.aws_secretsmanager_secret_version.db_password.secret_string
    password = var.db_password
}

# data "aws_secretsmanager_secret_version" "db_password" {
#     secret_id = "mysql-master-password-stage"
# }

# Tell Terraform to store state in S3 bucket previously defined in Dropbox/code/terraform/terraform/terraform ch3 Isolation via File Layout/global/s3/main.tf
# Requires running terraform init again once this is coded for the first time.
terraform {
    backend "s3" { # aka "remote backend"
        # Replace this with your bucket name!
        bucket = "jairo-terraform-up-and-running-state" # bucket created earlier
        key = "stage/data-stores/mysql/terraform.tfstate" # S3 bucket file path for mysql db instance terraform.tfstate file.
        region = "us-east-2"

        # Replace this with your DynamoDB table name!
        dynamodb_table = "terraform-up-and-running-locks" # Created earlier to be used for locking.
        encrypt = true # Already done earlier but you can do again.
    }
}