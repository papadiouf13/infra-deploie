# MANUEL PÉDAGOGIQUE — infra-deploie

> **Version 2.0** — rédigé pour qu'un débutant comprenne *tout* : ce qu'on a
> fait, pourquoi, et **comment c'est codé**. Chaque fichier est commenté,
> chaque commande est expliquée, chaque bloc de code est copiable.
>
> 📖 **Démarche de lecture conseillée** : lire les chapitres **1 → 2 → 3** pour
> comprendre le *pourquoi*, puis **4 → 5** pour le *comment* (c'est le cœur du
> document), puis le reste en fonction des besoins.
>
> 🔑 **Légende** :
> - 🎯 = l'objectif (ce que l'on cherche à faire)
> - 💡 = l'explication (le « pourquoi » technique)
> - ⚠️ = attention / piège
> - 📦 = code à copier
> - 🧪 = commande à vérifier / tester

---

# 1. Ce qu'on a fait (l'histoire du projet)

## 1.1 La situation de départ

On avait une application web composée de **deux briques** :

| Brique | Techno | Rôle |
|---|---|---|
| `todo_back` | FastAPI (Python) + PostgreSQL | L'API (les fonctions métier) |
| `todo_front` | Next.js (React) | L'interface navigateur |

Elles tournaient sur une **VM (machine virtuelle) Ubuntu** chez soi, sans aucun
outil de gestion : on se connectait en SSH à la main, on installait tout à la
main, on configurait à la main. C'est le mode « historique ».

Mais il y avait plusieurs problèmes :
- ❌ **Pas reproductible** : reconstruire la machine depuis zéro = des heures
  et des erreurs.
- ❌ **Pas de surveillance** : on ne savait pas si le serveur était tombé,
  si le disque était plein, si un conteneur venait de crasher.
- ❌ **Pas de certificat HTTPS automatique**.
- ❌ **Pas de journalisation centralisée** (où sont passés les logs ?).

## 1.2 Ce qu'on a construit

On a créé un dépôt **`infra-deploie`** qui automatise *toute* l'infrastructure :

1. **Terraform** (si on est dans le cloud AWS) : crée le serveur, le réseau,
   le pare-feu cloud — avec du *code*, pas de clics.
2. **Ansible** (toujours) : installe et configure tout **sur** le serveur —
   Docker, Traefik, Prometheus, Grafana, Loki, etc.
3. **Des scripts** pour les tâches répétitives (générer des hash, préparer un
   serveur neuf).
4. **Un Makefile** : des raccourcis (une commande = toute une suite d'actions).

Le résultat : **une pile de monitoring complète** sur un seul serveur :

```
Internet ──(80/443)──► Traefik (proxy TLS)
                         ├─ Grafana     (consoles + alertes)
                         ├─ Prometheus  (métriques)
                         ├─ Traefik UI  (dashboard du proxy)
                         ├─ Whoami      (route de test)
                         └─ SonarQube   (qualité du code, prod)
```

Et ça marche **de deux façons** :
- **Mode AWS** : Terraform crée la VM dans le cloud, puis Ansible la configure.
- **Mode VPS / serveur maison** : on renseigne l'IP à la main, le même code
  Ansible configure tout pareil.
- **Mode standalone** (ajout récent) : le serveur se configure **lui-même**,
  sans poste séparé — parfait pour une VM VMware chez soi.

## 1.3 Les grandes dates / étapes

| Étape | Quoi |
|---|---|
| 1 | Le dépôt est créé : Terraform + Ansible, deux environnements `dev` / `prod` |
| 2 | La pile se déploie sur AWS (VPS de test) |
| 3 | Création de la **documentation** MANUEL.md + les 17 chapitres découpés dans `docs/` |
| 4 | Ajout du **DuckDNS** (vrai domaine `*.tioukh.duckdns.org`) + certificats Let's Encrypt **réels** en IP privée |
| 5 | Ajout du **mode standalone** : un nouveau serveur peut se déployer depuis lui-même |
| 6 | **Sécurisation** de la procédure : SSH durci avant de déployer (procédure v2) |
| 7 | **Refonte pédagogique** de ce manuel (v2.0) |

## 1.4 Les mots du métier (glossaire absolu)

| Mot | Définition simple |
|---|---|
| **IaC** (Infrastructure as Code) | Décrire son infrastructure (serveurs, réseau, pare-feu) dans des fichiers texte plutôt que par des clics. |
| **Terraform** | Outil IaC du cloud. Il lit des fichiers `.tf` et crée/modifie les ressources (VM, VPC, SG). |
| **Ansible** | Outil de « configuration des machines » : se connecte en SSH et exécute des actions (installer, copier, lancer). |
| **Playbook** | Fichier Ansible qui contient la liste des actions (tasks) à faire. |
| **Rôle Ansible** | Une brique réutilisable (ex : rôle `grafana` = tout ce qui concerne Grafana). |
| **Gather facts** | Ansible va lire des infos sur la machine hôte (OS, IP, RAM…) automatiquement. |
| **Idempotent** | Une action qu'on peut rejouer à l'infini sans casser quoi que ce soit. Ansible est conçu pour ça. |
| **Conteneur Docker** | Une « mini-machine » qui n'embarque que le nécessaire pour faire tourner un programme. |
| **docker compose** | Outil pour décrire et lancer plusieurs conteneurs ensemble (fichier YAML `docker-compose.yml`). |
| **Reverse-proxy** | Serveur qui reçoit tout le trafic et le redirige vers les bons services. Traefik en est un. |
| **Label Docker/Traefik** | Des étiquettes posées sur un conteneur qui disent à Traefik « route vers moi ainsi ». |
| **ACME** | Protocole utilisé par Let's Encrypt pour délivrer des certificats TLS automatiquement. |
| **Vault Ansible** | Chiffrement de fichiers (nos secrets) par un mot de passe. |
| **YAML** | Format de fichier lisible par l'humain, utilisé par Ansible et docker compose. L'indentation (espaces) est **cruciale**. |
| **Jinja2** | Langage de gabarits (templates) utilisé par Ansible : `{{ variable }}` sera remplacé par la valeur de la variable. |
| **PromQL / LogQL** | Langages de requête de Prometheus (métriques) et Loki (logs). |
| **TLS / HTTPS** | Le « cadenas » des navigateurs : les échanges sont chiffrés. |
| **nip.io** | Service magique : `192.168.1.15.nip.io` => le nom de domaine pointe vers 192.168.1.15. Aucune config DNS. |
| **DuckDNS** | Service gratuit de sous-domaines type `mon-domaine.duckdns.org` avec mise à jour dynamique d'IP. |

---

# 2. L'architecture expliquée

## 2.1 Le principe central : UN serveur = TOUTE la pile

Tout tient sur **un seul serveur** Ubuntu. Un `docker-compose.yml` par
composant, avec des **réseaux Docker partagés**, et un seul point d'entrée
externe : **Traefik**.

> 💡 C'est volontaire : un seul serveur = plus simple à maintenir, à dépanner
> et à expliquer. On sacrifie la haute disponibilité (serveur multiple) au
> profit de la simplicité. Pour une « VM magique » de monitoring, c'est le bon
> compromis.

## 2.2 Les réseaux Docker (les « quartiers » du serveur)

Docker permet de créer des réseaux privés virtuels entre conteneurs. On en
utilise 4, avec des **subnets figés** (pour que les règles UFW restent valides) :

| Réseau | Subnet | Petit nom | À quoi il sert |
|---|---|---|---|
| `proxy` | `172.30.0.0/24` | le « quartier public » web | Traefik + les services exposés au navigateur |
| `monitoring` | `172.30.1.0/24` | le « quartier interne » | Les collecteurs de métriques, jamais visibles de l'extérieur |
| `back` | `172.30.10.0/24` | le « quartier des données » | Les bases de données des applications, jamais exposées |
| `sonar-net` | auto | le garage de Sonar | SonarQube ↔ sa base PostgreSQL |

Un conteneur peut appartenir à **plusieurs** réseaux. Par exemple Grafana est
sur `proxy` **et** `monitoring` : il est accessible depuis le navigateur (via
Traefik sur `proxy`) et visible depuis Prometheus (sur `monitoring`).

## 2.3 Le flux d'une requête navigateur

```
Navigateur ──HTTPS 443──► Traefik
                            │  Traefik regarde le nom de domaine demandé
                            │  (ex : grafana.tioukh.duckdns.org)
                            ▼
                      Le bon conteneur
                      (grâce aux labels posés sur le conteneur)
```

Traefik est le **seul** conteneur qui publie des ports sur l'hôte (80/443).
Tous les autres utilisent `expose:` (interne seulement) et sont rejoints via le
réseau `proxy`.

## 2.4 Le flux des métriques (Prometheus)

```
node-exporter (CPU/RAM/disque) ─┐
cadvisor (conteneurs) ──────────┤
Traefik (requêtes HTTP) ────────┼──► Prometheus (TSDB) ──► Grafana
daemon Docker (9323) ───────────┤        │
grafana/loki/alloy (santé) ─────┘        └──► règles d'alerte ──► e-mail/Telegram/Slack
```

## 2.5 Le flux des logs (Loki + Alloy)

```
logs des conteneurs (docker.sock) ─┐
logs système (/var/log) ───────────┼──► Alloy ──► Loki (stockage) ──► Grafana (dashboard logs)
access logs Traefik (JSON) ────────┤
rapports Trivy (trivy.jsonl) ─────┘
```

## 2.6 🧠 L'image mentale complète

| Couche | Outil | Rôle |
|---|---|---|
| 1. Cloud / réseau | Terraform (optionnel) | La VM, le VPC, le pare-feu cloud |
| 2. Serveur | Ansible rôle `common` | Durcissement : UFW, fail2ban, mises à jour auto |
| 3. Conteneurs | Ansible rôle `docker` | Docker + les 3 réseaux partagés |
| 4. Entrée réseau | Ansible rôle `traefik` | Reverse-proxy + TLS |
| 5. Métriques | `node_exporter`, `cadvisor`, `prometheus` | Capteurs + base de métriques |
| 6. Logs | `loki`, `alloy` | Collecte + stockage de logs |
| 7. Console | `grafana` | Dashboards + alertes |
| 8. Sécurité images | `trivy` | Scan de vulnérabilités des images |
| 9. Qualité de code | `sonarqube` (prod) | Analyse statique du code des apps |
| 10. Déploiement apps | `app_deploy` + GitHub Actions | Le pipeline CI/CD |

---

# 3. Avant de commencer : les prérequis et les deux modes de travail

## 3.1 Ce qu'il faut sur son poste (mode « contrôleur »)

Le « contrôleur » est la machine d'où l'on lance les commandes. Elle pilote le
serveur à distance (ou se pilote elle-même en mode standalone).

| Outil | À quoi il sert | Version minimale |
|---|---|---|
| `terraform` | Créer la VM chez AWS (mode cloud seulement) | ≥ 1.9.0 |
| `ansible` (+ collections) | Configurer le serveur | core ≥ 2.15 |
| `docker` | Nécessaire surtout pour `make urls`… en fait utilisé par Ansible ? Non — voir note | — |
| `git` | Récupérer/modifier le dépôt | — |
| `curl` | Tests HTTP | — |

> ⚠️ Le `make preflight` vérifie terraform, ansible-playbook, docker, curl.
> Avec Ansible Core seul (sans `ansible` full), une erreur de « module `ansible` »
> peut apparaître ; installer les collections via `requirements.yml` règle la
> majorité des cas (voir §4.3).

## 3.2 Modes d'utilisation

| Mode | Rôle du contrôleur | Rôle du serveur | Quand |
|---|---|---|---|
| **AWS** | Poste admin (WSL) | VM dans le cloud créée par Terraform | Déploiement cloud réel |
| **VPS** | Poste admin (WSL) | Serveur chez un hébergeur (Contabo, Hetzner…) | Pas de cloud, serveur loué |
| **Standalone** | Le serveur lui-même | Le serveur | En local / VMware sans poste séparé |

Le **code Ansible est identique** dans les 3 modes : seule la façon de remplir
l'inventaire change.

---

# 4. L'arborescence du dépôt (utilité de chaque dossier/fichier)

> 🎯 Objectif de ce chapitre : savoir **où est quoi** et **pourquoi ça existe**.

## 4.1 Vue d'ensemble

```
infra-deploie/
├── Makefile                        → les raccourcis (make configure, make verify…)
├── README.md                       → le point d'entrée rapide
├── MANUEL.md                       → CE document (version complète)
├── MANUEL.docx                     → la version Word générée
├── NOUVEAU-SERVEUR-PROCEDURE.md    → la procédure pas-à-pas pour un serveur neuf
├── CHANGEMENT-IP-SERVEUR.md        → que faire si l'IP de la VM change
├── docs/                           → le manuel découpé en 17 chapitres
├── scripts/
│   ├── gen-bcrypt-hash.sh          → génère un hash bcrypt pour les login HTTP
│   └── standalone-prep.sh          → prépare UN NOUVEAU SERVEUR à se déployer seul
├── terraform/                      → le code cloud (AWS / EC2 / réseau)
│   ├── main.tf                     → les ressources principales
│   ├── variables.tf                → les variables (taillés par tfvars)
│   ├── outputs.tf                  → les sorties (IP, inventaire Ansible)
│   ├── backend.tf                  → où est stocké le « state » Terraform
│   ├── providers.tf                → le fournisseur AWS
│   ├── versions.tf                 → versions exigées (terraform, provider)
│   ├── dev.tfvars.example          → exemple de valeurs dev (copier en dev.tfvars)
│   ├── prod.tfvars.example         → exemple de valeurs prod
│   └── modules/
│       ├── network/                → VPC + subnet + passerelle internet
│       ├── security/               → le pare-feu cloud (security group)
│       └── ec2/                    → l'instance + sa clé + son IP publique
└── ansible/                        → TOUTE la configuration du serveur
    ├── ansible.cfg                 → les réglages globaux d'Ansible
    ├── requirements.yml            → les collections Ansible nécessaires
    ├── group_vars/
    │   ├── all.yml                 → variables communes à tout
    │   ├── dev.yml                 → variables de l'environnement dev
    │   ├── prod.yml                → variables de l'environnement prod
    │   ├── server_vars.yml.example → modèle des variables PROPRES au serveur
    │   └── vault.yml.example       → modèle des secrets (fichier chiffré)
    ├── inventories/
    │   └── dev/
    │       ├── hosts.ini           → l'adresse du serveur (généré/non commité)
    │       └── hosts.ini.example   → le modèle
    ├── playbooks/
    │   ├── site.yml                → installe TOUTE la pile
    │   ├── verify.yml              → vérifie que tout va bien
    │   └── app-deploy.yml          → prépare l'accueil des apps (CI/CD)
    └── roles/                      → une brique par service
        ├── common/                 → durcissement (UFW, fail2ban, DuckDNS)
        ├── docker/                 → moteur Docker + réseaux
        ├── traefik/                → reverse-proxy TLS
        ├── node_exporter/          → métriques système
        ├── cadvisor/               → métriques conteneurs
        ├── prometheus/             → base de métriques
        ├── loki/                   → stockage des logs
        ├── alloy/                  → collecteur de logs
        ├── grafana/                → consoles + alertes
        ├── trivy/                  → scan images conteneurs
        ├── sonarqube/              → qualité de code (prod)
        └── app_deploy/             → accueil apps + réseau back
```

## 4.2 Les fichiers ignorés par git (.gitignore) — CRUCIAL

> 💡 Le `.gitignore` liste ce que **git ne doit jamais tracker** (donc jamais
> publier). C'est ta protection anti-secrets.

| Chemin ignoré | Pourquoi |
|---|---|
| `*.tfvars` | Contiennent ton IP admin, ta région… données de déploiement, pas du code git. |
| `ansible/inventories/*/hosts.ini` | Contiennent IP réelles + utilisateur + mot de passe sudo en clair. |
| `ansible/group_vars/vault.yml` | **LE fichier de secrets** (mots de passe, tokens). Jamais en clair sur GitHub. |
| `ansible/group_vars/server_vars.yml` | Les variables propres au serveur (connexion, domaines). |
| `*.pem`, `*.key` | Les clés SSH privées. |
| `.env` | Fichiers d'environnement potentiellement sensibles. |
| `.vault-pass` | Le mot de passe du vault Ansible. |
| `*.vps-bak` | Sauvegardes chiffrées du vault (utile, jamais en clair). |

> ⚠️ Seuls les fichiers **`.example`** sont commités : ils servent de modèles,
> sans contenir de valeur réelle.

## 4.3 Les collections Ansible (`ansible/requirements.yml`)

```yaml
---
# Collections Ansible requises :
#   ansible-galaxy collection install -r requirements.yml
collections:
  - name: community.docker
    version: ">=3.4.0"
  - name: community.general
    version: ">=8.0.0"
```

> 💡 Ansible est fourni en « noyau », les **collections** ajoutent des modules.
> - `community.docker` : les modules `docker_*` (réseaux, compose, conteneurs).
> - `community.general` : les modules `ufw`, `timezone`, `cron`…
>
> 📦 À lancer une fois :
> ```bash
> ansible-galaxy collection install -r ansible/requirements.yml
> ```

## 4.4 La configuration globale d'Ansible (`ansible/ansible.cfg`)

```ini
[defaults]
roles_path = ./roles
inventory = inventories/dev/hosts.ini
host_key_checking = False
retry_files_enabled = False
interpreter_python = /usr/bin/python3

[ssh_connection]
pipelining = True

[privilege_escalation]
timeout = 60
```

Ligne par ligne :
- `roles_path = ./roles` : dit où sont les rôles (à la racine `ansible/`).
- `inventory = inventories/dev/hosts.ini` : l'inventaire par défaut.
- `host_key_checking = False` : ne pas demander confirmation pour les
  empreintes SSH inconnues (pratique en test, ⚠️ à durcir en prod : §15.2).
- `retry_files_enabled = False` : pas de fichier `.retry` qui traîne.
- `interpreter_python = /usr/bin/python3` : on force l'interpréteur Python.
- `pipelining = True` : accélère les connexions SSH (connexions groupées).
- `timeout = 60` : timeout d'escalade sudo.

---

# 5. Le cœur : le code, fichier par fichier

> 🎯 On passe au **comment**. Chaque fichier est donné **en intégralité ou
> extrait**, suivi d'une **explication ligne par ligne ou par bloc**.

## 5.1 Le Makefile : toutes les commandes en raccourci

> 💡 `make` est un outil qui lit un `Makefile` et exécute des commandes
> nommées (« cibles »). `make configure ENV=dev` lance la commande associée à
> `configure` avec `ENV=dev`.

### 5.1.1 `make preflight` — vérifier que les outils existent

```make
preflight:
	@command -v terraform >/dev/null 2>&1 || echo "AVERTISSEMENT: terraform non trouvé (ignoré en mode VPS/standalone ; requis uniquement pour AWS plan/apply/destroy)"
	@command -v ansible-playbook >/dev/null 2>&1 || { echo "ERREUR: ansible manquant (pip install ansible + collections)"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "ERREUR: docker manquant"; exit 1; }
	@command -v curl >/dev/null 2>&1 || { echo "ERREUR: curl manquant"; exit 1; }
	@echo "Preflight OK ($(ENV))"
```

Explication :
- `command -v <outil>` : teste si l'outil existe dans le PATH.
- `>/dev/null 2>&1` : cache sa sortie (on ne veut pas la voir).
- `|| echo …` : si l'outil est absent, on affiche un message.
- `exit 1` : arrête avec une erreur (le Makefile s'arrête).
- **terraform est optionnel** (mode VPS/standalone) : simple avertissement.

### 5.1.2 `make inventory && make configure && make verify` — la trilogie

```make
inventory: tf-select
	terraform -chdir=$(TF_DIR) output -raw ansible_inventory > $(INV_TPL)
	@echo "Inventaire écrit : $(INV_TPL)"
	@grep -E '^(dev|prod) ' $(INV_TPL)

configure:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.ini playbooks/site.yml $(VAULT_ARGS)

verify:
	cd $(ANSIBLE_DIR) && ansible-playbook -i inventories/$(ENV)/hosts.ini playbooks/verify.yml $(VAULT_ARGS)
```

Explication :
- `inventory` : demande à Terraform sa sortie `ansible_inventory` (voir
  §5.2.4) et l'écrit dans `ansible/inventories/<env>/hosts.ini`. En mode
  VPS/standalone, on **écrit ce fichier à la main** (`standalone-prep.sh` le
  fait pour nous).
- `configure` : lance le playbook **site.yml** (installer tout).
- `verify` : lance le playbook **verify.yml** (vérifier que tout est bon).
- `$(VAULT_ARGS)` : par défaut `--ask-vault-pass` (on te demandera le mot de
  passe du vault). Pour l'automatiser : `VAULT_ARGS='--vault-password-file ../.vault-pass'`.

### 5.1.3 `make urls` — afficher les URL + le bloc hosts Windows

```make
urls:
	@IP=$$(grep -oP 'public_ip=\K[^ ]+' $(INV_TPL) 2>/dev/null \
		|| grep -oP 'ansible_host=\K[^ ]+' $(INV_TPL) 2>/dev/null \
		|| terraform -chdir=$(TF_DIR) output -raw private_ip 2>/dev/null \
		|| terraform -chdir=$(TF_DIR) output -raw public_ip 2>/dev/null); \
	DOMAIN=$$(grep -oP '^infra_domain:\s*"?\K[^" ]+' $(ANSIBLE_DIR)/group_vars/server_vars.yml 2>/dev/null \
		|| grep -oP '^infra_domain:\s*"?\K[^" ]+' $(ANSIBLE_DIR)/group_vars/$(ENV).yml 2>/dev/null); \
	DOMAIN=$${DOMAIN:-"$$IP.nip.io"}; \
	...
	echo " Grafana    : https://grafana.$${DOMAIN}        (admin Grafana)"
	...
```

Explication :
- On cherche l'IP **d'abord** dans `public_ip` (standalone/VPS), **sinon**
  dans `ansible_host`, **sinon** dans les outputs Terraform. Le `||` gère la
  priorité.
- On cherche le domaine **d'abord** dans `server_vars.yml` (variables
  spécifiques au serveur), **sinon** dans `<env>.yml`.
- Si aucun domaine : on fabrique `IP.nip.io`.

## 5.2 Terraform (le cloud, optionnel)

> 🎯 Terraform décrit l'infrastructure cloud en code. Ici : **1 VPC, 1 subnet,
> 1 pare-feu (SG), 1 VM Ubuntu (EC2), 1 IP publique (EIP)**.

### 5.2.1 `versions.tf` — contraintes de version

```hcl
terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
```

- `required_version` : on exige Terraform ≥ 1.9.
- `required_providers` : on fixe le fournisseur AWS (~> 5.0 = 5.x, pas 6).

### 5.2.2 `providers.tf` — le fournisseur AWS

```hcl
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
```

- `region` : où créer les ressources (`eu-west-3` = Paris).
- `default_tags` : des étiquettes posées sur **toutes** les ressources (pour
  facturation/identification).

### 5.2.3 `backend.tf` — où vit le « state »

```hcl
terraform {
  backend "s3" {
    bucket         = "infra-deploie-tfstate-examen"
    key            = "monitoring/${workspace}/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    dynamodb_table = "terraform-lock"
  }
}
```

> 💡 Terraform garde un fichier « state » (mémoire de ce qu'il a créé). On le
> range dans un **bucket S3** (cloud durable et versionné) + un verrou
> DynamoDB (pour ne pas faire 2 applis en même temps). Un `workspace` =
> un environnement (`dev` → clé `.../dev/terraform.tfstate`, `prod` → …).

### 5.2.4 `outputs.tf` — les sorties (dont l'inventaire Ansible)

```hcl
output "ansible_inventory" {
  description = "Fichier INI prêt à être écrit dans ansible/inventories/<env>/hosts.ini"
  value       = <<-EOT
    # Fichier généré par Terraform (workspace ${terraform.workspace}) — ne pas éditer.
    [${var.environment}]
    ${var.environment} ansible_host=${module.ec2.public_ip} public_ip=${module.ec2.public_ip} private_ip=${module.ec2.private_ip} server_name=${local.server_name}

    [all:vars]
    ansible_user=${var.ansible_user}
  EOT
}
```

> 💡 C'est **ce** texte qui est écrit dans `hosts.ini` par `make inventory`.
> `<<-EOT … EOT` est un « heredoc » : un bloc de texte multi-lignes. Terraform
> y injecte les vraies valeurs (IP publique, IP privée…).

### 5.2.5 `main.tf` — les ressources

```hcl
locals {
  server_name = "${var.environment}-server"
  ami_id = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
}

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

module "network" {
  source            = "./modules/network"
  ...
}
module "security" {
  source       = "./modules/security"
  admin_cidr   = var.admin_cidr
  ...
}
module "ec2" {
  source            = "./modules/ec2"
  ...
}
```

- `locals` : des calculs internes (nom du serveur, AMI choisie).
- `data "aws_ami"` : interroge AWS pour LA dernière image Ubuntu 22.04
  officielle (owner `099720109477` = Canonical). Le `count = … ? 1 : 0`
  permet de ne l'utiliser que si `ami_id` n'est pas fourni.
- `module "…"` : on réutilise les briques `network`, `security`, `ec2`.

### 5.2.6 `modules/network/main.tf` — le réseau

```hcl
resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr  # ex 10.0.0.0/16
  enable_dns_support   = true
  enable_dns_hostnames = true
}
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.this.id
  cidr_block              = var.subnet_cidr  # ex 10.0.1.0/24
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
}
resource "aws_internet_gateway" "this" { vpc_id = aws_vpc.this.id }
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
}
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

C'est le « pont » entre ta VM et internet : un VPC (grand espace privé), un
subnet public (où vivra la VM), une table de routage vers internet, et une
passerelle internet.

### 5.2.7 `modules/security/main.tf` — le pare-feu cloud

```hcl
resource "aws_security_group" "this" {
  vpc_id = var.vpc_id

  ingress {
    from_port = 22
    protocol  = "tcp"
    cidr_blocks = [var.admin_cidr]     # SSH : SEULE ton IP
  }
  ingress {
    from_port = 80
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]        # HTTP : tout le monde (Traefik)
  }
  ingress {
    from_port = 443
    protocol  = "tcp"
    cidr_blocks = ["0.0.0.0/0"]        # HTTPS : tout le monde (Traefik)
  }
  egress { from_port = 0, protocol = "-1", cidr_blocks = ["0.0.0.0/0"] }  # sorties libres
}
```

- `ingress` = entrant. `egress` = sortant.
- La règle d'or : **22 restreint à ton IP**, **80/443 ouverts** (c'est là que
  Traefik écoute).

### 5.2.8 `modules/ec2/main.tf` — la machine et son IP stable

```hcl
resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.ssh_key_name
  user_data              = local.user_data
  iam_instance_profile   = aws_iam_instance_profile.ssm.name
  root_block_device {
    volume_size = var.root_volume_size
    encrypted   = true
  }
  lifecycle { ignore_changes = [ami] }   # on ne recrée pas la VM si l'AMI change
}
resource "aws_eip" "this" {
  instance = aws_instance.this.id
  domain   = "vpc"
}
```

- `instance_type` : la puissance (dev = `t3.small`, prod = plus).
- `encrypted = true` : disque chiffré (obligatoire pour être crédible).
- `lifecycle { ignore_changes = [ami] }` : garantit qu'un `make apply` ne
  recrée pas la VM chaque fois qu'une nouvelle AMI sort (évite les surprises).
- `aws_eip` : une **IP publique fixe** (l'adresse ne change jamais, même si la
  VM redémarre).

---

## 5.3 Les variables : comment Ansible connaît les bonnes valeurs

> 🎯 Ansible doit savoir **quoi configurer avec quelles valeurs**. C'est le
> rôle de `group_vars/` — une hiérarchie de variables, du plus général au plus
> spécifique.

### 5.3.1 `group_vars/all.yml` — les valeurs communes à TOUT

Lignes clés et leur sens :

```yaml
environment_name: "{{ group_names[0] }}"
```

> 💡 `group_names[0]` = le nom du groupe dans l'inventaire (`dev` ou `prod`).
> On dérive automatiquement « dev » ou « prod » sans rien écrire en dur.

```yaml
ansible_user: mamadou
ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
```

> ⚠️ `StrictHostKeyChecking=no` + `UserKnownHostsFile=/dev/null` : confort en
> test, mais risque MITM. Durcir en prod (§15.2).

```yaml
admin_cidr:
  - "0.0.0.0/0"
```

> ⚠️ **À restreindre en prod !** C'est l'IP autorisée sur les consoles de
> supervision via `ipAllowList`.

```yaml
infra_domain: "{{ public_ip }}.nip.io"
grafana_host: "grafana.{{ infra_domain }}"
prometheus_host: "prometheus.{{ infra_domain }}"
traefik_host: "traefik.{{ infra_domain }}"
sonar_host: "sonar.{{ infra_domain }}"
whoami_host: "whoami.{{ infra_domain }}"
```

> 💡 **Une seule variable** (`infra_domain`) détermine TOUS les hostnames.
> Changer le domaine = changer un seul endroit. Avec DuckDNS on surcharge
> `infra_domain` dans `dev.yml` → `tioukh.duckdns.org`, et tous les hostnames
> suivent (`grafana.tioukh.duckdns.org`, etc.).

```yaml
docker_networks:
  proxy:     { name: proxy,     subnet: "172.30.0.0/24",  gateway: "172.30.0.1" }
  monitoring:{ name: monitoring, subnet: "172.30.1.0/24",  gateway: "172.30.1.1" }
  back:      { name: back,      subnet: "172.30.10.0/24", gateway: "172.30.10.1" }
```

> 🔑 Les **subnets sont figés** : les règles UFW autorisent le 9323 du daemon
> Docker depuis ces subnets exactement.

```yaml
images:
  traefik: "traefik:v3.7.13"
  node_exporter: "prom/node-exporter:v1.8.2"
  ...
```

> ⚠️ **Pas de `latest` !** Toutes les versions sont épinglées. Pour monter une
> version : modifier ici + `make configure` (et `make verify`).

```yaml
alerts:
  server:
    cpu_warning: 80
    cpu_critical: 90
    ...
  traefik:
    error_5xx_pct: 5
    latency_p95_seconds: 3
```

> 💡 Tous les **seuils d'alertes** sont ici, configurables sans toucher au code
> des règles.

```yaml
alerting:
  email:    { enabled: true, to: "admin@example.com", smtp_*: ... }
  telegram: { enabled: true, bot_token: "", chat_id: "" }
  slack:    { enabled: true, webhook_url: "" }
  discord:  { enabled: false, webhook_url: "" }
```

> 💡 Les **valeurs réelles** sont dans le vault (le bloc `alerting` du vault
> **remplace** celui-ci, cf. §5.3.4).

```yaml
enable_sonarqube: false
monitoring_retention_days: 15
loki_retention_hours: 168
```

### 5.3.2 `group_vars/dev.yml` — le DEV

```yaml
infra_domain: "tioukh.duckdns.org"
acme_is_staging: false
acme_challenge: dns
acme_use_wildcard: true
monitoring_retention_days: 7
loki_retention_hours: 72
enable_sonarqube: false
app_deploy_user: papa
```

- Domaine DuckDNS + **vrais certificats** Let's Encrypt via DNS-01.
- `acme_use_wildcard: true` : UN cert `*.tioukh.duckdns.org` pour tous (avec
  DuckDNS, un seul `_acme-challenge` possible).
- Rétentions courtes en dev (7 j / 3 j).
- SonarQube désactivé (gourmand).

### 5.3.3 `group_vars/prod.yml` — la PROD

```yaml
acme_is_staging: false
monitoring_retention_days: 30
loki_retention_hours: 336
enable_sonarqube: true
```

- Rétentions longues, SonarQube actif.

### 5.3.4 `group_vars/vault.yml.example` — les SECRETS chiffrés

```yaml
grafana_admin_user: admin
grafana_admin_password: CHANGE-ME-GRAFANA-PASSWORD
prometheus_basic_auth_user: prometheus
prometheus_basic_auth_hash: "$2b$12$CHANGE-ME-GENERATED-HASH"
traefik_dashboard_basic_auth_user: traefik
traefik_dashboard_basic_auth_hash: "$2b$12$CHANGE-ME-GENERATED-HASH"
sonarqube_admin_current_password: admin
sonarqube_admin_new_password: CHANGE-ME-SONAR-PASSWORD
sonarqube_db_password: CHANGE-ME-SONAR-DB-PASSWORD
alerting:
  email:    { to: "...", smtp_*: "..." }
  telegram: { bot_token: "...", chat_id: "..." }
  slack:    { webhook_url: "..." }
  discord:  { enabled: false, webhook_url: "..." }
# duckdns_token: "CHANGE-ME-DUCKDNS-TOKEN"
# duckdns_domains: "tioukh,grafana-tioukh"
```

> 💡 Ce fichier est copié en `vault.yml` puis **chiffré** avec
> `ansible-vault encrypt`. Il est lu par les playbooks en `pre_tasks` avec
> `no_log: true` (aucun secret n'apparaît dans les logs).
> ⚠️ Le bloc `alerting` du vault **REMPLACE** celui de `all.yml` (précédence
> group_vars) : il doit donc contenir TOUTES les clés.

### 5.3.5 `group_vars/server_vars.yml.example` — redéfinir par serveur

```yaml
#infra_domain: "maquette.duckdns.org"
#duckdns_domains: "maquette"
#duckdns_token: ""          # laisser vide : pris depuis vault.yml
#app_deploy_user: "papa"
#public_ip: "203.0.113.10"
#timezone: "Europe/Paris"
#admin_cidr:
#  - "0.0.0.0/0"
#acme_is_staging: true
```

> 🔑 **Le mécanisme clé du mode standalone** : ce fichier, **non commité**, est
> chargé **en dernier** (après all/vault/env) par chaque playbook, uniquement
> si le fichier existe (testé par un `stat`). Il permet de « redéfinir un
> serveur » (domaine, utilisateur CI/CD, IP…) **sans toucher au code commité**.

## 5.4 L'inventaire (`hosts.ini.example`) — qui est le(s) serveur(s)

```ini
# Variables d'hôte attendues : public_ip, private_ip, server_name.
[dev]
dev ansible_host=203.0.113.10 public_ip=203.0.113.10 private_ip=203.0.113.10 server_name=dev-server

[all:vars]
ansible_user=ubuntu
```

- `[dev]` : le groupe (dev). La ligne du dessous : la machine `dev` avec ses
  variables d'hôte.
- `public_ip` : l'IP publique (utilisée par nip.io / DuckDNS).
- `private_ip` : l'IP privée/cluster LAN.
- `server_name` : le label du serveur (posé en label `server` sur les
  métriques).

**Mode standalone** (généré par `standalone-prep.sh`) :

```ini
# Inventaire dev (généré par standalone-prep.sh)
# Nœud de contrôle = la machine elle-même (ansible_connection=local).
[dev]
dev ansible_host=127.0.0.1 public_ip=192.168.175.131 private_ip=192.168.175.131 server_name=dev-server ansible_connection=local

[all:vars]
ansible_user=mamadou
ansible_become=true
```

> 💡 `ansible_connection=local` : Ansible travaille **sur la même machine**,
> sans SSH. C'est ça, le mode standalone.

## 5.5 Les playbooks (les « scénarios »)

### 5.5.1 `site.yml` — installer TOUTE la pile

```yaml
- name: Provisionner la pile de monitoring
  hosts: all
  become: true
  gather_facts: true

  pre_tasks:
    - name: Variables partagées (group_vars/all.yml)
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/all.yml"

    - name: Secrets (group_vars/vault.yml)
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/vault.yml"
      no_log: true

    - name: Variables d'environnement (group_vars/{{ env }}.yml)
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/{{ env }}.yml"
      vars:
        env: "{{ 'dev' if 'dev' in group_names else 'prod' }}"

    - name: Fichier server_vars.yml présent ?
      ansible.builtin.stat:
        path: "{{ playbook_dir }}/../group_vars/server_vars.yml"
      register: server_vars
      tags: always

    - name: Variables spécifiques au serveur (group_vars/server_vars.yml, optionnel)
      ansible.builtin.include_vars:
        file: "{{ playbook_dir }}/../group_vars/server_vars.yml"
      when: server_vars.stat.exists
```

Explication des `pre_tasks` (toujours exécutées avant les rôles) :
- `include_vars` charge **dans l'ordre** : all → vault → env → server_vars.
  Chaque chargement peut écraser les valeurs précédentes → le fichier chargé
  en dernier (server_vars) gagne.
- `file: "{{ playbook_dir }}/../group_vars/..."` — chemin relatif au playbook,
  robuste quel que soit le répertoire courant.
- `no_log: true` sur le vault : on cache tout (secrets).
- `vars: env: "{{ 'dev' if 'dev' in group_names else 'prod' }}"` — on déduit
  l'environnement du groupe auquel appartient l'hôte.
- `stat` + `register` : on mémorise si `server_vars.yml` existe, puis on le
  charge **seulement si** c'est le cas (`when:`). Pas de plantage si absent.

Ensuite les rôles, **dans l'ordre** (c'est l'ordre d'installation) :

```yaml
  roles:
    - common        # durcissement (UFW, fail2ban, unattended-upgrades, DuckDNS)
    - docker        # moteur + réseaux partagés
    - traefik       # reverse-proxy TLS + whoami
    - node_exporter # métriques système
    - cadvisor      # métriques conteneurs
    - prometheus    # collecte
    - loki          # stockage logs
    - alloy         # collecte logs
    - grafana       # console + alerting
    - trivy         # scan images
    - role: sonarqube        # qualité de code
      when: enable_sonarqube | bool   # seulement si activé
```

Et la conclusion :

```yaml
  post_tasks:
    - name: Récapitulatif des URLs
      ansible.builtin.debug:
        msg:
          - "Grafana   : https://{{ grafana_host }}"
          - "Prometheus: https://{{ prometheus_host }}"
          ...
          - "Aucun port d'application exposé en dehors de 80/443 (Traefik)."
```

### 5.5.2 `verify.yml` — l'examen de passage

```yaml
- name: Vérifier le déploiement de la pile de monitoring
  hosts: all
  become: true
  gather_facts: false
```

Les vérifications clés (avec leur « recette ») :

**1. Les conteneurs attendus tournent**
```yaml
    - name: Récupérer l'état des conteneurs
      community.docker.docker_host_info:
        containers: true
      register: docker_info

    - name: Tous les conteneurs du compose attendu doivent tourner
      ansible.builtin.assert:
        that:
          - item in (docker_info.containers | map(attribute='Names') | flatten | map('regex_replace', '^/', '') | list)
        success_msg: "Conteneur présent : {{ item }}"
        fail_msg: "Conteneur absent : {{ item }}"
      loop:
        - traefik
        - whoami
        - node-exporter
        - cadvisor
        - prometheus
        - loki
        - alloy
        - grafana
```
- `| map(attribute='Names')` : extrait les noms de tous les conteneurs.
- `| flatten` : aplatit la liste.
- `| map('regex_replace', '^/', '')` : enlève le `/` en tête des noms.
- `assert`: s'arrête et échoue si un conteneur est absent — magique.

**2. Seuls 80/443 publiés**
```yaml
    - name: Collecter les ports publiés sur l'hôte
      ansible.builtin.set_fact:
        published_ports: "{{ docker_info.containers | map(attribute='Ports') | flatten
                             | selectattr('PublicPort', 'defined')
                             | selectattr('PublicPort', 'gt', 0)
                             | map(attribute='PublicPort') | list }}"

    - name: Seuls les ports 80/443 (Traefik) peuvent être publiés
      ansible.builtin.assert:
        that:
          - published_ports | difference([80, 443]) | length == 0
        fail_msg: "Port(s) publié(s) non autorisé(s) : {{ published_ports | difference([80, 443]) }}"
```

**3. Prometheus répond + exige l'auth HTTPS**
```yaml
    - name: Prometheus doit répondre
      ansible.builtin.command:
        cmd: docker run --rm --network monitoring curlimages/curl:8.7.1 -fs http://prometheus:9090/-/healthy
```
- On lance un conteneur `curl` **jetable** sur le réseau `monitoring` (jamais
  besoin d'installer curl sur l'hôte).

```yaml
    - name: Récupérer l'IP de Traefik sur le réseau proxy
      ansible.builtin.shell:
        cmd: >-
          docker inspect traefik --format '{% raw %}{{ (index .NetworkSettings.Networks "proxy").IPAddress }}{% endraw %}'
      register: traefik_ip
      changed_when: false

    - name: Prometheus (https) doit exiger une authentification
      ansible.builtin.shell:
        cmd: docker run --rm --network proxy curlimages/curl:8.7.1 -sk -o /dev/null -w '%{http_code}' --resolve '{{ prometheus_host }}:443:{{ traefik_ip.stdout }}' https://{{ prometheus_host }}
      register: prom_auth
      failed_when: prom_auth.stdout != '401'
```
- `--resolve host:443:IP` : force la résolution DNS vers l'IP interne de
  Traefik (on teste le HTTPS **sans passer par le DNS public**).
- `204` attendu ? Non : **401** (basic-auth demandée) → le proxy protège bien.

**4. Grafana accepte le login admin**
```yaml
      cmd: docker run --rm --network proxy curlimages/curl:8.7.1 -sk -u '{{ grafana_admin_user }}:{{ grafana_admin_password }}' --resolve '{{ grafana_host }}:443:{{ traefik_ip.stdout }}' https://{{ grafana_host }}/api/org
```

**5. Loki=prêt + contient des logs**
```yaml
    - name: Loki doit répondre (prêt)
      ansible.builtin.command:
        cmd: docker run --rm --network monitoring curlimages/curl:8.7.1 -fs http://loki:3100/ready
      register: loki_ready
      retries: 30
      delay: 5
      until: loki_ready.rc == 0

    - name: Loki doit contenir des journaux (ingestion par Alloy)
      ansible.builtin.command:
        cmd: docker run --rm --network monitoring curlimages/curl:8.7.1 -fs http://loki:3100/loki/api/v1/labels
```

**6. Trivy = prêt (script, timer, premier rapport)**
```yaml
    - name: Trivy - lancer un premier scan si aucun rapport n'existe
      ansible.builtin.command:
        cmd: systemctl start trivy-scan.service
      when: not trivy_report.stat.exists

    - name: Trivy - attendre la création du rapport (le 1er scan télécharge les bases)
      ansible.builtin.stat:
        path: "{{ trivy_report_dir }}/trivy.jsonl"
      register: trivy_report
      retries: 60
      delay: 5
      until: trivy_report.stat.exists
```

**7. Récap final**
```yaml
    - name: Récapitulatif
      ansible.builtin.debug:
        msg: "Le déploiement est sain, tous les contrôles sont passés."
```

### 5.5.3 `app-deploy.yml` — « l'accueil » des applications

```yaml
- name: Préparer l'hôte au déploiement CI/CD des applications
  hosts: all
  become: true
  gather_facts: true

  pre_tasks:   # (identique à site.yml : chargement des variables)

  roles:
    - app_deploy

  post_tasks:
    - name: Lire la clé publique pour vérification
      ansible.builtin.command: "cat {{ deploy_dir }}/.ssh/{{ deploy_key_name }}.pub"
      register: verif_pub

    - name: Récapitulatif
      ansible.builtin.debug:
        msg:
          - "Racine des apps : {{ app_root }}"
          - "Clé CI/CD       : {{ deploy_dir }}/.ssh/{{ deploy_key_name }}"
          - "Publique        : {{ verif_pub.stdout }}"
          - ">>> Copier la clé PRIVÉE dans le secret GitHub SSH_PRIVATE_KEY :"
          - ">>>   ssh {{ app_deploy_user }}@<host> 'cat {{ deploy_dir }}/.ssh/{{ deploy_key_name }}'"
```

---

## 5.6 Les rôles (une brique = un rôle)

### 5.6.0 La structure d'un rôle (toujours la même)

Chaque rôle a ce squelette :

```
roles/<nom>/
├── tasks/
│   └── main.yml     → les actions à exécuter (le cœur)
├── templates/
│   └── *.j2         → les fichiers générés avec des variables Jinja
├── defaults/
│   └── main.yml     → les valeurs par défaut (surchargeables)
├── handlers/
│   └── main.yml     → les « réactions » (ex : redémarrer un service)
└── files/           → les fichiers statiques (pas de templating)
```

> 💡 **Handler** : une action déclenchée `notify:` par une tâche, exécutée à
> la fin du playbook (ex : « si le fichier config a changé, redémarre le
> service »).

### 5.6.1 Rôle `common` — le durcissement du serveur

**Ce qu'il fait** : paquets de base, timezone, UFW (pare-feu), fail2ban,
unattended-upgrades, et optionnellement la mise à jour DuckDNS.

```yaml
- name: Apt - mise à jour du cache
  ansible.builtin.apt:
    update_cache: true
    cache_valid_time: 3600

- name: Apt - paquets de base
  ansible.builtin.apt:
    name:
      - ufw
      - fail2ban
      - unattended-upgrades
      - curl
      - ca-certificates
      - gnupg
      - python3-apt
    state: present
```

**UFW (pare-feu hôte)** — l'important :

```yaml
- name: "UFW - politique par défaut : refuser les entrées"
  community.general.ufw:
    direction: incoming
    policy: deny

- name: UFW - autoriser SSH (22)
  community.general.ufw:
    rule: allow
    port: "22"
    proto: tcp

- name: UFW - autoriser HTTP (80)   # idem pour 443

- name: UFW - autoriser les métriques du daemon Docker ({{ docker_metrics_port }}) depuis les réseaux Docker
  community.general.ufw:
    rule: allow
    port: "{{ docker_metrics_port }}"   # 9323
    proto: tcp
    from_ip: "{{ item }}"
  loop: "{{ docker_metrics_allow_cidrs.split(',') }}"

- name: UFW - activer le pare-feu
  community.general.ufw:
    state: enabled

- name: UFW - autoriser le forwarding (requis pour Docker)
  ansible.builtin.lineinfile:
    path: /etc/default/ufw
    regexp: '^DEFAULT_FORWARD_POLICY='
    line: 'DEFAULT_FORWARD_POLICY="ACCEPT"'
  notify: Recharger UFW
```

> ⚠️ **Le piège n°1 (TFS-2)** : par défaut `DEFAULT_FORWARD_POLICY` est DROP,
> donc les conteneurs Docker n'ont **pas** de connectivité réseau. On le passe
> à `ACCEPT`. Sans ça, tout casse (même Prometheus ne peut plus joindre ses
> cibles).

**fail2ban** (anti brute-force SSH) :

```yaml
- name: fail2ban - configurer la jail SSH
  ansible.builtin.template:
    src: jail.local.j2
    dest: /etc/fail2ban/jail.local
    mode: "0644"
  notify: Redémarrer fail2ban

- name: fail2ban - démarrer et activer au boot
  ansible.builtin.systemd:
    name: fail2ban
    state: started
    enabled: true
```

**unattended-upgrades** (mises à jour automatiques de sécurité) :

```yaml
- name: unattended-upgrades - activer les mises à jour automatiques
  ansible.builtin.copy:
    dest: /etc/apt/apt.conf.d/20auto-upgrades
    content: |
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
    mode: "0644"
```

**DuckDNS (optionnel)** — garder le sous-domaine à jour même si l'IP change :

```yaml
- name: DuckDNS - script de mise à jour de l'adresse IP
  ansible.builtin.template:
    src: duckdns-update.sh.j2
    dest: /usr/local/bin/duckdns-update.sh
    mode: "0755"
  when: duckdns_token | length > 0 and duckdns_domains | length > 0

- name: DuckDNS - planifier la mise à jour toutes les 10 minutes
  ansible.builtin.cron:
    name: "duckdns-update"
    minute: "*/10"
    job: "/usr/local/bin/duckdns-update.sh >/dev/null 2>&1"
  when: duckdns_token | length > 0 and duckdns_domains | length > 0
```

Le template `duckdns-update.sh.j2` produit ce script (ici : dev) :

```bash
set -euo pipefail
DOMAINS="inframonitoring"
TOKEN="<secret-du-vault>"
URL="https://www.duckdns.org/update?domains=${DOMAINS}&token=${TOKEN}"
curl -fsS --connect-timeout 5 --max-time 15 "${URL}"
```

> 💡 DuckDNS est un service qui pointe un nom de domaine vers ton IP (même
> publique derrière NAT). La VM a un IP dynamique ? Le cron refait la mise à
> jour toutes les 10 min.

### 5.6.2 Rôle `docker` — le moteur

**Ce qu'il fait** : installer Docker CE + plugin compose, configurer le daemon
(logs + métriques), ajouter l'utilisateur au groupe docker, créer les 3
réseaux partagés.

```yaml
- name: Docker - dépôt APT officiel
  ansible.builtin.apt_repository:
    repo: "deb [arch={{ ansible_architecture | regex_replace('x86_64', 'amd64') }} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu {{ ansible_distribution_release }} stable"
    filename: docker
    state: present

- name: Docker - installer le moteur, le CLI et les plugins
  ansible.builtin.apt:
    name:
      - docker-ce
      - docker-ce-cli
      - containerd.io
      - docker-buildx-plugin
      - docker-compose-plugin
      - python3-docker
    state: present
```

Le **daemon.json** (via template) :

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "metrics-addr": "0.0.0.0:9323",
  "live-restore": true
}
```

- Rotation des logs des conteneurs (10 Mo × 3 fichiers max) → le disque ne
  se remplit pas.
- `metrics-addr 0.0.0.0:9323` : le daemon expose ses propres métriques
  (scrapées par Prometheus via le réseau interne).
- `live-restore` : Docker ne tue pas les conteneurs quand on redémarre le
  service docker (résilience).

**Réseaux partagés** :

```yaml
- name: Docker - réseau proxy (Traefik + services web)
  community.docker.docker_network:
    name: "{{ docker_networks.proxy.name }}"
    driver: bridge
    driver_options:
      com.docker.network.bridge.name: br-proxy
    ipam_config:
      - subnet: "{{ docker_networks.proxy.subnet }}"
        gateway: "{{ docker_networks.proxy.gateway }}"
    state: present
# ... idem monitoring (br-monitoring)
```

> 💡 Le `driver_options.bridge.name` fixe le nom de l'interface réseau
> (`br-proxy`) : indispensable pour que les règles UFW visant les subnets
> restent valides.

**Bonus** : récupérer le GID du groupe docker :
```yaml
- name: Docker - mémoriser le GID du groupe docker (pour docker_sd Prometheus)
  ansible.builtin.command: getent group docker
  register: docker_group_ent
  changed_when: false

- name: Docker - exposer le GID docker en fait
  ansible.builtin.set_fact:
    docker_group_gid: "{{ docker_group_ent.stdout.split(':')[2] | int }}"
```
> 💡 Prometheus a besoin de ce GID pour lire le socket Docker (docker_sd).

### 5.6.3 Rôle `traefik` — le reverse-proxy TLS

**Ce qu'il fait** : déployer Traefik (seul à publier 80/443), le dashboard, le
service `whoami` de test, et les middlewares.

La **config statique** (`traefik.yml.j2`) :

```yaml
api:
  dashboard: true
ping: true

entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
  websecure:
    address: ":443"
  traefik:
    address: ":8080"    # dashboard interne (jamais publié)
  metrics:
    address: ":8082"    # métriques Prometheus (jamais publié)

metrics:
  prometheus:
    entryPoint: metrics

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false
    network: proxy
  file:
    filename: /etc/traefik/dynamic.yml
    watch: true

accessLog:
  filePath: "/var/log/traefik/access.log"
  format: json
```

- 4 `entryPoints` : web (80), websecure (443), traefik (dashboard 8080),
  metrics (8082). Les 2 derniers ne sont **jamais publiés** sur l'hôte.
- `providers.docker` : Traefik découvre automatiquement les conteneurs dotés
  des bons **labels** — c'est la magie du routage par label.
- `exposedByDefault: false` : SEULS les conteneurs avec `traefik.enable=true`
  sont routés.
- `certificatesResolvers.letsencrypt` : le block ACME (staging/dev dns-01).

La **config dynamique** (`dynamic.yml.j2`) — les middlewares partagés :

```yaml
http:
  middlewares:
    basic-auth-prom:
      basicAuth:
        users:
          - "{{ prometheus_basic_auth_user }}:{{ prometheus_basic_auth_hash }}"
    basic-auth-traefik:
      basicAuth:
        users:
          - "{{ traefik_dashboard_basic_auth_user }}:{{ traefik_dashboard_basic_auth_hash }}"
    allowlist-admin:
      ipAllowList:
        sourceRange: {{ admin_cidr }}
    security-headers:
      headers:
        customFrameOptionsValue: "SAMEORIGIN"
        contentTypeNosniff: true
        browserXssFilter: true
        referrerPolicy: "strict-origin-when-cross-origin"
        permissionsPolicy: "camera=(), microphone=(), geolocation=()"
```

> 💡 `basic-auth-prom` et `basic-auth-traefik` : les login HTTP devant
> Prometheus et le dashboard Traefik. Les hash sont **précalculés** et stockés
> dans le vault (déterministe, aucun secret en clair dans le fichier).
> `allowlist-admin` : restreint à `admin_cidr`.

Le **docker-compose** (`docker-compose.yml.j2`) :

```yaml
services:
  traefik:
    image: "{{ images.traefik }}"
    container_name: traefik
    restart: unless-stopped
    networks: [proxy, monitoring]
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic.yml:/etc/traefik/dynamic.yml:ro
      - ./acme.json:/etc/traefik/acme.json
      - ./logs:/var/log/traefik
    environment:
      - "{{ acme_dns_env_key }}={{ acme_dns_env_value }}"   # si challenge dns
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.traefik.rule=Host(`{{ traefik_host }}`)"
      - "traefik.http.routers.traefik.entrypoints=websecure"
      - "traefik.http.routers.traefik.tls=true"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=basic-auth-traefik@file,allowlist-admin@file"
```

- **Labels Traefik** : c'est ici qu'on dit « ce conteneur est routé » et « par
  quel hostname ». `api@internal` = le dashboard de Traefik lui-même.
- `whoami` : un petit service qui renvoie ses infos — la route de test
  (`whoami.<domaine>`) pour vérifier que Traefik fonctionne.

### 5.6.4 Rôle `node_exporter` — métriques du système

```yaml
services:
  node-exporter:
    image: "{{ images.node_exporter }}"
    container_name: node-exporter
    restart: unless-stopped
    user: "65534:65534"
    networks: [monitoring]
    expose: ["9100"]
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - --path.procfs=/host/proc
      - --path.sysfs=/host/sys
      - --path.rootfs=/rootfs
```

> 💡 Il monte `/proc`, `/sys`, `/` **en lecture seule** pour lire les stats de
> la machine (CPU, RAM, disque, réseau, load).

### 5.6.5 Rôle `cadvisor` — métriques des conteneurs

```yaml
services:
  cadvisor:
    image: "{{ images.cadvisor }}"
    container_name: cadvisor
    restart: unless-stopped
    networks: [monitoring]
    expose: ["8080"]
    command:
      - --port=8080
      - --docker_only=true
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
```

> 💡 cAdvisor lit `/var/lib/docker` pour voir tous les conteneurs en cours
> d'exécution et leurs consommations.

### 5.6.6 Rôle `prometheus` — la base de métriques

Le **prometheus.yml.j2** : liste des cibles (jobs). Chaque job est déclaré
avec `static_configs` + les labels `environment`/`server` :

```yaml
global:
  scrape_interval: {{ monitoring_scrape_interval }}
  evaluation_interval: {{ monitoring_scrape_interval }}

scrape_configs:
  - job_name: prometheus
    static_configs:
      - targets: ["localhost:9090"]
        labels:
          environment: "{{ environment_name }}"
          server: "{{ server_name }}"
  - job_name: node_exporter   # "node-exporter:9100"
  - job_name: cadvisor        # "cadvisor:8080"
  - job_name: traefik         # "traefik:8082"
  - job_name: docker          # "host.docker.internal:9323", scrape_interval: 30s
  - job_name: grafana         # "grafana:3000", metrics_path: /metrics
  - job_name: loki            # "loki:3100"
  - job_name: alloy           # "alloy:12345"
```

> 💡 `host.docker.internal:9323` + `extra_hosts` dans le compose Prometheus :
> on atteint le port 9323 du **daemon hôte** depuis l'intérieur du conteneur.

**Le docker_sd** (découverte automatique des apps futurs) :

```yaml
  - job_name: docker-containers
    docker_sd_configs:
      - host: unix:///var/run/docker.sock
        host_networking_host: host.docker.internal
    relabel_configs:
      - source_labels: [__meta_docker_container_label_prometheus_scrape]
        regex: "true"
        action: keep
      # remplace le port → label prometheus.port
      - source_labels: [__address__, __meta_docker_container_label_prometheus_port]
        regex: "(.*):(\\d+);(\\d+)"
        replacement: "${1}:${3}"
        action: replace
        target_label: __address__
      - target_label: environment
        replacement: "{{ environment_name }}"
      - target_label: server
        replacement: "{{ server_name }}"
```

> 💡 N'importe quel conteneur portant le label `prometheus.scrape=true` sera
> automatiquement scrapé **sans reconfigurer Prometheus**. Les relabels
> transforment les métadonnées Docker en adresses/ports de scraping.

Le **compose Prometheus** :

```yaml
services:
  prometheus:
    image: "{{ images.prometheus }}"
    container_name: prometheus
    user: "{{ prometheus_uid }}:{{ prometheus_uid }}"
    group_add:
      - "{{ docker_group_gid | default(988) }}"   # accès socket docker
    networks: [proxy, monitoring]
    expose: ["9090"]
    extra_hosts: ["host.docker.internal:host-gateway"]
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./data:/prometheus
      - /var/run/docker.sock:/var/run/docker.sock:ro
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --storage.tsdb.retention.time={{ prometheus_retention }}
      - --web.external-url=https://{{ prometheus_host }}
      - --log.level=info
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.prometheus.rule=Host(`{{ prometheus_host }}`)"
      - "traefik.http.routers.prometheus.service=prometheus"
      - "traefik.http.routers.prometheus.middlewares=basic-auth-prom@file,allowlist-admin@file"
```

### 5.6.7 Rôle `loki` — le stockage des logs

Config minimale (mode standalone, filesystem) :

```yaml
auth_enabled: false
server:
  http_listen_port: 3100
common:
  path_prefix: /loki
  storage:
    filesystem: { chunks_directory: /loki/chunks, rules_directory: /loki/rules }
  replication_factor: 1
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
limits_config:
  retention_period: {{ loki_retention }}
  allow_structured_metadata: true
compactor:
  working_directory: /tmp/compactor
  retention_enabled: true
```

> 💡 Loki est **seulement interne** (`monitoring`). Pas d'auth horizontale
> (`auth_enabled: false`) : choix assumé pour l'usage interne (voir §6.3).

### 5.6.8 Rôle `alloy` — le colleur de logs

Le **config.alloy.j2** (langage River) :

```river
discovery.docker "containers" {
  host = "unix:///var/run/docker.sock"
}
discovery.relabel "containers" {
  targets = discovery.docker.containers.targets
  rule {
    source_labels = ["__meta_docker_container_name"]
    target_label  = "container"
  }
  rule {
    source_labels = ["__meta_docker_container_label_com_docker_compose_service"]
    target_label  = "service"
  }
  rule {
    source_labels = ["__meta_docker_container_image"]
    target_label  = "image"
  }
}

loki.write "default" {
  endpoint { url = "http://loki:3100/loki/api/v1/push" }
  external_labels = {
    environment = "{{ environment_name }}",
    server      = "{{ server_name }}",
  }
}

loki.source.docker "docker_logs" {
  host       = "unix:///var/run/docker.sock"
  targets    = discovery.relabel.containers.output
  forward_to = [loki.write.default.receiver]
}

loki.source.file "system_logs" {
  targets    = [
    { "__path__" = "/var/log/syslog" },
    { "__path__" = "/var/log/auth.log" },
  ]
  forward_to = [loki.write.default.receiver]
}

loki.source.file "traefik_access" {
  targets    = [{ "__path__" = "/logs/traefik/access.log" }]
  forward_to = [loki.process.traefik.receiver]
}

loki.process "traefik" {
  stage.json {
    expressions = { status = "DownstreamStatus", method = "RequestMethod", ... }
  }
  forward_to = [loki.write.default.receiver]
}

loki.source.file "trivy_reports" {
  targets    = [{ "__path__" = "/opt/trivy/reports/trivy.jsonl", source = "trivy" }]
  forward_to = [loki.write.default.receiver]
}
```

> 💡 River = un langage déclaratif « flow » : `composant.nom "étiquette"`.
> Alloy découvre les conteneurs, enrichit avec des labels (service, image…),
> parse les access logs JSON de Traefik (statut, méthode, durée…), et pousse
> tout vers Loki avec les labels `environment`/`server` en commun.

Le **compose Alloy** — attention aux binds :

```yaml
services:
  alloy:
    image: "{{ images.alloy }}"
    container_name: alloy
    restart: unless-stopped
    networks: [monitoring]
    expose: ["12345"]
    mem_limit: "{{ alloy_mem_limit }}"
    volumes:
      - ./config.alloy:/etc/alloy/config.alloy:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /var/log:/var/log:ro
      # ⚠️ EROFS : on NE monte PAS /var/log/traefik à travers le bind ro /var/log.
      - /opt/traefik/logs:/logs/traefik:ro
      - /opt/trivy/reports:/opt/trivy/reports:ro
```

> ⚠️ **Le piège n°2 (TFS-3)** : monter `/var/log` en ro **puis** essayer de
> monter `/var/log/traefik` par-dessus → l'OS refuse (EROFS). Solution :
> accès logs Traefik via un bind séparé `/opt/traefik/logs:/logs/traefik`.

### 5.6.9 Rôle `grafana` — la console + l'alerting

Le **compose** (extrait des variables clés) :

```yaml
services:
  grafana:
    image: "{{ images.grafana }}"
    container_name: grafana
    user: "{{ grafana_uid }}:{{ grafana_uid }}"
    networks: [proxy, monitoring]
    expose: ["3000"]
    mem_limit: "{{ grafana_mem_limit }}"
    environment:
      GF_PATHS_PROVISIONING: /etc/grafana/provisioning
      GF_SERVER_ROOT_URL: "https://{{ grafana_host }}/"
      GF_SERVER_DOMAIN: "{{ grafana_host }}"
      GF_SECURITY_ADMIN_USER: "{{ grafana_admin_user }}"
      GF_SECURITY_ADMIN_PASSWORD: "{{ grafana_admin_password }}"
      GF_USERS_ALLOW_SIGN_UP: "false"
      GF_UNIFIED_ALERTING_ENABLED: "true"
      GF_SMTP_ENABLED: "true"                     # si alerting.email.enabled
      GF_SMTP_HOST: "{{ alerting.email.smtp_host }}:{{ alerting.email.smtp_port }}"
      GF_SMTP_PASSWORD: "{{ alerting.email.smtp_password }}"
    volumes:
      - ./provisioning:/etc/grafana/provisioning:ro
      - ./data:/var/lib/grafana
      - ./dashboards:/var/lib/grafana/dashboards:ro
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.grafana.rule=Host(`{{ grafana_host }}`)"
      - "traefik.http.routers.grafana.service=grafana"
```

> 💡 Tout passe par **provisioning** (fichiers versionnés). Grafana est en
> read-only (`allowUiUpdates=false`) : la source de vérité = les fichiers du
> rôle, pas l'UI.

**datasources.yml.j2** :
```yaml
datasources:
  - name: Prometheus
    type: prometheus
    uid: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

**dashboards.yml.j2** (le provider de dashboards) :
```yaml
providers:
  - name: Monitoring
    folder: Monitoring
    type: file
    disableDeletion: true
    updateIntervalSeconds: 30
    allowUiUpdates: false
    options:
      path: /var/lib/grafana/dashboards
```

**Alerting provisionné** — 3 fichiers :

`contact-points.yml.j2` (où envoyer les alertes) :
```yaml
contactPoints:
  - orgId: 1
    name: all-channels
    receivers:
      - uid: cp-email
        type: email
        settings:
          addresses: "{{ alerting.email.to }}"
      # + telegram / slack / discord conditionnellement ({% if … %})
```

`policies.yml.j2` (les règles de tri/regroupement) :
```yaml
policies:
  - orgId: 1
    receiver: all-channels
    group_by: ["alertname"]
    group_wait: 30s
    group_interval: 5m
    repeat_interval: 4h
    routes:
      - matcher: severity="critical"
        receiver: all-channels
        group_interval: 2m
        repeat_interval: 2h
```

`rules.yml.j2` (les 16 règles d'alerte) — des **macros Jinja** :

```jinja
{%- macro alert_rule(uid, title, expr, severity='critical', for='2m', nodata='Alerting') -%}
- uid: {{ uid }}
  title: "{{ title }}"
  for: "{{ for }}"
  labels:
    severity: {{ severity }}
    environment: "{{ environment_name }}"
  condition: C
  data:
    - refId: A
      datasourceUid: prometheus
      model:
        expr: '{{ expr }}'
        instant: true
    - refId: B
      datasourceUid: __expr__
      model: { type: reduce, expression: A, reducer: last }
    - refId: C
      datasourceUid: __expr__
      model:
        type: threshold
        expression: B
        conditions:
          - evaluator: { type: gt, params: [0] }
{%- endmacro %}
```

Et l'usage :
```jinja
{{ alert_rule('alert-node-up', 'Node Exporter indisponible', '(1 - up{job="node_exporter"}) == 1', 'critical', '2m', 'OK') | indent(6, true) }}
{{ alert_rule('alert-load', 'Charge CPU élevée', 'node_load15 / count(node_cpu_seconds_total{mode="user"}) > 0.8', 'warning', '10m', 'OK') }}
{{ alert_rule('alert-disk-crit', 'Disque root saturé', 'node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"} < 0.1', 'critical', '5m', 'OK') }}
{{ alert_rule('alert-5xx', 'Erreurs 5xx sur Traefik', 'sum by (service) (rate(traefik_service_requests_total{code=~"5.."}[5m])) > 0.05', 'warning', '5m', 'OK') }}
{{ alert_rule('alert-latency', 'Latence p95 élevée', '(histogram_quantile(0.95, sum by (le, service) (rate(traefik_service_request_duration_seconds_bucket[5m]))) > 3) and (sum by (service) (rate(traefik_service_requests_total[5m])) > 0.1)', 'warning', '5m', 'OK') }}
{{ alert_rule_loki('alert-trivy-critical', 'Vulnérabilités CRITICAL sur des conteneurs (Trivy)', 'sum(count_over_time({environment=~".*", source="trivy"} | json | critical != "0" [25h]))', 'critical', '5m', 90000) }}
```

> 💡 Chaque règle suit le même gabarit : une requête (A), une réduction (B) et
> un seuil (C). La macro `| indent(6, true)` gère l'indentation YAML.

### 5.6.10 Rôle `sonarqube` — qualité du code (prod)

```yaml
services:
  sonar-db:
    image: "{{ images.postgres }}"
    container_name: sonar-db
    networks: [sonar-net]
    environment:
      POSTGRES_USER: sonar
      POSTGRES_PASSWORD: "{{ sonarqube_db_password }}"
      POSTGRES_DB: sonarqube
    volumes: [./db-data:/var/lib/postgresql/data]
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U sonar -d sonarqube"]

  sonarqube:
    image: "{{ images.sonarqube }}"
    container_name: sonarqube
    depends_on:
      sonar-db:
        condition: service_healthy
    networks: [proxy, sonar-net]
    expose: ["9000"]
    mem_limit: "{{ sonarqube_mem_limit }}"
    cpus: "{{ sonarqube_cpu_limit }}"
    environment:
      SONAR_JDBC_URL: "jdbc:postgresql://sonar-db:5432/sonarqube"
      SONAR_SEARCH_JAVAOPTS: "-Xms512m -Xmx512m"
      SONAR_WEB_JAVAOPTS: "-Xmx768m -Xms256m"
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sonar.rule=Host(`{{ sonar_host }}`)"
```

> ⚠️ Garde-fou : le rôle échoue si exécuté avec `enable_sonarqube=false`.

### 5.6.11 Rôle `trivy` — scan des images de conteneurs

**Le cœur** = un script hôte (`scan-containers.sh.j2`) déclenché par un timer
systemd quotidien. Principe : pour **chaque image** des conteneurs actifs, on
lance un conteneur **éphémère** `aquasec/trivy`, puis on appende une ligne
JSONL au rapport.

```bash
mapfile -t IMAGES < <(docker ps --format '{{.Image}}' | sort -u)
...
for IMG in "${IMAGES[@]}"; do
  CONTAINERS=$(docker ps --filter "ancestor=${IMG}" --format '{{.Names}}' | paste -sd, -)
  OUT=$(docker run --rm \
        -v "${CACHE_DIR}:/cache" \
        -v /var/run/docker.sock:/var/run/docker.sock:ro \
        "${TRIVY_IMAGE}" --cache-dir /cache image \
        --severity "${SEVERITIES}" "${EXTRA[@]}" \
        --format json "${IMG}" 2>/dev/null || true)
  COUNTS=$(printf '%s' "${OUT}" | python3 -c '...compte CRITICAL/HIGH...')
  printf '{"ts":"%s","container":"%s","image":"%s","critical":%s,"high":%s}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${CONTAINERS}" "${IMG}" "${CRIT}" "${HIGH}" >> "${REPORT_FILE}"
done
```

Le **timer** systemd :
```ini
[Timer]
OnCalendar=*-*-* 03:05:00
Persistent=true
Unit=trivy-scan.service
```

> 💡 `Persistent=true` : si la machine était éteinte à 03:05, le scan est
> rattrapé au redémarrage. Le rapport (JSONL) est relu par **Alloy**
> (`source="trivy"`) → Loki → dashboard + alerte Grafana.

### 5.6.12 Rôle `app_deploy` — l'hôte CI/CD des applications

**Ce qu'il fait** : prépare la VM à recevoir les apps déployées par le pipeline
GitHub Actions :
- `/opt/apps` (une sous-couche par app) ;
- une clé SSH **dédiée** CI/CD + `authorized_keys` **restreinte** ;
- `deploy.sh` (générique : pull + up + santé + migrations) ;
- `start-apps.sh` + service systemd (relance les apps au boot) ;
- le réseau Docker `back` (données/API privées) ;
- `docker login` Docker Hub si les identifiants sont dans le vault.

```yaml
- name: App deploy - générer la clé ed25519 CI/CD (si absente)
  ansible.builtin.command:
    cmd: "ssh-keygen -t ed25519 -N '' -C 'papa-cicd-deploy' -f '{{ deploy_dir }}/.ssh/{{ deploy_key_name }}'"
    creates: "{{ deploy_dir }}/.ssh/{{ deploy_key_name }}"
```

> 💡 `creates:` = « ne lance la commande QUE si le fichier n'existe pas » :
> la clé n'est générée qu'une fois (idempotent).

```yaml
- name: App deploy - installer la clé restreinte dans authorized_keys
  ansible.builtin.lineinfile:
    path: "/home/{{ app_deploy_user }}/.ssh/authorized_keys"
    create: true
    mode: "0600"
    regexp: "{{ deploy_key_name }}"
    line: 'command="{{ deploy_dir }}/deploy-wrapper.sh",no-pty,no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-user-rc {{ deploy_pub.stdout }}'
    state: present
```

> 💡 La clé publique du CI est posée **avec un wrapper** : quand un runner se
> connecte avec cette clé, SSH exécute OBLIGATOIREMENT `deploy-wrapper.sh`,
> qui n'autorise que `deploy.sh <app>` et `put <app> <fichier>` — rien d'autre.

```yaml
- name: App deploy - garantir le réseau Docker back (données/API privées)
  community.docker.docker_network:
    name: "{{ docker_networks.back.name }}"
    ...
    state: present
  ignore_errors: true   # le réseau existe déjà (learning hub) ; on ne recrée pas
```

**`deploy-wrapper.sh.j2`** (le gardien de la clé) :
```sh
set -eu
cmd="${SSH_ORIGINAL_COMMAND:-}"
case "$cmd" in
  "deploy.sh "*)
    set -- $cmd
    app="$2"; tag="${3:-}"
    case "$app" in
      *[!a-zA-Z0-9_-]*) echo "nom d'app invalide" >&2; exit 1;;
    esac
    exec "$DEPLOY_DIR/deploy.sh" "$app" "$tag" ;;
  "put "*)
    ... // nom d'app + type de fichier validés, puis cat > fichier
  *)
    echo "commande non autorisée" >&2; exit 1 ;;
esac
```

**`deploy.sh.j2`** (le déploiement générique) :
```bash
set -euo pipefail
APP_ROOT="{{ app_root }}"
APP="${1:-}"; TAG="${2:-develop}"
APP_DIR="$APP_ROOT/$APP"
export IMAGE_TAG="$TAG"
for f in docker-compose*.yml; do
  docker compose -f "$f" pull --quiet
  docker compose -f "$f" up -d --remove-orphans
done
# attente healthy (si healthcheck défini) puis hook migrate.sh (optionnel)
```

> 💡 Les **apps** sont déployées par le pipeline GitHub (`ci.yml` des repos
> todo_back/todo_front, voir §11) : il écrit `.env` + compose dans
> `/opt/apps/<app>/` puis appelle `deploy.sh <app> sha-<sha>`.

---

## 5.7 Les scripts utilitaires

### 5.7.1 `gen-bcrypt-hash.sh` — générer un hash de mot de passe

```bash
scripts/gen-bcrypt-hash.sh "mon-mot-de-passe" [rounds]
```

Explication (avec le code) :
- Utilise `python3+bcrypt` **ou** `htpasswd -nbB`.
- Affiche le hash à coller dans le vault sous
  `prometheus_basic_auth_hash` / `traefik_dashboard_basic_auth_hash`.
- **Pourquoi précalculer ?** → pas de dépendance passlib/bcrypt au moment de la
  convergence ; le fichier reste idempotent (même hash à chaque run si le
  mot de passe ne change pas).

```bash
#!/usr/bin/env bash
set -euo pipefail
PASSWORD="${1:?Usage: $0 <password> [rounds]}"
ROUNDS="${2:-12}"

if command -v python3 >/dev/null 2>&1 && python3 -c "import bcrypt" 2>/dev/null; then
  HASH="$(python3 -c "import bcrypt,sys; print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt(rounds=int(sys.argv[2]))).decode())" "$PASSWORD" "$ROUNDS")"
elif command -v htpasswd >/dev/null 2>&1; then
  HASH="$(htpasswd -nbB -C "$ROUNDS" user "$PASSWORD" | cut -d: -f2)"
else
  echo "ERREUR: ni python3+bcrypt ni htpasswd ne sont disponibles." >&2
  exit 1
fi
echo "$HASH"
```

### 5.7.2 `standalone-prep.sh` — préparer UN NOUVEAU SERVEUR à se déployer seul

> 🎯 C'est LE script du mode « le serveur se configure lui-même ». À exécuter
> SUR le serveur, après le `git clone`.

```bash
#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"
```

Il fait 5 choses :

**1/5 — Outils contrôleur** (avec prise en compte de PEP 668) :
```bash
echo "=== 1/5 Outils contrôleur ==="
if ! command -v ansible-playbook >/dev/null 2>&1; then
  if ! command -v python3 >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y python3 python3-pip python3-venv
  fi
  python3 -m pip install --user --upgrade ansible-core \
    || python3 -m pip install --user --break-system-packages --upgrade ansible-core
  export PATH="$HOME/.local/bin:$PATH"
  if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  fi
fi
if [ ! -d "$HOME/.ansible/collections/ansible_collections/community/docker" ] \
  || [ ! -d "$HOME/.ansible/collections/ansible_collections/community/general" ]; then
  ansible-galaxy collection install -r ansible/requirements.yml
fi
```

> ⚠️ **PEP 668** : sur Ubuntu 24.04+, `pip` refuse d'installer hors de l'env
> virtuel → on retente avec `--break-system-packages` (acceptable sur un
> serveur dédié). Et on **vérifie les collections par l'existence de
> répertoires** (le `ansible-galaxy collection list` renvoie 0 même si rien
> n'est installé).

**2/5 — Inventaire en mode local** :
```bash
INV_FILE="ansible/inventories/$ENV/hosts.ini"
if [ ! -f "$INV_FILE" ]; then
  read -r -p "server_name (ex: vps2) : " SERVER_NAME
  read -r -p "public_ip (IP LAN vue depuis ton poste Windows — VM VMware bridged : ex 192.168.175.x) : " PUBLIC_IP
  read -r -p "ansible_user (compte SSH admin) [ubuntu] : " ANS_USER
  read -r -s -p "ansible_become_password (sudo, laissé vide si NOPASSWD) : " BECOME_PASS; echo
  {
    echo "# Inventaire $ENV (généré par standalone-prep.sh)"
    echo "# Nœud de contrôle = la machine elle-même (ansible_connection=local)."
    echo "[$ENV]"
    echo "$ENV ansible_host=127.0.0.1 public_ip=$PUBLIC_IP private_ip=$PRIVATE_IP server_name=$SERVER_NAME ansible_connection=local"
    echo ""
    echo "[all:vars]"
    echo "ansible_user=$ANS_USER"
    echo "ansible_become=true"
  } > "$INV_FILE"
  chmod 600 "$INV_FILE"
fi
```

**3/5 — Vault** : copie `vault.yml.example` → `vault.yml` (à éditer ensuite).

**4/5 — `server_vars.yml`** : copie le modèle des variables spécifiques au
serveur.

**5/5 — Mot de passe + chiffrage** :
```bash
if [ ! -f ".vault-pass" ]; then
  read -r -s -p "Choisir le mot de passe vault (laisser vide = générer) : " VAULTPASS; echo
  if [ -z "$VAULTPASS" ]; then
    VAULTPASS="$(python3 -c "import secrets; print(''.join(secrets.choice('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.') for _ in range(32)))")"
  fi
  umask 077
  printf '%s' "$VAULTPASS" > .vault-pass
fi

if [ -f "$VAULT_FILE" ] && ! grep -q '^\$ANSIBLE_VAULT' "$VAULT_FILE"; then
  read -r -p "Chiffrer $VAULT_FILE avec ce mot de passe ? [y/N] " ANS_ENC
  if [ "$ANS_ENC" = "y" ] || [ "$ANS_ENC" = "Y" ]; then
    ansible-vault encrypt --vault-password-file .vault-pass "$VAULT_FILE"
  fi
fi
```

> ⚠️ `.vault-pass` (le mot de passe du vault) est créé **une seule fois** et
> **jamais commité** (les deux fichiers sont gitignorés). Idempotence :
> tout ce qui existe déjà est conservé.

---

## 5.8 Les composants applicatifs (hors dépôt, liés au CI/CD)

> Ces fichiers ne vivent **pas** dans `infra-deploie` mais dans `todo_back` /
> `todo_front`. Ils participent au déploiement sur le serveur.

### 5.8.1 `todo_back/.github/workflows/ci.yml` et `todo_front/.github/workflows/ci.yml`

Le pipeline GitHub : **3 jobs** (test → build → deploy).

| Job | Runner | Condition | Fait quoi |
|---|---|---|---|
| `test` | ubuntu-latest | toujours | back : postgres service + ruff + pytest ; front : npm ci + eslint + next build |
| `build` | ubuntu-latest | `needs: test` | buildx ; sur PR → validation seule ; sur master → login Hub + push `develop` + `sha-<sha>` |
| `deploy` | **self-hosted** | `needs: build` + master | écrit `.env` + compose dans `/opt/apps/<app>/`, puis `/opt/deploy/deploy.sh <app> sha-<sha>` |

> 💡 `concurrency: <repo>_deploy` : un seul déploiement à la fois par repo.
> Le `.env` du back est **entièrement reconstruit** depuis les GitHub secrets
> (rien d'important n'est commité).

### 5.8.2 `todo_back/deploy/docker-compose.yml`

- `api`: image `mamadou173diouf/todo_back:${IMAGE_TAG:-develop}`, réseaux
  `proxy`+`back`, `env_file: .env`, `ROOT_PATH=/api`, labels Traefik
  (`Host + PathPrefix(/api)` + `stripprefix`).
- `postgres`: `postgres:16-alpine`, réseau `back`, volume `postgres_data`,
  healthcheck `pg_isready`.
- Noms fixes (`todo_back`, `todo_back_postgres`) exploités par dashboards/alertes.

### 5.8.3 `todo_front/deploy/docker-compose.yml`

- `web`: Next.js sur le réseau `proxy`, labels Traefik
  (`Host && !PathPrefix(/api)`). `NEXT_PUBLIC_API_URL=/api` embarqué au build.

### 5.8.4 `todo_back/entrypoint.sh` — migrations + serveur

```sh
#!/bin/sh
set -e
echo "Application des migrations Alembic..."
alembic upgrade head
echo "Démarrage d'Uvicorn..."
if [ -n "${ROOT_PATH:-}" ]; then
  exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" \
       --proxy-headers --root-path "$ROOT_PATH"
else
  exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}" --proxy-headers
fi
```

> 💡 `ROOT_PATH=/api` + `--proxy-headers` → FastAPI génère des URLs Swagger
> avec le préfixe `/api` (sinon `/openapi.json` renvoie 404 derrière Traefik).

---

# 6. Sécurisation (durcissement)

## 6.1 Par couches — ce que fait déjà le dépôt

| Couche | Mécanisme | Où |
|---|---|---|
| Cloud | SG : 22 → `admin_cidr`, 80/443 → 0.0.0.0/0 | module `security` |
| Hôte | UFW deny-in, allow 22/80/443, 9323 → subnets Docker | rôle `common` |
| Brute force | fail2ban jail sshd + unattended-upgrades | rôle `common` |
| Reverse-proxy | Traefik seul routeur publique, ACME TLS, 80→443 | rôle `traefik` |
| Auth proxy | basic-auth (bcrypt) + ipAllowList `admin_cidr` | `dynamic.yml` |
| Monitoring | Prometheus sous basic-auth + allowlist ; Grafana login ; Loki/Alloy internes | rôles |
| Disques | EBS chiffré + encrypt on tfstate S3 | module `ec2`, `backend.tf` |
| Secrets | Ansible Vault (chiffré) + gitignore | `.vault-pass`, `vault.yml` |
| CI/CD | clé SSH restreinte + wrapper / runners self-hostés | rôle `app_deploy` |

## 6.2 Les reliquats observés sur la VM de référence (à corriger)

| # | Constat | Risque | Correctif |
|---|---|---|---|
| S1 | `admin_cidr: ["0.0.0.0/0"]` | consoles Prometheus/Traefik exposées au monde | restreindre à l'IP admin |
| S2 | SSH strict check désactivé dans ansible.cfg | MITM possible | figer les empreintes (section 15.2) |
| S3 | Admin Grafana changé dans l'UI ≠ vault | tunnel de provisioning cassé | re-synchroniser le vault |
| S4 | Runners GH non provisionnés par Ansible | machine non « kif-kif » | créer un rôle `github_runner` |
| S5 | `SSH_PRIVATE_KEY` + `/opt/deploy/.ssh-archive` inutilisés | surface d'attaque inutile | purger |
| S6 | `SECRET_KEY` placeholder / clé Cloudinary exposée | données à clef connue | rotation + secrets |
| S7 | `APP_HOST` codé en dur dans les `ci.yml` | toute instance doit éditer le workflow | variable GitHub `APP_HOST` |
| S8 | images publiques `mamadou173diouf/todo_*` | exfiltration possible du code | rendre les images privées |
| S9 | `logs.json` : variable `allValue: ".*"` | Loki rejette le matcher | utiliser `.+` (corrigé en place) |
| S10 | pas de MFA AWS | console = contrôle total | activer MFA |

## 6.3 Recommandations fortes (nouveau serveur)

1. **`admin_cidr` ≠ 0.0.0.0/0** (all.yml + `dynamic.yml` + variables.tf).
2. **SSH durci** : port custom (facultatif), clés uniquement, empreintes
   figées.
3. **Grafana** : ne changer le mot de passe admin QUE via le vault.
4. **Runners** : rendre provisionnés par un rôle Ansible.
5. **Backups** : rôle `backup` (dumps + `/opt/apps` + off-site).
6. **Rotation secrets** : `SECRET_KEY` + compte Cloudinary.
7. **Images privées**.
8. **Loki** : garder réseau interne uniquement.
9. **MFA AWS** + droits réduits.
10. **`.env` back unifié** : générer un fichier de référence unique par le CI.

---

# 7. Dépendances et versions

## 7.1 Outils

| Outil | Version | Ref |
|---|---|---|
| Terraform | ≥ 1.9.0 | `versions.tf` |
| Provider AWS | ~> 5.0 (lock incluse) | `versions.tf` |
| Ansible | core ≥ 2.15 + `community.docker ≥ 3.4.0`, `community.general ≥ 8.0.0` | `requirements.yml` |
| Python | 3.x (`/usr/bin/python3`) | `ansible.cfg` |

> 💡 Le **fichier de lock** `terraform/.terraform.lock.hcl` est commité :
> Terraform réinstalle exactement les mêmes versions de providers.

## 7.2 Images épinglées (all.yml) — ne jamais utiliser `latest`

| Image | Version |
|---|---|
| traefik | v3.7.13 |
| node-exporter | v1.8.2 |
| cadvisor | v0.60.5 |
| prometheus | v2.54.1 |
| loki | 3.2.2 |
| alloy | v1.3.1 |
| grafana | 11.2.2 |
| trivy | 0.57.1 |
| whoami | v1.10.1 |
| sonarqube | lts-community |
| postgres | 16-alpine |

---

# 8. Déploiement (de zéro et itératif)

## 8.1 Workflow « un serveur propre »

```
0. Prérequis : credentials AWS, state TF, clé SSH (si cloud)
1. terraform workspace new dev && terraform apply -var-file=dev.tfvars
2. make inventory ENV=dev            → génère ansible/inventories/dev/hosts.ini
3. make configure ENV=dev            → ansible-playbook site.yml (demande vault-pass)
   # ou mode VPS : renseigner hosts.ini à la main puis même commande
4. make verify ENV=dev               → vérif globale
5. make urls ENV=dev                 → les URL + le bloc hosts Windows
```

## 8.1bis Mode standalone (le serveur est son propre contrôleur)

📦 Sur le serveur, première fois :

```bash
sudo apt update && sudo apt install -y git make curl
ssh-keygen -t ed25519                # clé GitHub si dépôt privé
git clone https://github.com/papadiouf13/infra-deploie.git
cd infra-deploie
bash scripts/standalone-prep.sh dev   # PAS ./ ni sudo
```

Puis, sur ce serveur :

```bash
# 1. Éditer SES variables propres :
nano ansible/group_vars/server_vars.yml    # infra_domain = sous-dom. DuckDNS
EDITOR=nano ansible-vault edit --vault-password-file .vault-pass ansible/group_vars/vault.yml
# 2. Si non chiffré encore :
ansible-vault encrypt --vault-password-file .vault-pass ansible/group_vars/vault.yml
# 3. Déployer / vérifier :
make configure ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
make verify   ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
make urls     ENV=dev
```

> ⚠️ **Chaque serveur = son sous-domaine DuckDNS** : `infra_domain`
> (server_vars.yml) **et** `duckdns_token` (vault.yml).
> ✅ La re-définition par serveur est garantie par `server_vars.yml` (chargé
> en dernier, dans les 3 playbooks).
> ℹ️ `make preflight` n'exige plus terraform en mode VPS/standalone.

## 8.2 Secrets : Ansible Vault

```bash
ansible-vault create ansible/group_vars/vault.yml   # mot de passe demandé
ansible-vault edit  ansible/group_vars/vault.yml
# Exécution :
make configure    # propose --ask-vault-pass
# Non interactif :
make configure VAULT_ARGS="--vault-password-file .vault-pass"
```

> ⚠️ Si le vault est perdu : seule une sauvegarde chiffrée le récupère. Ne
> jamais committer la pass phrase.

## 8.3 Déploiement itératif

| Type | Commande | Particularité |
|---|---|---|
| Changer une variable | éditer group_vars + `make configure` | idempotent |
| Changement Terraform | `make plan` + `make apply` | respecte le state |
| App sur la VM | pipeline GitHub | `deploy.sh` |

## 8.4 Réinstallation complète

1. Réutiliser le **state S3** → `terraform apply` recrée ce qui manque.
2. `make inventory` puis `make configure`.
3. Renseigner runners + secrets CI.

---

# 9. Réseau, DNS, TLS

## 9.1 Adressage

| Réseau | Subnet | Usage |
|---|---|---|
| `proxy` | 172.30.0.0/24 | traefik + apps exposées |
| `monitoring` | 172.30.1.0/24 | collecteurs |
| `back` | 172.30.10.0/24 | données/API privées |
| `sonar-net` | auto | sonarbd |

## 9.2 Hostnames : une seule variable `infra_domain`

```yaml
infra_domain: "{{ public_ip }}.nip.io"   # défaut : aucun DNS requis
# dans dev.yml / server_vars.yml :
infra_domain: "tioukh.duckdns.org"       # vrai domaine
```

Tous les hostnames dérivent : `grafana.`, `prometheus.`, `traefik.`,
`sonar.`, `whoami.`.

## 9.3 DNS réel (DuckDNS) + certificats en IP privée

> 💡 Avec DuckDNS, on utilise le **challenge DNS-01** : DuckDNS porte le TXT
> `_acme-challenge…`, Let's Encrypt valide, et **même une IP privée/non
> routée** peut obtenir des certificats valides. `acme_use_wildcard: true`
> → un seul cert `*.<domaine>`.

**Accès navigateur en LAN** : `*.duckdns.org` résout vers l'IP **publique** de
la box → côté LAN, on ajoute le bloc `hosts` (fourni par `make urls`) :

```
192.168.175.131  grafana.tioukh.duckdns.org
192.168.175.131  prometheus.tioukh.duckdns.org
192.168.175.131  traefik.tioukh.duckdns.org
192.168.175.131  whoami.tioukh.duckdns.org
192.168.175.131  sonar.tioukh.duckdns.org
```

## 9.4 TLS / Let's Encrypt

- `certificatesResolvers.letsencrypt`, stockage `acme.json` (0600), **jamais
  commité**.
- Challenge `http` (par défaut) ou `dns` (DuckDNS/IP privée).
- Dev (DuckDNS) : `acme_is_staging: false` → **vrais certs**.
- Points d'attention : rate-limits LE, propagation DuckDNS (`delayBeforeCheck`,
  15 s), ne pas bricoler `acme.json`.

## 9.5 Flux attendus  (cas de pannes réseau connus)

- **TFS 2** : `DEFAULT_FORWARD_POLICY` → conteneurs sans sortie.
- **TFS 3** : bind `/var/log/traefik` → EROFS (corrigé via `/opt/traefik/logs`).

---

# 10. Monitoring, logs et alertes

## 10.1 Vue d'ensemble

```
node-exporter:9100 ─┐
cadvisor:8080 ──────┼──► Prometheus:9090 ──► TSDB ──► Grafana:3000
traefik:8082 ───────┤           │
docker:9323 ────────┤           └── alertes ──► contact points
alloy:12345 ────────┘
Alloy ──► Loki:3100 ──► Grafana (logs)
```

- Scrape all 15 s (30 s pour docker).
- Rétention métriques : 7 j (dev) / 30 j (prod).
- Rétention logs : 72 h (dev) / 336 h (prod).

## 10.2 Auto-scrape des apps (docker_sd)

Sur le conteneur (dépendance des apps) :

```yaml
labels:
  - "prometheus.scrape=true"
  - "prometheus.port=8000"
  - "prometheus.path=/metrics"
```

→ Prometheus le découvre tout seul.

## 10.4 Règles d'alerte (unified alerting Grafana)

**Groupe `disponibilité`** (haut niveau) :

| Alerte | Requête | Priorité |
|---|---|---|
| Node/Prometheus/Traefik/Docker/Loki/Alloy down | `(1 - up{job=…}) == 1` | critical |
| Grafana down | up == 0 5m | critical |
| Erreurs 5xx | `sum by(service)(rate(traefik_service_requests_total{code=~"5.."}[5m])) > 0.05` | warning |
| Latence p95 | `histogram_quantile(0.95, …) > 3s` | warning |

**Groupe `ressources`** :
- load CPU > 80 % (warning) / mémoire > 90 % (critical)
- disque root < 20 % (warn) / < 10 % (crit)
- latence p95 > 3 s ; conteneurs qui redémarrent en boucle.

**Groupe `securite`** (Trivy, source Loki) :
- `alert-trivy-critical` (LogQL) : au moins 1 scan avec CRITICAL sur 25 h.

> 💡 Contact point unique `all-channels` : toujours e-mail, + Telegram/Slack/
> Discord selon le vault. Déclenchement : Grafana lui-même (pas d'Alertmanager).

## 10.5 Dashboards provisionnés

| Fichier | Contenu |
|---|---|
| `overview.json` | vue d'ensemble globale |
| `infrastructure.json` | hôte + conteneurs |
| `docker.json` | stats Docker |
| `traefik.json` | requêtes/latence/erreurs |
| `logs.json` | flux Loki (variables `env`/`server` avec `.+`) |
| `trivy.json` | vulnérabilités par image |

## 10.6 Données

| Composant | Chemin VM | Volume |
|---|---|---|
| Prometheus | `/opt/prometheus/data` | ./data |
| Loki | `/opt/loki/data` | ./data |
| Grafana | `/opt/grafana/{data,provisioning,dashboards}` | ./data |

> ⚠️ Grafana provisionné en read-only : toute modif UI est **perdue au
> redémarrage**. Source de vérité = les fichiers du rôle.

## 10.8 Trivy détaillé

```
timer systemd trivy-scan (03:05 UTC)
  └─ /opt/trivy/scan-containers.sh
       ├─ mise à jour auto de la base (cache /opt/trivy/cache)
       └─ par image active : docker run --rm trivy image ...
            -> /opt/trivy/reports/trivy.jsonl (1 ligne JSON/image)
                 ▼
       Alloy (loki.source.file, label source="trivy")
                 ▼
       Loki ──► dashboard trivy.json + alerte alert-trivy-critical
```

Ligne produite :

```json
{"ts":"2026-09-07T03:05:00Z","container":"grafana","image":"grafana/grafana:11.2.2","critical":0,"high":3}
```

Interrogations LogQL utiles :

```logql
# Images à risque CRITICAL :
count_over_time({source="trivy"} | json | critical != "0" [24h])
# Vérifier que le scan quotidien a tourné :
count_over_time({source="trivy"}[24h]) > 14
# Début détail :
{source="trivy"} | json
```

---

# 11. Les applications et le CI/CD

## 11.1 Architecture du déploiement

```
GitHub (todo_back / todo_front)
  ├─ ci.yml (job test)
  ├─ ci.yml (job build → Docker Hub)
  └─ ci.yml (job deploy; runner self-hosted) → .env + compose → deploy.sh
 VM
 /opt/apps/todo_back/{.env,docker-compose.yml}
 /opt/apps/todo_front/{.env,docker-compose.yml}
 /opt/deploy/{deploy.sh, deploy-wrapper.sh, start-apps.sh}
 Runners systemd : actions.runner.* (user gh-runner: docker+deployers)
```

## 11.2 Le workflow (structure)

```yaml
name: CI/CD
on:
  push:
    branches: [ master ]
  pull_request:
concurrency: <repo>_deploy

jobs:
  test:
    runs-on: ubuntu-latest
    steps: checkout / setup / (back: postgres + ruff + pytest ; front: npm ci + eslint + next build)
  build:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps: buildx / login Hub / build+push (tags develop, sha-<sha>)
  deploy:
    if: needs.build.result == 'success' && github.ref == 'refs/heads/master'
    runs-on: [self-hosted, linux, x64]
    steps:
      - checkout
      - génération .env (depuis les GitHub secrets)
      - copie .env + docker-compose.yml dans /opt/apps/<app>/
      - /opt/deploy/deploy.sh <app> sha-<sha>
```

## 11.3 Secrets GitHub

| Secret | Utilisé par |
|---|---|
| `DOCKER_USER` / `DOCKER_TOKEN` | build (login Hub) |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | .env du back |
| `SECRET_KEY` | ⚠️ placeholder à corseter (S6) |
| `CORS_ORIGINS` | .env du back |
| `CLOUDINARY_CLOUD` / `API_KEY` / `API_SECRET` | ⚠️ clé API exposée (S6) |

## 11.4 `deploy.sh` — le script de déploiement générique

```bash
set -euo pipefail
APP="$1"; shift; TAG="${1:-sha-master}"
CDIR="/opt/apps/${APP}"
[ -f "${CDIR}/docker-compose.yml" ] || exit 1
cd "${CDIR}"
IMAGE_TAG="${TAG}" docker compose up -d --pull always
docker compose ps
```

> 💡 Comportement : `IMAGE_TAG=sha-<sha>` pousse un tag précis ; un mauvais
> déploiement affiche `down` (exit non nul) → on peut relancer un `up` d'un
> ancien tag (rollback).

## 11.6 Runners self-hostés (état réel)

| Runner | Repo | Service systemd |
|---|---|---|
| `vm-todo-back` | todo_back | `actions.runner.papadiouf13-todo_back.vm-todo-back.service` |
| `vm-todo-front` | todo_front | `actions.runner.papadiouf13-todo_front.vm-todo-front.service` |
| `vpstest-api` / `vpstest-front` | app-learning-hub | `actions.runner.*` |

> ⚠️ Installés **manuellement** (pas Ansible) → cf. S4.

---

# 12. Validation (`make verify`)

| Contrôle | Sortie attendue |
|---|---|
| Conteneurs attendus tournent | 1 ligne « running » par conteneur |
| Ports publiés | **seulement 80 et 443** |
| Prometheus healthy + exige auth (https) | 200 puis 401 sans user |
| Grafana `/api/org` | 200 avec login admin du vault |
| Loki `/ready` + labels | 200 + labels non vides |
| SonarQube (prod) | `/api/system/status` 200 |
| Réseaux Docker | `proxy`, `monitoring` (et `back` si app_deploy) |
| Trivy | script 0750 + timer actif + `trivy.jsonl` existe |

---

# 13. Exploitation quotidienne

## 13.1 Rituels

| Fréquence | Action |
|---|---|
| Quotidien | Grafana (overview + logs), `docker ps`, alertes en cours |
| Quotidien | `journalctl -u actions.runner.*` |
| Hebdo | `df -h / /var/lib/docker`, résultats Trivy |
| Hebdo | `make verify ENV=dev` |
| Mensuel | test de restauration backups + mises à jour apt |
| Trimestriel | revue alertes, dashboards, droits, MFA |

## 13.2 Mise à jour

- **Images** : pas de `latest`. Changer le tag dans `all.yml` → `make configure`
  dans un env à la fois (dev → prod) → `make verify`.
- **Système** : `unattended-upgrades` actif.
- **Apps** : chaque push master = release via le CI.

## 13.3 MEP d'une modif d'infra

1. Commit + push (relecture).
2. `make plan ENV=prod`.
3. `make apply ENV=prod` / `make configure ENV=prod`.
4. `make verify ENV=prod`.
5. Vérifier dashboards + alertes + un log frais.

---

# 14. Sauvegardes et DRP

## 14.1 État existant

| Donnée | Sauvée ? |
|---|---|
| State Terraform | ✅ S3 versionné |
| `acme.json` (certs) | ❌ |
| Code + config | ✅ git |
| `.env` + compose apps | ❌ |
| Base Postgres | ❌ aucun dump auto |
| Métriques/logs | par design (TTL) |
| Grafana config | ✅ templates |
| Secrets vault | ⚠️ (mot de passe côté admin) |

## 14.2 Plan minimal (à implémenter)

1. Dump quotidien de chaque base :
   ```bash
   docker exec todo_back_postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
     > "/opt/backups/todo_back-$(date +%F).sql"
   ```
2. Archive `/opt/apps` + `/opt/backups` (gpg optionnel).
3. Envoi off-site (rclone /backblaze S3).
4. Rétention : X jours + 1/mois.
5. Alerte Grafana sur le dernier backup réussi.

## 14.3 Plan de reprise

| Scénario | Récup |
|---|---|
| Panne VM | recreate infra depuis S3 → `make configure` (nouvelle IP !) → runners → CI → reload DB |
| Conteneur cassé | `docker compose up -d` + chapitre 15 |
| Perte dataset | restaurer depuis `/opt/backups` |

---

# 15. Dépannage (runbooks)

## 15.1 Principes

Toujours commencer par `docker ps`, `make verify ENV=…`, `journalctl`.

## 15.2 Serveur sans réponse sur 80/443

1. `ssh` actif ? → `ip a`, `systemctl status docker`.
2. `ufw status` → 80/443 (et SSH !).
3. `docker ps` → traefik crashé ? `DEFAULT_FORWARD_POLICY` toujours ACCEPT ?
4. SG AWS (si cloud).

## 15.3 Conteneur en crash-loop

```bash
docker logs --tail 200 todo_back
# rollback vers image précédente :
cd /opt/apps/todo_back && IMAGE_TAG=sha-<précédent> docker compose up -d --pull always
```

## 15.4 Swagger/ReDoc sans `/api`

Marqueur : `/openapi.json` → 404. Vérifier `ROOT_PATH` (entrypoint.sh) et le
compose app.

## 15.5 Dashboard logs « No data »

- Vérifier Loki (labels reçus), réseau `monitoring`, et les **variables du
  dashboard** : `.*` rejeté par Loki → `.+`.

## 15.6 Rollback d'une app

```bash
cd /opt/apps/<app>
docker ps
IMAGE_TAG=sha-<bon-sha> docker compose up -d --pull always
```

## 15.7 Grafana inaccessible / auth

- `curl https://grafana.<host>/api/org -u admin:$(pass)` → 401 ? → S3
  (admin UI ≠ vault). Re-sync.

## 15.8 Disque plein

```bash
df -h / /var/lib/docker
# journaux Docker rotationnés 10m×3 ; rétention à baisser en quick fix
```

## 15.9 Runner lent / down

`sudo systemctl status actions.runner.*` + `./run.sh` du runner.

## 15.10 Vault-pass perdu

Reconstruire `vault.yml` à partir du `.example` + secrets GitHub.

---

# 16. Checklist de mise en production d'un serveur neuf

- [ ] **Poste admin**
  - [ ] AWS CLI configuré, key pair, Terraform/Ansible/collections (7.1)
- [ ] **Terraform**
  - [ ] tfvars (`admin_cidr` ≠ 0.0.0.0/0 !)
  - [ ] `plan`/`apply` (workspace dev)
  - [ ] `make inventory`
- [ ] **Provisioning**
  - [ ] `make configure ENV=dev` (vault demandé)
  - [ ] `make verify ENV=dev`
  - [ ] 80/443 seuls publiés
- [ ] **DNS/TLS**
  - [ ] hostnames visibles, certs LE OK, 80→443
- [ ] **Monitoring**
  - [ ] Prometheus 200 (avec auth), targets UP, Loki ingère, Grafana 200/admin, dashboards présents (dont logs)
  - [ ] Simuler un fail → contact point reçoit
  - [ ] Trivy : scan noté, dashboard rempli, alerte provisionnée
- [ ] **CI/CD apps**
  - [ ] runners installés/vérifiés
  - [ ] secrets GitHub complets (SECRET_KEY non-placeholder)
  - [ ] `deploy` sur master → app up, Swagger `/api` OK
  - [ ] images privées (ou décision assumée)
- [ ] **Sécurisation**
  - [ ] `admin_cidr` IP admin, Grafana admin = vault, fail2ban actif, MFA AWS
- [ ] **Backups/DRP**
  - [ ] backups automatisés + test de restauration
- [ ] **Documentation**
  - [ ] ce manuel à jour (IP, hostnames, runners)

---

# 17. Annexes

## 17.1 Commandes utiles (poste admin)

```bash
# Terraform (dans terraform/)
terraform workspace list && terraform plan
terraform apply -var-file=dev.tfvars

# Ansible (à la racine)
make preflight configure verify ENV=dev
ansible-playbook -i ansible/inventories/dev/hosts.ini ansible/playbooks/site.yml --ask-vault-pass

# Vault
ansible-vault edit ansible/group_vars/vault.yml

# Hashs bcrypt (middlewares Traefik)
scripts/gen-bcrypt-hash.sh "<pwd>"

# Mode standalone (sur le serveur)
bash scripts/standalone-prep.sh dev
make configure ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
make verify   ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
make urls     ENV=dev
```

## 17.2 Chemins à connaître sur la VM

| Chemin | Contenu |
|---|---|
| `/opt/traefik` | traefik.yml, dynamic.yml, acme.json, logs/, compose |
| `/opt/prometheus` | prometheus.yml, data/ |
| `/opt/loki` | config + data/ |
| `/opt/alloy` | config.alloy + data |
| `/opt/grafana` | provisioning/, dashboards/, data/ |
| `/opt/apps/*` | apps + `.env` + compose |
| `/opt/deploy` | deploy.sh, deploy-wrapper.sh, start-apps.sh, .ssh |
| `/opt/trivy` | scan-containers.sh, cache, reports/trivy.jsonl |
| `/opt/sonarqube` | compose, data, logs, extensions, db-data |

## 17.3 Ports

| Service | Port | Publié hôte ? | Accès |
|---|---|---|---|
| Traefik (web) | 80 / 443 | oui | internet |
| Dashboard Traefik | 8080 | non | traefik.<host> (basic-auth) |
| Metrics Traefik | 8082 | non | interne |
| Grafana | 3000 | non | grafana.<host> |
| Prometheus | 9090 | non | prometheus.<host> (basic-auth) |
| Loki | 3100 | non | interne |
| Alloy | 12345 | non | interne |
| node-exporter | 9100 | non | interne |
| cadvisor | 8080 | non | interne |
| docker-metrics | 9323 | non | UFW→subnets |
| app api | 8000 | non | <host>/api |
| app front | 3000 | non | <host> |

## 17.4 Environnement de référence

| Param | Valeur |
|---|---|
| VM de référence | `192.168.1.15` (LAN) ; hostnames `*.192.168.1.15.nip.io` |
| VM VMware (2e) | `192.168.175.131` — `tioukh.duckdns.org` |
| VM VMware (3e, dossier d'apprentissage) | `192.168.175.132` — `inframonitoring.duckdns.org` |
| OS | Ubuntu 22.04 / 24.04 |
| Utilisateurs | `papa` / `mamadou` / `diouf` (SSH), `gh-runner` (CI) |
| Apps | todo_back (FastAPI+Postgres), todo_front (Next.js) |

> 📖 **Rappel des procédures liées** :
> - `NOUVEAU-SERVEUR-PROCEDURE.md` : la marche à suivre **pas-à-pas** pour
>   installer un nouveau serveur (SSH → déploiement → REX).
> - `CHANGEMENT-IP-SERVEUR.md` : que faire si l'IP de la VM change.

---

*Fin du manuel — version pédagogique 2.0. Si un chapitre te semble encore
obscur, ouvre le dépôt à côté de ce document et suis le code : chaque bloc a
été écrit pour être lu et exécuté.*