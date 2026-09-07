# Guide de déploiement — nouveau serveur

Infrastructure « infra-deploie »  
Document étape par étape listant **toutes les commandes** à exécuter pour mettre en place la pile complète sur un nouveau VPS (Contabo, Hetzner, OVH…).

---

## 0. Prérequis (contrôleur local)

Avoir sur votre poste de contrôle (Linux/Mac/WSL/Windows avec Git Bash) :
- **Git** — pour récupérer le code source.
- **Python 3 + pip** — hôte d'Ansible.
- **Ansible + collections** — orchestrateur de déploiement.
- **SSH client + clé** — connexion au serveur.
- (Optionnel) **htpasswd** ou module python `bcrypt` — génération de hashes pour Traefik.

Vérifier rapidement :
```bash
git --version
python3 --version
ansible --version
```

---

## 1. Récupérer le code source

```bash
# Cloner le dépôt (remplacer <URL> par l'URL réelle du dépôt Git)
git clone <URL-du-depot> infra-deploie
```
Crée le répertoire `infra-deploie` avec toute l'infrastructure as code.

```bash
cd infra-deploie
```
Se placer à la racine du projet (toutes les commandes suivantes se font ici).

---

## 2. Installer les outils (contrôleur)

### 2.1 Python et pip (Debian/Ubuntu)
```bash
sudo apt update
sudo apt install -y git python3 python3-pip
```
Installe Git et Python 3 avec pip, base nécessaire pour Ansible.

### 2.2 Ansible
```bash
pip3 install --user ansible
```
Installe Ansible en mode utilisateur (pas besoin de sudo). Ajoute `~/.local/bin` au PATH si nécessaire.

### 2.3 Collections Ansible requises
```bash
ansible-galaxy install -r ansible/requirements.yml
```
Télécharge les collections `community.docker` (≥ 3.4.0) et `community.general` (≥ 8.0.0) nécessaires aux rôles (Docker, UFW…).

### 2.4 Outils optionnels — hash bcrypt
```bash
pip3 install --user bcrypt
# OU (Debian/Ubuntu) :
sudo apt install -y apache2-utils
```
Permet de générer les hashes bcrypt pour l'authentification basic-auth de Traefik (Prometheus, dashboard).

### 2.5 Vérification rapide
```bash
python3 -c "import bcrypt; print('bcrypt OK')"
make preflight ENV=dev
```
Vérifie que Ansible et les outils requis sont bien installés (`terraform` n'est pas requis en mode VPS).

---

## 3. Préparer le nouveau serveur (hôte cible)

### 3.1 Avoir un accès SSH avec droits sudo
```bash
# Depuis le contrôleur, copier votre clé publique sur le serveur
# (remplacer <IP_SERVEUR> par l'IP publique du VPS)
ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@<IP_SERVEUR>
```
Copie la clé SSH sur le serveur pour permettre une connexion sans mot de passe.

### 3.2 Mettre à jour le serveur
```bash
# Connexion au serveur
ssh -i ~/.ssh/id_ed25519 ubuntu@<IP_SERVEUR>
```
Connecte au serveur distant.

```bash
# Sur le serveur :
sudo apt update && sudo apt -y upgrade
```
Met à jour tous les paquets du serveur (sécurité + correctifs).

```bash
sudo reboot
```
Redémarre pour appliquer les mises à jour kernel. Patienter 30 s puis recoller en SSH.

### 3.3 (Optionnel) Créer l'utilisateur de déploiement
Le playbook utilise par défaut l'utilisateur `ubuntu` (cf. `hosts.ini.example`). Si vous souhaitez un utilisateur dédié `papa` (utilisé dans les configs CI/CD) :
```bash
# Sur le serveur (en tant que root ou ubuntu avec sudo)
sudo adduser papa
sudo usermod -aG sudo papa
```
Crée l'utilisateur `papa` et lui donne les droits sudo.

---

## 4. Configurer l'inventaire (mode VPS)

```bash
# Sur le contrôleur, à la racine du projet
cp ansible/inventories/dev/hosts.ini.example ansible/inventories/dev/hosts.ini
```
Copie le fichier d'inventaire exemple.

```bash
nano ansible/inventories/dev/hosts.ini
```
Éditer le fichier avec les vraies valeurs. Contenu minimal :
```ini
[dev]
dev ansible_host=<IP_SERVEUR> public_ip=<IP_SERVEUR> private_ip=<IP_SERVEUR> server_name=dev-server

[all:vars]
ansible_user=ubuntu
```
- `ansible_host` : IP publique du serveur.
- `server_name` : nom lisible (sera injecté comme label).
- `ansible_user` : user SSH (`ubuntu` ou `papa`).

---

## 5. Préparer les secrets (vault Ansible)

```bash
cp ansible/group_vars/vault.yml.example ansible/group_vars/vault.yml
```
Copie le fichier exemple des secrets.

```bash
nano ansible/group_vars/vault.yml
```
Remplacer **toutes** les valeurs `CHANGE-ME` par de vraies valeurs :
- `grafana_admin_password` — mot de passe admin Grafana.
- `prometheus_basic_auth_hash` / `traefik_dashboard_basic_auth_hash` — hash bcrypt (voir étape 5.1).
- `alerting.email.*` — identifiants SMTP.
- (Optionnel) `alerting.telegram.*`, `alerting.slack.*`.
- `sonarqube_*` — si SonarQube activé en prod.

### 5.1 Générer les hashes bcrypt (Traefik basic-auth)
```bash
bash scripts/gen-bcrypt-hash.sh "VotreMotDePassePrometheus"
```
Génère un hash bcrypt. Copier le résultat dans `vault.yml` :
```yaml
prometheus_basic_auth_hash: "$2b$12$..."
traefik_dashboard_basic_auth_hash: "$2b$12$..."
```
Répéter pour chaque mot de passe si besoin.

### 5.2 Chiffrer le vault
```bash
ansible-vault encrypt ansible/group_vars/vault.yml
```
Chiffre le fichier secret. **Conserver le mot de passe vault** (sera demandé à chaque lancement). Vous pouvez aussi créer un fichier `.vault-pass` à la racine :
```bash
echo "mon-mot-de-passe-vault" > .vault-pass
chmod 600 .vault-pass
```
Pour une exécution non interactive :
```bash
export ANSIBLE_VAULT_PASSWORD_FILE=.vault-pass
```

---

## 6. Vérifier les prérequis (contrôleur)

```bash
make preflight ENV=dev
```
Vérifie que `terraform` (ignoré en VPS), `ansible-playbook`, `docker` et `curl` sont bien installés sur le contrôleur.

---

## 7. Déployer la pile complète

```bash
make configure ENV=dev
```
Lance le playbook `site.yml` via Ansible. Si vous n'avez pas défini `ANSIBLE_VAULT_PASSWORD_FILE`, il vous demandera le mot de passe vault.  
**Installe sur le serveur** (dans l'ordre) :
1. Common : UFW (22/80/443), fail2ban, upgrades automatiques, DuckDNS.
2. Docker : configuration du daemon, création des réseaux `proxy` et `monitoring`.
3. Traefik : reverse-proxy TLS sur 80/443 (Let's Encrypt), route whoami.
4. Node Exporter / cAdvisor : métriques hôte et conteneurs.
5. Prometheus : collecte (basic-auth + IP allowlist).
6. Loki + Alloy : logs centralisés.
7. Grafana : console, dashboards, alerting.
8. Trivy : scan quotidien des vulnérabilités des images (timer systemd).
9. SonarQube + PostgreSQL : désactivé en dev (`enable_sonarqube: false`).

---

## 8. Vérifications post-déploiement

```bash
make verify ENV=dev
```
Joue le playbook `verify.yml` qui vérifie :
- Tous les conteneurs sont bien lancés (`traefik`, `whoami`, `node-exporter`, `cadvisor`, `prometheus`, `loki`, `alloy`, `grafana`).
- Aucun port applicatif exposé en dehors de 80/443.
- Prometheus, Grafana et Loki répondent.
- Timer Trivy actif et rapport existant.

Si tout est OK, la sortie se termine par : *"Le déploiement est sain, tous les contrôles sont passés."*

---

## 9. Consulter les URLs

```bash
make urls ENV=dev
```
Affiche les URLs d'accès aux consoles (basées sur nip.io sans config DNS) :
- Grafana : `https://grafana.<IP>.nip.io`
- Prometheus : `https://prometheus.<IP>.nip.io`
- Traefik UI : `https://traefik.<IP>.nip.io`
- Whoami : `https://whoami.<IP>.nip.io`

Se connecter à Grafana avec les identifiants définis dans le vault (`grafana_admin_user` / `grafana_admin_password`).

---

## 10. Connexion SSH directe

```bash
make ssh ENV=dev
```
Se connecte en SSH au serveur (récupère l'IP depuis l'inventaire).

---

## 11. Installer la CI/CD (déploiement des applications)

### 11.1 Préparer le serveur pour les apps
```bash
ansible-playbook -i ansible/inventories/dev/hosts.ini ansible/playbooks/app-deploy.yml --ask-vault-pass
```
Exécute le playbook `app-deploy.yml` qui :
- Crée `/opt/apps` (racine des applications).
- Génère une paire de clés SSH ed25519 dédiée au CI/CD.
- Installe `deploy.sh` et le service `start-apps` (auto-démarrage au boot).
- Crée le réseau Docker `back`.

### 11.2 Récupérer la clé privée CI/CD
```bash
ssh -i ~/.ssh/id_ed25519 papa@<IP_SERVEUR> 'cat /opt/deploy/.ssh/deploy_key'
```
Copie la clé privée générée sur le serveur. **À conserver** (clé privée de déploiement).

### 11.3 Configurer les secrets GitHub
Dans chaque dépôt d'application (`todo_back`, `todo_front`), ajouter les secrets GitHub suivants :
- `SSH_PRIVATE_KEY` : la clé privée récupérée à l'étape 11.2.
- `SERVER_IP` : IP publique du serveur.
- `SERVER_USER` : `papa` (ou `ubuntu`).
- `DEPLOY_PATH` : `/opt/apps`.
- `SECRET_KEY` : clé secrète Django (générable via `python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())"`).
- `APP_HOST` : hostname publique (ex. `app.example.com`).
- `CLOUDINARY_*` : identifiants Cloudinary (selon configuration).

### 11.4 Déployer les applications
Pousser sur la branche `master` → GitHub Actions déploie automatiquement via le runner installé sur le serveur.

---

## 12. Monitoring & vérifications initiales

### 12.1 Dashboards Grafana
- **Overview** : état global (conteneurs UP/DOWN).
- **Logs** : flux de logs (Loki).
- **Infrastructure** : métriques hôte.
- **Traefik** : requêtes HTTP, latence.
- **Trivy** : vulnérabilités CRITICAL/HIGH des images conteneurs.

### 12.2 Vérifier les cibles Prometheus
```bash
# Depuis le contrôleur
ssh papa@<IP_SERVEUR>
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep '"state"'
```
Toutes les cibles doivent être à `"state": "UP"`.

### 12.3 Vérifier Trivy
```bash
# Sur le serveur
systemctl status trivy-scan.timer
cat /opt/trivy/reports/trivy.jsonl | head -5
```
Vérifie que le timer est actif et que des rapports existent. Pour lancer un scan manuellement :
```bash
sudo systemctl start trivy-scan.service
```

---

## 13. Sauvegardes (si applicatif)

Détails dans la section 14 du manuel complet (`MANUEL.md`). En résumé :
```bash
# Vérifier les tâches cron de sauvegarde (sur le serveur)
crontab -l -u papa
```
Vérifie les sauvegardes planifiées (Postgres, fichiers). Tester périodiquement la restauration.

---

## 14. Sécurisation finale

### 14.1 Restreindre l'IP admin (Grafana, Prometheus)
```bash
nano ansible/group_vars/all.yml
```
Modifier `admin_cidr` :
```yaml
admin_cidr: "<VOTRE_IP_FIXE>/32"
```
Puis relancer :
```bash
make configure ENV=dev
```
Applique le changement d'IP admin (Prometheus basic-auth + Traefik).

### 14.2 Vérifier fail2ban
```bash
# Sur le serveur
sudo fail2ban-client status
```
Affiche les jails actifs (sshd).

### 14.3 Vérifier UFW
```bash
sudo ufw status verbose
```
Doit montrer : 22, 80, 443, 9323 (Docker) actifs.

### 14.4 Roter les secrets compromis
Si des secrets ont été committés dans Git :
- `SECRET_KEY` Django → régénérer + modifier dans GitHub Actions.
- Cloudinary → régénérer les credentials via le portail Cloudinary.
- `SSH_PRIVATE_KEY` → régénérer sur le serveur + mettre à jour GitHub.

---

## 15. Fichiers utiles (références)

| Fichier | Rôle |
|---|---|
| `Makefile` | Orchestration (configure, verify, urls, ssh) |
| `ansible/group_vars/all.yml` | Variables globales (seuils alertes, dashboards, chemins) |
| `ansible/group_vars/vault.yml` | Secrets chiffrés (ne jamais commit) |
| `ansible/group_vars/dev.yml` | Spécificités environnement dev |
| `ansible/playbooks/site.yml` | Playbook principal (déploiement complet) |
| `ansible/playbooks/verify.yml` | Vérifications post-déploiement |
| `ansible/playbooks/app-deploy.yml` | Préparation CI/CD sur le serveur |
| `scripts/gen-bcrypt-hash.sh` | Génération de hash bcrypt |

---

Commandes de maintenance courante :
```bash
make urls ENV=dev           # Affiche les URLs
make verify ENV=dev         # Vérifie l'état de la stack
make configure ENV=dev      # Réapplique la configuration (idempotent)
make ssh ENV=dev            # Connexion SSH
sudo systemctl start trivy-scan.service   # Lancer un scan Trivy manuellement
```
