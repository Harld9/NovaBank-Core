#!/bin/bash
set -euo pipefail

#definition variables
versionpostgresql=18
reseauprive=192.168.56.0/24
cheminpostgresql="/etc/postgresql/${versionpostgresql}/main"
VERT_GRAS="\033[1;32m"
RESET="\033[0m"
nomdb=novabank

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

#message réussite étape 1
echo -e "${VERT_GRAS}✓ Étape 1 : Installation de PostgreSql et UFW réalisées !${RESET}"

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

#message réussite étape 2
echo -e "${VERT_GRAS}✓ Étape 2 : Configuration PostgreSql terminée !${RESET}"

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

#message réussite étape 3
echo -e "${VERT_GRAS}✓ Étape 3 : Configuration ufw terminée !${RESET}"


#lance postgres en tant que postgres et créé la db
sudo -u postgres psql -v ON_ERROR_STOP=ON -f ./sql/01_base.sql

#message réussite étape 4
echo -e "${VERT_GRAS}✓ Étape 4 : Création de la base de données et des schémas réussie !${RESET}"

#se connecte à la db nomdb et créé les tables avec les colonnes et les types
sudo -u postgres psql -v ON_ERROR_STOP=ON -f ./sql/02_tables.sql -d ${nomdb}

#message réussite étape 5
echo -e "${VERT_GRAS}✓ Étape 5 : Création des tables et des types réussie !${RESET}"

#se connecte à la db nomdb et créé les tables avec les colonnes et les types
sudo -u postgres psql -v ON_ERROR_STOP=ON -f ./sql/03_donnees.sql -d ${nomdb}

#message réussite étape 6
echo -e "${VERT_GRAS}✓ Étape 6 : Insertion des données dans les tables réussie !${RESET}"

#se connecte à la db nomdb et supprime puis recréé les roles et donnes les droits sur la db aux roles
sudo -u postgres psql -v ON_ERROR_STOP=ON -f ./sql/04_droits.sql -d ${nomdb}

#definition du mot de passe par le lanceur du script
sudo -u postgres psql -d ${nomdb} -c "\password harold_analyst"
sudo -u postgres psql -d ${nomdb} -c "\password harold_support"
sudo -u postgres psql -d ${nomdb} -c "\password harold_appli"
sudo -u postgres psql -d ${nomdb} -c "\password harold_auditeur"


#message réussite étape 7
echo -e "${VERT_GRAS}✓ Étape 7 : Création des roles et configuration des droits réussies !${RESET}"

#se connecte à la db nomdb et créé les vues puis attribue les roles
sudo -u postgres psql -v ON_ERROR_STOP=ON -f ./sql/05_vues.sql -d ${nomdb}

#message réussite étape 8
echo -e "${VERT_GRAS}✓ Étape 8 : Création des vues et attribution des droits réussies !${RESET}"

#affichage du temps d'une requête dans core.transactions SANS index
echo "Temps d'une requête SANS index : $(sudo -u postgres psql -d "${nomdb}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.transactions WHERE account_id = 42;" | grep "Execution Time")"

#création des index
sudo -u postgres psql -v ON_ERROR_STOP=ON -f ./sql/06_index.sql -d "${nomdb}"

#affichage du temps d'une requête dans core.transactions AVEC index
echo "Temps d'une requête AVEC index : $(sudo -u postgres psql -d "${nomdb}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.transactions WHERE account_id = 42;" | grep "Execution Time")"

#message réussite étape 9
echo -e "${VERT_GRAS}✓ Étape 9 : Création des index réussie !${RESET}"

#creation des triggers
sudo -u postgres psql -v ON_ERROR_STOP=ON -f ./sql/07_triggers.sql -d "${nomdb}"

#message réussite étape 10
echo -e "${VERT_GRAS}✓ Étape 10 : Création des triggers réussie !${RESET}"

#creation des procedures
sudo -u postgres psql -v ON_ERROR_STOP=ON -f ./sql/08_procedures.sql -d "${nomdb}"

#message réussite étape 11
echo -e "${VERT_GRAS}✓ Étape 11 : Création des procédures réussie !${RESET}"

#message final de réussite
echo -e "${VERT_GRAS}✓ Tout s'est bien passé, tout a bien été configuré !${RESET}"
