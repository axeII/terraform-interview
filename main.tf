terraform {
  cloud {
    organization = "akira128"

    workspaces {
      name = "terraform-interview"
    }
  }
}
provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.region}"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical
}

resource "aws_instance" "hello-world" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  # key_name      = "<ssh_key_name>"

  user_data = <<-EOF
              #!/bin/bash
              echo "foo" > /home/ubuntu/hello-world.txt
              chown ubuntu:ubuntu /home/ubuntu/hello-world.txt
              EOF

  tags = {
    Name = "HelloWorld"
  }
}