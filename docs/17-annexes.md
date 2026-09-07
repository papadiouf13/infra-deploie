# 17. Annexes

## 17.1 Rappel de commandes utiles (poste admin)

```bash
# Terraform (dans terraform/)
terraform workspace list && terraform plan  # préview
terraform apply -var-file=dev.tfvars

# Ansible (à la racine)
make preflight configure verify ENV=dev
ansible-playbook -i ansible/inventories/dev/hosts.ini ansible/playbooks/site.yml --ask-vault-pass

# Vault
ansible-vault edit ansible/group_vars/vault.yml

# Hashs bcrypt (middlewares Traefik)
scripts/gen-bcrypt-hash.sh "<pwd>"   # out → vault

# Test Alert (récepteur) via Grafana API
curl -u admin:$GF_ADMIN \
  -H 'Content-Type: application/json' -X POST \
  "https://grafana.<ip>.nip.io/api/alertmanager/grafana/config/api/v1/receivers/test" ...
```

## 17.2 Rappel des chemins à connaître sur la VM

| Chemin | Contenu |
|---|---|
| `/opt/traefik` | traefik.yml, dynamic.yml, acme.json, logs/, docker-compose.yml |
| `/opt/prometheus` | prometheus.yml, data/ |
| `/opt/loki` | config + data/ |
| `/opt/alloy` | config.alloy + data |
| `/opt/grafana` | provisioning/, dashboards/, data/ |
| `/opt/apps/*` | apps + `.env` + compose |
| `/opt/deploy` | deploy.sh, deploy-wrapper.sh, start-apps.sh, .ssh |
| `/opt/trivy` | scan-containers.sh, cache (base de vulnérabilités), reports/trivy.jsonl |
| `/opt/sonarqube` | compose, data, logs, extensions, db-data |

## 17.3 Récap environnement et ports

| Service | Port in-VM | Publié hôte ? | Accessible via |
|---|---|---|---|
| Traefik (web+websecure) | 80/443 | oui | internet |
| Dashboard Traefik | 8080 | non | traefik.<ip>.nip.io (basic-auth) |
| Metrics Traefik | 8082 | non | interne (prometheus) |
| Grafana | 3000 | non | grafana.<ip>.nip.io |
| Prometheus | 9090 | non | prometheus.<ip>.nip.io (basic-auth) |
| Loki | 3100 | non | interne logging |
| Alloy | 12345 | non | interne (metrics) |
| node-exporter | 9100 | non | interne |
| cadvisor | 8080 | non | interne |
| docker-metrics | 9323 | non | UFW→subnets |
| app api | 8000 | non | todo.<ip>.nip.io/api |
| app front | 3000 | non | todo.<ip>.nip.io |

## 17.4 Environnement de référence (VM actuelle)

| Param | Valeur |
|---|---|
| IP publique / host | `192.168.1.15` (LAN) ; hostnames `*.192.168.1.15.nip.io` |
| OS | Ubuntu 22.04 |
| Mode | VPS/LAN (géré à la main) — pas de Terraform pour cette VM |
| Utilisateur | `papa` (SSH, sudo), `gh-runner` (runner CI), `app_deploy_user` |
| Runner | `vm-todo-back`, `vm-todo-front` (+ 2 « vpstest ») |
| Apps | todo_back (FastAPI+Postgres), todo_front (Next.js) |

> Document livré pour être **exécutable** : toute valeur « flexible » doit être
> repérée et personnalisée (IP, admin_cidr, emails, secrets) avant utilisation
> sur des machines différentes. La référence « kif kif » = le contenu réel de
> la VM + ce qui est déclaré ici qui manque (runners, .env, backups…).

---
*Fin du manuel.*

