# =====================================================================
# BACKEND PARTAGÉ (S3 + DynamoDB)
#
# Un workspace Terraform = un environnement (dev / prod) :
#   dev  -> clé "monitoring/dev/terraform.tfstate"
#   prod -> clé "monitoring/prod/terraform.tfstate"
#
# Création une seule fois (bucket + table DynamoDB) :
#   aws s3api create-bucket --bucket infra-deploie-tfstate-examen \
#       --region eu-west-3 --create-bucket-configuration LocationConstraint=eu-west-3
#   aws s3api put-bucket-versioning --bucket infra-deploie-tfstate-examen \
#       --versioning-configuration Status=Enabled
#   aws dynamodb create-table --table-name terraform-lock \
#       --attribute-definitions AttributeName=LockID,AttributeType=S \
#       --key-schema AttributeName=LockID,KeyType=HASH \
#       --billing-mode PAY_PER_REQUEST
#
# Variante locale (utilisateur seul, dépannage) — commenter le bloc s3 :
#   backend "local" {
#     path = "terraform.tfstate"
#   }
# =====================================================================
terraform {
  backend "s3" {
    bucket         = "infra-deploie-tfstate-examen"
    key            = "monitoring/${workspace}/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}