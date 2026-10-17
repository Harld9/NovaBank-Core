#!/bin/bash
set -euo pipefail

#definition de la version de postgresql
versionpostgresql=18

#verification pour savoir si l'utilisateur qui lance le script est root sinon on arrête le script
if [[ $EUID -ne 0 ]]; then
	echo "Ce script doit être lancé en tant que root !"
	exit 1
fi

#mis à jour des paquets
apt-get update

#installation postgresql avec assume yes pour pas avoir à dire y en plein milieu du script
apt-get --yes install postgresql

#ecriture des listen_addresses dans /etc/postgresql/18/main/conf.d/listenaddresses.conf
echo listen_addresses = "'*'" > "/etc/postgresql/${versionpostgresql}/main/conf.d/listenaddresses.conf"

#redemarrage de postgresql pour qu'il modifie ses listen_addresses et qu'elles pointent bien listenaddresse.conf
systemctl restart postgresql

#verification que postgresql est bien actif
if ! pg_isready -qh localhost ; then
	echo "Postgresql a rencontré une erreur et n'est pas actif"
	exit 1
fi
