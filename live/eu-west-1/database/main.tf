provider "aws" {
  version = "~> 2.11.0"
  region  = "eu-west-1"
}

terraform {
  backend "s3" {
    bucket  = "s3cours"
    encrypt = true
    key     = "live/eu-west-1/database/.terraform/terraform.tfstate"
    region  = "eu-west-1"
  }
}

variable "ami_name" {}
variable "ami_id" {}
variable "ami_key_pair_name" {}

resource "aws_vpc" "main" {
  cidr_block           = "172.20.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
}

resource "aws_db_instance" "default" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "9.6"
  instance_class         = "db.t2.micro"
  name                   = "mydb"
  username               = "root"
  password               = "A7B3UR54"
  parameter_group_name   = "default.postgres9.6"
  db_subnet_group_name   = "${aws_db_subnet_group.default.id}"
  availability_zone      = "eu-west-1a"
  vpc_security_group_ids = ["${aws_security_group.allow_tls.id}"]
  skip_final_snapshot    = true
}

resource "aws_subnet" "main" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "172.20.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "Main"
  }
}

resource "aws_subnet" "main2" {
  vpc_id            = "${aws_vpc.main.id}"
  cidr_block        = "172.20.2.0/24"
  availability_zone = "eu-west-1b"

  tags = {
    Name = "Main"
  }
}

resource "aws_security_group" "allow_tls" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = "${aws_vpc.main.id}"

  ingress {
    cidr_blocks = [
      "0.0.0.0/0",
    ]

    from_port = 22
    to_port   = 22
    protocol  = "tcp"
  }

  ingress {
    cidr_blocks = [
      "0.0.0.0/0",
    ]

    from_port = 8080
    to_port   = 8080
    protocol  = "tcp"
  }

  ingress {
    cidr_blocks = [
      "0.0.0.0/0",
    ]

    from_port = 5432
    to_port   = 5432
    protocol  = "tcp"
  }

  // Terraform removes the default rule
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = ["${aws_subnet.main.id}", "${aws_subnet.main2.id}"]

  tags = {
    Name = "My DB subnet group"
  }
}

//servers.tf
resource "aws_instance" "test-ec2-instance" {
  ami             = "${var.ami_id}"
  instance_type   = "t2.micro"
  key_name        = "${var.ami_key_pair_name}"
  security_groups = ["${aws_security_group.allow_tls.id}"]

  tags {
    Name = "coucou ${var.ami_name}"
  }

  subnet_id = "${aws_subnet.main.id}"
}

resource "aws_eip" "ip-test-env" {
  instance = "${aws_instance.test-ec2-instance.id}"
  vpc      = true
}

//gateways.tf
resource "aws_internet_gateway" "test-env-gw" {
  vpc_id = "${aws_vpc.main.id}"

  tags {
    Name = "test-env-gw"
  }
}

//subnets.tf
resource "aws_route_table" "route-table-test-env" {
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.test-env-gw.id}"
  }

  tags {
    Name = "test-env-route-table"
  }
}

resource "aws_route_table_association" "subnet-association" {
  subnet_id      = "${aws_subnet.main.id}"
  route_table_id = "${aws_route_table.route-table-test-env.id}"
}
