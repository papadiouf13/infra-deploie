#!/usr/bin/env bash
# =====================================================================
# scripts/gen-bcrypt-hash.sh — génère un hash bcrypt pour Traefik
# basicAuth (Prometheus / dashboard Traefik).
#
# Usage :
#   scripts/gen-bcrypt-hash.sh "mon-mot-de-passe" [rounds]
#
# Le résultat s'écrit dans group_vars/vault.yml sous :
#   prometheus_basic_auth_hash: "<hash>"
#   traefik_dashboard_basic_auth_hash: "<hash>"
#
# Dépendances (une au choix) :
#   - python3 + module "bcrypt" (pip install bcrypt)
#   - htpasswd du paquet apache2-utils
# =====================================================================
set -euo pipefail

PASSWORD="${1:?Usage: $0 <password> [rounds]}"
ROUNDS="${2:-12}"

if command -v python3 >/dev/null 2>&1 && python3 -c "import bcrypt" 2>/dev/null; then
  HASH="$(python3 -c "import bcrypt,sys; print(bcrypt.hashpw(sys.argv[1].encode(), bcrypt.gensalt(rounds=int(sys.argv[2]))).decode())" "$PASSWORD" "$ROUNDS")"
elif command -v htpasswd >/dev/null 2>&1; then
  HASH="$(htpasswd -nbB -C "$ROUNDS" user "$PASSWORD" | cut -d: -f2)"
else
  echo "ERREUR: ni python3+bcrypt ni htpasswd ne sont disponibles." >&2
  exit 1
fi

echo "Hash bcrypt généré :"
echo "$HASH"
echo
echo "À copier dans group_vars/vault.yml :"
echo "  prometheus_basic_auth_hash: \"$HASH\""