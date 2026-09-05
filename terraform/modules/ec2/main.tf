# =====================================================================
# MODULE EC2 — instance + EIP + profil IAM SSM minimal + user-data
# =====================================================================

locals {
  user_data = templatefile("${path.module}/user_data.tpl", {
    ansible_user = var.ansible_user
  })
}

# ---- Profil IAM minimal pour SSM (session manager / Systems Manager) ----
resource "aws_iam_role" "ssm" {
  name = "${var.project_name}-${var.environment}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(var.extra_tags, { Name = "${var.project_name}-${var.environment}-ssm-role" })
}

resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.project_name}-${var.environment}-ssm-profile"
  role = aws_iam_role.ssm.name
}

# ---- Instance EC2 ----
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.ssh_key_name
  user_data              = local.user_data
  iam_instance_profile   = aws_iam_instance_profile.ssm.name

  root_block_device {
    volume_type = var.root_volume_type
    volume_size = var.root_volume_size
    encrypted   = true
  }

  # Le sel de l'AMI ne change pas l'infrastructure : on ignore la dérive AMI.
  lifecycle {
    ignore_changes = [ami]
  }

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}"
      Env  = var.environment
      Role = "monitoring-server"
    },
  )
}

# ---- Elastic IP (adresse publique stable : DNS nip.io / CI s'y réfèrent) ----
resource "aws_eip" "this" {
  instance = aws_instance.this.id
  domain   = "vpc"

  tags = merge(
    var.extra_tags,
    {
      Name = "${var.project_name}-${var.environment}-eip"
      Env  = var.environment
    },
  )
}