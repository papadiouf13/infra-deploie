# 3. Prérequis et hypothèses

## 3.1 Prérequis matériel et OS

| Élément | Valeur minimale constatée | Recommandé |
|---|---|---|
| CPU | 2 vCPU | 4 vCPU (SonarQube activé) |
| RAM | 4 Go | 8 Go |
| Disque | 20 Go (SSD) | 40 Go+ (images Docker, TSDB Prometheus, logs Loki, volumes Postgres) |
| OS | Ubuntu 22.04 | Ubuntu 22.04/24.04 x86_64 |
| Réseau | 1 IP publique | IP publique stable (ou EIP / domaine cinématique via DuckDNS) |

## 3.2 Prérequis du poste administrateur (contrôleur)

Outils requis **sur le poste depuis lequel on déploie** :

- `terraform` ≥ 1.9 (mode AWS uniquement)
- `ansible` ≥ 2.14 + collections (voir 3.3)
- `docker` + plugin `docker compose` (pour lancer des conteneurs éphémères de
  test/curl, cf. playbook `verify.yml`)
- `curl`, `git`, `make`
- Clé SSH privée pour l'instance (fichier `.pem` en mode AWS ; clé locale en
  mode VPS)
- (optionnel) `ansible-vault` — fourni avec Ansible

> ℹ️ Sur Windows, l'environnement de référence utilise **PowerShell +
> OpenSSH** (`ssh -i …`). Le code Ansible/Terraform est exécuté depuis la
> même machine ; les commandes `make` décrites supposent un shell POSIX
> (WSL, Git Bash ou tout serveur Linux dédié).

## 3.3 Collections Ansible requises

Fichier : `ansible/requirements.yml`

```yaml
collections:
  - name: community.docker
    version: ">=3.4.0"
  - name: community.general
    version: ">=8.0.0"
```

Installation :

```bash
# poste admin
ansible-galaxy collection install -r ansible/requirements.yml
```

## 3.4 Hypothèses de fonctionnement

- Le serveur (VPS ou EC2) est **nouveau ou vierge** (Ubuntu minimal) ; on
  applique le chapitre 6 (durcissement) avant tout déploiement.
- Le contrôleur (poste admin) possède une **clé SSH** autorisée sur le compte
  `ansible_user` (par défaut `ubuntu`, voir `group_vars/all.yml`).
- En mode AWS : la **key pair** `ssh_key_name` existe déjà
  (`aws ec2 create-key-pair --key-name monitoring-key`).
- Les hostnames sont **nip.io** par défaut (aucune configuration DNS) ; un vrai
  domaine ou DuckDNS est optionnel (chapitre 9).
- En production, l'IP admin (`admin_cidr`) doit être **restreinte** (jamais
  `0.0.0.0/0`).
- Docker Hub est le registre d'images applicatives (login optionnel pour les
  limites de pull, via vault `docker_hub_*`).

---


