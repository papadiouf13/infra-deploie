# 11. Applications déployées : todo_back / todo_front et CI/CD

## 11.1 Architecture du déploiement (VM de référence)

```
GitHub (todo_back / todo_front)
  ├─ ci.yml (job test)           ├─ ci.yml (job build → Hub)
  └─ ci.yml (job deploy; self-hosted runner) → copie .env+compose → deploy.sh
 VM 192.168.1.15
 /opt/apps/todo_back/{.env,docker-compose.yml}
 /opt/apps/todo_front/{.env,docker-compose.yml}
 /opt/deploy/{deploy.sh, deploy-wrapper.sh, start-apps.sh}
 Runners systemd : actions.runner.* (user gh-runner: docker+deployers)
```

- Images : `mamadou173diouf/todo_back:sha-<sha>`, `mamadou173diouf/todo_front:sha-<sha>`.
- Le front est **buildé avec `NEXT_PUBLIC_API_URL=/api`** (chemin relatif via
  Traefik) → aucune URL DNS en dur dans le front.

## 11.2 Workflow `ci.yml` (par repo) — détail

```yaml
name: CI/CD
on:
  push:
    branches: [ master ]
  pull_request:
concurrency: <repo>_deploy   # un seul déploiement à la fois

jobs:
  test:
    runs-on: ubuntu-latest
    steps: checkout / setup / (back: postgres service + ruff + pytest de l'API)
           (front: npm ci + eslint + next build)
  build:
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    steps: docker/setup-buildx-action
           logout → login Docker Hub (DOCKER_USER/DOCKER_TOKEN)
           build+publish : tags develop, sha-<sha> ; push : false sur PR
  deploy:
    if: needs.build.result == 'success' && github.ref == 'refs/heads/master'
    runs-on: [self-hosted, linux, x64]
    steps:
      - checkout
      - génération du .env (depuis les secrets GitHub, cf 11.3)
      - scp-like : copie du .env et du docker-compose.yml dans /opt/apps/<app>/
      - /opt/deploy/deploy.sh <app> sha-<sha>
```

> Le `.env` du back est **reconstruction** complète à chaque run à partir des
> GitHub secrets (pas de fichier commité). Les `POSTGRES_*` y sont dérivés.

## 11.3 Secrets GitHub utilisés

| Secret | Utilisé par | Origine / dst |
|---|---|---|
| `DOCKER_USER` / `DOCKER_TOKEN` | build (login Hub) | Docker Hub token |
| `POSTGRES_USER` / `POSTGRES_PASSWORD` / `POSTGRES_DB` | .env du back | base de l'app |
| `SECRET_KEY` (back) | .env du back | **⚠️ placeholder à corseter** cf. S6 |
| `CORS_ORIGINS` | .env du back | origine du front |
| `CLOUDINARY_CLOUD` / `CLOUDINARY_API_KEY` / `CLOUDINARY_API_SECRET` | .env du back | **⚠️ clé API exposée** cf. S6 |

## 11.4 `deploy.sh` (sur la VM) — contenu

```bash
#!/usr/bin/env bash
set -euo pipefail

APP="$1"; shift; TAG="${1:-sha-master}"
CDIR="/opt/apps/${APP}"
[ -f "${CDIR}/docker-compose.yml" ] || exit 1
[ -f "${CDIR}/.env" ] || exit 1
cd "${CDIR}" || exit 1
IMAGE_TAG="${TAG}" docker compose up -d --pull always   # pull + up
docker compose ps --format 'table{{.Name}}\t{{.Status}}'
sleep 3
# migrations échouent-elles ? (voir 11.5) → d'abord contrôler le conteneur
```

Comportement observé (VM) :
- Utilisé par les runners avec `IMAGE_TAG=sha-<sha>`.
- Logge les erreurs ; le pipeline échoue si la commande retourne ≠ 0,
  → un mauvais déploiement **reste dans `/opt/apps`** mais s'affiche `down`
  (docker compose up avec una tas image = exit) → dégagé vite par un "up"
  --pull relancé à la main.

## 11.5 Migrations & healthcheck côté app

- `entrypoint.sh` (todo_back) : `alembic upgrade head` **avant** uvicorn
  (5.8.4). Si un déploiement rate son démarrage (migration binaire cassée),
  voir 15.6 (rollback image précédente : `IMAGE_TAG=sha-<précédent>`).

## 11.6 Runners self-hosted (VM) — état réel

| Runner | Repo | Service systemd |
|---|---|---|
| `vm-todo-back` | todo_back | `actions.runner.papadiouf13-todo_back.vm-todo-back.service` |
| `vm-todo-front` | todo_front | `actions.runner.papadiouf13-todo_front.vm-todo-front.service` |
| `vpstest-api` / `vpstest-front` | (app-learning-hub) | `actions.runner.*` |

- Installés **manuellement** (pas via Ansible — cf. S4 / 8.5).
- Compte `gh-runner` dans les groupes `docker` et `deployers` ; ignore la VM
  de `pwd` (repose sur les répertoires).

## 11.7 📌 Recommandations (apps / CI)
- Passer `APP_HOST` en variable GitHub (S7) : le workflow doit lire
  `vars.APP_HOST` au lieu d'un hostname en dur (fallback `todo.192.168.1.15.nip.io`).
- Rendre les runners **reproduisibles** (rôle `github_runner`, token → secrets repo).
- Purger l'inutile : `SSH_PRIVATE_KEY` (repo secrets), `/opt/deploy/.ssh-archive`,
  anciens tags `develop` obsolètes.
- **Priver les images** (S8).

---


