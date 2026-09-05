# =====================================================================
# MODULE SECURITY — security group : 22 (admin), 80 et 443 (Traefik)
# =====================================================================

resource "aws_security_group" "this" {
  name        = "${var.project_name}-${var.environment}-sg"
  description = "22 restreint (admin), 80/443 ouvert (Traefik)"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH depuis l'IP admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  ingress {
    description = "HTTP (redirection Traefik + challenges ACME)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS (Traefik)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.extra_tags,
    { Name = "${var.project_name}-${var.environment}-sg" },
  )
}