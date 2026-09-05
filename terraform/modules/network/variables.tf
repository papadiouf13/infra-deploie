variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "subnet_cidr" {
  type = string
}

variable "availability_zone" {
  type    = string
  default = "eu-west-3a"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}