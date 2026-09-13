# Projet de démonstration

Deux conteneurs `whoami` étiquetés `project=demo`, routés par Traefik sous
`demo-api` et `demo-web`. Objectif : voir les dashboards **Projets** et
**Projet — détail** avec de vraies données sur un serveur qui n'héberge encore
aucune application. À supprimer une fois la vérification faite.

## Déployer

```bash
sudo mkdir -p /opt/apps/demo
sudo cp ~/infra-deploie/examples/demo-project/docker-compose.yml /opt/apps/demo/
sudo cp ~/infra-deploie/examples/demo-project/.env.example /opt/apps/demo/.env
sudo nano /opt/apps/demo/.env          # vérifier INFRA_DOMAIN
cd /opt/apps/demo && sudo docker compose up -d
```

## Générer du trafic

Depuis un navigateur : `https://demo.<INFRA_DOMAIN>/` et
`https://demo.<INFRA_DOMAIN>/api`. Ou depuis le serveur :

```bash
for i in $(seq 1 60); do
  curl -sk -o /dev/null --resolve demo.<INFRA_DOMAIN>:443:127.0.0.1 https://demo.<INFRA_DOMAIN>/
  curl -sk -o /dev/null --resolve demo.<INFRA_DOMAIN>:443:127.0.0.1 https://demo.<INFRA_DOMAIN>/api
done
```

Un 404 volontaire alimente la courbe des 4xx :

```bash
curl -sk -o /dev/null --resolve demo.<INFRA_DOMAIN>:443:127.0.0.1 https://demo.<INFRA_DOMAIN>/api/inexistant
```

## Ce que tu dois voir

Dans **Projets** : une carte `demo` (2 services, CPU, RAM), une ligne dans le
tableau, et des courbes dans « Trafic HTTP par projet ». Un clic sur la carte
ouvre **Projet — détail** filtré sur `demo`, avec ses deux routers.

## Supprimer

```bash
cd /opt/apps/demo && sudo docker compose down
sudo rm -rf /opt/apps/demo
```
