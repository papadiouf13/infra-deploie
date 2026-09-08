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

## 9.2 Hostnames : une seule variable `infra_domain`

Tous les hostnames sont **dérivés d'une seule variable** `infra_domain`
(`ansible/group_vars/all.yml`), surchargée par environnement
(`ansible/group_vars/<env>.yml`) :

```
infra_domain: "tioukh.duckdns.org"        # dev (DuckDNS)
#infra_domain: "{{ public_ip }}.nip.io"   # défaut : aucun DNS requis
```

| app | hostname (dev) |
|---|---|
| Grafana | `grafana.tioukh.duckdns.org` |
| Prometheus | `prometheus.tioukh.duckdns.org` |
| Dashboard Traefik | `traefik.tioukh.duckdns.org` |
| whoami | `whoami.tioukh.duckdns.org` |
| SonarQube | `sonar.tioukh.duckdns.org` (si activé) |

- Variables : `grafana_host`, `prometheus_host`, etc. (`all.yml`) ; aucun
  hostname en dur dans les templates.
- `make urls ENV=dev` affiche les URL **et** le bloc `hosts` à copier.
- ⚠️ **Changer d'IP** après réinstallation : rejouer `make configure`
  (les hostnames Traefik/Grafana se mettent à jour — voir `CHANGEMENT-IP-SERVEUR.md`).

## 9.3 DNS réel (DuckDNS) — certifiats LE même en IP privée

Avec un vrai domaine DuckDNS (ex. `tioukh.duckdns.org`) :

1. **TXT dynamique** : DuckDNS porte le token `_acme-challenge.tioukh.duckdns.org`
   pour le challenge **DNS-01** (API `DUCKDNS_TOKEN` injectée dans le conteneur
   traefik via `vault.yml`).
2. **Wildcard** (`acme_use_wildcard: true`) : un **seul certificat
   `*.tioukh.duckdns.org`** sert tous les services → c'est obligatoire avec
   DuckDNS, qui ne supporte qu'un seul enregistrement `_acme-challenge` cogéré
   (les demandes parallèles par sous-domaine s'écraseraient).
3. **Attention** : `*.tioukh.duckdns.org` résout vers l'**IP publique** de la
   box (41.208.191.241 dans notre cas). En **LAN privé, les hostnames ne sont
   pas atteignables directement** → il faut :
   - la cible `make urls` qui affiche le bloc à copier, **ou**
   - ajouter dans `C:\Windows\System32\drivers\etc\hosts` (admin) :
     ```
     192.168.175.131  grafana.tioukh.duckdns.org
     192.168.175.131  prometheus.tioukh.duckdns.org
     192.168.175.131  traefik.tioukh.duckdns.org
     192.168.175.131  whoami.tioukh.duckdns.org
     192.168.175.131  sonar.tioukh.duckdns.org
     ```
   - le navigateur obtient alors un cadenas **vert** (cert LE wildcard valide).
   - Pour un accès réel depuis Internet : redirection NAT 80/443 de la box vers
     la VM **et** restreindre `admin_cidr` (défaut `0.0.0.0/0`).

## 9.4 TLS / Let's Encrypt

- TLS automatique via `certificatesResolvers.letsencrypt`, stockage
  `acme.json` (0600), jamais exposé dans un dépôt, à sauvegarder (14).
- Challenge configurable : `acme_challenge: http` (défaut, port 80) ou
  `acme_challenge: dns` (DuckDNS, IP privée) ; provider et résolveurs dans
  `all.yml` (`acme_dns_provider`, `acme_dns_resolvers`).
- **Dev ({dev}, DuckDNS)** : `acme_is_staging: false` → **certificats réels**
  (testés : `*.tioukh.duckdns.org` émis, valide ~90 j).
- Option : `traefik_cert_type: selfsigned` (aucun ACME, cert auto-signé).

Points d'attention :
- **Rate limits LE (prod)** : ne pas rejouer trop souvent ; laisser l'ACME
  renouveler seul.
- **Propagation DuckDNS** : `acme_dns_delay_before_check` (15 s) attend la
  propagation TXT avant validation ; en cas d'échec de propagation, Traefik
  retente seul (ne pas redémarrer en boucle).
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


