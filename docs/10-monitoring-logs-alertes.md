# 10. Monitoring, logs et alertes

## 10.1 Vue d'ensemble de la chaîne

```
[Capteurs]                     [Collecte]                 [Stockage]          [Visualisation/Alerting]
node-exporter :9100 ─┐
cadvisor :8080 ──────┼──► Prometheus :9090 ──► TSDB (rétention 7d/30d) ──► Grafana :3000
traefik :8082 ───────┤           │
docker :9323 ────────┤           └── règles d'alerte ──► (unified alerting) ──► contact points
lori/alloy :12345 ───┘
Alloy (docker.sock + syslog + traefik + trivy.jsonl) ──► Loki :3100 ──► (query range) ──► Grafana (dashboard logs)
```

- Prometheus : scraping toutes les 15 s (30 s pour `docker`).
- Loki : réception en continu (push Alloy), retention 72 h (dev) / 14 j (prod).
- Grafana : datasources Prometheus (uid `prometheus`) + Loki (uid `loki`),
  provisionnées (read-only).

## 10.2 Scraping — targets et labels

Voir 5.6.6 (jobs + relabels docker_sd) et 9.5 (adresses).

**Labels communs à toutes les cibles** :
- `environment` (défini dans `group_vars`) → permet de filtrer les séries.
- `server` (var d'hôte `server_name`) → `dev-server` / nom du serveur.
- Ajout au `docker_sd` : `prometheus.scrape`, `prometheus.port`, `prometheus.path`.

**Auto-scrape des apps** : poser sur le conteneur :
```yaml
labels:
  - "prometheus.scrape=true"
  - "prometheus.port=8000"
  - "prometheus.path=/metrics"
```
→ Prometheus le découvre sans config.

## 10.3 Limites / extinction
- Pas d'auth horizontale `auth_enabled` sur Loki (interne only, 6.1).
- Le `job docker` pointe `host.docker.internal:9323` (extra_hosts) pour éviter
  la conteneurisation du port 9323.
- Absence de rate-limit sur l'ingestion Loki : un afflux massif de logs peut
  remplir le disque (surveiller `df -h`, voir 15.8).

## 10.4 Règles d'alerte (unified alerting Grafana)

> 16 règles provisionnées (macros), groupées par :

**Groupe « disponibilité »** (haut niveau, focus panne) :
| Alerte | Seuil | Priorité |
|---|---|---|
| Hôte down | instance cible absente (up == 0) ≥ 2 min | critique |
| Conteneur down | cible de scrape Docker absente | critique |
| `LokiDown` / `AlloyDown` | target up == 0 | critique |
| `TraefikDown` / `PrometheusDown` | up == 0 | critique |
| `GrafanaDown` | up == 0 5 m | critique |
| `DockerDaemonDown` | up == 0 5 m | critique |
| `HighErrorRate` | `sum(rate(traefik_service_requests_total{code=~\"5..\"}))` / services = 5 % 10 m | critique |
| `HighLatency` | `histogram_quantile(0.95, rate(traefik_service_request_duration_seconds_bucket))` > 800 ms 10 m | — |

**Groupe `ressources`** (capacité) :
| Alerte | Seuil |
|---|---|
| CPU haute | > 90 % 10 m |
| RAM haute | > 90 % 10 m |
| DiskRootHigh | `node_filesystem_avail_bytes` root < 10 % 5 m |
| DiskVarHigh | /var/lib/docker < 10 % |
| TraefikLatency | latence p95 > 1 s 5 m |
| ContainerHighRestart | `docker_container_restarts >= 3` 5 m |
| SonarDown (si sonar) | up == 0 |

**Groupe `securite`** (Trivy, source Loki — voir 10.8) :
| Alerte | Source | Déclenchement |
|---|---|---|
| `alert-trivy-critical` | Loki (`source="trivy"`, `critical != "0"`) | ≥ 1 scan avec CRITICAL sur les 25 dernières heures |

- **group_by**: `alertname` ; group_wait 30 s ; group_interval 5 m ;
  repeat_interval 4 h ; sous-groupe `severity=critical` avec `group_interval 2 m`,
  `repeat_interval 2 h`.
- Contact point unique `all-channels` : toujours e-mail (+ option Telegram/Slack/Discord).
- Déclenchement : Grafana lui-même (pas d'Alertmanager).

## 10.5 Dashboards provisionnés (Grafana)

| Nom de fichier | Panneaux / axes |
|---|---|
| `overview.json` | vue d'ensemble : up servers, HTTP erreurs, latence, Docker, Node, CPU/RAM |
| `infrastructure.json` | hôte (CPU, RAM, disk, réseau), conteneurs Docker (restarts, mem), système |
| `docker.json` | stats Docker conteneurs (CPu, mem, restarts, flux d'I/O) |
| `traefik.json` | requêtes/s, codes, latences, top routers |
| `logs.json` | **Loki** : flux des logs (variables `env`/`server`, `allValue: ".+"`) + stats |
| `trivy.json` | **Loki** : CRITICAL/HIGH par image, filtre des scans à risque, stat « images CRITICAL 24 h » |
| labels | Tous : `environment`, `server` |

> ⚠️ Mise à jour de `logs.json` (S9) : les variables `env` et `server` ont été
> corrigées de `allValue: ".*"` (matcher rejeté par Loki, d'où le « No data »)
> vers `allValue: ".+"`. Tout nouveau dashboard utilisant ces variables doit
> respecter ce pattern.

## 10.6 Volumes / données métriques

| Composant | Chemin dans la VM | Volume |
|---|---|---|
| Prometheus TSDB | `/opt/prometheus/data` | `./data` |
| Loki | `/opt/loki/data` | `./data` |
| Grafana | `/opt/grafana/{data,provisioning,dashboards}` | `./data` |
| Alloy | DATA_PATH `/var/lib/alloy/data` (dans conteneur) | — |

- Rétention : `--storage.tsdb.retention.time` (Prometheus) et
  `limits_config.retention_period` (Loki).
- ⚠️ Grafana est provisionné en read-only + `allowUiUpdates=false` : toute
  modification faite dans l'interface est **perdue au redémarrage** (la
  source de vérité est constituée des fichiers provisionnés). À noter pour
  l'exploitation (chapitre 15).

## 10.7 📌 Recommandations (monitoring)
- Tester la **fenêtre d'alerte réelle** (vérifier alertes + contact point =
  haut de page) après MEP (voir ch. 13).
- Prévoir un **espace disque dédié** ou un `retention` ajusté à la place
  réelle (dumps de Loki → cf. 14).
- Brancher **alertes « backup »** (dernier événement de sauvegarde) cf. 14.
- Consolider les **nettoyages des datasources/dashboards UI** (read-only) —
  tout changement doit passer par les templates versionnés.

## 10.8 Sécurité des conteneurs — Trivy

**Positionnement** : scan **à l'exécution** des images des conteneurs actifs
chaque nuit (rôle `trivy` — 5.6.12). Complémentaire d'un futur scan Trivy en
**CI** (au build des images `todo_*`).

**Chaîne de donnée** :

```
timer systemd trivy-scan (03:05 UTC)
  └─ /opt/trivy/scan-containers.sh
       ├─ mise à jour automatique de la base (cache /opt/trivy/cache)
       └─ pour chaque image active :
            docker run --rm aquasec/trivy image --severity HIGH,CRITICAL
            -> /opt/trivy/reports/trivy.jsonl  (1 ligne JSON / image)
                 │
                 ▼
       Alloy (loki.source.file "trivy_reports", label source="trivy")
                 ▼
       Loki ──► dashboard trivy.json + alerte alert-trivy-critical
```

**Ligne JSONL produite** :
```json
{"ts":"2026-09-07T03:05:00Z","container":"grafana","image":"grafana/grafana:11.2.2","critical":0,"high":3}
```

**Interrogations utiles (LogQL)** :
- Images à risque CRITICAL : `count_over_time({source="trivy"} | json | critical != "0" [24h])`
- Vérifier que le scan quotidien a tourné : `count_over_time({source="trivy"}[24h]) > 14`
- Détail du dernier scan : `{source="trivy"} | json` (labels `critical`, `high`, `image`, `ts`)
- **Règle d'alerte** `alert-trivy-critical` : `sum(count_over_time({source="trivy"} | json | critical != "0" [25h])) > 0`, `for: 5m` (une alerte unique, agrégée sur toutes les images).

**Réglages** (défaut → adapter dans `group_vars`) :
- `trivy_schedule`: `*-*-* 03:05:00` (heure UTC) ;
- `trivy_severities`: `HIGH,CRITICAL` — passer à `CRITICAL` seul pour moins
  de bruit ;
- `trivy_ignore_unfixed`: `true` — ne pas alerter sur les CVE sans
  correctif disponible.

**À connaître** :
- Le rapport `trivy.jsonl` est **recalculable** n'importe quand
  (`systemctl start trivy-scan.service`) : il n'a pas besoin d'être
  sauvegardé (donnée dérivée) ;
- La **base de vulnérabilités** est requise au premier run (sortie réseau
  vers les registres Trivy) ;
- À l'exécution manuelle, surveiller `journalctl -u trivy-scan`.

---


