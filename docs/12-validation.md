# 12. Validation / vérification (make verify)

## 12.1 Cibles de vérification

`make verify ENV=<env>` exécute `ansible-playbook playbooks/verify.yml -i
inventories/<env>/hosts.ini` et signale :

| Contrôle | sortie attendue |
|---|---|
| conteneurs attendus (traefik, whoami, node-exporter, cadvisor, prometheus, loki, alloy, grafana [+ sonarqube, sonar-db en prod]) | 1 ligne "running" |
| ports publiés | **seulement 80 et 443** (aucun 9323/3000/8080/9000 publié) |
| Prometheus healthy | réponse 200 avec body sur l'endpoint `/api/v1/targets` (curlimages jetable) |
| Prometheus (https) requiert auth | `curl` sans user → HTTP 401 |
| Grafana → `/api/org` | 200 avec le login admin du vault |
| Loki ready + labels | `/ready` 200 ; `/loki/api/v1/labels` non vide |
| SonarQube (prod) | `/api/system/status` 200 |
| Réseaux Docker | `br-proxy`, `br-monitoring` créés |
| Trivy | script `scan-containers.sh` (0750) présent ; timer `trivy-scan.timer` actif ; `trivy.jsonl` existe |

- Exécutable **répétable** (idempotent).
- Runner à chaque MEP : idéal **une fois** en dev + **une fois** avant/l'après
  MEP prod (13).

## 12.2 Vérifications manuelles complémentaires

- Les commandes `curl` de vérification manuelle (Grafana, Prometheus,
  Loki) sont détaillées au **chapitre 15** (dépannage).
- En cas d'alerte déclenchée pendant la vérification, s'y référer au
  chapitre 10 (règles et contact points).

---


