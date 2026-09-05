# =====================================================================
# RESSOURCES PRINCIPALES — un workspace = un environnement (dev ou prod)
# =====================================================================

locals {
  server_name = "${var.environment}-server"

  # AMI : fournie par l'utilisateur si ami_id renseigné, sinon la
  # dernière Ubuntu 22.04 officielle Canonical.
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
}

# ---------------- AMI Ubuntu 22.04 (dernière stable) ----------------
data "aws_ami" "ubuntu" {
  count       = var.ami_id == "" ? 1 : 0
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
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

# ---------------- Réseau ----------------
module "network" {
  source            = "./modules/network"
  project_name      = var.project_name
  environment       = var.environment
  vpc_cidr          = var.vpc_cidr
  subnet_cidr       = var.subnet_cidr
  availability_zone = var.availability_zone
  extra_tags        = var.extra_tags
}

# ---------------- Sécurité ----------------
module "security" {
  source       = "./modules/security"
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.network.vpc_id
  admin_cidr   = var.admin_cidr
  extra_tags   = var.extra_tags
}

# ---------------- Instance EC2 ----------------
module "ec2" {
  source            = "./modules/ec2"
  project_name      = var.project_name
  environment       = var.environment
  server_name       = local.server_name
  ami_id            = local.ami_id
  instance_type     = var.instance_type
  subnet_id         = module.network.subnet_id
  security_group_id = module.security.security_group_id
  ssh_key_name      = var.ssh_key_name
  vpc_id            = module.network.vpc_id
  root_volume_size  = var.root_volume_size
  root_volume_type  = var.root_volume_type
  ansible_user      = var.ansible_user
  extra_tags        = var.extra_tags
}