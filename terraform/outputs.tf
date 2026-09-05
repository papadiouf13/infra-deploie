# =====================================================================
# OUTPUTS — utilisés par `make inventory` et par les workflows
# =====================================================================

output "public_ip" {
  description = "IP publique (EIP) de l'instance de l'environnement"
  value       = module.ec2.public_ip
}

output "private_ip" {
  description = "IP privée de l'instance (injectée dans les templates Ansible/Prometheus)"
  value       = module.ec2.private_ip
}

output "instance_id" {
  description = "Identifiant de l'instance EC2"
  value       = module.ec2.instance_id
}

output "server_name" {
  description = "Nom du serveur dans l'environnement (ex: dev-server)"
  value       = module.ec2.server_name
}

output "security_group_id" {
  description = "Security group de l'environnement"
  value       = module.security.security_group_id
}

output "ansible_inventory" {
  description = "Fichier INI prêt à être écrit dans ansible/inventories/<env>/hosts.ini"
  value       = <<-EOT
    # Fichier généré par Terraform (workspace ${terraform.workspace}) — ne pas éditer.
    # Les secrets et paramètres globaux sont dans ansible/group_vars/.
    [${var.environment}]
    ${var.environment} ansible_host=${module.ec2.public_ip} public_ip=${module.ec2.public_ip} private_ip=${module.ec2.private_ip} server_name=${local.server_name}

    [all:vars]
    ansible_user=${var.ansible_user}
  EOT
}