# DÉPLOIEMENT D'UN NOUVEAU SERVEUR — Procédure complète (v2.0)

## Introduction

Ce document décrit, de A à Z, la mise en service d'un **nouveau serveur** (VPS ou
VM Ubuntu 22.04/24.04) avec l'infrastructure `infra-deploie` :

- **Partie A** : sécuriser la machine **avant tout** (connexion SSH, mises à jour,
  clé SSH + durcissement).
- **Partie B** : déployer l'infrastructure de monitoring (Grafana, Prometheus,
  Traefik, Loki/Alloy, Trivy) **en mode standalone** — le serveur est à la fois
  nœud de contrôle Ansible et cible, **aucun WSL/PC requis**.
- **Partie C** : retour d'expérience sur les problèmes rencontrés et leurs
  correctifs.

> **Avant de commencer** : ce guide est pensé pour une VM **VMware** (Ubuntu
> 24.04). En VM, préférer le réseau **Bridged** (la machine a une IP de votre LAN)
> et prévoir une **IP statique** ou une réservation DHCP (sinon le fichier `hosts`
> Windows casse après un reboot).

---

# PARTIE A — Sécuriser la machine (EN PREMIER)

## A.1 — Connexion SSH

**PowerShell / cmd (Windows)**
```text
ssh <user>@<IP-contact>
```
- `yes` à la question sur l'empreinte, puis le mot de passe.
- Coller : clic droit ou `Ctrl+Shift+V` ; copier : sélectionner suffit (ou `Ctrl+Shift+C`).
- Si `Connection refused` : installer le serveur SSH depuis la console VMware :
  ```bash
  sudo apt install openssh-server -y
  ```

## A.2 — Mises à jour système

**serveur**
```bash
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y
sudo reboot && sleep 30 && exit   # se reconnecter après ~30 s
```

> UFW, fail2ban et les mises à jour automatiques (`unattended-upgrades`) sont
> **déjà gérés par Ansible** en Partie B (rôle `common`). Pas de redondance ici :
> on ne refait pas ces étapes à la main.

## A.3 — Authentification SSH par clé

Principe : une paire de clés est générée sur le poste Windows. La clé privée
n'en sort jamais ; seule la clé publique est copiée dans
`~/.ssh/authorized_keys` du serveur.

### A.3.1 Générer la paire de clés (Windows)

**PowerShell / cmd (Windows)**
```powershell
ssh-keygen -t ed25519
# Entrée pour l'emplacement par défaut ; passphrase facultative
```
Ed25519 est préféré à RSA (clés courtes, rapides, robustes).

### A.3.2 Copier la clé publique sur le serveur (Windows)

Windows n'a pas `ssh-copy-id` ; on l'émule avec un pipe :

**PowerShell**
```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh <user>@<IP-contact> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

**cmd**
```cmd
type "%USERPROFILE%\.ssh\id_ed25519.pub" | ssh <user>@<IP-contact> "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys"
```

Le mot de passe est demandé une dernière fois. **Test** :
`ssh <user>@<IP-contact>` doit ouvrir la session sans mot de passe.

### A.3.3 Durcir le serveur SSH

Fichier dédié dans `/etc/ssh/sshd_config.d/`, jamais dans `sshd_config` :

**serveur (session SSH)**
```bash
sudo tee /etc/ssh/sshd_config.d/00-hardening.conf <<'EOF'
PasswordAuthentication no
PermitRootLogin no
PubkeyAuthentication yes
MaxAuthTries 3
X11Forwarding no
EOF
sudo sshd -t                          # valide la syntaxe (silence = OK)
sudo sshd -T | grep -i passwordauth   # doit afficher : passwordauthentication no
sudo systemctl restart ssh
```

> **Piège Ubuntu 24.04** : le préfixe `00-` est **obligatoire**. L'installeur
> crée `/etc/ssh/sshd_config.d/50-cloud-init.conf` contenant
> `PasswordAuthentication yes` ; OpenSSH lit les fichiers par ordre alphabétique
> et garde la **première** valeur. Un fichier nommé `hardening.conf` serait lu
> après et **ignoré** → le mot de passe resterait accepté.

### A.3.4 Vérifier

Garder la session SSH ouverte, puis dans un **second terminal** (Windows) :
```powershell
ssh <user>@<IP-contact>                              # doit passer sans mot de passe
ssh -o PubkeyAuthentication=no <user>@<IP-contact>   # doit échouer : Permission denied (publickey).
```
En cas de blocage : la console VMware reste accessible avec le mot de passe
(supprimer `00-hardening.conf` et redémarrer `ssh`).

---

# PARTIE B — Déployer l'infrastructure (infra-deploie)

## B.1 — Prérequis

| Élément | Valeur |
|---|---|
| Serveur | Ubuntu 22.04 / 24.04, accès SSH + compte `sudo` |
| Ressources | 2 vCPU / 4 Go RAM min (8 Go si SonarQube) / 40 Go disque |
| Comptes | 1 compte GitHub (clone) + 1 compte **DuckDNS** |
| Réseau | Ports 80/443 HTTPS en sortie (validation DNS-01 = IP privée OK) |

## B.2 — Récupérer le projet

**serveur**
```bash
ssh <user>@<IP-contact>

# outils de base
sudo apt install -y git make curl nano

# cloner le dépôt
git clone https://github.com/papadiouf13/infra-deploie.git
cd infra-deploie
```

## B.3 — Créer son sous-domaine DuckDNS

Chaque serveur a **son propre sous-domaine** DuckDNS.

1. https://www.duckdns.org → se connecter.
2. **add domain** → noter le nom choisi (ex : `inframonitoring`).
3. Copier le **token** du domaine (il ira dans le vault, partie B.6).
4. Noter les **deux IP** :
   - IP **publique** : `curl -s https://api.ipify.org` (c'est celle que DuckDNS
     affiche automatiquement via le cron du serveur — rien à forcer ici) ;
   - IP **LAN** : `ip a` sur le serveur (en VM Bridged, ex `192.168.175.x`) —
     **c'est celle qu'on donnera au prompt `public_ip` du script (B.4)**.

> ⚠️ Ne jamais réutiliser un sous-domaine déjà rattaché à un autre serveur.

## B.4 — Préparation automatique du serveur

`standalone-prep.sh` installe Ansible + les collections Docker, crée
l'inventaire local, copie les fichiers de variables depuis les exemples et
génère le mot de passe vault.

**serveur**
```bash
cd infra-deploie
bash scripts/standalone-prep.sh dev
```

> ⚠️ Utiliser **`bash scripts/...`** et non `./scripts/...`
> (pas de permission d'exécution sur les fichiers clonés → `Permission denied`).
> Ne pas utiliser `sudo` (le script fait déjà ses `sudo` ; l'exécuter en root
> créerait des fichiers mal propriétaires).

Le script demande interactivement :

| Prompt | À saisir |
|---|---|
| Environnement | `dev` (ou `prod`) |
| `server_name` | un identifiant (ex : `vps4`) |
| `public_ip` | **l'IP LAN du serveur** (vue depuis le poste Windows) — PAS l'IP publique |
| `ansible_user` | le compte SSH admin (ex : `diouf`) |
| `ansible_become_password` | le mot de passe `sudo` de ce compte (vide si NOPASSWD) |
| `private_ip` | ⏎ (défaut = public_ip) |
| Mot de passe vault | ⏎ pour en générer un — **il est affiché, note-le** |
| Chiffrer le vault ? | `y` |

**Gestion des pièges Ubuntu 24.04 (déjà traitée par le script) :**

- **PEP 668** : si `pip` refuse l'installation (`externally-managed-environment`),
  le script retente automatiquement avec `--break-system-packages`. Si pour une
  raison quelconque Ansible n'est pas installé à la fin, le faire à la main :
  ```bash
  python3 -m pip install --user --break-system-packages ansible-core
  export PATH="$HOME/.local/bin:$PATH"
  ```
- **Collections** : le script vérifie la **présence effective** des dossiers
  `community/docker` et `community/general`. S'ils manquent, il lance
  `ansible-galaxy collection install -r ansible/requirements.yml`.
- **PATH** : le script ajoute `$HOME/.local/bin` à `~/.bashrc` pour que `make`
  trouve `ansible-playbook` dans les sessions futures (toujours `export PATH="$HOME/.local/bin:$PATH"` dans la session courante si besoin).

Vérifier en fin de script :
```bash
ansible-playbook --version | head -1
ansible-galaxy collection list community.docker
ansible-galaxy collection list community.general
```

## B.5 — Variables spécifiques au serveur (`server_vars.yml`)

**serveur**
```bash
nano ansible/group_vars/server_vars.yml
```

Renseigner au minimum :
```yaml
infra_domain: "<votre-sous-domaine>.duckdns.org"
duckdns_domains: "<votre-sous-domaine>"
app_deploy_user: "<votre-compte-ssh-local>"
```

> `app_deploy_user` = l'utilisateur **local** qui possédera `/opt/apps` et les
> clés de déploiement CI/CD. Utiliser **son propre compte** (ex : `diouf`) —
> jamais `papa` (compte de la VM de référence, qui n'existe pas ailleurs).
> Ce rôle (`app_deploy`) **n'est pas lancé par `make configure`** (playbook
> séparé) : aucun impact immédiat.

Sauvegarder : **Ctrl+O** → **Entrée** → **Ctrl+X**.
Ne pas commiter ce fichier (déjà dans `.gitignore`).

## B.6 — Secrets dans le vault (`vault.yml`)

Le script a **déjà chiffré** `vault.yml`. Pour l'éditer, on passe par
`ansible-vault edit` (jamais `nano` direct, qui afficherait du bruit chiffré ;
et **ne pas relancer** `ansible-vault encrypt`, le fichier l'est déjà).

**serveur**
```bash
EDITOR=nano ansible-vault edit --vault-password-file .vault-pass ansible/group_vars/vault.yml
```

> `EDITOR=nano` est **important** : par défaut Ansible peut ouvrir `vi`, sur
> lequel on ne peut pas taper directement (mode navigation). Avec `nano`, on
> écrit comme un bloc-notes : **Ctrl+O** sauve, **Ctrl+X** quitte, Ansible
> rechiffre automatiquement.

Remplacer les `CHANGE-ME` :

| Variable | Valeur |
|---|---|
| `grafana_admin_password` | mot de passe admin Grafana |
| `prometheus_basic_auth_hash` | hash bcrypt (`scripts/gen-bcrypt-hash.sh "mdp"`) |
| `traefik_dashboard_basic_auth_hash` | hash bcrypt du mdp Traefik |
| `sonarqube_*` | à personnaliser (SonarQube désactivé en dev par défaut) |
| `alerting.email.smtp_password` | mot de passe d'application Gmail (2FA) |
| `alerting.telegram.bot_token` / `chat_id` | (optionnel) |
| `alerting.slack.webhook_url` | (optionnel) |
| `duckdns_token` | **le token du sous-domaine DuckDNS (B.3)** |

> ⚠️ **YAML strict** : `duckdns_token:` et `duckdns_domains:` doivent être à la
> **colonne 0**, sans espace de début (sinon Ansible refuse de charger le vault).
> Tous les secrets collés ici vont dans un fichier **chiffré**.

Vérifier le chiffrage :
```bash
head -1 ansible/group_vars/vault.yml            # $ANSIBLE_VAULT;1.1;AES256
ansible-vault view --vault-password-file .vault-pass ansible/group_vars/vault.yml | head -3
```

## B.7 — Déployer

**serveur**
```bash
make configure ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
```

Résultat attendu (fin de sortie) :
```
PLAY RECAP ****************************************
dev : ok=97 changed=63 unreachable=0 failed=0 skipped=7 ...
```
- Relançable en cas d'échec : le playbook est **idempotent**.
- Les certificats Let's Encrypt (wildcard `*.<sous-domaine>.duckdns.org`) sont
  émis automatiquement au premier déploiement (DNS-01 DuckDNS).
- Si le playbook s'arrête sur *« Missing sudo password »* : le
  `ansible_become_password` de l'inventaire est vide → remplir `hosts.ini` ou
  lancer `make configure ENV=dev VAULT_ARGS='...' --ask-become-pass` (saisir le
  mdp sudo).

## B.8 — Vérifier

**serveur**
```bash
make verify ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
```

Attendu : **« Le déploiement est sain, tous les contrôles sont passés. »**
(`ok=21 failed=0`).

## B.9 — Accès navigateur depuis un poste

DuckDNS pointe le domaine vers l'IP **publique**. Depuis le LAN, le fichier
`hosts` du poste pointe les hostnames vers l'IP **LAN** du serveur.

**serveur**
```bash
make urls ENV=dev
```
> Ce bloc s'appuie sur `public_ip` de l'inventaire et `infra_domain` de
> `server_vars.yml` (plus de `127.0.0.1` ni de domaine par défaut erroné).

**Windows (admin)**
```powershell
notepad C:\Windows\System32\drivers\etc\hosts
```
Ajouter (IP LAN réelle + hostnames finaux) :
```text
<IP-LAN>  grafana.<sous-domaine>.duckdns.org
<IP-LAN>  prometheus.<sous-domaine>.duckdns.org
<IP-LAN>  traefik.<sous-domaine>.duckdns.org
<IP-LAN>  whoami.<sous-domaine>.duckdns.org
<IP-LAN>  sonar.<sous-domaine>.duckdns.org
```
Puis :
```powershell
ipconfig /flushdns
```

Ouvrir le navigateur (cadenas vert attendu — certificat réel) :

| Service | URL |
|---|---|
| Grafana | `https://grafana.<sous-domaine>.duckdns.org` |
| Prometheus | `https://prometheus.<sous-domaine>.duckdns.org` |
| Traefik | `https://traefik.<sous-domaine>.duckdns.org` |
| Whoami | `https://whoami.<sous-domaine>.duckdns.org` |
| SonarQube | `https://sonar.<sous-domaine>.duckdns.org` (prod uniquement) |

---

# PARTIE C — Retour d'expérience (problèmes rencontrés)

| Symptôme | Cause | Correctif |
|---|---|---|
| `scripts/standalone-prep.sh: Permission denied` | droit d'exécution absent sur les fichiers clonés | `bash scripts/standalone-prep.sh dev` (et non `./…`) |
| `error: externally-managed-environment` (Ubuntu 24.04) | PEP 668 bloque `pip --user` | le script relance avec `--break-system-packages` ; sinon à la main |
| `community.docker` non trouvé après le script | l'ancien test `collection list` retournait 0 même vide | le script vérifie désormais la présence des dossiers ; sinon `ansible-galaxy collection install -r ansible/requirements.yml` |
| `make` ne trouve pas `ansible-playbook` | `~/.local/bin` absent du PATH (nouvelle session) | `export PATH="$HOME/.local/bin:$PATH"` / ajout auto dans `~/.bashrc` |
| vault qui s'affiche « illisible » au `nano` | fichier **chiffré** ouvert directement | `EDITOR=nano ansible-vault edit -…` |
| « je ne peux pas taper » dans le vault | Ansible ouvre `vi` (pas nano) | `EDITOR=nano` devant la commande |
| `duckdns_token` refusé à la lecture du vault | espaces en début de ligne (YAML) | replacer `duckdns_token:` / `duckdns_domains:` à la colonne 0 |
| `ansible-vault encrypt` re-lancé → problème | le fichier est déjà chiffré par le script | ne pas relancer ; éditer via `ansible-vault edit` |
| `Missing sudo password` (double `sudo`) | `ansible_become_password` vide | remplir `hosts.ini` ou `--ask-become-pass` |
| `PasswordAuthentication` toujours accepté | `50-cloud-init.conf` lu avant le fichier de durcissement | nommer le fichier **`00-hardening.conf`** |
| `make urls` affiche `127.0.0.1` ou le mauvais domaine | ancienne lecture `ansible_host` + `group_vars/<env>.yml` | corrigé : `public_ip` + `infra_domain` depuis `server_vars.yml` |
| Avertissements `DEPRECATION WARNING` (apt_repository, facts) | obsolescences Ansible | sans impact fonctionnel ; ignorables |

## Rappels de sécurité

- Le mot de passe vault (`~/.vault-pass`) est **indispensable** : le sauvegarder
  dans un coffre. Sans lui, les secrets sont illisibles.
- Ne jamais commiter `vault.yml`, `hosts.ini`, `.vault-pass`, `server_vars.yml`
  (déjà dans `.gitignore`).
- En production : restreindre `admin_cidr` (jamais `0.0.0.0/0`) et activer
  SonarQube.

## Références

- Manuel complet : `MANUEL.md` ⇄ `MANUEL.docx`
- Le script de préparation : `scripts/standalone-prep.sh`
- Variables serveur : `ansible/group_vars/server_vars.yml.example`
- Things détaillées : `docs/08-deploiement.md` (§8.1 bis), `docs/09-reseau-dns-tls.md`