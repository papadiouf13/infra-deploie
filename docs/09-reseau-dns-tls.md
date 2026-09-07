# 9. Réseau, DNS, TLS

> Ce chapitre traite de l'exposé réseau (le split par réseaux Docker,
> l'adressage, le routage) et du TLS (ACME).

## 9.1 Adressage et réseaux Docker

| Réseau Docker | Subnet | Gateway | Usage |
|---|---|---|---|
| `br-proxy` | 172.20.0.0/16 | 172.20.0.1 | traefik + apps exposées + whoami + prometheus + grafana |
| `br-monitoring` | 172.30.0.0/16 | 172.30.0.1 | traefik + node-exporter + cadvisor + prometheus + loki + alloy + grafana |
| `br-back` | 172.40.0.0/16 | 172.40.0.1 | apps back-end + postgres (app) |
| `sonar-net` | réseau par défaut Docker | — | sonarqube + sonar-db |

- Les subnets sont **figés** (quartets 20/30/40) pour stabiliser les cibles
  UFW et les règles Traefik.
- Seul `traefik` publie les ports hôte (80/443). Toutes les autres interfaces
  internes (`.expose`) ne sont jamais visibles de l'extérieur.

## 9.2 Hostnames (nip.io, « sous-domaines »)

Rappel des règles (environnement `dev`, IP publique A.B.C.D) :

| app | nom |
|---|---|
| Grafana | `grafana.<ip>.nip.io` |
| Prometheus | `prometheus.<ip>.nip.io` |
| Dashboard Traefik | `traefik.<ip>.nip.io` |
| whoami | `whoami.<ip>.nip.io` |
| SonarQube | `sonar.<ip>.nip.io` |

- Variables : `grafana_host`, `prometheus_host`, etc. (all.yml).
- L'IP est injectée dans le **template `traefik`** via la var d'hôte
  `public_ip` de l'inventaire (+ le hostname tenant compte du `nip.io`).
- ⚠️ **Changer d'IP** après réinstallation : re-rejouer `make configure`
  (les hostnames dans Traefik/Grafana se mettent à jour), et mettre à jour le
  DNS réel (si `domain` renseigné).

## 9.3 DNS réel (domaine propre)

En cas de domaine réel (`domain` non vide) :
1. Terraform routable `domain` vers l'EIP (NS / A).
2. `dynamic.yml.j2` : une route par sous-domaine (ou wildcard).
3. ACME HTTPS-01 chargé sur `web` (port 80, redirection auto vers 443).

## 9.4 TLS / Let's Encrypt

- Mode par défaut : **TLS automatique** via `certificatesResolvers.letsencrypt`
  (ACME HTTP-01 sur le port 80 → redirection 443).
- `acme.json` (0600) : stocke les certs ; **jamais** exposé dans un dépôt ;
  à sauvegarder (14).
- Dev : `acme_is_staging: true` (évite les rate-limits, pas de cert valide).
- Prod : `acme_is_staging: false`.
- Alternative possible : `traefik_cert_type: selfsigned` (aucun ACME, cert
  auto-signé).

Points d'attention :
- **Rate limits LE** (prod) : ne pas rejouer trop souvent ; laisser le
  ACME renouveler seul (dépend de l'accès au port 80).
- **Port 80** : indispensable en HTTP-01 même quand tout est en 443.
- Le certificat est renouvelé par Traefik ; ne pas bricoler `acme.json`
  quand le service tourne.

## 9.5 Réseau + Flux applicatif attendu

Flux entrant (trafic internet) :

```
Internet ──► 80/443 ──► Traefik ──(routing par label)──► grafana / prometheus / traefik / whoami / app front / app api
```

Scrape interne (Prometheus) :

```
Prometheus ──► traefik:8082, node-exporter:9100, cadvisor:8080, docker:9323, grafana:3000/metrics, loki:3100/metrics, alloy:12345/metrics, apps (docker_sd)
```

Logs (Alloy) :

```
Alloy ──► (docker.sock) logs conteneurs + /var/log/{syslog,auth.log} + /logs/traefik/access.log + /opt/trivy/reports/trivy.jsonl ──► Loki:3100
```

**Cas de panne réseau à connaître** (voir 15 pour résolution) :
- TFS 2 `DEFAULT_FORWARD_POLICY` → conteneurs sans sortie (5.6.1).
- TFS 3 un `down` sur une interface UFW → tout bloqué (ou conteneurs muets).
- Alloy `/var/log/traefik` → EROFS (bind séparé en place, 5.6.8).

---

---


