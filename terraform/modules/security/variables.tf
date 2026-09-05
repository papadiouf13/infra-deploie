variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "admin_cidr" {
  type = string
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}