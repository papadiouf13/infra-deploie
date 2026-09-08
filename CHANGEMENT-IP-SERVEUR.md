# Guide — Changement d'adresse IP du serveur

Infrastructure « infra-deploie »

Ce document explique, **étape par étape**, comment :
1. **Reconfigurer le serveur** quand son adresse IP change (rare cas : AWS sans Elastic IP fixée, redémarrage avec DHCP, changement de réseau...) pour que tout redeviens accessible.
2. **Fixer l'adresse IP** pour qu'elle **ne change plus jamais** (virtualisation / AWS Elastic IP / DHCP réservation).
3. **Vérifier** que tout fonctionne après le changement.

Suivez l'ordre : **Partie A** (si l'IP a déjà changé), **Partie B** (fixer l'IP), **Partie C** (vérifications). Chaque commande est décrite et expliquée.

---

## Partie A — L'IP a changé : ré-appliquer la configuration

L'infrastructure utilise des **hostnames nip.io** qui dépendent de l'IP publique : `grafana.<IP>.nip.io`, `todo.<IP>.nip.io`, etc. Ces hostnames sont gravés dans les **labels Traefik** de chaque conteneur au moment du déploiement.

> **⚠️ Cause la plus fréquente** : l'IP a changé mais les conteneurs ont gardé les anciens hostnames → les pages répondent **404** (Traefik ne connaît pas la nouvelle route) ou **ERR_CERT_AUTHORITY_INVALID** (certificat TLS pour l'ancienne IP).

### A.0 — Connaître votre nouvelle IP

```bash
# Sur votre poste, tester la connexion à la nouvelle IP
ping 192.168.1.22
```
Vérifie que le serveur répond. Remplacez `192.168.1.22` par **votre** nouvelle IP dans tout ce document.

```bash
# Se connecter au serveur
ssh papa@192.168.1.22
```
Ouvre une session SSH sur le serveur. Toutes les commandes suivantes (sauf indication) se font **sur le serveur**.

### A.1 — Identifier les anciennes IP dans la configuration

```bash
# Rechercher partout une IP "192.168.1.15" (remplacer par l'ANCIENNE IP)
sudo grep -rniE '192\.168\.1\.15' /opt 2>/dev/null | grep -viE 'access\.log'
```
Liste les fichiers de configuration qui contiennent encore l'ancienne IP. Les `access.log` (historique de trafic) sont à ignorer. **Notez quels fichiers sont concernés** — ce sont ceux à corriger.

---

### A.2 — Corriger le reverse-proxy et la surveillance (base)

Ces services sont ceux qui ont des **routes Traefik** (hostnames nip.io). Pour chacun :

**A.2.1 — Grafana**
```bash
cd /opt/grafana
```
Se place dans le répertoire de configuration de Grafana.

```bash
sudo sed -i 's/192.168.1.15/192.168.1.22/g' docker-compose.yml
```
Remplace l'ancienne IP par la nouvelle dans le fichier compose **en tant que root** (le `sudo` est indispensable : le fichier appartient à root). Le `-i` modifie le fichier en place.

```bash
sudo docker compose up -d
```
Recrée le conteneur avec les nouveaux labels Traefik (nouvelles routes). Les services inchangés ne sont pas relancés ; seul celui-là est recréé.

```bash
sudo grep -ni 'Host(' docker-compose.yml
```
**Vérifie** que la route affiche bien la nouvelle IP :
`Host(\`grafana.192.168.1.22.nip.io\`)`

**A.2.2 — Prometheus**
```bash
cd /opt/prometheus
sudo sed -i 's/192.168.1.15/192.168.1.22/g' docker-compose.yml
sudo docker compose up -d
sudo grep -ni 'Host(' docker-compose.yml
```

**A.2.3 — Traefik (dashboard) + whoami**
> ⚠️ `whoami` est défini **dans le même fichier** que Traefik (`/opt/traefik/docker-compose.yml`) → une seule commande corrige les deux.
```bash
cd /opt/traefik
sudo sed -i 's/192.168.1.15/192.168.1.22/g' docker-compose.yml
sudo docker compose up -d
sudo grep -ni 'Host(' docker-compose.yml
```

---

### A.3 — Corriger les applications (projet Todo)

Les applications `todo_back` et `todo_front` utilisent une **variable d'environnement** `APP_HOST` (définie dans leur `.env`), lue par le compose au moment du `up`. On corrige donc le **`.env`**, pas le compose (le compose contient `${APP_HOST}`).

**A.3.1 — back**
```bash
cd /opt/apps/todo_back
```
Se place dans le répertoire de l'application back.

```bash
sudo sed -i 's/192.168.1.15/192.168.1.22/g' .env
```
Met à jour `APP_HOST` dans `.env` (il devient `todo.192.168.1.22.nip.io`).

```bash
sudo docker compose up -d
```
Recrée le conteneur qui lit le nouveau `.env` → nouvelle route Traefik.

```bash
sudo grep -i 'APP_HOST' .env
```
Vérifie : `APP_HOST=todo.192.168.1.22.nip.io`

**A.3.2 — front**
```bash
cd /opt/apps/todo_front
sudo sed -i 's/192.168.1.15/192.168.1.22/g' .env
sudo docker compose up -d
sudo grep -i 'APP_HOST' .env
```

---

### A.4 — Corriger les autres applications (Learning Hub)

Les applications `hub-api` et `hub-front` ont, elles, l'IP **écrite en dur** dans le `docker-compose.yml` (pas de variable) :
> Chemin : `/opt/learning-hub/compose/apps/docker-compose.yml`

```bash
cd /opt/learning-hub/compose/apps
sudo sed -i 's/192.168.1.15/192.168.1.22/g' docker-compose.yml
sudo docker compose up -d
```
Corrige l'IP en dur (lignes `Host(\`learning-hub.192.168.1.22.nip.io\`)`) et recrée les conteneurs.

```bash
sudo grep -ni 'Host(' docker-compose.yml
```
Vérifie les deux routes (`hub-api` et `hub-front`).

---

### A.5 — Mettre à jour les secrets GitHub (CI/CD uniquement)

> ⚠️ **Si vos applications sont déployées via GitHub Actions** (runner qui écrit le `.env`), il faut mettre à jour le secret pour que le **prochain déploiement** n'écrase pas la correction manuelle.

Sur **github.com** → dépôt de l'application → **Settings → Secrets and variables → Actions** :

| Secret | Que faire |
|---|---|
| `APP_HOST` | **Obligatoire** : changer `todo.192.168.1.15.nip.io` → `todo.192.168.1.22.nip.io` |
| `SSH_HOST` | **Uniquement si** le runner est GitHub-hosted : mettre l'IP (publique) `192.168.1.22`. Si le runner est **self-hosted** sur le serveur, ne rien changer. |
| `SSH_USER` / `SSH_PRIVATE_KEY` / `DOCKER_TOKEN` / `DOCKER_USER` | ❌ Rien à changer |

---

### A.6 — Cas particulier : certificats TLS (alerte navigateur)

```bash
sudo grep -niE 'caServer' /opt/traefik/traefik.yml
```
Affiche le serveur ACME configuré :
- Si la ligne contient `acme-staging-v02` → **staging** (dev) : le navigateur affichera **toujours** une alerte de certificat. C'est normal.
- Sinon → **production** : le certificat sera renouvelé automatiquement par Let's Encrypt pour les nouveaux hostnames.

> **⚠️ Limite importante** : sur une **IP privée** (ex. `192.168.1.22`), Let's Encrypt ne peut **pas** valider le domaine (impossible de le joindre depuis internet) → obtention du certificat **impossible** → alerte persistante. Ceci est **inévitable** tant qu'on est sur IP privée avec nip.io.
>
> **Solution** (si vous voulez vraiment un certificat valide) : il faut une **IP publique** + des hostnames accessibles d'internet, **ou** un certificat auto-signé ajouté aux autorités de confiance de vos postes.

---

## Partie B — Fixer l'IP pour qu'elle ne change plus jamais

> **Principe** : l'IP doit être **statique** (attribuée une seule fois, jamais changée) ou **réservée** (le DHCP redonne toujours la même). Choisissez la méthode selon votre environnement.

### B.1 — Machine physique / virtualisée (Linux/Ubuntu) : IP statique via Netplan

> Méthode pour une **VM** (VirtualBox, KVM, Proxmox, VMware...) ou un serveur Ubuntu sous Netplan servant une adresse fixe.

```bash
ls /etc/netplan/
```
Liste les fichiers Netplan (ex. `01-netcfg.yaml`, `50-cloud-init.yaml`). C'est ici qu'on définit l'IP.

```bash
sudo nano /etc/netplan/01-netcfg.yaml
```
Ouvre le fichier Netplan. Repérez votre **interface** réseau (ex. `eth0`, `ens18`, `enp0s3` — celle qui a actuellement l'IP). Ajoutez/modifiez :

```yaml
network:
  version: 2
  ethernets:
    eth0:                    # <-- votre interface (adapter)
      dhcp4: no              # désactive le DHCP (plus d'IP aléatoire)
      addresses:
        - 192.168.1.22/24    # <-- VOTRE IP fixe + masque
      routes:
        - to: default
          via: 192.168.1.1   # <-- votre passerelle (gateway)
      nameservers:
        addresses:
          - 8.8.8.8          # <-- vos DNS (ou ceux du réseau)
          - 1.1.1.1
```

```bash
sudo netplan apply
```
Applique la configuration sans redémarrer. **⚠️ Réseau peut se couper un instant.**

```bash
ip a show eth0
```
Vérifie l'IP attribuée à l'interface.

> **Astuce** : pour ne pas perdre la main si vous vous trompez, faites ces commandes **depuis une console de la VM** (écran virtuel), pas via SSH, sinon une erreur coupe votre seule connexion.

### B.2 — VirtualBox : réserver l'IP (mode "réseau par NAT" ou "réseau interne fixe")

```bash
# Afficher l'IP actuelle de la VM
ip a
```
Identifiez l'IP actuelle et l'interface.

> Configuration **dans l'interface VirtualBox** (pas en ligne) :
> 1. VM → **Paramètres → Réseau**.
> 2. Choisir **"Réseau interne"** (IP fixe que vous définissez, méthode B.1) **ou** **"Accès par pont" (Bridged)** + réserver l'IP dans le routeur (B.3).
> 3. **Activer "Connecté"** et cocher les options adaptées.

### B.3 — Fixer l'IP via le routeur (DHCP reservation) — VM en accès par pont

> Méthode la plus propre en **réseau local** : le routeur **retient** l'adresse MAC de la VM et lui redonne **toujours la même** IP.

1. Récupérer l'**adresse MAC** de la VM :
   ```bash
   ip link show eth0 | grep ether
   ```
   → ex. `52:54:00:ab:cd:ef` (noter cette valeur).

2. Dans l'interface du **routeur** (192.168.1.1 en général) → **DHCP / Réservation d'adresse (Address Reservation)** :
   - Adresse MAC : `52:54:00:ab:cd:ef` (celle de la VM)
   - IP réservée : `192.168.1.22`
   - Activer et enregistrer.

3. Tester :
   ```bash
   sudo reboot
   # après redémarrage de la VM, vérifier que l'IP est toujours la même
   ip a
   ```

### B.4 — AWS : attacher une **Elastic IP** (obligatoire pour un IP fixe)

> Sur AWS, une instance **sans** Elastic IP (EIP) reçoit une IP publique **changeable** à chaque arrêt/démarrage. **La seule façon de la fixer = une Elastic IP.**

Via la console AWS ou CLI :

```bash
# 1) Allouer une Elastic IP
aws ec2 allocate-address --region eu-west-3

# 2) Associer à votre instance (remplacer les ID)
aws ec2 associate-address \
  --instance-id i-0abcdef123456789 \
  --allocation-id eipalloc-0abcdef123456789 \
  --region eu-west-3
```

```bash
# Vérifier que l'IP est bien associée
aws ec2 describe-addresses --allocation-id eipalloc-0abcdef123456789 --region eu-west-3
```
Confirme : `"PublicIp": "54.12.34.56"` (cette IP devient fixe).

> **Avantage** : même si l'instance est arrêtée puis relancée, l'Elastic IP reste la **même**. Veillez à ce que le serveur écoute bien dessus (pas de changement de configuration à refaire).

### B.5 — Appliquer la Partie A une dernière fois après avoir fixé l'IP

Une fois l'IP **fixée**, il n'y a normalement plus rien à faire. Mais si vous avez changé l'IP (ex. passée en statique différente), refaites la **Partie A** avec cette nouvelle IP pour que les routes/nip.io correspondent.

---

## Partie C — Vérifications finales

### C.1 — S'assurer que tout est "Up"

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'
```
Liste tous les conteneurs et leur état. Les composants de la pile doivent être `Up` (et `healthy` quand un healthcheck est défini) : `traefik`, `whoami`, `prometheus`, `grafana`, `loki`, `alloy`, `cadvisor`, `node-exporter`, et les applications.

### C.2 — Vérifier qu'aucun hostname n'a oublié d'être mis à jour

```bash
docker ps --format '{{.Names}}' | while read c; do
  h=$(docker inspect "$c" --format '{{range .Config.Labels}}{{println .}}{{end}}' | grep -oP 'Host\([^)]*')
  [ -n "$h" ] && echo "$c => $h"
done
```
Affiche pour **chaque** conteneur sa règle `Host(...)`. **Toutes** doivent pointer vers la **nouvelle** IP (`.22`). Si une ligne montre encore l'ancienne IP, refaites la **Partie A** pour le service concerné.

### C.3 — Vérifier que les alertes ne contiennent pas d'ancienne IP

```bash
sudo grep -rniE '192\.168\.1\.15' /opt/grafana /opt/prometheus /opt/traefik /opt/loki /opt/alloy 2>/dev/null | grep -viE 'access\.log'
```
Doit renvoyer **vide** (hors historique de logs). Les règles d'alerte Grafana utilisent des **labels** et des expressions (pas d'IP codée) → **rien à corriger** normalement.

### C.4 — Tester les accès dans le navigateur

Ouvrez les URLs (en remplaçant `.22` par votre IP) :

| Service | URL |
|---|---|
| Grafana | `https://grafana.192.168.1.22.nip.io` |
| Prometheus | `https://prometheus.192.168.1.22.nip.io` |
| Traefik UI | `https://traefik.192.168.1.22.nip.io` |
| Whoami | `https://whoami.192.168.1.22.nip.io` |
| Todo (app) | `https://todo.192.168.1.22.nip.io` |
| Learning Hub | `https://learning-hub.192.168.1.22.nip.io` |
| SonarQube | `https://sonar.192.168.1.22.nip.io` (uniquement si activé) |

> **Alerte de certificat** : sur IP privée / staging, le navigateur affiche une alerte de sécurité. Cliquez sur **"Avancé" → "Continuer vers le site (non sécurisé)"**. Ce n'est pas une erreur de configuration, c'est le comportement attendu sur IP privée avec nip.io.

### C.5 — Test rapide de la stack depuis le serveur (curl sans vérif de certificat)

```bash
curl -k -s -o /dev/null -w 'Grafana HTTP %{http_code}\n' https://grafana.192.168.1.22.nip.io/resolve 2>/dev/null || true
```
`-k` ignore le certificat (utile en staging/IP privée). Un code `200`/`3xx` = routes actives.

---

## Rappels et bonnes pratiques

- **Toujours utiliser `sudo`** pour éditer les fichiers sous `/opt` (ils appartiennent à root) : `sed -i ...` sans `sudo` échoue avec `Permission denied` (fichier temporaire non créé).
- **Toujours vérifier après modification** avec le `grep` correspondant (voir chaque étape) avant de passer à la suite.
- **L'ordre compte** : faire Traefik **en dernier** dans la Partie A permet de recharger toutes les routes en une fois ; ici on a corrigé Grafana/Prometheus d'abord, puis les apps, et Traefik a déjà été fait — peu importe, l'important est de **tout** couvrir.
- **Le changement d'IP n'affecte pas les alertes** : elles se basent sur des métriques (Prometheus) et des labels (Grafana), pas sur l'adresse IP.
- **Si l'IP change souvent** : la vraie solution est de la **fixer** (Partie B). Tant qu'elle bouge, il faudra rejouer la Partie A à chaque changement.

---

*Document généré pour la pile « infra-deploie ». Adaptez les valeurs `192.168.1.15` / `192.168.1.22` / `eth0` à votre environnement.*
