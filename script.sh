#!/bin/bash
set -euo pipefail

#definition variables
versionpostgresql=18
reseauprive=192.168.56.0/24
cheminpostgresql="/etc/postgresql/${versionpostgresql}/main"

#verification pour savoir si l'utilisateur qui lance le script est root sinon on arrête le script
if [[ $EUID -ne 0 ]]; then
        echo "Ce script doit être lancé en tant que root !"
        exit 1
fi

#mis à jour des paquets
apt-get update

#installation postgresql avec assume yes pour pas avoir à dire y en plein milieu du script
apt-get --yes install postgresql

if [[ ! -d ${cheminpostgresql} ]]; then
	echo "Une erreur s'est produite à l'installation de PostgreSql le script ne le trouve pas"
	exit 1
fi

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

