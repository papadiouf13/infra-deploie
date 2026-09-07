# 14. Sauvegardes et reprise d'activité (DRP)

## 14.1 État existant

| Donnée | Support | Sauvegardée ? |
|---|---|---|
| State Terraform | S3 (versioning activé) | ✅ versioning S3 (restaurer via `terraform state`/bucket) |
| `acme.json` (certs) | `/opt/traefik` | ❌ non sauvegardée (⚠️ reconstitution possible mais redû) |
| Code + config infra | git (dépôts) | ✅ git |
| `.env` + `docker-compose.yml` apps | `/opt/apps/*/` | ❌ **non sauvegardés** (et `.env` = secrets !) |
| Base `todo_back` (Postgres) | volume `postgres_data` | ❌ **aucun dump automatisé** |
| Métriques/alertes (période) | Prometheus/Loki TSDB | utilisation par design (TTL), non sauvegardé |
| Grafana dashboards, config | templates Ansible + datasources/règles | ✅ versionnés (re-générés au `make configure`) |
| Accounts/secrets | vault.yml (git, chiffré) + mot de passe vault | ⚠️ selon le poste admin ; à mettre aussi dans un coffre |

## 14.2 📌 Recommandations — plan de sauvegarde minimal

Concevoir un rôle `backup` (dans le dépôt) qui :
1. **dump quotidien** de chaque base Postgres (app + sonar) dans
   `/opt/backups/` :
   ```bash
   docker exec todo_back_postgres pg_dump -U "$POSTGRES_USER" "$POSTGRES_DB" \
     > "/opt/backups/todo_back-$(date +%F).sql"
   ```
   (informations de connexion lues dans `/opt/apps/todo_back/.env`)
2. **archive** `/opt/apps/todo_back/{.env,docker-compose.yml}` +
   `/opt/backups/*` compressées (gpg avec clé maître, optionnel).
3. **envoi off-site** (rclone S3/backblaze, ou `scp` vers une machine de
   réserve).
4. **rétention** : X jours + une par mois (rotation).
5. **alerte** : endpoint Grafana `since=24h` (ou `last_total_success`) liée à
   un contact point.

**Tests** : restauration d'un dump sur un Postgres jetable ×1/mois (13.1).

## 14.3 Plan de reprise (priorités)

| Scenario | Recovers |
|---|---|
| Panne VM (pas de migration) | re-créer l'infra depuis terraform (S3 state) → `make configure` (sur **nouvelle ip** → vérifier `admin_cidr`, hostnames nip.io et bearer runners) → ré-installer runners → re-run CI → reload backup DB |
| VM fonctionnelle, conteneur cassé | `docker compose up -d` / redémarrer le service + détail 15 |
| Perte dataset | restaurer depuis `/opt/backups` (job + dumps) |

---


