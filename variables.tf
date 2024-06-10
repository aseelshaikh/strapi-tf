variable "rds_name" {
  type        = string
  description = "The name of the RDS instance"
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
}

variable "aws_region" {
  type        = string
  description = "AWS Region"
}

variable "s3_name" {
  type        = string
  description = "The name of the S3 Bucket"
}

variable "rds_username" {
  description = "Enter the username for the RDS instance"
}

variable "rds_password" {
  description = "Enter the password for the RDS instance"
}

variable "strapi_domain" {
  description = "Enter the domain for Strapi"
}

variable "key_name" {
  type    = string
  description = "The name of the key pair"
}

variable "public_key_filename" {
  type    = string
  default = "~/.ssh/id_rsa.pub"
  description = "The path to the public key file"
}