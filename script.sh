#!/bin/bash
set -euo pipefail

#definition variables
versionpostgresql=18
reseauprive=192.168.56.0/24
cheminpostgresql="/etc/postgresql/${versionpostgresql}/main"
VERT_GRAS="\033[1;32m"
RESET="\033[0m"

#verification pour savoir si l'utilisateur qui lance le script est root sinon on arrête le script
if [[ $EUID -ne 0 ]]; then
        echo "Ce script doit être lancé en tant que root !"
        exit 1
fi

#mis à jour des paquets
apt-get update

#installation postgresql et ufw avec assume yes pour pas avoir à taper notre choix en plein milieu du script
apt-get --yes install postgresql
apt-get --yes install ufw

#verification de l'existence du dossier /etc/postgresql/18/main
if [[ ! -d ${cheminpostgresql} ]]; then
	echo "Une erreur s'est produite à l'installation de PostgreSql le script ne le trouve pas"
	exit 1
fi

#message 1/3
echo -e "${VERT_GRAS}✓ Étape 1 : Installation de PostgreSql et UFW réalisée 1/3 !${RESET}"

#ecriture des listen_addresses dans /etc/postgresql/18/main/conf.d/listenaddresses.conf
echo listen_addresses = "'*'" > "${cheminpostgresql}/conf.d/listenaddresses.conf"

#ecriture configuration hba postgresql pour définir qui a le droit de rentrer
cat << EOF > "${cheminpostgresql}/pg_hba.conf"
# PostgreSQL Client Authentication Configuration File
# ==================================================

# ----------------------------------
# Put your actual configuration here
# ----------------------------------

local   all             postgres                                peer

# TYPE  DATABASE        USER            ADDRESS                 METHOD

# "local" is for Unix domain socket connections only
local   all             all                                     peer
# IPv4 local connections:
host    all             all             127.0.0.1/32            scram-sha-256
# IPv6 local connections:
host    all             all             ::1/128                 scram-sha-256
# Allow replication connections from localhost, by a user with the
# replication privilege.
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256
host    all             all             ${reseauprive}        scram-sha-256
EOF

#redemarrage de postgresql pour qu'il modifie ses listen_addresses et qu'elles pointent bien vers listenaddresse.conf et qu'il modifie les configurations hba
systemctl restart postgresql

#verification que postgresql est bien actif
if ! pg_isready -qh localhost ; then
        echo "Postgresql a rencontré une erreur et n'est pas actif"
        exit 1
fi

#message 2/3
echo -e "${VERT_GRAS}✓ Étape 2 : Configuration PostgreSql terminée 2/3 !${RESET}"

#modifier les politiques par défaut de ufw 
ufw default deny incoming
ufw default allow outgoing

#modifier les regles d'ufw pour accepter les connexions sur le port 22 (SSH) et le port 5432 (PostgreSQL)
ufw allow from ${reseauprive} to any port 22 proto tcp
ufw allow from ${reseauprive} to any port 5432 proto tcp

#mettre en action les regles établies au-dessus
ufw --force enable 

#verification qu'ufw est bien actif
if ! ufw status | grep -q "Status: active" ; then
        echo "ufw a rencontré une erreur et n'est pas actif"
        exit 1
fi

#message 3/3
echo -e "${VERT_GRAS}✓ Étape 3 : Configuration ufw terminée 3/3 !${RESET}"

echo -e "${VERT_GRAS}✓ Tout s'est bien passé PostgreSQL est installé et actif, ufw est installé et actif et pg_hba a bien été configuré !${RESET}"
