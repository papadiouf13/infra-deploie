variable "aws_region" {
  description = "Région AWS où déployer les ressources"
  type        = string
  default     = "eu-west-3"
}

variable "environment" {
  description = "Environnement (dev ou prod) — identique au workspace Terraform"
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment doit être 'dev' ou 'prod'."
  }
}

variable "project_name" {
  description = "Préfixe de nommage des ressources"
  type        = string
  default     = "infra-deploie"
}

variable "instance_type" {
  description = "Type d'instance EC2 (dev=t3.small, prod=c7i-flex.large par défaut)"
  type        = string
}

variable "ssh_key_name" {
  description = "Nom de la key pair EC2 existante (créer avant : aws ec2 create-key-pair)"
  type        = string
}

variable "ami_id" {
  description = "AMI Ubuntu 22.04 (optionnel : si vide, data source Canonical la plus récente)"
  type        = string
  default     = ""
}

variable "vpc_cidr" {
  description = "CIDR du VPC de l'environnement"
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR du subnet public (héberge toutes les instances de l'environnement)"
  type        = string
}

variable "availability_zone" {
  description = "Zone de disponibilité du subnet public"
  type        = string
  default     = "eu-west-3a"
}

variable "admin_cidr" {
  description = "CIDR admin autorisé en SSH et sur les interfaces protégées (basic-auth + allowlist)"
  type        = string
}

variable "root_volume_size" {
  description = "Taille du disque racine en Go (images Docker, Prometheus, Loki, Grafana)"
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "Type du disque racine"
  type        = string
  default     = "gp3"
}

variable "extra_tags" {
  description = "Tags supplémentaires appliqués aux ressources"
  type        = map(string)
  default     = {}
}

variable "domain" {
  description = "Nom de domaine (optionnel). Si vide, les URL passent en nip.io via l'IP publique."
  type        = string
  default     = ""
}

variable "ansible_user" {
  description = "Utilisateur Ansible sur les hôtes (ubuntu sur AWS, root sur certains VPS)"
  type        = string
  default     = "ubuntu"
}