# =====================================================================
# infra-deploie — Makefile d'orchestration
#
# Usage :
#   make preflight  ENV=dev|prod    Vérifie les outils présents
#   make plan       ENV=dev|prod    Terraform plan (workspace + tfvars)
#   make apply      ENV=dev|prod    Terraform apply
#   make inventory  ENV=dev|prod    Écrit ansible/inventories/<env>/hosts.ini
#   make configure  ENV=dev|prod    Ansible site.yml (Docker, Traefik, monitoring)
#   make deploy     ENV=dev|prod    = apply + inventory + configure
#   make verify     ENV=dev|prod    Ansible verify.yml (contrôles post-déploiement)
#   make destroy    ENV=dev|prod    Terraform destroy (avec confirmation)
#   make ssh        ENV=dev|prod    Connexion SSH au serveur
#   make urls       ENV=dev|prod    Affiche les URL Grafana/Prometheus/Traefik/Sonar
#
# Mode VPS (Contabo, Hetzner, OVH...) : pas de Terraform.
#   Remplir ansible/inventories/<env>/hosts.ini à la main PUIS :
#   make configure ENV=<env>  (et make verify)
# pour tout le reste.
# =====================================================================

SHELL       := /bin/bash
ENV         ?= dev

# Vault : passe --ask-vault-pass par défaut, mais permet une passe
# dédiée :  make configure ENV=prod VAULT_ARGS="--vault-password-file .vault-pass"
# (ou export ANSIBLE_VAULT_PASSWORD_FILE=...)
VAULT_ARGS  ?= --ask-vault-pass

TF_DIR      := terraform
ANSIBLE_DIR := ansible
INV_TPL     := $(ANSIBLE_DIR)/inventories/$(ENV)/hosts.ini
PLAYBOOK    := $(ANSIBLE_DIR)/playbooks/site.yml
VERIFY      := $(ANSIBLE_DIR)/playbooks/verify.yml

.PHONY: help preflight plan apply inventory configure deploy verify destroy ssh urls

help:
	@echo "Cibles disponibles (ENV=dev|prod) :"
	@echo "  preflight  - vérifie les outils (terraform, ansible, docker, curl)"
	@echo "  plan       - terraform plan (workspace + tfvars)"
	@echo "  apply      - terraform apply (création infra AWS)"
	@echo "  inventory  - génère ansible/inventories/<env>/hosts.ini depuis terraform"
	@echo "  configure  - ansible-playbook site.yml"
	@echo "  deploy     - apply + inventory + configure"
	@echo "  verify     - ansible-playbook verify.yml"
	@echo "  destroy    - terraform destroy (confirmation demandée)"
	@echo "  ssh        - connexion SSH"
	@echo "  urls       - affiche les URLs de l'environnement"
	@echo ""
	@echo "Mode VPS : remplir l'inventaire à la main puis configure/verify/ssh/urls."

preflight:
	@command -v terraform >/dev/null 2>&1 || { echo "ERREUR: terraform manquant"; exit 1; }
	@command -v ansible-playbook >/dev/null 2>&1 || { echo "ERREUR: ansible manquant (pip install ansible + collections)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "ERREUR: docker manquant"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "ERREUR: curl manquant"; exit 1; }
	@echo "Preflight OK ($(ENV))"

tf-select:
	cd $(TF_DIR) && (terraform workspace select $(ENV) 2>/dev/null || terraform workspace new $(ENV)) >/dev/null 2>&1

plan: preflight tf-select
	cd $(TF_DIR) && terraform plan -var-file=$(ENV).tfvars

apply: preflight tf-select
	cd $(TF_DIR) && terraform apply -var-file=$(ENV).tfvars

inventory: tf-select
	terraform -chdir=$(TF_DIR) output -raw ansible_inventory > $(INV_TPL)
	@echo "Inventaire écrit : $(INV_TPL)"
	@grep -E '^(dev|prod) ' $(INV_TPL)

configure:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.ini playbooks/site.yml $(VAULT_ARGS)

deploy: apply inventory configure

verify:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.ini playbooks/verify.yml $(VAULT_ARGS)

destroy: preflight tf-select
	@read -r -p "Confirmer la destruction de l'infra '$(ENV)' ? [y/N] " ans; \
	if [ "$$ans" = "y" ] || [ "$$ans" = "Y" ]; then \
		cd $(TF_DIR) && terraform destroy -var-file=$(ENV).tfvars; \
	else \
		echo "Annulé."; \
	fi

# IP cible : preferentiellement l'output terraform, sinon l'inventaire (VPS).
get-ip:
	@echo $(shell terraform -chdir=$(TF_DIR) output -raw public_ip 2>/dev/null \
		|| grep -oP 'public_ip=\K[^ ]+' $(INV_TPL) 2>/dev/null)

ssh:
	@IP=$$(terraform -chdir=$(TF_DIR) output -raw public_ip 2>/dev/null \
		|| grep -oP 'public_ip=\K[^ ]+' $(INV_TPL) 2>/dev/null); \
	if [ -z "$$IP" ]; then echo "IP introuvable (terraform output ou inventaire)."; exit 1; fi; \
	ssh -o StrictHostKeyChecking=no $$IP

urls:
	@IP=$$(grep -oP 'ansible_host=\K[^ ]+' $(INV_TPL) 2>/dev/null \
		|| terraform -chdir=$(TF_DIR) output -raw private_ip 2>/dev/null \
		|| terraform -chdir=$(TF_DIR) output -raw public_ip 2>/dev/null); \
	DOMAIN=$$(grep -oP '^infra_domain:\s*"?\K[^" ]+' $(ANSIBLE_DIR)/group_vars/$(ENV).yml 2>/dev/null); \
	DOMAIN=$${DOMAIN:-"$$IP.nip.io"}; \
	if [ -z "$$IP" ]; then echo "IP introuvable (inventaire ou terraform)."; exit 1; fi; \
	echo "---------------------------------------------------------------"; \
	echo " Environnement $(ENV) — domaine : $${DOMAIN} — IP LAN : $$IP"; \
	echo "---------------------------------------------------------------"; \
	echo " Grafana    : https://grafana.$${DOMAIN}        (admin Grafana)"; \
	echo " Prometheus : https://prometheus.$${DOMAIN}     (basic-auth)"; \
	echo " Traefik    : https://traefik.$${DOMAIN}        (basic-auth)"; \
	echo " Whoami     : https://whoami.$${DOMAIN}"; \
	echo " SonarQube  : https://sonar.$${DOMAIN}          (prod par défaut)"; \
	echo "---------------------------------------------------------------"; \
	echo " Accès LAN derrière DuckDNS : ajouter au fichier hosts Windows :"; \
	echo "   $$IP  grafana.$${DOMAIN}"; \
	echo "   $$IP  prometheus.$${DOMAIN}"; \
	echo "   $$IP  traefik.$${DOMAIN}"; \
	echo "   $$IP  whoami.$${DOMAIN}"; \
	echo "   $$IP  sonar.$${DOMAIN}"; \
	echo "  (admin) : notepad C:\\Windows\\System32\\drivers\\etc\\hosts"; \
	echo "---------------------------------------------------------------"; \
	echo "SSH : make ssh ENV=$(ENV)"