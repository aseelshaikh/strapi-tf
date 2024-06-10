terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.50.0"
    }
  }
}

provider "aws" {
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  region = var.aws_region
}

resource "aws_s3_bucket" "strapi_s3" {
  bucket = var.s3_name
}

resource "null_resource" "get_rds_credentials" {
  provisioner "local-exec" {
    command = "read -p 'RDS username: ' rds_username; echo 'rds_username = \"'$rds_username'\"' >> terraform.tfvars; read -p 'RDS password: ' -s rds_password; echo 'rds_password = \"'$rds_password'\"' >> terraform.tfvars"
  }
}

resource "aws_db_instance" "strapi_db" {
  name              = var.rds_name
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "postgres"
  engine_version    = "12"
  instance_class    = "db.t2.micro"
  username          = var.rds_username
  password          = var.rds_password
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.strapi_sg.id]
  db_subnet_group_name  = aws_db_subnet_group.strapi_db_sub.name
}

resource "aws_db_subnet_group" "strapi_db_sub" {
  name        = "mystrapidbsubnetgroup"
  description = "My DB subnet group"
  subnet_ids  = [aws_subnet.strapi_sub.id, aws_subnet.strapi_sub2.id]
}

resource "aws_security_group" "strapi_sg" {
  name        = "example2"
  description = "Example security group"
  vpc_id = aws_vpc.strapi_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 1337
    to_port     = 1337
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_subnet" "strapi_sub" {
  vpc_id                  = aws_vpc.strapi_vpc.id
  cidr_block              = "10.0.0.0/24"
  availability_zone       = "us-east-1a"
}

resource "aws_subnet" "strapi_sub2" {
  vpc_id     = aws_vpc.strapi_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
}

resource "aws_vpc" "strapi_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_internet_gateway" "strapi_igw" {
  vpc_id = aws_vpc.strapi_vpc.id
}

resource "aws_eip" "strapi_ip" {
  vpc = true
}

resource "null_resource" "get_strapi_domain" {
  provisioner "local-exec" {
    command = "read -p 'Strapi domain: ' strapi_domain; echo 'strapi_domain = \"'$strapi_domain'\"' >> terraform.tfvars"
  }
}

resource "aws_route_table" "route-table-exapmle" {
  vpc_id = "${aws_vpc.strapi_vpc.id}"
route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.strapi_igw.id}"
  }
}
resource "aws_route_table_association" "subnet-association" {
  subnet_id      = "${aws_subnet.strapi_sub.id}"
  route_table_id = "${aws_route_table.route-table-exapmle.id}"
}

resource "aws_key_pair" "strapi_pubkey" {
  key_name = var.key_name
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDi8gqsv45RYGqoX2RGgEUhw3/y9IXv2CC8PmHwLUFo1Ktdn4pKPnhOun7hdb6on2Bz/SPC6Ay6iAvkT9e/7FioQYID8eG/lJSwen9cW8uOlle9k20VxANmVvxRLg6a2z+fo3yEzKXczwguV76aq8jrgutDbUqyJhF2cR8kqidKsclMjZ5YsGp21VIBlnyjwjQTKG2oNrArbgIxyV0Fo09ibmofZiJEebKjs50P+ffiqlT+8+NM9uqpMoEkZIHPbzUPgdu6f/EaeiojgNRRSQATO9KlJHonm1fituVEj4IOQxx8rHkttHNjZydNuknakZeKT5O5Unyeq3DN2U0htyO9fn3Z8jRCk+QS63f3V/HbI5X6hGTRW0VIRG4DHr+l0GTiibnHP0KiWeCF56EBVBeKzHMiA+7y5VtlFrkNSwseh9YWkCsPp8lR1y+EOvnbPwyPZLSPG8o9CgOQ8h92sBbxtbvUG0lAOb4ugx0PBs3wdlB292IZrCCcHJbnkXbiXb8="
}

resource "aws_instance" "strapi_ec2" {
  depends_on    = [aws_db_subnet_group.strapi_db_sub]
  ami           = "ami-0778521d914d23bc1"
  instance_type = "t2.xlarge"
  key_name      = var.key_name
  vpc_security_group_ids = [aws_security_group.strapi_sg.id]
  subnet_id     = aws_subnet.strapi_sub.id
  tags = {
    Name = "Terra-Strapi-Ubuntu"
  }
}

resource "aws_eip_association" "strapi_eip_assc" {
  depends_on = [aws_instance.strapi_ec2]
  instance_id = aws_instance.strapi_ec2.id
  public_ip = aws_eip.strapi_ip.public_ip
}

resource "null_resource" "add_key" {
  depends_on = [local.endpoint]
  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command = "./local-exec.sh ${aws_eip.strapi_ip.public_ip}; scp -i ~/.ssh/strapikey.pem userdata.sh ubuntu@${aws_eip.strapi_ip.public_ip}:/tmp/"
  }
}

resource "null_resource" "ssh_ec2" {
  depends_on = [null_resource.add_key]
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = "${aws_eip.strapi_ip.public_ip}"
      private_key = "${file("~/.ssh/strapikey.pem")}"
      timeout = "2m"
      agent = false
      }
        inline = [
          "bash /tmp/userdata.sh ${local.endpoint} ${var.rds_username} ${var.rds_password} ${var.rds_name} ${aws_s3_bucket.strapi_s3.bucket} ${var.strapi_domain} ${var.aws_access_key} ${var.aws_secret_key} ${var.aws_region}"
        ]
    }
}

locals {
  depends_on = [aws_eip_association.strapi_eip_assc]
  endpoint = split(":", aws_db_instance.strapi_db.endpoint)[0]
}

output "endpoint_without_port" {
  value = local.endpoint
}

output "server_private_ip" {
value = aws_instance.strapi_ec2.private_ip
}
output "server_public_ipv4" {
value = aws_instance.strapi_ec2.public_ip
}
output "server_id" {
value = aws_instance.strapi_ec2.id
}
