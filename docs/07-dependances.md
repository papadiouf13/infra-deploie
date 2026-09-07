# 7. Dépendances et versions

## 7.1 Outils (poste admin / machine de contrôle)

| Outil | Version imposée | Où | Ref |
|---|---|---|---|
| Terraform | ≥ 1.9.0 (avd. lock incluse) | `versions.tf` | 5.1.1 |
| Provider AWS | ~> 5.0 (lock `terraform/.terraform.lock.hcl`) | `versions.tf` | 5.1.1 |
| Ansible | core ≥ 2.15 + collections `community.docker ≥ 3.4.0`, `community.general ≥ 8.0.0` | `requirements.yml` | 5.4.2 |
| Python | 3.x (interpréteur cible `/usr/bin/python3`) | ansible.cfg | 5.4.1 |

- Le **fichier de lock Terraform** (`terraform/.terraform.lock.hcl`) est
  commité et garantit la reproduction exacte des providers.
- Collections Ansible : `ansible-galaxy collection install -r ansible/requirements.yml`.

## 7.2 Versions épinglées des images du monitoring (all.yml)

| Image | Version | Usée par |
|---|---|---|
| traefik | `v3.7.13` | 5.6.3 |
| prom/node-exporter | `v1.8.2` | 5.6.4 |
| ghcr.io/google/cadvisor | `v0.60.5` | 5.6.5 |
| prom/prometheus | `v2.54.1` | 5.6.6 |
| grafana/loki | `3.2.2` | 5.6.7 |
| grafana/alloy | `v1.3.1` | 5.6.8 |
| grafana/grafana | `11.2.2` | 5.6.9 |
| aquasec/trivy | `0.57.1` | 5.6.12 |
| traefik/whoami | `v1.10.1` | 5.6.3 |
| sonarqube | `lts-community` | 5.6.10 |
| postgres (sonar) | `16-alpine` | 5.6.10 |

- ⚠️ Les hashes de versions sont **épinglés par tag immutable/digest** — ne
  jamais utiliser `latest`. Planifier une montée de version **contrôlée**
  (voir 13 « politique de mise à jour ») avec test en dev d'abord.

## 7.3 Versions des services applicatifs (VM de référence)

| Composant | Version/image | Granularité |
|---|---|---|
| Docker CE | paquet stable (docker-ce/cli/containerd/bin) | APT |
| UFW, fail2ban, unattended-upgrades | paquets Ubuntu | APT |
| Ubuntu | 22.04 LTS (AMI Canonical) | data source AMI |
| back API | image `mamadou173diouf/todo_back` tag `sha-<sha>` | GitHub Actions |
| front | image `mamadou173diouf/todo_front` tag `sha-<sha>` | GitHub Actions |
| postgres (app) | `postgres:16-alpine` | compose app |

## 7.4 📌 Recommandations
- Tooling, **Dockerfile** des apps : suivre les motifs du chapitre 11 ;
  épinglage par digest dans les rôles (`@sha256:...`).
- Mettre en place un **gardien de dépendances** (renovate/dependabot) sur le
  dépôt infra + les repos apps.

---


