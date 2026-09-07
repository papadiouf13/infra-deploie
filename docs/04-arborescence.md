# 4. Arborescence du projet

> Arbre complet des fichiers du dépôt `infra-deploie` (les fichiers générés /
> secrets ne sont pas représentés : `*.tfvars`, `hosts.ini` réels, `vault.yml`,
> `*.pem`, `*.key`, `.terraform/`).

```
infra-deploie/
├── .gitignore                          # exclusions (secrets, tfvars, state, vault)
├── Makefile                            # orchestration (preflight/plan/apply/inventory/configure/deploy/verify/destroy/ssh/urls)
├── README.md                           # guide rapide du dépôt
├── ansible/
│   ├── ansible.cfg                     # config Ansible (roles_path, inventaire par défaut, pipelining)
│   ├── requirements.yml                # collections community.docker + community.general
│   ├── group_vars/
│   │   ├── all.yml                     # variables communes (réseaux, images, alertes, alerting, admin)
│   │   ├── dev.yml                     # spécificités DEV (staging ACME, rétention courte, sonar off)
│   │   ├── prod.yml                    # spécificités PROD (ACME réel, rétention longue, sonar on)
│   │   └── vault.yml.example           # gabarit des secrets chiffrés (chapitre 8)
│   ├── inventories/
│   │   ├── dev/hosts.ini.example       # gabarit inventaire DEV (IP à renseigner)
│   │   └── prod/hosts.ini.example      # gabarit inventaire PROD
│   ├── playbooks/
│   │   ├── site.yml                    # provisionnement pile monitoring (rôles commun→grafana→sonar)
│   │   ├── app-deploy.yml              # préparation hôte CI/CD (app_deploy)
│   │   └── verify.yml                  # contrôles post-déploiement (idempotent)
│   └── roles/
│       ├── common/                     # durcissement : UFW, fail2ban, unattended-upgrades, DuckDNS, timezone
│       ├── docker/                     # install Docker + daemon.json + réseaux proxy/monitoring
│       ├── traefik/                    # reverse-proxy TLS + whoami (routes/middlewares/acme)
│       ├── node_exporter/              # métriques hôte
│       ├── cadvisor/                   # métriques conteneurs
│       ├── prometheus/                 # collecte + docker_sd + rétention
│       ├── loki/                       # stockage logs
│       ├── alloy/                      # collecte logs → Loki
│       ├── grafana/                    # datasources, dashboards, alerting (templates+JSON)
│       │   └── files/dashboards/       # overview, infrastructure, docker, traefik, logs (JSON)
│       ├── sonarqube/                  # SonarQube + PostgreSQL (prod)
│       └── app_deploy/                 # CI/CD : /opt/apps, clé restreinte, deploy.sh, start-apps, réseau back
├── scripts/
│   └── gen-bcrypt-hash.sh              # génération des hash bcrypt basic-auth Traefik
└── terraform/
    ├── backend.tf                      # backend S3 + DynamoDB (état partagé, par workspace)
    ├── versions.tf                     # terraform ≥1.9, provider aws ~> 5.0
    ├── providers.tf                    # région + default_tags
    ├── variables.tf                    # catalogue des variables (env, instance, CIDR, disque…)
    ├── main.tf                         # routage des modules (network/security/ec2) + data AMI
    ├── outputs.tf                      # public_ip, private_ip, ansible_inventory, …
    ├── dev.tfvars.example              # gabarit tfvars DEV
    ├── prod.tfvars.example             # gabarit tfvars PROD
    ├── .terraform.lock.hcl             # verrouillage des versions des providers
    └── modules/
        ├── network/                    # VPC + subnet public + IGW + route table
        ├── security/                   # security group (22 admin, 80/443 ouvert)
        └── ec2/                        # instance + EIP + IAM SSM + user-data
            └── user_data.tpl           # script de boot (install Python3 minimal)
```

> Les composants **applicatifs** (hors de ce dépôt, mais intégrés à
> l'infrastructure de référence) sont détaillés au chapitre 5.8 :
>
> ```
> todo_back/
> ├── .github/workflows/ci.yml           # pipeline CI/CD du back
> ├── deploy/docker-compose.yml          # compose de prod (déposé par le CD)
> └── entrypoint.sh                      # migrations Alembic + uvicorn (ROOT_PATH)
> todo_front/
> ├── .github/workflows/ci.yml           # pipeline CI/CD du front
> └── deploy/docker-compose.yml          # compose de prod (déposé par le CD)
> ```
---


