# 6. Sécurisation (durcissement)

> Cette section décrit **l'existant** dans le dépôt puis liste les écarts /
> durcissements **recommandés**. La règle d'or reste : **l'Internet en face
> du 443 seulement**, tout le reste interne ou restreint au CIDR admin.

## 6.1 Chaîne de protection existante (par couche)

| Couche | Mécanisme | Dépôt | Où |
|---|---|---|---|
| Réseau cloud | SG AWS : 22 → `admin_cidr`, 80/443 → 0.0.0.0/0 | Terraform module `security` | 5.2.2 |
| Host | UFW : deny in par défaut, allow 22/80/443, 9323 → subnets Docker | rôle `common` | 5.6.1 |
| Brute force | fail2ban (jail sshd), unattended-upgrades | rôle `common` | 5.6.1 |
| Reverse-proxy | Traefik : unique routeur, ACME TLS, redirection 80→443 | rôle `traefik` | 5.6.3 |
| Auth reverse-proxy | basic-authent Traefik (bcrypt) + ipAllowList `admin_cidr` | `dynamic.yml` | 5.6.3 |
| Monitoring | Prometheus sous basic-auth + allowlist ; Grafana login + membres ; Loki/Alloy **internes only** | rôles `prometheus`/`grafana`/`loki` | 5.6 |
| Disques | EBS chiffré + `encrypt: true` sur le tfstate S3 | module `ec2`, `backend.tf` | 5.1 |
| Secrets | Ansible Vault (fichiers `vault.yml` + mot de passe hors repo) ; secrets GitHub | scripts/vault | 8.2 |
| CI/CD | clé restreinte + wrapper (legacy) / runners self-hosted (actuel) | rôle `app_deploy` | 11 |

## 6.2 État de sécurité observé sur la VM de référence (écarts constatés)

| # | Constat | Risque | Correctif |
|---|---|---|---|
| S1 | `admin_cidr: ["0.0.0.0/0"]` dans `all.yml` | basic-auth seule (pas d'IP allowlist) — Prometheus/dashboard Traefik exposés au monde | restreindre à l'IP admin (voir 「Recommandations」) |
| S2 | SSH sur port 22 standard, `StrictHostKeyChecking no` + `UserKnownHostsFile=/dev/null` dans ansible.cfg/all.yml | MITM possible lors des converges ; brute force SSH | (la VM est une machine fixe : figer les empreintes, restreindre `admin_cidr` ; SSR port custom optionnel) |
| S3 | mot de passe admin Grafana réinitialisé **dans l'UI** → l'API/vault ne le connaît plus (401) | perte du compte admin si l'UI ne répond plus ; tunnel de provisioning cassé | re-synchroniser le vault puis `GF_SECURITY_ADMIN_PASSWORD`, réunifier compte UI == vault |
| S4 | runner self-hostés **non provisionnés par Ansible** (instances à la main : `gh-runner`, services systemd separés) | à la réinstall sur une autre machine, les runners manquent (pas « kif kif ») | créer un rôle `github_runner` documenté (voir 「Recommandations」) |
| S5 | secret GitHub `SSH_PRIVATE_KEY` + dossier `/opt/deploy/.ssh-archive` **inutilisés** (clé legacy retirée) | surface d'attaque inutile | purger secret + dossier |
| S6 | secret GitHub `SECRET_KEY` du back = **placeholder** (`xxxxx` ?) et clé Cloudinary **exposée** dans le repo/ECR historique | données chiffrées à clef connue ; compte Cloudinary piratable | rotation + notifier l'auteur (voir 16.x checklist) |
| S7 | `APP_HOST` **codé en dur** dans chacun des `ci.yml` (`todo.192.168.1.15.nip.io`) | toute nouvelle instance doit éditer le workflow | passer par une variable GitHub (`APP_HOST`), fallback conservé |
| S8 | images publiques `mamadou173diouf/todo_*` | pull sans auth → risque d'exfiltration du code | les rendre privées (login Docker Hub au build) fait déjà ; niveau de sécurité réel faible → à auditer |
| S9 | `logs.json` Grafana : variable `server`/`env` avec `allValue: ".*"` | Loki rejette le matcher regex vide → dashboard « No data » | fait : `.+` |
| S10 | accès console AWS : pas de MFA imposé | console AWS admin = total contrôle | activer MFA sur compte AWS + `admin_cidr` |

## 6.3 📌 Recommandations (durcissements à appliquer pour un autre serveur)

> Ces recommandations vont **au-delà** de l'existant ; elles sont à intégrer
> dans le dépôt pour reproduire la config sur les autres machines.

1. **Restreindre `admin_cidr`** (all.yml + `dynamic.yml` + variables.tf) à la
   liste des IP admin (jamais `0.0.0.0/0`). Avoir `basic-auth` + `ipAllowList`.
2. **SSH durci** : port custom (optionnel), `PasswordAuthentication no`,
   empreintes figées dans `known_hosts`, clés uniquement.
3. **Grafana re-synchronisé** : remettre le vault en unique créateur du
   password, ne plus le changer dans l'UI (ou changer via API puis enregistrer
   dans le vault).
4. **Runner provisionnés par Ansible** : rôle Paquet `github_runner`
   (user `gh-runner`, token, services systemd `actions.runner.*`) — présent
   actuellement à la main sur la VM de référence.
5. **Backups hors du dépôt** : rôles `backup` (dumps `todo_back`, revers de
   `/opt/apps` + `.env`, S3 fsync) + alertes dessus (voir 14).
6. **Rotation** : `SECRET_KEY` déployée sur toutes les instances &
   Cloudinary (API key révélée) ; retirer l'ancienne clé du fichier.
7. **Images privées** : passer les images `todo_*` en privées sur Docker Hub
   (S8).
8. **Loki SOCKS** : `auth_enabled` réel ou binding `127.0.0.1` si jamais
   exposé (rester sur `monitoring` interne).
9. **MFA AWS** + réduction des droits de l'utilisateur de déploiement.
10. **Régulariser le `.env` du back** : garantir un fichier de référence du
   `.env` unique généré par le CI, sans duplicata hors dépôt.

---


