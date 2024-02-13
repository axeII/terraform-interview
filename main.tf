terraform {
  cloud {
    organization = "akira128"

    workspaces {
      name = "github-terraform-interview"
    }
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "5.36.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

}

resource "aws_instance" "hello-world" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  user_data = <<-EOF
              #!/bin/bash
              echo "foo" > /home/ubuntu/hello-world.txt
              chown ubuntu:ubuntu /home/ubuntu/hello-world.txt
              EOF

  tags = {
    Name = "HelloWorld"
  }
}
