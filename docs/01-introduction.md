# 1. Introduction et périmètre

## 1.1 Objectif

Ce dépôt déploie une **pile de monitoring DevOps complète et auto-déployable**
(Terraform + Ansible) sur un serveur unique, en deux environnements (`dev` /
`prod`), de deux manières possibles :

| Mode | Infrastructure | Inventaire Ansible |
|---|---|---|
| **AWS** | `Terraform` provisionne l'instance EC2 + VPC/subnet/security group + EIP | Généré automatiquement (`make inventory`) |
| **VPS** (Contabo, Hetzner, OVH…) | Aucun Terraform — le serveur existe déjà | Rempli à la main (`hosts.ini`) |

Dans les deux cas, **le code de déploiement Ansible est identique**.

Au-delà de la pile de monitoring, le même serveur héberge **des applications
déployées en continu** via GitHub Actions : `todo_back` (API FastAPI +
PostgreSQL) et `todo_front` (Next.js).

## 1.2 Ce qui est couvert

- L'architecture globale et les dépendances entre composants.
- La documentation **bloc par bloc** de l'ensemble du code du dépôt.
- La procédure de **durcissement** du serveur avant déploiement.
- L'installation des dépendances et le déploiement de la pile.
- Le **monitoring, les logs et l'alerte** (Prometheus, Loki, Grafana).
- Le **déploiement des applications** par CI/CD et runners auto-hébergés.
- La validation post-déploiement, l'exploitation quotidienne et le dépannage.

## 1.3 Ce qui n'est **pas** couvert (explicitement manquant dans le dépôt)

| Sujet | État constaté | Où le trouver |
|---|---|---|
| **Sauvegardes** automatisées (base, fichiers, certificats) | **Absent** du dépôt | Chapitre 14 — procédure et scripts recommandés |
| **Provisionnement des runners self-hosted** par l'infra | Fait manuellement sur le serveur de référence, **absent** du code Ansible | Chapitre 11 — mode manuel documenté + rôle Ansible recommandé |
| **Alertmanager** (Prometheus) | Remplacé par l'**alerting natif Grafana** (provisionné) | Chapitre 10 |
| **Vault Ansible** (fichier chiffré réel) | Non committé (volontaire) ; seul l'exemple est fourni | Chapitre 8 |
| Réseaux **TLS internes** (Loki/Alloy/Prometheus) | Non chiffrés : flux sur les réseaux Docker privés | Chapitre 9 (choix assumé) |
| Rotation automatisée des secrets applicatifs | Manuelle | Chapitres 6 et 13 |

> 📌 **Recommandation** — avant mise en production réelle, traiter au minimum
> les sauvegardes et la rotation des secrets (chapitres 6, 14, 16).

## 1.4 Conventions du document

- `blocs de code` : commandes à exécuter sur le serveur, sur le poste
  administrateur ou dans un conteneur — le contexte est précisé en commentaire
  (`# poste admin`, `# serveur`, `# conteneur`).
- `> ⚠️ Avertissement` : point de vigilance important (risque de perte d'accès,
  d'écriture, etc.).
- `> 📌 Recommandation` : complément **non présent dans le dépôt**, proposé à
  part.
- **Mermaid** : schémas rendus par les éditeurs Markdown compatibles (GitHub,
  Obsidian, VS Code).

---


