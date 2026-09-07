# 5. Documentation détaillée des fichiers et du code

> Chaque fichier est analysé dans l'ordre : **objectif, contenu bloc par bloc,
> variables/paramètres, dépendances, risques et éléments à personnaliser**.

---

## 5.1 Terraform — racine

### 5.1.1 `terraform/versions.tf`

**Objectif** : verrouille la version de Terraform et du provider AWS.

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

- `required_version` : impose une version récente (les fonctionnalités
  `-chdir`, workspaces et `-var-file` utilisées par le Makefile nécessitent
  ≥ 1.9).
- `required_providers` : émet un binaire `aws` compatible (famille 5.x, lock
  fichier `.terraform.lock.hcl`).
- **Risques** : un provider plus ancien peut manquer d'attributs récents ;
  un changement majeur (`aws ~> 6.0`) exigerait de relire la doc des
  ressources.
- **À personnaliser** : rien (mais mettre à jour `version` lors des montées
  de version voulues).

### 5.1.2 `terraform/providers.tf`

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

- `region` : par défaut `eu-west-3` (voir `variables.tf`).
- `default_tags` : tagge **toutes** les ressources créées — indispensable pour
  identifier/côtoyer les coûts.
- **Dépendances** : variable `aws_region`, `project_name`, `environment`.
- **Éléments à personnaliser** : région AWS.

### 5.1.3 `terraform/backend.tf`

**Objectif** : stockage de l'état Terraform dans S3 (partagé, chiffré) +
verrouillage dynamoDB.

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

- Un **workspace** = un environnement (`dev`/`prod`) → deux clés d'état
  distinctes dans le même bucket.
- `encrypt = true` : chiffrement côté serveur de l'objet S3.
- `dynamodb_table` : verrouillage pessimiste anti-concurrence entre `apply`
  simultanés.
- **Bootstrap initial** (une seule fois) :
  ```bash
  # poste admin
  aws s3api create-bucket --bucket infra-deploie-tfstate-examen \
      --region eu-west-3 --create-bucket-configuration LocationConstraint=eu-west-3
  aws s3api put-bucket-versioning --bucket infra-deploie-tfstate-examen \
      --versioning-configuration Status=Enabled
  aws dynamodb create-table --table-name terraform-lock \
      --attribute-definitions AttributeName=LockID,AttributeType=S \
      --key-schema AttributeName=LockID,KeyType=HASH \
      --billing-mode PAY_PER_REQUEST
  ```
- **Risques** : perdre le bucket = perdre l'état → **activer le versioning**
  (fait ci-dessus) et mettre en place une sauvegarde (chapitre 14).
- **Variable locale (dépannage)** : commenter le bloc S3 et utiliser
  `backend "local" { path = "terraform.tfstate" }`.
- ⚠️ **Avertissement** : ne jamais oublier de re-synchroniser le local et le
  distant en cas de bascule backend local ⇄ S3.

### 5.1.4 `terraform/variables.tf`

Catalogue des variables avec validations. Principales :

| Variable | Type | Défaut | Rôle | À personnaliser |
|---|---|---|---|---|
| `aws_region` | string | `eu-west-3` | Région AWS | Oui (selon emplacement) |
| `environment` | string | — | `dev` ou `prod` (obligatoire, validé) | Obligatoire |
| `project_name` | string | `infra-deploie` | Préfixe de nommage | Oui |
| `instance_type` | string | — | Type EC2 | Oui |
| `ssh_key_name` | string | — | Key pair EC2 existante | Obligatoire |
| `ami_id` | string | `""` | AMI Ubuntu 22.04 (sinon data source Canonical) | Optionnel |
| `vpc_cidr` / `subnet_cidr` | string | — | Plan d'adressage | Oui |
| `availability_zone` | string | `eu-west-3a` | AZ du subnet public | Oui |
| `admin_cidr` | string | — | CIDR admin : SSH + allowlist interfaces protégées | **Oui (sécurité)** |
| `root_volume_size` | number | `20` | Taille disque (Go) | Oui |
| `root_volume_type` | string | `gp3` | Type disque | Optionnel |
| `extra_tags` | map(string) | `{}` | Tags additionnels | Optionnel |
| `domain` | string | `""` | Domaine réel (optionnel) | Optionnel |
| `ansible_user` | string | `ubuntu` | Utilisateur Ansible | Selon OS |

- ⚠️ `admin_cidr` doit être **IP /32 de l'admin** en prod, jamais `0.0.0.0/0`.

### 5.1.5 `terraform/main.tf`

Relie les modules et résout l'AMI :

```hcl
locals {
  server_name = "${var.environment}-server"
  ami_id      = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu[0].id
}
```

- `data "aws_ami" "ubuntu"` : recherche la dernière AMI Ubuntu 22.04 officielle
  Canonical (`owners = ["099720109477"]`).

Modules appelés (ordre logique : réseau → sécurité → instance) :
- `module "network"` (VPC, subnet, IGW, route).
- `module "security"` (SG : 22 restreint, 80/443 ouvert).
- `module "ec2"` (instance + EIP + IAM SSM + user-data).

**Dépendances** : chaque module reçoit les sorties du précédent
(`vpc_id`, `subnet_id`, `security_group_id`).

### 5.1.6 `terraform/outputs.tf`

Sorties consommées par le Makefile et les workflows :

| Output | Valeur | Usage |
|---|---|---|
| `public_ip` | EIP | URLs nip.io, `make ssh/urls`, inventaire |
| `private_ip` | IP privée | injectée dans templates Ansible |
| `instance_id` | id EC2 | opérations AWS |
| `server_name` | `dev-server`/`prod-server` | label Prometheus `server` |
| `security_group_id` | id SG | debugging |
| `ansible_inventory` | texte INI | écrit tel quel dans `hosts.ini` par `make inventory` |

> L'output `ansible_inventory` inclut `[all:vars] ansible_user`. C'est ce que
> `make inventory` recopie dans `ansible/inventories/<env>/hosts.ini`.

### 5.1.7 `terraform/dev.tfvars.example` / `prod.tfvars.example`

Gabarits de variables par environnement :

```hcl
environment      = "dev"
instance_type    = "t3.small"          # éligible Free Tier
ssh_key_name     = "monitoring-key"
admin_cidr       = "1.2.3.4/32"        # { ma_ip } — remplacer
vpc_cidr         = "10.0.0.0/16"
subnet_cidr      = "10.0.1.0/24"
root_volume_size = 20
```

- Copier en `dev.tfvars` / `prod.tfvars` puis adapter.
- ⚠️ `*.tfvars` sont **ignorés par git** (`.gitignore`) : ne jamais committer.

---

## 5.2 Terraform — modules

### 5.2.1 `terraform/modules/network/`

**Objectif** : VPC + subnet public + Internet Gateway + table de routage.

| Resource | Rôle |
|---|---|
| `aws_vpc.this` | VPC avec DNS support + hostnames |
| `aws_subnet.public` | Subnet public (IP publique attribuée au lancement) |
| `aws_internet_gateway.this` | Accès internet sortant |
| `aws_route_table.public` + association | Route `0.0.0.0/0` → IGW |

- Variables : `project_name`, `environment`, `vpc_cidr`, `subnet_cidr`,
  `availability_zone`, `extra_tags`.
- Sorties : `vpc_id`, `subnet_id`.
- **Personnalisation** : `vpc_cidr`/`subnet_cidr` (plan d'adressage),
  `availability_zone`.

### 5.2.2 `terraform/modules/security/`

**Objectif** : security group.

| Ingress | Port | Source |
|---|---|---|
| SSH | 22 | `admin_cidr` (**IP admin** — jamais 0.0.0.0/0) |
| HTTP | 80 | `0.0.0.0/0` (redirection + ACME HTTP-01) |
| HTTPS | 443 | `0.0.0.0/0` (Traefik) |
| Egress | tout | `0.0.0.0/0` |

- ⚠️ Ce contrôle est **doublé** par UFW dans le rôle `common` : l'un comme
  l'autre peuvent bloquer l'accès. Toute modification réseau doit être testée
  sur les deux niveaux (chapitre 9).

### 5.2.3 `terraform/modules/ec2/`

**Objectif** : instance + EIP + profil IAM SSM + user-data.

- **IAM** : rôle + policy `AmazonSSMManagedInstanceCore` + instance profile →
  permet **SSM Session Manager** (accès console AWS sans SSH ouvert).
- **Instance** :
  - `key_name` : key pair admin ;
  - `user_data` : via `user_data.tpl` (voir plus bas) ;
  - disque racine **chiffré** (`encrypted = true`), type/size paramétrés ;
  - `lifecycle { ignore_changes = [ami] }` : le remplacement de l'AMI ne
    recrée pas l'infra (patching éphémère). ⚠️ Ce choix signifie que les mises
    à jour système se font **dans la VM** (unattended-upgrades), pas par
    pourvoir.
- **EIP** : IP publique stable (les hostnames nip.io et le CI s'y réfèrent).

**`user_data.tpl`** (script de boot, minimal par conception) :

```bash
apt-get update -y
apt-get install -y python3 python3-apt python3-venv
# crée l'utilisateur ansible si différent de "ubuntu"
echo "user-data OK: python3 installé" > /var/log/user-data.log
```

> Toute la suite (UFW, Docker, Traefik, monitoring) est posée par **Ansible**
> au `make configure`. Le user-data ne doit **pas** dupliquer ces étapes.

---

## 5.3 Makefile (orchestration)

**Objectif** : enveloppe ergonomique autour de Terraform/Ansible.

| Cible | Fonction |
|---|---|
| `make help` | Liste les cibles |
| `make preflight ENV=dev` | Vérifie `terraform`/`ansible-playbook`/`docker`/`curl` |
| `make plan` / `apply` | Terraform plan/apply (workspace `ENV` + `-var-file`) |
| `make inventory` | Écrit `hosts.ini` depuis l'output `ansible_inventory` |
| `make configure` | `ansible-playbook site.yml` (`--ask-vault-pass` par défaut) |
| `make deploy` | `apply → inventory → configure` |
| `make verify` | `ansible-playbook verify.yml` |
| `make destroy` | `terraform destroy` (confirmation interactive) |
| `make ssh` | `ssh` vers l'IP (output Terraform ou inventaire) |
| `make urls` | Affiche les URLs de l'environnement |

**Variables** :
- `ENV ?= dev` ; `VAULT_ARGS ?= --ask-vault-pass` (remplaçable :
  `make configure ENV=prod VAULT_ARGS="--vault-password-file .vault-pass"`).
- `tf-select` : `terraform workspace select ENV` (ou `new`).

**Détails notables** :
- `get-ip`/`ssh`/`urls` préfèrent la sortie Terraform puis l'inventaire
  (fallback VPS).
- `destroy` demande confirmation explicite (`[y/N]`).
- ⚠️ `ssh` n'active pas `StrictHostKeyChecking` (comportement de
  `ansible.cfg`). Vérifier l'empreinte de la clé de l'hôte au premier accès.

---

## 5.4 Ansible — configuration générale

### 5.4.1 `ansible/ansible.cfg`

```ini
[defaults]
roles_path = ./roles
inventory  = inventories/dev/hosts.ini
host_key_checking = False
retry_files_enabled = False
interpreter_python = /usr/bin/python3

[ssh_connection]
pipelining = True

[privilege_escalation]
timeout = 60
```

- `roles_path` : rôles locaux du dépôt.
- `host_key_checking = False` : évite les prompts sur hôtes éphémères (AWS) —
  ⚠️ **à réévaluer** en prod (risque MITM) ; préférer fixer les empreintes en
  `known_hosts` pour une VM fixe.
- `pipelining = True` : améliore fortement la performance des tâches.
- `interpreter_python`: cible Ubuntu (python3).

### 5.4.2 `ansible/requirements.yml`

Déclare les collections `community.docker` (≥3.4.0) et `community.general`
(≥8.0.0). Installer avec `ansible-galaxy collection install -r …`.

### 5.4.3 `ansible/group_vars/all.yml`

Variables **communes** à tous les environnements. Blocs principaux :

- **Identité / connexion** :
  ```yaml
  environment_name: "{{ group_names[0] }}"
  ansible_user: ubuntu
  ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  ansible_ssh_private_key_file: "~/.ssh/monitoring-key.pem"
  ```
  ⚠️ `UserKnownHostsFile=/dev/null` : même remarque sécurité que ci-dessus.

- **Admin / hostnames** :
  ```yaml
  admin_cidr: ["0.0.0.0/0"]          # ⚠️ À RESTREINDRE EN PROD
  admin_email: admin@example.com      # email ACME
  grafana_host: "grafana.{{ public_ip }}.nip.io"
  prometheus_host: "prometheus.{{ public_ip }}.nip.io"
  traefik_host: "traefik.{{ public_ip }}.nip.io"
  sonar_host: "sonar.{{ public_ip }}.nip.io"
  whoami_host: "whoami.{{ public_ip }}.nip.io"
  ```
  `public_ip` est une **variable d'hôte** de l'inventaire.

- **TLS/ACME** : `traefik_cert_type`, `acme_is_staging` (true en dev), emails
  et hashes bcrypt (voir vault).

- **Réseaux Docker** (subnets fixes, cf. 2.5).
- **Images épinglées** :
  ```yaml
  images:
    traefik: "traefik:v3.7.13"
    node_exporter: "prom/node-exporter:v1.8.2"
    cadvisor: "ghcr.io/google/cadvisor:v0.60.5"
    prometheus: "prom/prometheus:v2.54.1"
    loki: "grafana/loki:3.2.2"
    alloy: "grafana/alloy:v1.3.1"
    grafana: "grafana/grafana:11.2.2"
    whoami: "traefik/whoami:v1.10.1"
sonarqube: "sonarqube:lts-community"
    postgres: "postgres:16-alpine"
    trivy: "aquasec/trivy:0.57.1"
  ```

- **Seuils d'alertes** (subject `alerts:`), **contact points** (`alerting:`),
  **rétention** (`monitoring_retention_days`, `loki_retention_hours`),
  **SonarQube** (off par défaut, chiffres mémoire), **DuckDNS** (vide = off),
  **intervalle de scrape** (15 s), **dashboards** provisionnés (dont `trivy`),
  **Trivy** (`trivy_schedule`, `trivy_severities`, `trivy_ignore_unfixed`,
  répertoires `/opt/trivy`).
  Voir détail au chapitre 10.

### 5.4.4 `ansible/group_vars/dev.yml`

- `acme_is_staging: true` (rate-limits Let's Encrypt évités).
- `monitoring_retention_days: 7` ; `loki_retention_hours: 72` (3 j).
- `enable_sonarqube: false` (RAM de l'instance dev trop juste).
- `app_deploy_user: papa` (utilisateur CD de la VM de référence).

### 5.4.5 `ansible/group_vars/prod.yml`

- `acme_is_staging: false`.
- `monitoring_retention_days: 30` ; `loki_retention_hours: 336` (14 j).
- `enable_sonarqube: true`.

### 5.4.6 `ansible/group_vars/vault.yml.example`

Gabarit des **secrets** (voir chapitre 8 pour la mise en place) :

| Variable | Usage |
|---|---|
| `grafana_admin_user` / `grafana_admin_password` | Compte admin Grafana |
| `prometheus_basic_auth_user` / `hash` | basic-auth Prometheus (Traefik) |
| `traefik_dashboard_basic_auth_user` / `hash` | basic-auth dashboard Traefik |
| `sonarqube_admin_current_password` / `new_password` / `db_password` | SonarQube |
| `alerting.email.*` / `telegram.*` / `slack.*` / `discord.*` | Contact points (remplace le bloc de all.yml) |
| `duckdns_token` / `duckdns_domains` | DuckDNS (optionnel) |

> ⚠️ Le bloc `alerting:` du vault **remplace** celui de `all.yml` (précédence
> group_vars). Il doit donc contenir **toutes** les clés `alerting`.

### 5.4.7 Inventaires dev/prod (`hosts.ini.example`)

```ini
[dev]
dev ansible_host=203.0.113.10 public_ip=203.0.113.10 private_ip=203.0.113.10 server_name=dev-server

[all:vars]
ansible_user=ubuntu
```

- Variables d'hôte attendues : `public_ip`, `private_ip`, `server_name`.
- En mode VPS : copier en `hosts.ini` et renseigner les IP.
- `hosts.ini` réel est **ignoré par git**.

---

## 5.5 Ansible — playbooks

### 5.5.1 `playbooks/site.yml`

**Provisions la pile complète** dans l'ordre :

```
pre_tasks : include_vars all.yml + vault.yml + <env>.yml puis assert
roles     : common → docker → traefik → node_exporter → cadvisor →
            prometheus → loki → alloy → grafana → sonarqube (si enable_sonarqube)
post_tasks: récapitulatif des URLs
```

- Déclenchement : `make configure ENV=<env>` (ou
  `ansible-playbook -i inventories/<env>/hosts.ini playbooks/site.yml --ask-vault-pass`).
- **Idempotence** : ré-exécutable librement (reconvergure).

### 5.5.2 `playbooks/app-deploy.yml`

Prépare la **VM à recevoir des applications déployées par GitHub Actions**
(rôle `app_deploy`) : `/opt/apps`, clé ed25519 CI/CD restreinte + wrapper,
`deploy.sh`, `start-apps.service`, réseau Docker `back`.
(Chapitre 11 — note : la VM de référence passe désormais par des **runners
self-hosted** plutôt que par la clé restreinte+wrapper ; les deux mécanismes
sont documentés.)

### 5.5.3 `playbooks/verify.yml`

Contrôles post-déploiement **idempotents** :

| Vérification | Détail |
|---|---|
| Conteneurs attendus | traefik, whoami, node-exporter, cadvisor, prometheus, loki, alloy, grafana (+ sonarqube/sonar-db si prod) |
| Ports publiés | seuls `80`/`443` (différence vs [80,443] vide) |
| Prometheus healthy | `docker run curl` sur le réseau monitoring |
| Prometheus (https) exige auth | code HTTP = `401` sans credentials |
| Grafana accepte admin | `curl -u admin:…` → `/api/org` |
| Loki ready + ingestion | `/ready` + `/loki/api/v1/labels` non vide |
| SonarQube répond (si prod) | `/api/system/status` |

- Utilise de petits conteneurs `curlimages/curl:8.7.1` jetables sur les
  réseaux `monitoring`/`proxy` (aucun outil à installer sur l'hôte).

---
---

## 5.6 Ansible — rôles (documentation détaillée)

### 5.6.1 `roles/common` — durcissement de base

**Fichiers** : `tasks/main.yml`, `defaults/main.yml`, `handlers/main.yml`,
`templates/jail.local.j2`, `templates/duckdns-update.sh.j2`.

**Rôle** : paquets de base, fuseau horaire, **UFW**, **fail2ban**,
**unattended-upgrades**, **DuckDNS** (optionnel).

**Tâches principales (`tasks/main.yml`)** :

| Tâche | Description | Risque / point d'attention |
|---|---|---|
| `apt update` | Actualise le cache (cache 1 h) | — |
| apt : ufw, fail2ban, unattended-upgrades, curl, ca-certificates, gnupg, python3-apt | Paquets de base | — |
| `community.general.timezone` | Fuseau (défaut UTC) | Se fait aussi en prod : attention aux logs datés |
| UFW default deny incoming / allow outgoing | Politique par défaut | ⚠️ appliquée **avant** l'activation |
| UFW allow **22/80/443** | Ports visibles | ⚠️ **Ne pas ressaisir un mauvais port SSH** (risque coupure) |
| UFW allow `9323` depuis subnets Docker | Métriques daemon Docker | Sans cette règle, le scrape `job: docker` échoue |
| UFW enable | Active le pare-feu | — |
| `DEFAULT_FORWARD_POLICY="ACCEPT"` | Forwarding requis pour Docker | Sans cela, les conteneurs n'ont pas de connectivité sortante → impossible de joindre Traefik |
| fail2ban template `jail.local` | Jail SSH (`maxretry`, `bantime`, `findtime`) | Voir 5.6.1.1 |
| systemd fail2ban | start + enable | — |
| unattended-upgrades `20auto-upgrades` | Màj packages auto | — |
| DuckDNS script + cron `*/10` | Màj IP des sous-domaines | Seulement si `duckdns_token`+`duckdns_domains` renseignés |

**Config fail2ban (`jail.local.j2`)** :

```ini
[DEFAULT]
bantime  = 1h
findtime = 600
maxretry = 5
[sshd]
enabled  = true
port     = ssh
```

**Variables (`defaults/main.yml`)** : `timezone`, `fail2ban_maxretry`,
`fail2ban_bantime`, `fail2ban_findtime`, `docker_metrics_port` (9323),
`docker_metrics_allow_cidrs` (subnets proxy+monitoring),
`unattended_upgrades_mail`.

> ⚠️ Sur la VM de référence, le port SSH est **22 standard** : `jail.local`
> cible `port = ssh`. Si l'on change le port SSH (recommandé en durcissement),
> adapter cette valeur.

### 5.6.2 `roles/docker` — moteur + daemon + réseaux

**Rôle** : installe Docker CE (dépôt officiel), configure `daemon.json`,
crée les réseaux `proxy` et `monitoring`.

**Étapes** :
1. Dépendances `apt` (`ca-certificates`, `curl`, `gnupg`).
2. Clé GPG officielle `/etc/apt/keyrings/docker.asc`.
3. Dépôt APT docker (arch détectée `x86_64`→`amd64`, release détectée).
4. Paquets : `docker-ce`, `docker-ce-cli`, `containerd.io`,
   `docker-buildx-plugin`, `docker-compose-plugin`, `python3-docker`.
5. Service `docker` activé au boot.
6. Utilisateur `ansible_user` ajouté au groupe `docker`.
7. GID docker mémorisé (pour `docker_sd` de Prometheus).
8. `daemon.json` + restart handler.

**`daemon.json.j2`** :

```json
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "3" },
  "metrics-addr": "0.0.0.0:9323",
  "live-restore": true
}
```

- **Rotation des logs conteneurs** : 10 Mo / 3 fichiers → évite le disque plein.
- **`metrics-addr`** : expose les métriques du daemon sur `9323` (scrapé par
  Prometheus, filtré UFW aux subnets internes).
- **`live-restore`** : les conteneurs restent up lors d'un redémarrage du
  démon (bascule de services).

**Réseaux** : `proxy` (br-proxy), `monitoring` (br-monitoring) en bridge, avec
subnets/gateway épinglés (cf. 2.5).

> ⚠️ Le `daemon.json` **surcharge** la configuration Docker standard : après
> modification, les handlers redémarrent Docker (`systemctl restart docker`),
> ce qui **redémarre le démon**. `live-restore` limite l'impact sur les
> conteneurs au repos.

### 5.6.3 `roles/traefik` — reverse-proxy TLS

**Rôle** : Traefik + whoami, config statique, config dynamique, `acme.json`,
compose.

**Tâches** :
- Répertoires `/opt/traefik`, `/opt/traefik/logs`.
- Templates : `traefik.yml` (statique), `dynamic.yml` (middlewares), compose.
- `acme.json` (touch, mode 0600).
- `docker_compose_v2` (`state: present`, `pull: missing`).
- Attente : port 443 puis routage HTTPS whoami (retries 10 × 5 s).

**Compose (`docker-compose.yml.j2`)** — points structurants :

```yaml
services:
  traefik:
    ports: ["80:80", "443:443"]          # seul à publier
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic.yml:/etc/traefik/dynamic.yml:ro
      - ./acme.json:/etc/traefik/acme.json
      - ./logs:/var/log/traefik
    labels:                               # dashboard exposé via Traefik lui-même
      - "traefik.http.routers.traefik.rule=Host(`{{ traefik_host }}`)"
      - "traefik.http.routers.traefik.service=api@internal"
      - "traefik.http.routers.traefik.middlewares=basic-auth-traefik@file,allowlist-admin@file"
  whoami:
    image: "{{ images.whoami }}"
    expose: ["80"]
    labels:
      - "traefik.http.routers.whoami.rule=Host(`{{ whoami_host }}`)"
      - "traefik.http.services.whoami.loadbalancer.server.port=80"
networks:
  proxy:     { external: true }
  monitoring:{ external: true }
```

> ℹ️ Traefik est sur **deux réseaux** : `proxy` (routage) et `monitoring`
> (scraping des métriques 8082 par Prometheus).

**Statique (`traefik.yml.j2`)** — points :

```yaml
api:      { dashboard: true, debug: false }
ping:     true
entryPoints:
  web:      { address: ":80", http.redirections.entryPoint → websecure (permanent) }
  websecure:{ address: ":443" }
  traefik:  { address: ":8080" }     # dashboard interne (non publié)
  metrics:  { address: ":8082" }     # métriques Prometheus (non publié)
metrics:
  prometheus: { entryPoint: metrics, addEntryPointsLabels: true, addServicesLabels: true }
providers:
  docker: { endpoint: "unix:///var/run/docker.sock", exposedByDefault: false, network: proxy, watch: true }
  file:   { filename: /etc/traefik/dynamic.yml, watch: true }
accessLog:
  filePath: "/var/log/traefik/access.log"
  format: json
  bufferingSize: 100
certificatesResolvers:
  letsencrypt:
    acme:
      caServer: "<staging si acme_is_staging>"   # dev
      email: "{{ admin_email }}"
      storage: /etc/traefik/acme.json
      httpChallenge: { entryPoint: web }
```

- `exposedByDefault: false` : seuls les conteneurs avec `traefik.enable=true`
  sont routés.
- Le mode `selfsigned` (`traefik_cert_type: selfsigned`) supprime le résolveur
  ACME et sert le certificat auto-généré de Traefik (avertissement navigateur).
- **Access logs JSON** consommés par Alloy (stage.json).

**Dynamique (`dynamic.yml.j2`)** — middlewares partagés :

```yaml
http:
  middlewares:
    basic-auth-prom:     basicAuth { users: [ "user:bcrypt-hash" ] }
    basic-auth-traefik:  basicAuth { users: [ "user:bcrypt-hash" ] }
    allowlist-admin:     ipAllowList { sourceRange: {{ admin_cidr }} }
    security-headers:    headers { SAMEORIGIN, nosniff, XSS, referrer, permissionsPolicy }
```

- **bcrypt** : hashs précalculés par `scripts/gen-bcrypt-hash.sh`, stockés dans
  le vault (pas de dépendance passlib à l'exécution).
- ⚠️ `admin_cidr` liste = `[{...}]` ; si vide, allowlist inactive → protection
  uniquement basic-auth.

### 5.6.4 `roles/node_exporter` — métriques hôte

**Compose** :

```yaml
node-exporter:
  image: prom/node-exporter:v1.8.2
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
    - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc|var/lib/docker)($$|/)
```

- **`collector.filesystem.mount-points-exclude`** : évite les doubles comptes
  (mounts Docker, sysfs, proc).
- Vérification : conteneur jetable `curl` sur `:9100/metrics` (retries 10).

### 5.6.5 `roles/cadvisor` — métriques conteneurs

**Compose** : cAdvisor en `:8080` sur `monitoring`, volumes ro (`/`,
`/var/run`, `/sys`, `/var/lib/docker`, `/dev/disk`).

- `CADVISOR_HEALTHCHECK_URL: "http://localhost:8080/"` : corrige le healthcheck
  intégré (sinon il sonde le mauvais port).

### 5.6.6 `roles/prometheus` — collecte

**Compose** :

```yaml
prometheus:
  user: "{{ prometheus_uid }}:{{ prometheus_uid }}"     # 65534:65534
  group_add: ["{{ docker_group_gid | default(988) }}"]  # lecture docker.sock
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
    - --storage.tsdb.retention.time={{ prometheus_retention }}   # examples: 7d/30d
    - --web.external-url=https://{{ prometheus_host }}
    - --web.route-prefix=/
```

- Labels Traefik : route `prometheus_host`, middlewares
  `basic-auth-prom@file,allowlist-admin@file`, certresolver LE.

**Métriques scrapées** (`prometheus.yml.j2`), toutes avec
`environment`/`server` en labels :

| Job | Cible |
|---|---|
| `prometheus` | `localhost:9090` |
| `node_exporter` | `node-exporter:9100` |
| `cadvisor` | `cadvisor:8080` |
| `traefik` | `traefik:8082` |
| `docker` | `host.docker.internal:9323` (intervalle 30 s) |
| `grafana` | `grafana:3000/metrics` |
| `loki` | `loki:3100/metrics` |
| `alloy` | `alloy:12345/metrics` |
| `docker-containers` | **docker_sd** : conteneurs label `prometheus.scrape=true` |

**Job `docker-containers` (docker_sd + relabels)** :

- `keep` si `__meta_docker_container_label_prometheus_scrape == "true"`.
- `prometheus.port` : remplace le port du `__address__`.
- `prometheus.path` : remplace `__metrics_path__` (défaut `/metrics`).
- ajoute `environment`/`server`.

> ℹ️ **Auto-scrape des apps** : pour qu'une app soit scrapée automatiquement,
> il suffit de lui poser `prometheus.scrape=true` (+ `prometheus.port` /
> `prometheus.path`) dans son compose. C'est utilisé par les apps de la VM de
> référence.

### 5.6.7 `roles/loki` — stockage des logs

**Compose** : Loki `:3100` sur `monitoring`, user `10001:10001`, volume
`./data:/loki`.

**Config (`loki.yml.j2`)** — mode **standalone**, stockage **filesystem** :

```yaml
auth_enabled: false
common:
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
schema_config:
  configs:
    - from: 2024-01-01
      store: tsdb
      object_store: filesystem
      schema: v13
      index: { prefix: index_, period: 24h }
limits_config:
  retention_period: {{ loki_retention }}        # 72h (dev) / 336h (14j prod)
  allow_structured_metadata: true
compactor:
  working_directory: /tmp/compactor
  retention_enabled: true
  delete_request_store: filesystem
```

- **Rétention** appliquée par le **compactor** (pas uniquement le schéma).
- ⚠️ Loki **n'exige pas d'authentification** (`auth_enabled: false`) : il vit
  sur le réseau interne `monitoring`. Ne **jamais** l'exposer hors de la VM.

### 5.6.8 `roles/alloy` — collecteur de logs

**Config (`config.alloy.j2`, format River)** — 3 sources + parsing :

| Bloc | Rôle |
|---|---|
| `discovery.docker "containers"` | Découverte des conteneurs via le socket |
| `discovery.relabel "containers"` | Labels lisibles : `container`, `service` (compose_service), `compose_project`, `image` |
| `loki.write "default"` | Point de sortie `http://loki:3100/loki/api/v1/push` + `external_labels { environment, server }` |
| `loki.source.docker "docker_logs"` | Logs des conteneurs Docker |
| `loki.source.file "system_logs"` | `/var/log/syslog` + `/var/log/auth.log` |
| `loki.source.file "traefik_access"` + `loki.process "traefik"` | Access logs JSON Traefik → stage.json (status, method, duration_ms, router, source, proto) |

**Compose** :

```yaml
alloy:
  expose: ["12345"]
  mem_limit: 512m
  volumes:
    - ./config.alloy:/etc/alloy/config.alloy:ro
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - /var/log:/var/log:ro
    - /opt/traefik/logs:/logs/traefik:ro
  command:
    - run
    - --server.http.listen-addr=0.0.0.0:12345
    - --storage.path=/var/lib/alloy/data
    - --stability.level=generally-available
    - /etc/alloy/config.alloy
```

**Pourquoi le volume `/opt/traefik/logs:/logs/traefik:ro` (et pas `/var/log/
traefik`) ?** `runc` ne peut pas créer un point de montage `/var/log/traefik`
à travers un bind `ro` sur `/var/log` (EROFS). D'où le bind séparé du dossier
Traefik.

### 5.6.9 `roles/grafana` — console, dashboards, alerting

**Tâches** : répertoires, templates datasources/dashboards/contact-points/
policies/rules, copie des dashboards JSON, compose, healthcheck.

**Compose** :

```yaml
grafana:
  user: "472:472"
  mem_limit: 384m
  networks: [proxy, monitoring]
  expose: ["3000"]
  environment:
    GF_PATHS_PROVISIONING: /etc/grafana/provisioning
    GF_SERVER_ROOT_URL: "https://{{ grafana_host }}/"
    GF_SERVER_DOMAIN: "{{ grafana_host }}"
    GF_SERVER_HTTP_PORT: "3000"
    GF_SECURITY_ADMIN_USER: "{{ grafana_admin_user }}"
    GF_SECURITY_ADMIN_PASSWORD: "{{ grafana_admin_password }}"
    GF_SECURITY_DISABLE_GRAVATAR: "true"
    GF_USERS_ALLOW_SIGN_UP: "false"
    GF_ALERTING_ENABLED: "true"
    GF_UNIFIED_ALERTING_ENABLED: "true"
    GF_ANALYTICS_REPORTING_ENABLED: "false"
    GF_SNAPSHOTS_EXTERNAL_ENABLED: "false"
    GF_LOG_MODE: console
    # + bloc SMTP si alerting.email.enabled
  volumes:
    - ./provisioning:/etc/grafana/provisioning:ro
    - ./data:/var/lib/grafana
    - ./dashboards:/var/lib/grafana/dashboards:ro
```

- Provisioning en lecture seule ; données et dashboards exposés en volumes.
- Seconde adresse `monitoring` : Prometheus scrape `grafana:3000/metrics`.
- SMTP : `GF_SMTP_*` avec politique STARTTLS dérivée de
  `alerting.email.smtp_starttls` (`Required` / `Opportunistic`).

**Datasources (`datasources.yml.j2`)** : `Prometheus` (uid `prometheus`) +
`Loki` (uid `loki`), `access: proxy`, URLs internes.

**Dashboards (`dashboards.yml.j2`)** : provider `Monitoring` → path
`/var/lib/grafana/dashboards` ; `disableDeletion`, `allowUiUpdates=false`,
`updateIntervalSeconds=30`.

**Alerting — trois fichiers provisionnés** :
- **`contact-points.yml.j2`** : contact point `all-channels` avec receivers
  e-mail (toujours), Telegram/Slack/Discord selon `alerting.*.enabled`.
- **`policies.yml.j2`** : politique racine vers `all-channels`
  (`group_by: alertname`, `group_wait: 30s`, `group_interval: 5m`,
  `repeat_interval: 4h`) + route dédiée `severity="critical"`
  (`group_interval: 2m`, `repeat_interval: 2h`).
- **`rules.yml.j2`** : macro `alert_rule()` + groupes « disponibilité » et
  `ressources` (16 règles, cf. 10.4).

**Dashboards JSON (5)** : `overview`, `infrastructure`, `docker`, `traefik`,
`logs` (voir 10.5).

### 5.6.10 `roles/sonarqube` — qualité du code (prod)

**Garde-fou** : `fail` immédiat si le rôle est exécuté alors que
`enable_sonarqube=false`.

**Compose** :

```yaml
sonar-db:
  image: postgres:16-alpine
  networks: [sonar-net]
  environment: { POSTGRES_USER: sonar, POSTGRES_PASSWORD, POSTGRES_DB: sonarqube }
  volumes: [./db-data:/var/lib/postgresql/data]
  healthcheck: pg_isready

sonarqube:
  image: sonarqube:lts-community
  depends_on: { sonar-db: { condition: service_healthy } }
  networks: [proxy, sonar-net]
  expose: ["9000"]
  mem_limit: 2g
  cpus: 1.5
  environment:
    SONAR_JDBC_URL: jdbc:postgresql://sonar-db:5432/sonarqube
    SONAR_JDBC_USERNAME: sonar
    SONAR_JDBC_PASSWORD
    SONAR_SEARCH_JAVAOPTS: "-Xms512m -Xmx512m"
    SONAR_WEB_JAVAOPTS: "-Xmx768m -Xms256m"
    SONAR_CE_JAVAOPTS: "-Xmx768m -Xms256m"
  volumes: [./data, ./logs, ./extensions]
  labels: route Traefik sonar_host
```

- **Mémoires volontairement serrées** (instance 4 Go) — à ajuster à la RAM
  réelle du serveur.
- Changement du mot de passe admin via l'API (`/api/users/change_password`) une
  fois (défaut `admin` → nouveau mot de passe du vault).

### 5.6.11 `roles/app_deploy` — hôte CI/CD (historique, mécanisme legacy)

> La VM de référence a migré le déploiement applicatif vers des **runners
> self-hosted** (chapitre 11). Le rôle `app_deploy` prépare la machine et
> reste le socle : `/opt/apps`, réseau `back`, `deploy.sh`, `start-apps`
> restent utilisés. Seule la **clé SSH restreinte + wrapper** est devenue
> inutilisée (clé retirée, archivée).

Ce rôle (playbook `app-deploy.yml` uniquement) :

1. `/opt/apps` (racine des apps, owner `app_deploy_user`, groupe, mode 0755).
2. `/opt/deploy/.ssh` (mode 0700).
3. Clé ed25519 CI/CD `deploy_key` (**créée si absente**, via `ssh-keygen`).
4. Clé restreinte ajoutée dans `authorized_keys` de `app_deploy_user` :
   ```
   command="<dir>/deploy-wrapper.sh",no-pty,no-agent-forwarding,
   no-port-forwarding,no-X11-forwarding,no-user-rc <pub>
   ```
5. Wrapper + scripts (`deploy-wrapper.sh`, `deploy.sh`, `start-apps.sh`) +
   service `start-apps` (boot).
6. Réseau Docker `back` (garanti, `ignore_errors` — le réseau peut exister
   déjà d'un projet antérieur).
7. `docker login` Docker Hub **si `docker_hub_user`/`docker_hub_token`** dans
   le vault (limite les rate-limits de pull).

**`deploy-wrapper.sh.j2`** — enveloppe restreinte de la clé :
- N'autorise que : `deploy.sh <app> [tag]` et `put <app> <fichier>`.
- Valide le nom d'app (`[a-zA-Z0-9_-]+`) et le type de fichier
  (`docker-compose.yml|docker-compose.yaml|*.env|migrate.sh|.env.example`).
- Journalise tout (`logger -t deploy-wrapper`), rejette le reste.

**`deploy.sh.j2`** — déploiement générique aka « deploy.sh » (voir 11.4 pour
l'usage CI/CD) : pull, up, santé, migrations. **`start-apps.service.j2`** :
oneshot systemd `After=docker.service` → `/opt/deploy/start-apps.sh`.
**`start-apps.sh.j2`** : `docker compose up -d` pour chaque `/opt/apps/*/`
au boot (log `/var/log/start-apps.log`).

> ⚠️ **Sécurité** : la clé privée `deploy_key` ne doit **jamais** quitter
> l'hôte autrement que par un canal sûr (secret GitHub). Sur la VM de
> référence, elle est archivée dans `/opt/deploy/.ssh-archive/` (fonctionne
> plus).

### 5.6.12 `roles/trivy` — scan de vulnérabilités des images de conteneurs

> Rôle dédié au **runtime security** : scanner chaque nuit les images des
> conteneurs **en cours d'exécution** sur le serveur. Aucun conteneur
> persistent : un conteneur `aquasec/trivy` **éphémère** par image à scanner.

**Comportement (reproductible)** :
- Répertoires `/opt/trivy/{cache,reports}`.
- Script hôte `/opt/trivy/scan-containers.sh` (mode `0750`, owner root).
- **Timer systemd** `trivy-scan.timer` (défaut `*-*-* 03:05:00`,
  `Persistent=true` pour rattraper un scan raté pendant une coupure) +
  unité `trivy-scan.service` (`Type=oneshot`, `After=docker.service`).

**Déroulé du script** :
1. la **base de vulnérabilités** est mise à jour **automatiquement** par Trivy
   au moment du scan (cache partagé `/opt/trivy/cache:/cache`, téléchargement
   incrémental), une fois par jour au plus ;
2. énumère les images des conteneurs actifs (`docker ps --format
   '{{.Image}}' | sort -u`) ;
3. pour **chaque image** : `docker run --rm` de l'image trivy, `docker.sock`
   monté **en lecture seule**, `trivy image --severity HIGH,CRITICAL
   [--ignore-unfixed] --format json <image>` ;
4. parse le JSON (python3 de l'hôte) et appende **une ligne JSONL** dans
   `/opt/trivy/reports/trivy.jsonl` :
   `{"ts","container","image","critical","high"}` ;
5. le `stdout`/`journal` du service donne aussi une visibilité syslog
   (`Scan terminé (N image(s))`).

**Intégration monitoring** (voir 10.8) :
- Alloy relit `trivy.jsonl` (label `source="trivy"`) → Loki ;
- dashboard `trivy.json` (CRITICAL/HIGH par image, filtre des scans à risque) ;
- règle d'alerte `alert-trivy-critical` (groupe `securite`, source Lokis,
  contact point `all-channels`).

**Variables** (`group_vars/all.yml` + `defaults`) : `trivy_image`
(épinglée, défaut `aquasec/trivy:0.57.1`), `trivy_schedule`
(`*-*-* 03:05:00`), `trivy_severities` (`HIGH,CRITICAL`),
`trivy_ignore_unfixed` (`true`), `trivy_{base_dir,cache_dir,report_dir}`.

> ⚠️ **Limites assumées** : scan au **niveau image** (pas de configuration
> hôte) ; nécessite une **sortie réseau** vers les registres Trivy (base de
> vulnérabilités) au moment du `db update` ; premier run plus long
> (téléchargement initial de la base). `trivy_ignore_unfixed: true` évite
> d'alerter sur des CVE sans correctif disponible.

---

## 5.7 Scripts utilitaires

### `scripts/gen-bcrypt-hash.sh`

Génère un **hash bcrypt** pour les middlewares `basicAuth` de Traefik
(Prometheus / dashboard Traefik) :

```bash
# poste admin
scripts/gen-bcrypt-hash.sh "mon-mot-de-passe" [rounds]
```

- Utilise `python3+bcrypt` **ou** `htpasswd -nbB -C <rounds> user <pwd>`
  (apache2-utils).
- Écrase le résultat (hash) → à recoller sous
  `prometheus_basic_auth_hash` / `traefik_dashboard_basic_auth_hash` dans le
  vault.
- **Pourquoi précalculé ?** éviter la dépendance passlib/bcrypt au moment de
  la convergence Ansible — le fichier reste idempotent (hash identique à
  chaque run si le mot de passe ne change pas).

---

## 5.8 Composants applicatifs (hors dépôt, intégrés à l'infra de référence)

> Ces fichiers vivent dans les dépôts `todo_back` et `todo_front`, mais font
> partie intégrante du fonctionnement de l'infrastructure : ils sont déposés
> sur le serveur par le pipeline CI/CD. Ils sont documentés en détail au
> chapitre 11 ; aperçu ici.

### 5.8.1 `todo_back/.github/workflows/ci.yml` et `todo_front/.github/workflows/ci.yml`

Pipeline CI/CD (un fichier unique par repo) :

| Job | Runner | Condition | Action |
|---|---|---|---|
| `test` | `ubuntu-latest` | toujours | back : postgres service + ruff + pytest ; front : `npm ci` + eslint + next build |
| `build` | `ubuntu-latest` | `needs: test` | buildx ; sur PR → `push:false` (validation) ; sur master → login Docker Hub + build/push `develop`+`sha-<sha>` |
| `deploy` | **[self-hosted, linux, x64]** | `needs: build` + `refs/heads/master` | génère `.env` depuis les GitHub secrets, copie `.env`+`docker-compose.yml` dans `/opt/apps/<app>/`, puis `/opt/deploy/deploy.sh <app> sha-<sha>` |

- `concurrency: <repo>_deploy` : un seul déploiement à la fois par repo.
- Le `.env` du back est **entièrement reconstruit** depuis les GitHub secrets
  (locking des secrets hors du dépôt).

### 5.8.2 `todo_back/deploy/docker-compose.yml`

- `api`: image `mamadou173diouf/todo_back:${IMAGE_TAG:-develop}`, réseaux
  `proxy`+`back`, `env_file: .env`, `environment: ROOT_PATH: /api`, expose
  8000, labels Traefik (`Host(${APP_HOST}) && PathPrefix(/api)` +
  `stripprefix /api` + `todo-api-strip`).
- `postgres`: image `postgres:16-alpine`, réseau `back`, env
  `${POSTGRES_USER/PASSWORD/DB}` (dérivés du `.env`), volume
  `postgres_data`, healthcheck `pg_isready`.
- **Racine de nommage** : `container_name` fixes (`todo_back`,
  `todo_back_postgres`) — exploités par le dashboard et les alertes.

### 5.8.3 `todo_front/deploy/docker-compose.yml`

- `web`: image `mamadou173diouf/todo_front:${IMAGE_TAG:-develop}`, réseau
  `proxy`, expose 3000, labels Traefik
  (`Host(${APP_HOST}) && !PathPrefix(/api)`).
- `NEXT_PUBLIC_API_URL=/api` est **embarqué au build** (ARG Dockerfile) → le
  front converse avec l'API par Traefik (chemin `/api`).

### 5.8.4 `todo_back/entrypoint.sh`

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

- **`ROOT_PATH=/api`** (posé par le compose) + `--proxy-headers` → FastAPI
  génère les URLs Swagger/ReDoc avec le préfixe `/api` (sinon
  `/openapi.json` 404 sur le wire, cf. 15.4).
- Les **migrations Alembic** doivent être **idempotentes** (réexécutées à
  chaque départ de conteneur).

---

---


