# 15. Dépannage (runbooks)

## 15.1 Principes
- Toujours commencer par `docker ps`, `make verify ENV=…`, `journalctl`.
- Sur la VM : `docker logs <c>`, `systemctl status <svc>`.
- PostgreSQL : `docker exec todo_back_postgres psql -U $POSTGRES_USER -d $POSTGRES_DB`.

## 15.2 Serveur sans réponse sur 80/443 (flux entrant)

1. `ssh` encore actif ? → `ip a`, `systemctl status docker`.
2. `ufw status` → vérifier 80/443 (et SSH !).
3. `docker ps` → traefik a-t-il crashé, est-ce que `DEFAULT_FORWARD_POLICY`
   est toujours ACCEPT (5.6.1) ?
4. Vérifier le SG AWS (si cloud).

## 15.3 Conteneur crash-loop (un app)

```bash
docker logs --tail 200 todo_back
# ex. fail migrations → répondre par rollback image précédente :
cd /opt/apps/todo_back && IMAGE_TAG=sha-<précédent> docker compose up -d --pull always
```

## 15.4 Swagger/ReDoc qui renvoie des URLs sans `/api`

Marqueur : `/openapi.json` renvoie 404 (ou UI cassée) via Traefik.
Cause connue : ROOT_PATH absent/non appliqué. Vérifier le `entrypoint.sh`
(5.8.4) et `ROOT_PATH` dans le compose app ; rebuild si nécessaire.

## 15.5 Dashboard Grafana « No data » malgré des logs

- Vérifier côté **Loki** : logs reçus (label `count_over_time`), réseau
  `monitoring`, et les **variables du dashboard** (allValue) — cf. S9 :
  `.*` est rejeté par Loki, utiliser `.+` (déjà corrigé en place sur la VM).

## 15.6 Rollback d'une app

```bash
cd /opt/apps/<app>
docker ps                       # tag actuel (imag sha-…)
git log dans repo → repérer un bon sha
IMAGE_TAG=sha-<bon-sha> docker compose up -d --pull always
```

## 15.7 Grafana inaccessible / auth
- `curl https://grafana.<ip>.nip.io/api/org -u admin:$(pass)` → 401 ?
  → S3 ? (l'admin dans l'UI ≠ vault). Re-sync vault→UI.
- Conteneur redémarré avec l'ancien `.compose` → Grafana écoute sur autre port ?
  vérifier labels Traefik.

## 15.8 Disque plein
```bash
df -h / /var/lib/docker
# journaux Docker → purge à la demande (les logs sont rotationnés 10m×3)
# volume Prometheus/Loki → rétention à baisser en quick fix
```

## 15.9 Runner ralentit / agent down
`sudo systemctl status actions.runner.*` + `./run.sh` du runner (voir 11.6).

## 15.10 Vault-pass perdu
- Introuvable : impossible de re-décrypter → reconstruire vault.yml à partir
  du `.example` + secrets .env (décryptables via le secret GitHub).

---


