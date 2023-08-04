#Root module terrraform 
terraform {
    required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
      }
    }
    #Remote Back-end S3
    backend "s3" {
	bucket = "s3891667-state-bucket"
	key            = "terraform.tfstate"
	region         = "us-east-1"
	dynamodb_table = "state_lock_table"
	encrypt        = true
    }
}

#Connect with aws service
provider "aws" {
  region = "us-east-1"
}

#taking output form servers and datase to use it in Ansible
output  "servers_ip"{ 
	value = [for instance in aws_instance.servers: instance.public_ip ]
}

output "db_ip" {
	value = aws_instance.database.public_ip
}
