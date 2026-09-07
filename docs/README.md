# Manuel d'exploitation — table des chapitres

> Version découpée chapitre par chapitre du **manuel complet**.
> La version intégrale (introduction + sommaire + les 17 chapitres dans un seul
> fichier, avec les diagrammes d'architecture) est disponible dans
> [`MANUEL.md`](../MANUEL.md) à la racine du dépôt.

Ce dossier contient **un fichier par chapitre** pour une consultation ciblée.
Chaque chapitre est autonome ; les références croisées indiquent le numéro de
chapitre correspondant dans `MANUEL.md`.

| # | Chapitre | Fichier |
|---|----------|---------|
| 1 | Introduction et périmètre | [`01-introduction.md`](01-introduction.md) |
| 2 | Vue d'ensemble de l'architecture | [`02-architecture.md`](02-architecture.md) |
| 3 | Prérequis et hypothèses | [`03-prerequis.md`](03-prerequis.md) |
| 4 | Arborescence du projet | [`04-arborescence.md`](04-arborescence.md) |
| 5 | Documentation détaillée des fichiers et du code | [`05-fichiers.md`](05-fichiers.md) |
| 6 | Sécurisation (durcissement) | [`06-securisation.md`](06-securisation.md) |
| 7 | Dépendances et versions | [`07-dependances.md`](07-dependances.md) |
| 8 | Déploiement (de zéro et itératif) | [`08-deploiement.md`](08-deploiement.md) |
| 9 | Réseau, DNS, TLS | [`09-reseau-dns-tls.md`](09-reseau-dns-tls.md) |
| 10 | Monitoring, logs et alertes | [`10-monitoring-logs-alertes.md`](10-monitoring-logs-alertes.md) |
| 11 | Applications déployées : todo_back / todo_front et CI/CD | [`11-applications-cicd.md`](11-applications-cicd.md) |
| 12 | Validation / vérification (make verify) | [`12-validation.md`](12-validation.md) |
| 13 | Exploitation quotidienne et politique de mise à jour | [`13-exploitation.md`](13-exploitation.md) |
| 14 | Sauvegardes et reprise d'activité (DRP) | [`14-sauvegardes-drp.md`](14-sauvegardes-drp.md) |
| 15 | Dépannage (runbooks) | [`15-depannage.md`](15-depannage.md) |
| 16 | Checklist de mise en production d'un serveur neuf | [`16-checklist.md`](16-checklist.md) |
| 17 | Annexes | [`17-annexes.md`](17-annexes.md) |

## Comment utiliser ce dossier

- **Découverte** : lire `MANUEL.md` (ou le chapitre 2 pour l'architecture).
- **Tâche précise** : ouvrir le fichier du chapitre concerné (ex. *rollback* → 15).
- **Déploiement d'un serveur neuf** : suivre le chapitre 16 (checklist) qui
  référence toutes les étapes dans leur ordre.