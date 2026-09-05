#!/bin/bash
# ---------------------------------------------------------------------
# user-data — volontairement minimal : installe SEULEMENT Python 3.
# Le reste (UFW, fail2ban, Docker, Traefik, monitoring, SonarQube...)
# est géré par Ansible (playbooks/site.yml), déclenché par `make configure`.
# ---------------------------------------------------------------------
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y python3 python3-apt python3-venv

# L'utilisateur Ansible doit être créé/validé.
if [ "${ansible_user}" != "ubuntu" ]; then
  id "${ansible_user}" >/dev/null 2>&1 || useradd -m -s /bin/bash "${ansible_user}"
fi

echo "user-data OK : python3 installé pour $(ansible_user)" > /var/log/user-data.log