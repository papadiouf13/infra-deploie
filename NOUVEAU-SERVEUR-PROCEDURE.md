# NOUVEAU SERVEUR — Procédure pas à pas

## 1. Objectif

Ce document décrit la mise en service d'un **nouveau serveur** (VPS/VM Ubuntu)
avec l'infrastructure `infra-deploie`, **sans poste de contrôle séparé**
(le serveur est à la fois nœud de contrôle Ansible et cible). Aucun WSL ni PC
Windows n'est requis : on travaille directement **en SSH sur le serveur**.

Résultat : les outils Grafana, Prometheus, Traefik, Loki/Alloy et Trivy
tournent derrière un **certificat Let's Encrypt réel** (wildcard via DNS-01
DuckDNS) sur **votre propre sous-domaine** DuckDNS.

## 2. Prérequis

| Élément | Valeur |
|---|---|
| Serveur | Ubuntu 22.04 / 24.04, accès SSH, compte avec `sudo` |
| Ressources | 2 vCPU / 4 Go RAM minimum (8 Go si SonarQube) / 40 Go SSD |
| Internet | Ports 80 et 443 ouverts en sortie (DuckDNS = DNS-01, IP privée OK) |
| Comptes | un compte GitHub (clone) et un compte **DuckDNS** (gratuit) |

## 3. Sur le serveur : récupérer le projet

Se connecter, puis installer les outils de base et cloner le dépôt.

```bash
ssh <utilisateur>@<ip-du-serveur>

# outils de base
sudo apt update
sudo apt install -y git make curl nano

# cloner le dépôt (remplacer l'URL si le dépôt est privé / autre propriétaire)
git clone https://github.com/papadiouf13/infra-deploie.git
cd infra-deploie
```

## 4. Créer son domaine DuckDNS

Chaque serveur possède **son propre sous-domaine DuckDNS**.

1. Aller sur https://www.duckdns.org et se connecter.
2. Cliquer **add domain** et noter le nom choisi (ex : `moninfra`).
3. Copier le **token** de ce domaine (il servira à l'étape 5).
4. Noter les **deux IP** du serveur :
   - IP **publique** : sur le serveur, `curl -s https://api.ipify.org` (c'est elle qui va dans DuckDNS automatiquement, pas besoin de la façonner ici).
   - IP **LAN** de la VM : `ip a` dans la VM (mode VMware **Bridged**, même réseau que ton poste, ex `192.168.175.x`). C'est **cette IP que tu donneras au prompt `public_ip` de l'étape 5** et que tu mettras dans le fichier `hosts` Windows.

> ⚠️ Ne **jamais** réutiliser `tioukh` (déjà rattaché à un autre serveur).
> Le sous-domaine sera : `moninfra.duckdns.org`.

## 5. Préparation automatique du serveur

Le script `standalone-prep.sh` installe Ansible + les collections Docker,
crée l'inventaire local, copie les fichiers de secrets/variables depuis les
exemples et génère le mot de passe vault.

```bash
cd infra-deploie
scripts/standalone-prep.sh dev
```

Le script demande interactivement :

| Prompt | À saisir |
|---|---|
| Environnement | `dev` (ou `prod`) |
| `server_name` | ex : `monvps` |
| `public_ip` | **l'IP LAN de la VM** (vue depuis ton poste Windows, mode Bridged) — PAS l'IP publique (le cron DuckDNS s'occupe de l'IP publique tout seul) |
| `ansible_user` | le compte SSH administrateur (ex : `ubuntu`) |
| `ansible_become_password` | le mot de passe `sudo` de ce compte |
| Mot de passe vault | laisser vide pour en générer un (affiché une fois) |

> **VM VMware** : placer la VM sur le réseau **Bridged** (elle a alors une IP
> de ton LAN et est joignable par les autres machines). En **NAT**, elle n'est
> joignable que depuis l'hôte Windows — fonctionnel pour tester depuis ton
> poste uniquement. IP fixe recommandée (ou réservation DHCP dans VMware),
> sinon le fichier `hosts` casse après un reboot.

À la fin, le script affiche les étapes restantes (édition des fichiers).

## 6. Renseigner SES variables (fichiers locaux, jamais commités)

### 6.1 `ansible/group_vars/server_vars.yml` — le domaine

```bash
nano ansible/group_vars/server_vars.yml
```

Décommenter et renseigner (le reste peut rester en commentaire) :

```yaml
infra_domain: "moninfra.duckdns.org"
duckdns_domains: "moninfra"
app_deploy_user: "papa"
timezone: "Europe/Paris"
```

> Tous les hostnames en découlent : `grafana.moninfra.duckdns.org`,
> `prometheus.moninfra.duckdns.org`, `traefik.moninfra.duckdns.org`,
> `whoami.moninfra.duckdns.org`, `sonar.moninfra.duckdns.org`.

### 6.2 `ansible/group_vars/vault.yml` — les secrets

```bash
nano ansible/group_vars/vault.yml
```

Renseigner au minimum :

| Variable | Valeur |
|---|---|
| `grafana_admin_password` | mot de passe admin Grafana |
| `prometheus_basic_auth_hash` | hash bcrypt du mdp Prometheus (`scripts/gen-bcrypt-hash.sh`) |
| `traefik_dashboard_basic_auth_hash` | hash bcrypt du mdp Traefik |
| `sonarqube_admin_new_password` | (si SonarQube activé) |
| `sonarqube_db_password` | (si SonarQube activé) |
| `duckdns_token` | **le token du sous-domaine créé à l'étape 4** |
| `alerting.*` | e-mail / Telegram / Slack (optionnel) |

Générer les hash bcrypt :

```bash
# méthode 1 : python3 + bcrypt (sudo apt install -y python3-bcrypt)
scripts/gen-bcrypt-hash.sh "mon-mot-de-passe-prometheus"
# méthode 2 : htpasswd (sudo apt install -y apache2-utils)
htpasswd -nbB -C 12 user "mon-mot-de-passe"
```

Chiffrer le vault (si le script ne l'a pas fait) :

```bash
ansible-vault encrypt --vault-password-file .vault-pass ansible/group_vars/vault.yml
```

## 7. Déployer

```bash
cd ~/infra-deploie
make configure ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
```

En cas d'échec, relancer la même commande : le playbook est **idempotent**.
Les certificats Let's Encrypt (wildcard `*.moninfra.duckdns.org`) sont émis
automatiquement au premier déploiement (DNS-01 DuckDNS).

## 8. Vérifier

```bash
make verify ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
```

Tous les contrôles doivent passer (« Le déploiement est sain ») :
conteneurs actifs, ports limités à 80/443, authentifications HTTP,
ingestion Loki, scanner Trivy.

## 9. Accès depuis un poste (browser)

DuckDNS pointe le domaine vers l'IP **publique**. Depuis le LAN, ajouter
dans le fichier `hosts` du poste (`notepad C:\Windows\System32\drivers\etc\hosts`
en admin sous Windows) l'IP **LAN** de la VM (mode Bridged) :

```text
<ip-LAN-du-serveur>  grafana.moninfra.duckdns.org
<ip-LAN-du-serveur>  prometheus.moninfra.duckdns.org
<ip-LAN-du-serveur>  traefik.moninfra.duckdns.org
<ip-LAN-du-serveur>  whoami.moninfra.duckdns.org
<ip-LAN-du-serveur>  sonar.moninfra.duckdns.org
```

Puis :

```powershell
ipconfig /flushdns
```

Ouvrir le navigateur (cadenas vert attendu — certificat réel) :

| Service | URL |
|---|---|
| Grafana | `https://grafana.moninfra.duckdns.org` |
| Prometheus | `https://prometheus.moninfra.duckdns.org` |
| Traefik | `https://traefik.moninfra.duckdns.org` |
| Whoami | `https://whoami.moninfra.duckdns.org` |
| SonarQube | `https://sonar.moninfra.duckdns.org` (si activé) |

Pour rappel des URL : `make urls ENV=dev`.

## 10. Dépannage rapide

| Symptôme | Remède |
|---|---|
| Playbook bloque sur le vault | Utiliser `VAULT_ARGS='--vault-password-file ../.vault-pass'` |
| `Certificat` invalide | Vérifier `duckdns_token` + propagation DNS (`dig TXT _acme-challenge.moninfra.duckdns.org`) |
| Timeout HTTP | Vérifier `hosts` du poste + IP LAN correcte |
| SonarQube absent malgré utilisation | `enable_sonarqube: true` (prod) ou RAM ≥ 8 Go |
| Mauvais domaine | `infra_domain` dans `server_vars.yml` |
| Rôle `common` introuvable | Lancer depuis `ansible/` ou via `make` (et non la racine le playbook seul) |

## 11. Rappels de sécurité

- Le mot de passe vault (`~/.vault-pass`) est **indispensable** : le sauvegarder
  dans un coffre. Sans lui, les secrets sont illisibles.
- Ne **jamais** commiter `vault.yml`, `hosts.ini`, `.vault-pass`,
  `server_vars.yml` (tous déjà dans `.gitignore`).
- En production, restreindre `admin_cidr` dans `server_vars.yml` (jamais
  `0.0.0.0/0`) et activer SonarQube.

## 12. Références

- Manuel complet : `MANUEL.MD` → export Word `MANUEL.docx`
- Réseau / DNS / TLS : `docs/09-reseau-dns-tls.md`
- Déploiement (détail) : `docs/08-deploiement.md` (§8.1 bis « mode standalone »)
- Prérequis : `docs/03-prerequis.md`
- Le script : `scripts/standalone-prep.sh`
- Variables serveur : `ansible/group_vars/server_vars.yml.example`