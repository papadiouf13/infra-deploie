# 8. Déploiement (de zéro et itératif)

## 8.1 Workflow « un serveur propre »

Rappel rapide (le détail est dans 4 et 5) :

```
0. Prérecuis : AWS credentials, knowles TF state (5.1.3), clés SSH
1. terraform workspace new dev && terraform apply -var-file=dev.tfvars
2. make inventory ENV=dev            → génère ansible/inventories/dev/hosts.ini
3. make configure ENV=dev            → ansible-playbook site.yml (demande vault-pass)
   # ou mode VPS : renseigner hosts.ini à la main puis même commande
4. make verify ENV=dev               → vérif de l'ensemble
5. discovery manuelle : https://grafana.<ip>.nip.io …
```

Sur la **VM existante** : passer l'inventaire en mode VPS avec `public_ip`,
`server_name`, `app_deploy_user=papa`, puis rejouer `make configure ENV=dev`
(vaut aussi `-i inventories/dev/hosts.ini`).

## 8.1bis Mode standalone (le serveur est son propre contrôleur, sans WSL)

Pour déployer un **nouveau serveur** en SSH directement, sans poste de contrôle
séparé :

```
# sur le serveur (Ubuntu), première fois
sudo apt update && sudo apt install -y git make curl
ssh-keygen -t ed25519                # clé GitHub si dépôt privé
git clone https://github.com/papadiouf13/infra-deploie.git
cd infra-deploie
scripts/standalone-prep.sh [dev|prod]
```

Le script prépare les **outils contrôleur** (python3, pip, ansible +
collections `requirements.yml`), génère `inventories/<env>/hosts.ini` en mode
local (`ansible_connection=local`), copie les fichiers `vault.yml` /
`server_vars.yml` depuis les exemples et crée `.vault-pass`.

Ensuite, sur ce serveur :

```bash
# 1. Éditer SES variables propres (DUCK objectif principal) :
nano ansible/group_vars/server_vars.yml    # infra_domain = son sous-dom. DuckDNS
nano ansible/group_vars/vault.yml          # duckdns_token, password Grafana, hashs…

# 2. Chiffrer le vault (une fois) :
ansible-vault encrypt --vault-password-file .vault-pass ansible/group_vars/vault.yml

# 3. Déployer / vérifier :
make configure ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
make verify   ENV=dev VAULT_ARGS='--vault-password-file ../.vault-pass'
make urls     ENV=dev
```

> ⚠️ Chaque serveur a **son** sous-domaine DuckDNS → son `infra_domain` (dans
> `server_vars.yml`) **et** son `duckdns_token` (dans `vault.yml`). Tous les
> hostnames en dérivent. Voir 9 (DNS/TLS).
>
> ℹ️ `make preflight` ne **exige plus** terraform : il est ignoré (warning) en
> mode VPS/standalone ; `terraform` reste requis seulement pour les cibles AWS
> (`plan`/`apply`/`deploy`/`destroy`).

## 8.2 Secrets : Ansible Vault

- Fichier cible : `ansible/group_vars/vault.yml` (déclaré dans site.yml via
  `include_vars` avec `decrypt: auto`).
- Gabarit : `ansible/group_vars/vault.yml.example` (voir 5.4.6).
- Création / édition :
  ```bash
  ansible-vault create ansible/group_vars/vault.yml      # mot de passe à renseigner
  ansible-vault edit  ansible/group_vars/vault.yml
  ```
- Exécution : `make configure` propose `--ask-vault-pass`.

**Problème de pass phrase** :
- `--ask-vault-pass` (interactif) ou
  `ANSIBLE_VAULT_PASSWORD_FILE=/path/.vault-pass` + `make configure VAULT_ARGS="--vault-password-file .vault-pass"` (CI).

> ⚠️ Si le vault est **corrompu ou perdu** : seule une sauvegarde chiffrée du
> fichier le récupère. Ne jamais committer la pass phrase.

## 8.3 Déploiement itératif (change management)

| Type | Commande | Particularité |
|---|---|---|
| Changer une variable | éditer group_vars + `make configure ENV=…` | idempotent ; les modifies portent effet (compose, configs) |
| Changement Terraform | modifier `*.tf` + `make apply ENV=…` | respectueux du state/plan ; le VSi-server n'est pas recréé si l'AMI est idem |
| App sur la VM | pipeline GitHub (voir 11) | `deploy.sh` (pull, up, santé, migrations) |

## 8.4 Ordre de réinstallation complet (quand tout est à refaire)

1. Réutiliser le **state S3** (bucket+clé existants) → `terraform apply`
   recrée uniquement ce qui manque.
2. `make inventory` puis `make configure`.
3. Renseigner les données de la VM (runners, secrets CI) si besoin.

## 8.5 📌 Recommandations
- Rendre les runners GH **reproductibles** par le rôle `github_runner`
  (6.3-4).
- Planifier une **checklist « nouveau serveur »** basée sur 16 pour valider
  chaque étage avant mise en prod.

---


