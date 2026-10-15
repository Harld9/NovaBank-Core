#!/bin/bash
set -euo pipefail

#verification pour savoir si l'utilisateur qui lance le script est root sinon on arrête le script
if [[ $EUID -ne 0 ]]; then
	echo "Ce script doit être lancé en tant que root !"
	exit 1
fi

#mis à jour des paquets
apt-get update

#installation postgresql avec assume yes pour pas avoir à dire y en plein milieu du script
apt-get --yes install postgresql

#verification que postgresql est bien actif
if ! pg_isready -q ; then
	echo "Postgresql a rencontré une erreur et n'est pas actif"
	exit 1
fi
