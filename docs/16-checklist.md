# 16. Checklist de mise en production d'un serveur neuf

> Chaque étape doit être validée avant de passer à la suivante. Cette
> checklist formalise la promesse « kif kif » : un serveur qui reproduit
> exactement l'infrastructure de la VM de référence.

- [ ] **D. Poste admin**
  - [ ] AWS CLI configuré, key pair créée (`~/.ssh/monitoring-key.pem`)
  - [ ] Terraform/Ansible/collections installées (7.1)
- [ ] **Terraform**
  - [ ] scolaire variables `*.tfvars` (admin_cidr ≠ 0.0.0.0/0 !) 
  - [ ] `terraform plan`/`apply` à workspace dev
  - [ ] `make inventory`
- [ ] **Provisioning**
  - [ ] `make configure ENV=dev` (vault prompted) 
  - [ ] `make verify ENV=dev`
  - [ ] port 80/443 seuls publiés
- [ ] **DNS/TLS**
  - [ ] hostnames nip.io visibles, certs LE (ou staging) OK, 80→443
- [ ] **Monitoring**
  - [ ] Prometheus 200 (avec auth), targets UP, Loki pèse des logs, Grafana 200/admin OK, dashboards présents (dont logs utilisable)
  - [ ] alertes: simulate fail → contact point (email) reçoit
  - [ ] **Trivy** : un scan noté dans `trivy.jsonl`, dashboard `trivy.json` rempli, alerte `alert-trivy-critical` provisionnée
- [ ] **CI/CD apps**
  - [ ] runners installés/vérifiés (GH check green)
  - [ ] secrets GitHub complets (11.3) et `SECRET_KEY` non-placeholder
  - [ ] `deploy` sur master → app up, Swagger `/api` OK, front OK
  - [ ] images privées (ou au moins décision assumée)
- [ ] **Sécurisation**
  - [ ] `admin_cidr` IP admin (P+firewall), Grafana admin=vault, fail2ban actif, MFA AWS
- [ ] **Backups/DRP**
  - [ ] backups automatisées + test de restauration, off-site
- [ ] **Documentation** — ce document à jour (IP, hostnames, runners)

---


