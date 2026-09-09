# Déploiement d'une application par CI/CD — sans toucher au serveur

> **Version 1.0 — procédure générique**, applicable à toute application.
> Les exemples citent les applications existantes `todo_back` / `todo_front`
> (déployées sur la VM de référence), mais le modèle s'adapte à n'importe quel
> projet : change le nom de l'app, ses images, ses labels Traefik et ses
> secrets — le pipeline est identique.

---

## 1. Principe

L'infrastructure `infra-deploie` est installée sur le serveur avec un socle
de déploiement applicatif (`app_deploy`) : un dossier `/opt/apps`, un script
`/opt/deploy/deploy.sh`, un service de démarrage au boot et le réseau Docker
partagé `back`.

**Une fois ce socle en place, le serveur devient une boîte noire** : on n'y
touche plus pour livrer une application.

```
git push master  →  GitHub Actions  →  Docker Hub  →  runner self-hosted (VM)
                                                         ↓
                                            copie .env + docker-compose.yml
                                            dans /opt/apps/<app>/
                                                         ↓
                                            /opt/deploy/deploy.sh <app> sha-<sha>
                                                         ↓
                                            pull image + docker compose up -d
                                            + attente healthy + migrations
```

La seule exception : la configuration réseau/DNS d'une **nouvelle**
application (sous-domaine public) — voir la section 11.

---

## 2. Schéma de flux (détail)

```
Développeur (git push master)
   └─ GitHub Actions (cloud)
        ├─ job test      (ubuntu-latest)   : lint, tests, build de validation
        ├─ job build     (ubuntu-latest)   : buildx → Docker Hub (develop, sha-<sha>)
        └─ job deploy    (self-hosted)     : reconstruit .env depuis les secrets
                                             → copie .env + docker-compose.yml
                                               dans /opt/apps/<app>/
                                             → /opt/deploy/deploy.sh <app> sha-<sha>
Runner self-hosted (sur la VM, compte gh-runner)
   └─ /opt/deploy/deploy.sh
        ├─ docker compose pull    (IMAGE_TAG=sha-<sha>)
        ├─ docker compose up -d --remove-orphans
        ├─ attente statut "healthy" (délai 120 s, configurable)
        └─ exécute ./migrate.sh (optionnel) → conteneurs sains prêts
```

---

## 3. Prérequis (à vérifier UNE fois)

Le serveur doit déjà disposer de :

| Élément | Emplacement | Créé par |
|---|---|---|
| Racine des apps | `/opt/apps` (owner `app_deploy_user`, 0755) | playbook `app-deploy.yml` |
| Script de déploiement | `/opt/deploy/deploy.sh` | playbook `app-deploy.yml` |
| Wrapper restreint (clé CI/CD) | `/opt/deploy/deploy-wrapper.sh` | playbook `app-deploy.yml` |
| Démarrage au boot | `/opt/deploy/start-apps.sh` + service systemd `start-apps` | playbook `app-deploy.yml` |
| Réseau Docker partagé | réseau `back` (défini dans `ansible/group_vars/all.yml`, `docker_networks`) | playbook `app-deploy.yml` |
| Runner self-hosted | un runner systemd `actions.runner.*` **par repository** | installation manuelle (voir 4.2) |
| Utilisateur déploiement | `app_deploy_user` (ex. `papa` en dev) | inventaire/group_vars |
| Traefik (reverse-proxy TLS) | réseau `proxy`, labels automatisés | rôle `traefik` (via `site.yml`) |

> La liste exacte des réseaux et de leurs subnets est dans
> `ansible/group_vars/all.yml` (bloc `docker_networks`). Sur la VM de
> référence, leurs noms effectifs sont `br-proxy`, `br-monitoring`,
> `br-back` (à confirmer avec `docker network ls`).

Vérification rapide depuis le controleur :

```bash
ssh papa@<host> 'ls /opt/deploy /opt/apps && systemctl is-enabled start-apps && docker network ls'
```

---

## 4. Étape 0 — Une seule fois par serveur

Cette étape s'effectue **une fois** lors de la mise en place du serveur
(elle est déjà faite sur la VM de référence).

### 4.1 Socle applicatif (Ansible)

```bash
# Depuis le dépôt infra-deploie (controleur) :
cd ansible
ansible-playbook -i inventories/dev/hosts.ini playbooks/app-deploy.yml \
    --vault-password-file ../.vault-pass
```

Le playbook crée (détail dans `ansible/roles/app_deploy`) :

- `/opt/apps` et `/opt/deploy/.ssh` ;
- la clé ed25519 CI/CD `/opt/deploy/.ssh/deploy_key` (**créée si absente**) ;
- la clé **restreinte** dans `authorized_keys` de `app_deploy_user`,
  enveloppée par `deploy-wrapper.sh` :
  ```
  command="/opt/deploy/deploy-wrapper.sh",no-pty,no-agent-forwarding,
  no-port-forwarding,no-X11-forwarding,no-user-rc <clé publique>
  ```
- `deploy.sh`, `deploy-wrapper.sh`, `start-apps.sh`, le service `start-apps`
  et le réseau Docker `back`.

> La clé privée `deploy_key` ne doit **jamais** quitter l'hôte par un canal
> non sûr (elle alimente un secret GitHub si le mode « clé SSH » est utilisé).
> Sur la VM de référence, le déploiement passe désormais par des **runners
> self-hosted** (4.2) ; la clé legacy est archivée dans
> `/opt/deploy/.ssh-archive/`.

### 4.2 Runner self-hosted (par repository)

Le runner est **installé manuellement** (pas encore via Ansible) :

1. GitHub repo → Settings → Actions → Runners → **New self-hosted runner**
   (choisir linux/x64) → installer sur la VM.
2. Démarrer comme **service systemd** : `./svc.sh install && ./svc.sh start`
   (nom du service : `actions.runner.<owner>-<repo>.<name>.service`).
3. Le compte runner (`gh-runner`) doit être dans les groupes **`docker`** et
   **`deployers`** :
   ```bash
   sudo usermod -aG docker gh-runner
   sudo usermod -aG deployers gh-runner
   ```
4. Le runner doit être labellisé **`self-hosted`, `linux`, `x64`** (labels
   par défaut) : le job `deploy` y tourne.

Vérification :

```bash
systemctl list-units 'actions.runner.*' --no-pager --all
```

---

## 5. Étape 1 — Préparer le repository de l'application

Le repository doit produire une **image conteneur** poussée sur **Docker Hub**
(l'infra pull cette image au moment du déploiement).

Points obligatoires :

- Le `Dockerfile` doit exister à la racine du repo (buildx classique).
- L'image est taguée avec **`develop`** (dernier état) et **`sha-<sha>`**
  (état figé) par le job `build` du pipeline (section 7).
- Le compose d'exploitation référence l'image comme :
  ```
  image: <votre-user>/<votre-app>:${IMAGE_TAG:-develop}
  ```
  → c'est le script `deploy.sh` qui renseigne `IMAGE_TAG=sha-<sha>` au moment
  du `up`. **Sans `${IMAGE_TAG}`, le déploiement ne sait pas quelle version
  tirer.**

Sur `todo_back` / `todo_front`, les images sont
`mamadou173diouf/todo_*:sha-<sha>` (voir `docs/05-fichiers.md` §5.8).

---

## 6. Étape 2 — Écrire le `deploy/docker-compose.yml` de l'app

Le compose d'exploitation n'est **pas** committé au même endroit que le code
dans tous les repos existants : il est **déposé sur le serveur** par le job
`deploy` dans `/opt/apps/<app>/docker-compose.yml`. Gardez-le donc **dans le
repo** (dossier `deploy/`) pour que le job `deploy` puisse le copier.

### 6.1 Règles communes

- Le **nom de l'app** servira de dossier : `/opt/apps/mon-app` (caractères
  autorisés : lettres, chiffres, `-`, `_`).
- Raccrochez chaque service au réseau **`proxy`** (traefik) — et au réseau
  **`back`** pour les services privés (bases de données) :
  ```
  networks:
    proxy:
      external: true
    back:
      external: true
  ```
- Tout service web exposé publiquement déclare des **labels Traefik** :
  `traefik.enable=true`, une règle `Host(...)`, le service/port et
  éventuellement des middlewares.
- Donnez des **`container_name` fixes** pour les apps critiques (utilisés par
  le dashboard et les alertes — `todo_back`, `todo_back_postgres`).
- Si l'app a des données persistantes, déclarez des **volumes nommés**.
- Si l'app a des migrations, créez **`./migrate.sh`** (exécuté après le `up`).

### 6.2 Modèle « back+base de données » (dérivé de `todo_back`)

```yaml
# deploy/docker-compose.yml  (exemple : API + base de données)
name: mon_app

services:
  api:
    image: votreuser/mon_app:${IMAGE_TAG:-develop}
    container_name: mon_app
    env_file: .env
    environment:
      - ROOT_PATH=/api          # ex. FastAPI : génère Swagger sous /api
    expose:
      - "8000"
    networks:
      - proxy
      - back
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mon-app.rule=Host(`${APP_HOST}`) && PathPrefix(`/api`)"
      - "traefik.http.routers.mon-app.middlewares=mon-app-strip@docker"
      - "traefik.http.middlewares.mon-app-strip.stripprefix.prefixes=/api"
      - "traefik.http.services.mon-app.loadbalancer.server.port=8000"
    healthcheck:
      test: ["CMD", "curl", "-fs", "http://localhost:8000/health"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 10s

  db:
    image: postgres:16-alpine
    container_name: mon_app_db
    env_file: .env
    environment:
      - POSTGRES_USER=${POSTGRES_USER}
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
      - POSTGRES_DB=${POSTGRES_DB}
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - back
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

volumes:
  pgdata:

networks:
  proxy:
    external: true
  back:
    external: true
```

### 6.3 Modèle « front » (dérivé de `todo_front`)

```yaml
# deploy/docker-compose.yml (exemple : front statique/SSR derrière Traefik)
name: mon_front

services:
  web:
    image: votreuser/mon_front:${IMAGE_TAG:-develop}
    container_name: mon_front
    expose:
      - "3000"
    networks:
      - proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.mon-front.rule=Host(`${APP_HOST}`) && !PathPrefix(`/api`)"
      - "traefik.http.services.mon-front.loadbalancer.server.port=3000"

networks:
  proxy:
    external: true
```

> Astuce front : embarquez l'URL de l'API **au build** avec une variable ARG
> du Dockerfile (ex. `NEXT_PUBLIC_API_URL=/api`) plutôt qu'en dur. Le front
> parle ainsi à l'API par Traefik (chemin `/api`), sans URL DNS codée.

### 6.4 Les middlewares

Les middlewares partagés sont définis dans la config dynamique de Traefik
(`ansible/roles/traefik/templates/dynamic.yml.j2`) et référencés avec
`@file` :

| Middleware | Rôle |
|---|---|
| `basic-auth-prom@file` | basic-auth sur Prometheus |
| `basic-auth-traefik@file` | basic-auth sur le dashboard Traefik |
| `allowlist-admin@file` | restriction par IP source (`admin_cidr`) |
| `security-headers@file` | en-têtes de sécurité communs |

> Les middlewares **propres à une app** sont déclarés **par labels Traefik**
> dans son compose (ex. le `stripprefix` de `/api` ci-dessus, référencé avec
> `@docker`). On ne touche pas à la config dynamique pour une app.

---

## 7. Étape 3 — Écrire `.github/workflows/ci.yml`

Un fichier unique à la racine du repo, avec **trois jobs** :

| Job | Runner | Condition | Action |
|---|---|---|---|
| `test` | `ubuntu-latest` | toujours | lint + tests + build de validation |
| `build` | `ubuntu-latest` | `needs: test` | buildx ; PR → `push:false` ; master → Docker Hub |
| `deploy` | `[self-hosted, linux, x64]` | `needs: build` + `refs/heads/master` | copie `.env`+compose, `deploy.sh <app> sha-<sha>` |

Modèle complet (adapter `MON_APP`, les tests, les secrets) :

```yaml
name: CI/CD

on:
  push:
    branches: [ master ]
  pull_request:

concurrency: mon_app_deploy        # un seul déploiement à la fois

env:
  IMAGE: votreuser/mon_app

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      # Job propre à chaque projet : pytest+ruff, npm ci+eslint+next build, etc.

  build:
    if: github.event_name == 'push'
    needs: test
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: docker/setup-buildx-action@v3
      - name: Login Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USER }}
          password: ${{ secrets.DOCKER_TOKEN }}
      - name: Build & push
        uses: docker/build-push-action@v6
        with:
          context: .
          push: true
          tags: |
            ${{ env.IMAGE }}:develop
            ${{ env.IMAGE }}:sha-${{ github.sha }}

  deploy:
    needs: build
    if: github.event_name == 'push' && github.ref == 'refs/heads/master'
    runs-on: [self-hosted, linux, x64]
    steps:
      - uses: actions/checkout@v4
      - name: Générer le .env (depuis les secrets GitHub)
        run: |
          cat > deploy/.env <<EOF
          APP_HOST=${{ vars.APP_HOST }}
          POSTGRES_USER=${{ secrets.POSTGRES_USER }}
          POSTGRES_PASSWORD=${{ secrets.POSTGRES_PASSWORD }}
          POSTGRES_DB=${{ secrets.POSTGRES_DB }}
          SECRET_KEY=${{ secrets.SECRET_KEY }}
          EOF
      - name: Déployer sur le serveur
        run: |
          install -m 0644 deploy/docker-compose.yml /opt/apps/mon_app/docker-compose.yml
          install -m 0644 deploy/.env            /opt/apps/mon_app/.env
          /opt/deploy/deploy.sh mon_app sha-${{ github.sha }}
```

> Le `.env` est **entièrement reconstruit** à chaque run depuis les secrets
> GitHub (aucun `.env` committé). Les variables `POSTGRES_*` y sont dérivées.
>
> Sur la VM de référence, les workflows réels listent `APP_HOST` en dur dans
> le job (santé S7 du manuel) : **utilisez de préférence une variable
> GitHub `vars.APP_HOST`** (option économique d'instance → nouvel hôte sans
> modifier le code). Fallback conseillé : `${{ vars.APP_HOST
> || 'monapp.<domaine>.nip.io' }}`.

---

## 8. Étape 4 — Poser les secrets GitHub

Dans le repo de l'app : Settings → Secrets and variables → Actions.

| Secret/Variable | Type | Utilisé par | Origine |
|---|---|---|---|
| `DOCKER_USER` | secret | build (login Hub) | compte Docker Hub |
| `DOCKER_TOKEN` | secret | build (login Hub) | token Docker Hub |
| `APP_HOST` | variable | deploy (.env) | hostname public de l'app |
| `POSTGRES_USER` | secret | .env de l'app (base) | base de l'app |
| `POSTGRES_PASSWORD` | secret | .env de l'app (base) | base de l'app |
| `POSTGRES_DB` | secret | .env de l'app (base) | base de l'app |
| `SECRET_KEY` | secret | .env de l'app (back) | clé de signature/encryption |
| `CORS_ORIGINS` | secret | .env de l'app (back) | origines autorisées (dev : localhost + front) |
| `CLOUDINARY_*` (si utilisé) | secret | .env de l'app (back) | stockage d'images |

> Ne committez jamais un `.env` ni une clé. Le `no_log` est implicite : les
> secrets GitHub ne sont pas affichés dans les logs des steps.

---

## 9. Étape 5 — Déployer

Il suffit d'un **push sur `master`** :

```bash
git add -A && git commit -m "feat: nouvelle version" && git push origin master
```

Ce qui s'exécute derrière :

1. **test** → lint + tests (vérifier les regressions avant tout build).
2. **build** → pousse `develop` et `sha-<sha>` sur Docker Hub.
3. **deploy** (runner self-hosted sur la VM) :
   - reconstruit `.env` et le compose dans `/opt/apps/mon_app/` ;
   - appelle `/opt/deploy/deploy.sh mon_app sha-<sha>`.
4. **`deploy.sh`** (script générique déposé par Ansible) :
   - `export IMAGE_TAG=sha-<sha>` ;
   - `docker compose pull` pour chaque `docker-compose*.yml` ;
   - `docker compose up -d --remove-orphans` ;
   - attend que tous les services soient **`healthy`** (délai
     `DEPLOY_HEALTH_TIMEOUT` par défaut 120 s ; pas de healthcheck = jugé
     sain) ;
   - exécute `./migrate.sh` s'il existe ;
   - loggue le tout sous `[deploy:mon_app]`.

Surveillance du pipeline : GitHub → Actions → onglet du run. En cas
d'échec, le job le signale ; le conteneur fautif reste démarré s'il est
`up` mais pas healthy (voir section 12 pour le rollback).

Commande équivalente manuelle depuis le serveur (dépannage) :

```bash
IMAGE_TAG=sha-<sha> /opt/deploy/deploy.sh mon_app sha-<sha>
# ou, dans /opt/apps/mon_app :
cd /opt/apps/mon_app && IMAGE_TAG=sha-<sha> docker compose up -d --pull always
```

---

## 10. Étape 6 — Vérifier

Après le run vert du job `deploy` :

1. **URL publique** : `https://<APP_HOST>/` (l'app est servie par Traefik avec
   un certificat LE — cadenas vert).
2. **Sonde de l'API** : `https://<APP_HOST>/api/health` doit répondre 200.
3. **Dashboard** : jeter un œil aux métriques dans Grafana
   (dashboard `overview`/`infrastructure`).
4. **Logs** : Loki via Grafana (Explorer) — les logs des conteneurs de l'app
   y remontent automatiquement via Alloy (docker.sock).
5. **`make verify`** (depuis le contrôleur) : cible globale d'intégrité.

```bash
# Depuis le contrôleur :
make urls ENV=dev                       # liste des URL publiées
make verify ENV=dev VAULT_ARGS='--vault-password-file .vault-pass'
```

---

## 11. Nouvelle application / cas particuliers

### 11.1 Premier déploiement

Le job `deploy` crée `/opt/apps/mon_app/` **au premier run** (le `install`
dans le pipeline crée le dossier cible s'il manque). Il faut donc, en plus du
pipeline normal :

- donner la **variable `APP_HOST`** (hostname public) ;
- si vous ne déployez pas via runner mais via la **clé CI/CD restreinte**,
  le premier `put` doit créer le dossier : la commande
  `put mon_app docker-compose.yml` crée `/opt/apps/mon_app/` automatiquement
  (`mkdir -p` dans `deploy-wrapper.sh`) ;
- fichiers autorisés par le wrapper :
  `docker-compose.yml | docker-compose.yaml | *.env | migrate.sh | .env.example`.

### 11.2 DNS / routage d'une nouvelle app

Par défaut, la plateforme sert tout le monde via un wildcard
(`*.infra_domain`, ex. `*.tioukh.duckdns.org`) : **aucun DNS à créer** pour
un nouveau sous-domaine — il suffit qu'`APP_HOST` indique ce sous-domaine.

> En LAN privé, le wildcard DuckDNS résout vers l'IP publique de la box.
> Pour un accès local : ajoutez la ligne dans
> `C:\Windows\System32\drivers\etc\hosts` (admin) :
> ```
> 192.168.175.131  monapp.tioukh.duckdns.org
> ```
> Pour un accès Internet réel : redirection NAT 80/443 de la box vers la VM
> (détails dans `docs/09-reseau-dns-tls.md`).

### 11.3 Changement d'IP du serveur

`APP_HOST` est une variable d'environnement de l'app (lue par le compose au
`up`) : on corrige **le `.env`**, pas le compose. Voir la procédure dédiée
`CHANGEMENT-IP-SERVEUR.md` :

```bash
cd /opt/apps/mon_app
sudo sed -i 's|<ancien host>|<nouveau host>|' .env
sudo grep 'APP_HOST' .env          # vérifie la nouvelle valeur
```

---

## 12. Rollback

Le pipeline de build ne stocke pas l'historique des `sha-` : l'image
`sha-<sha>` d'une **version précédente** est toujours sur Docker Hub.

Deux chemins :

1. **Via le runner / SSH** (simple) :
   ```bash
   /opt/deploy/deploy.sh mon_app sha-<sha-précédent>
   ```
2. **En CI/CD** : relancer un run `build` + `deploy` depuis la branche
   `master` de la version voulue (le `sha-` correspond au commit) —
   l'identique d'un nouveau déploiement.

> Le service disposant de la version fautive reste dans `/opt/apps` :
> un simple `up --pull always` avec l'ancien `IMAGE_TAG` le remplace
> immédiatement. Le dashboard Grafana le montre `down`/unhealthy le temps
> du correctif.

---

## 13. Pièges & erreurs fréquentes

| Piège | Explication / solution |
|---|---|
| `docker-compose.yml` sans `${IMAGE_TAG}` | le pull tire toujours `develop` ; ajoutez `${IMAGE_TAG:-develop}` à l'image |
| Nom d'app invalide | seuls `[a-zA-Z0-9_-]` sont acceptés (`deploy-wrapper.sh` rejette le reste) |
| Fichier refusé par `put` | seuls `docker-compose.yml`, `docker-compose.yaml`, `*.env`, `migrate.sh`, `.env.example` sont autorisés |
| `container_name` non fixe | dashboards et alertes ne peuvent pas cibler l'app ; fixez le nom |
| Service non raccordé au réseau `proxy` | Traefik ne route rien → 404 ; raccordez `proxy: external: true` |
| Pas de `external: true` sur `proxy`/`back` | Docker tenterait de créer un réseau `mon_app_proxy` ; le compose échoue |
| Reconstruire `.env` à la main sur le serveur | c'est le job `deploy` qui le fait ; un `.env` fait main devient incohérent |
| Absence de `healthcheck` | le dernier stat warning de `deploy.sh` étant loggé « none » = jugé sain (pas bloquant) |
| Runner non dans les groupes `docker`/`deployers` | permission refusée sur `/opt/apps` et sur le socket Docker |
| Modification d'IP sans mettre à jour `.env` d'app | l'app continue de pointer vers l'ancien host ; cf. 11.3 |

---

## 14. Récapitulatif — checklist de mise en place d'une app

- [ ] Image de l'app sur Docker Hub (tags `develop` + `sha-<sha>`).
- [ ] `deploy/docker-compose.yml` dans le repo (`${IMAGE_TAG}`, `proxy`, labels
      Traefik, `container_name`, healthcheck, `migrate.sh` si besoin).
- [ ] `.github/workflows/ci.yml` (test → build → deploy self-hosted).
- [ ] Secrets/variables GitHub posés (`DOCKER_USER/TOKEN`, `APP_HOST`,
      `POSTGRES_*`, `SECRET_KEY`, …).
- [ ] Runner self-hosted installé et labellisé `[self-hosted, linux, x64]`.
- [ ] `git push origin master` → jobs verts.
- [ ] Vérif : URL `https://<APP_HOST>/`, sonde `/api/health`, Grafana.
- [ ] (si besoin) ligne `hosts` Windows / redirection NAT de la box (section 11).

---

## 15. Renvois

| Sujet | Référence |
|---|---|
| Socle `app_deploy` (rôle) | `ansible/roles/app_deploy` + `docs/05-fichiers.md` §5.6.11 |
| Composes réels | `docs/05-fichiers.md` §5.8 |
| Réseau/DNS/TLS | `docs/09-reseau-dns-tls.md` |
| Moniteur/logs/alertes | `docs/10-monitoring-logs-alertes.md` |
| CI/CD existant (todo_back/front) | `docs/11-applications-cicd.md` |
| Déploiement serveur de zéro | `docs/08-deploiement.md` + `DEPLOIEMENT-NOUVEAU-SERVEUR.md` |
| Changement d'IP | `CHANGEMENT-IP-SERVEUR.md` |