variable "project_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "server_name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "security_group_id" {
  type = string
}

variable "ssh_key_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "root_volume_size" {
  type    = number
  default = 20
}

variable "root_volume_type" {
  type    = string
  default = "gp3"
}

variable "ansible_user" {
  type    = string
  default = "ubuntu"
}

variable "extra_tags" {
  type    = map(string)
  default = {}
}