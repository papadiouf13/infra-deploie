#!/usr/bin/env bash
# =====================================================================
# scripts/standalone-prep.sh — prépare UN NOUVEAU SERVEUR à déployer
# l'infra depuis lui-même (nœud de contrôle = cible), sans WSL.
#
# À exécuter SUR le serveur, après :
#   git clone https://github.com/papadiouf13/infra-deploie.git
#   cd infra-deploie  &&  scripts/standalone-prep.sh
#
# Crée :
#   1. les outils contrôleur (python3, pip, ansible + collections)
#   2. ansible/inventories/<env>/hosts.ini          (mode local)
#   3. ansible/group_vars/vault.yml chiffré         (s'il manque)
#   4. ansible/group_vars/server_vars.yml           (re-définition serveur)
#   5. .vault-pass  (mot de passe vault)
# puis affiche les commandes make à lancer.
#
# Idempotent : les fichiers déjà présents ne sont pas écrasés.
# =====================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_DIR"

echo "=== 1/5 Outils contrôleur ==="
if ! command -v ansible-playbook >/dev/null 2>&1; then
  if ! command -v python3 >/dev/null 2>&1; then
    sudo apt update && sudo apt install -y python3 python3-pip python3-venv
  fi
  if ! command -v pip3 >/dev/null 2>&1 && ! command -v pip >/dev/null 2>&1; then
    sudo apt install -y python3-pip
  fi
  # PEP 668 (Ubuntu 24.04+) : pip bloque l'installation hors venv.
  # On tente d'abord normalement ; en cas d'échec on relance avec --break-system-packages.
  python3 -m pip install --user --upgrade ansible-core \
    || python3 -m pip install --user --break-system-packages --upgrade ansible-core
  export PATH="$HOME/.local/bin:$PATH"
  # Rendre le PATH persistant pour les sessions futures (sinon make ne trouve pas ansible-playbook).
  if ! grep -q '.local/bin' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
    echo "> Ajout pour mémoire : export PATH=\"\$HOME/.local/bin:\$PATH\" in ~/.bashrc"
  fi
fi
# Vérifier la présence réelle des collections (le `list` renvoie 0 même si rien n'est installé).
if [ ! -d "$HOME/.ansible/collections/ansible_collections/community/docker" ] \
  || [ ! -d "$HOME/.ansible/collections/ansible_collections/community/general" ]; then
  ansible-galaxy collection install -r ansible/requirements.yml
fi
echo "Ansible : $(ansible-playbook --version 2>/dev/null | head -1)"

echo
echo "=== 2/5 Environnement (dev|prod) ==="
ENV="${1:-}"
if [ -z "$ENV" ]; then
  read -r -p "Environnement de l'inventaire [dev|prod] (défaut: dev) : " ENV
  ENV="${ENV:-dev}"
fi
INV_DIR="ansible/inventories/$ENV"
INV_FILE="$INV_DIR/hosts.ini"

if [ ! -f "$INV_FILE" ]; then
  [ -f "$INV_DIR/hosts.ini.example" ] || { echo "ERREUR: pas d'exemple $INV_DIR/hosts.ini.example"; exit 1; }
  echo "l'inventaire $INV_FILE n'existe pas -> on le crée (mode local)."
  read -r -p "server_name (ex: vps2) : " SERVER_NAME
  read -r -p "public_ip (IP LAN de CE serveur, vue depuis ton poste Windows — VM VMware bridged : ex 192.168.175.x ; DuckDNS pointe automatiquement l'IP publique) : " PUBLIC_IP
  read -r -p "ansible_user (compte SSH admin) [ubuntu] : " ANS_USER
  ANS_USER="${ANS_USER:-ubuntu}"
  read -r -s -p "ansible_become_password (sudo, laissé vide si NOPASSWD) : " BECOME_PASS; echo
  read -r -p "private_ip (défaut = public_ip) : " PRIVATE_IP
  PRIVATE_IP="${PRIVATE_IP:-$PUBLIC_IP}"

  {
    echo "# Inventaire $ENV (généré par standalone-prep.sh)"
    echo "# Nœud de contrôle = la machine elle-même (ansible_connection=local)."
    echo "[$ENV]"
    echo "$ENV ansible_host=127.0.0.1 public_ip=$PUBLIC_IP private_ip=$PRIVATE_IP server_name=$SERVER_NAME ansible_connection=local"
    echo ""
    echo "[all:vars]"
    echo "ansible_user=$ANS_USER"
    echo "ansible_become=true"
    [ -n "$BECOME_PASS" ] && echo "ansible_become_password=$BECOME_PASS"
  } > "$INV_FILE"
  chmod 600 "$INV_FILE"
  echo "écrit : $INV_FILE"
else
  echo "inventaire existant (conservé) : $INV_FILE"
fi

echo
echo "=== 3/5 Vault ==="
VAULT_FILE="ansible/group_vars/vault.yml"
if [ ! -f "$VAULT_FILE" ]; then
  [ -f "ansible/group_vars/vault.yml.example" ] || { echo "ERREUR: pas d'exemple vault"; exit 1; }
  cp "ansible/group_vars/vault.yml.example" "$VAULT_FILE"
  echo "> copié vault.yml.example -> $VAULT_FILE"
  echo "> ÉDITEZ MAINTENANT ce fichier (valeurs réelles) PUIS chiffrez (étape 5) :"
  echo "    nano $VAULT_FILE"
else
  echo "vault existant (conservé) : $VAULT_FILE"
fi

echo
echo "=== 4/5 Variables spécifiques au serveur ==="
SV_FILE="ansible/group_vars/server_vars.yml"
if [ ! -f "$SV_FILE" ]; then
  cp "ansible/group_vars/server_vars.yml.example" "$SV_FILE"
  echo "> copié server_vars.yml.example -> $SV_FILE"
  echo "> À ÉDITER : surtout infra_domain (sous-domaine DuckDNS de CE serveur)."
else
  echo "server_vars existant (conservé) : $SV_FILE"
fi

echo
echo "=== 5/5 Mot de passe vault + chiffrage ==="
if [ ! -f ".vault-pass" ]; then
  read -r -s -p "Choisir le mot de passe vault (laisser vide = générer) : " VAULTPASS; echo
  if [ -z "$VAULTPASS" ]; then
    VAULTPASS="$(python3 -c "import secrets; print(''.join(secrets.choice('abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-.') for _ in range(32)))")"
    echo "  (généré : $VAULTPASS)"
  fi
  umask 077
  printf '%s' "$VAULTPASS" > .vault-pass
  echo "> .vault-pass créé (gardez-le : indispensable pour rejouer les playbooks)."
else
  echo ".vault-pass existant (conservé)."
fi

if [ -f "$VAULT_FILE" ] && ! grep -q '^\$ANSIBLE_VAULT' "$VAULT_FILE"; then
  read -r -p "Chiffrer $VAULT_FILE avec ce mot de passe ? [y/N] " ANS_ENC
  if [ "$ANS_ENC" = "y" ] || [ "$ANS_ENC" = "Y" ]; then
    ansible-vault encrypt --vault-password-file .vault-pass "$VAULT_FILE"
    echo "vault chiffré."
  else
    echo "> NON chiffré. Plus tard, depuis la racine du dépôt :"
    echo "    ansible-vault encrypt --vault-password-file .vault-pass $VAULT_FILE"
  fi
fi

echo
echo "================================================================"
echo " Prêt. Renseigner maintenant :"
echo "  1. nano ansible/group_vars/vault.yml      (valeurs réelles, agent brut)"
echo "     puis chiffrer : ansible-vault encrypt --vault-password-file .vault-pass ansible/group_vars/vault.yml"
echo "  2. nano ansible/group_vars/server_vars.yml    (infra_domain en tête)"
echo "================================================================"
echo " Commandes de déploiement :"
echo "   make configure ENV=$ENV VAULT_ARGS='--vault-password-file ../.vault-pass'"
echo "   make verify   ENV=$ENV VAULT_ARGS='--vault-password-file ../.vault-pass'"
echo "   make urls     ENV=$ENV"
echo "================================================================"