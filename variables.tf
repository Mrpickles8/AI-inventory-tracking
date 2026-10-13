variable "aws_region" {
  type    = string
  default = "eu-west-1"
}

variable "project_name" {
  type    = string
  default = "AI-tracking"
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_user" {
  type      = string
  sensitive = true
}

variable "admin_email" {
  type      = string
  sensitive = true
}

variable "instance_type" {
  type    = string
  default = "t3.small"
}