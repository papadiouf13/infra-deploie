# infra-deploie — Pile de monitoring DevOps auto-déployable (Terraform + Ansible)

Dépôt Infrastructure-as-Code **neuf et autonome** déployant une pile de
monitoring complète sur **2 environnements (dev / prod)**, utilisable de deux
façons :

- **AWS** : `Terraform` provisionne l'instance + réseau/security group, puis
  génère l'inventaire Ansible.
- **VPS (Contabo, Hetzner, OVH…)** : on remplit l'inventaire Ansible à la
  main, le code de déploiement est **identique**.

Entrée principale : **`make deploy ENV=dev|prod`**.

```
                     ┌─────────────────────────────────────────────┐
  Internet ──(80/443)──►│  Traefik (reverse-proxy TLS)             │
  user / alerte        │   ├─ Grafana    : grafana.<IP>.nip.io      │
                     │   ├─ Prometheus : prometheus.<IP>.nip.io   │
                     │   ├─ Traefik UI : traefik.<IP>.nip.io      │
                     │   ├─ Whoami     : whoami.<IP>.nip.io       │
                     │   └─ SonarQube  : sonar.<IP>.nip.io (prod) │
                     └──────────────┬──────────────────────────────┘
                                    │ réseaux Docker internes
                   ┌────────────────┴───────────────────────────────┐
                   │  Prometheus ◄── node-exporter / cadvisor /     │
                   │                 daemon-docker (9323) / Traefik  │
                   │  Loki      ◄── Grafana Alloy (logs Docker,      │
                   │                 syslog, access logs Traefik)    │
                   │  Grafana   ──► contact points e-mail/Telegram/  │
                   │                 Slack (+ Discord désactivé)     │
                   │  SonarQube ──► PostgreSQL 16                     │
                   └─────────────────────────────────────────────────┘
```

## Contenu

| Brique | Rôle | Notes |
|---|---|---|
| Traefik | Reverse-proxy TLS | Publié sur **80/443 uniquement** ; Let's Encrypt HTTP-01 ; staging en dev ; `whoami` exemple de route |
| Prometheus | Métriques | Scrape statique + `docker_sd` (label `prometheus.scrape=true`) ; console derrière basic-auth + IP allowlist |
| Loki + Alloy | Journaux centralisés | Conteneurs + syslog + access logs Traefik (JSON parsé) |
| Grafana | Console + Alerting | Datasources/composantes provisionnés ; 5 dashboards ; règles de gravité |
| cAdvisor / Node Exporter / daemon Docker | Métriques conteneurs/hôte | Réseau interne uniquement |
| SonarQube + PostgreSQL | Qualité du code | **prod par défaut** (dev désactivé pour RAM) |
| common (UFW, fail2ban, upgrades auto, DuckDNS) | Durcissement | 22/80/443 + 9323 (réseaux Docker) ouverts |

## Prérequis (contrôleur de déploiement)

- `terraform` ≥ 1.5
- `ansible` + collections : `community.docker`, `community.general`
  (`ansible-galaxy install -r ansible/requirements.yml`)
- `docker`
- clé SSH privée pour l'instance (fichier `.pem`)

## Démarrage rapide

```bash
# 0) Secrets (voir ansible/group_vars/vault.yml.example)
cp ansible/group_vars/vault.yml.example ansible/group_vars/vault.yml
ansible-vault encrypt ansible/group_vars/vault.yml

# 1) Vérifier les prérequis
make preflight ENV=dev

# 2) Créer l'infrastructure AWS + générer l'inventaire + déployer
make deploy ENV=dev          # = apply + inventory + configure

# 3) Contrôles post-déploiement
make verify ENV=dev

# 4) Consulter
make urls ENV=dev
```
`make deploy` vous demandera le pass-vault (`--ask-vault-pass`). Pour une passe
non interactive : `make deploy ENV=prod VAULT_ARGS="--vault-password-file .vault-pass"`.

### Mode VPS (sans AWS)

```bash
# 1) Remplir à la main (variables : public_ip, private_ip, server_name)
cp ansible/inventories/dev/hosts.ini.example ansible/inventories/dev/hosts.ini
# 2) Déployer (identique au mode AWS)
make configure ENV=dev
make verify    ENV=dev
```

## Commandes du Makefile

| Cible | Description |
|---|---|
| `preflight` | Vérifie terraform / ansible / docker / curl |
| `plan` | `terraform plan` (workspace + tfvars de l'environnement) |
| `apply` | `terraform apply` |
| `inventory` | Écrit `ansible/inventories/<env>/hosts.ini` depuis terraform |
| `configure` | `ansible-playbook playbooks/site.yml` |
| `deploy` | `apply` + `inventory` + `configure` |
| `verify` | `ansible-playbook playbooks/verify.yml` (santé + exposition réseau) |
| `destroy` | `terraform destroy` (confirmation) |
| `ssh` / `urls` | Connexion / affichage des URLs de l'environnement |

## Sécurité

- **Aucun port applicatif exposé** : seule Traefik publie 80/443.
  Prometheus/Grafana/Traefik-UI sont authentifiés (basic-auth bcrypt).
- Seule l'IP allowlist `admin_cidr` peut ouvrir les consoles ; restreindre
  impérativement (`0.0.0.0/0` par défaut, à bloquer en prod).
- Secrets dans un vault Ansible chiffré (`ansible-vault`) ; `*.tfvars` jamais commités.
- UFW (22/80/443 + métriques Docker depuis les réseaux internes) + fail2ban
  + unattended-upgrades activés par défaut.

## Rétention & alerting (configurables)

- Métriques : 7 j (dev) / 30 j (prod) — `monitoring_retention_days`.
- Logs : 3 j (dev) / 14 j (prod) — `loki_retention_hours`.
- Seuils d'alertes (CPU, RAM, disque, charge, 5xx, latence) : block `alerts:` de
  `ansible/group_vars/all.yml`.

## DNS : nip.io et DuckDNS

- **Par défaut** : hostnames `*.x.y.z.w.nip.io` résolus par votre navigateur
  sans aucune config DNS.
- **Optionnel DuckDNS** (pas de wildcard) : renseigner `duckdns_token` et
  `duckdns_domains` dans le vault ; un cron met à jour l'IP des sous-domaines.

## FAQ / limites

- **bcrypt** : les middlewares basic-auth de Traefik utilisent des **hash
  précalculés** (`scripts/gen-bcrypt-hash.sh`) stockés dans le vault — pas de
  dépendance passlib côté contrôleur à l'exécution.
- **Let's Encrypt nip.io** : fonctionne nativement avec HTTP-01 ; en dev on
  reste en `acme_is_staging=true` pour éviter les rate-limits.
- **SonarQube** : gourmand en RAM (≈2 Go + PostgreSQL). Désactivé en dev.