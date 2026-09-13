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

## 11.6 Runners self-hosted — installation automatisée

Le serveur n'est pas joignable depuis Internet (NAT, pas de port-forward) :
c'est donc lui qui va chercher les jobs chez GitHub, via un **runner
self-hosted par dépôt**. Ces runners étaient installés à la main ; ils sont
désormais posés par le rôle Ansible `github_runner` :

```bash
make app-runner ENV=dev REPO=papadiouf13/todo_back TOKEN=A2XXXXXXXXXXXX \
     VAULT_ARGS='--vault-password-file ../.vault-pass'
```

Le `TOKEN` s'obtient sur GitHub — dépôt > Settings > Actions > Runners >
**New self-hosted runner** : c'est la valeur passée à `./config.sh --token`.
Il expire au bout d'une heure et ne sert qu'au **premier** enregistrement ;
rejouer la commande sans `TOKEN` ne fait rien si le runner existe déjà.

Ce que le rôle met en place :

| Élément | Détail |
|---|---|
| Compte | `gh-runner` (système), membre de `docker` et `deployers` |
| Groupe partagé | `deployers`, qui contient aussi `app_deploy_user` |
| Droits | `/opt/apps` et `/opt/deploy` en `2775` groupe `deployers` (setgid : ce que le runner crée reste modifiable par le compte de déploiement) |
| Emplacement | `/opt/actions-runner/<serveur>-<depot>/` |
| Nom du runner | `<serveur>-<depot>`, ex. `tioukh-todo-back` (surchargeable par `NAME=`) |
| Service | `actions.runner.<owner>-<depot>.<nom>.service`, activé au boot |

Le job `deploy` du workflow cible ces runners par `runs-on: [self-hosted,
linux, x64]` — labels posés automatiquement par GitHub.

> ⚠️ **Migration de serveur.** Un runner est enregistré sur le *dépôt*,
> pas sur la machine. Si tu installes les runners d'un nouveau serveur
> sans retirer les anciens, le dépôt en aura deux et GitHub enverra le
> job de déploiement au premier disponible — un push peut alors déployer
> sur l'ancienne machine sans erreur visible. Retire l'ancien runner
> (dépôt > Settings > Actions > Runners > Remove), ou cible le bon par
> son label serveur : `runs-on: [self-hosted, linux, x64, <serveur>]`.
> Chaque runner porte le nom de son serveur comme label.

Vérification :

```bash
systemctl list-units 'actions.runner.*' --no-pager --all
```

## 11.7 📌 Recommandations (apps / CI)
- Passer `APP_HOST` en variable GitHub (S7) : le workflow doit lire
  `vars.APP_HOST` au lieu d'un hostname en dur (fallback `todo.192.168.1.15.nip.io`).
- ~~Rendre les runners reproduisibles~~ — fait : rôle `github_runner` + `make app-runner` (11.6).
- Purger l'inutile : `SSH_PRIVATE_KEY` (repo secrets), `/opt/deploy/.ssh-archive`,
  anciens tags `develop` obsolètes.
- **Priver les images** (S8).

---


