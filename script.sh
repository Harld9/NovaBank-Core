#!/bin/bash
set -euo pipefail

#definition variables
VERSION_POSTGRESQL=18
RESEAU_PRIVE=192.168.56.0/24
CHEMIN_POSTGRESQL="/etc/postgresql/${VERSION_POSTGRESQL}/main"
VERT_GRAS="\033[1;32m"
BLEU_GRAS="\033[1;34m"
RESET="\033[0m"
NOM_DB=novabank
CHEMIN_FICHIERS_SQL=$(cd "$(dirname "$0")" && pwd)/sql

#verification pour savoir si l'utilisateur qui lance le script est root sinon on arrête le script
if [[ $EUID -ne 0 ]]; then
        echo "Ce script doit être lancé en tant que root !"
        exit 1
fi

#confirmation de l'utilisateur
while true; do
    read -p "Souhaitez-vous réellement supprimer la base de données (si elle existe) pour la recréer ? (o/n) : " choix

    if [[ "$choix" == "o" || "$choix" == "O" || "$choix" == "y" || "$choix" == "Y" ]]; then
	echo "Le script continue"
        break # Sort de la boucle pour exécuter la suite du script
    elif [[ "$choix" == "n" || "$choix" == "N" ]]; then
        echo "Le script s'arrête car vous avez refusé."
        exit 1 # Arrête complètement le script
    else
        echo "Saisie invalide. Veuillez répondre par oui (o/y) ou non (n)."
        echo "" # Optionnel : affiche une ligne vide pour aérer le texte
    fi
done

#mis à jour des paquets
apt-get update

#installation postgresql et ufw avec assume yes pour pas avoir à taper notre choix en plein milieu du script
apt-get --yes install postgresql
apt-get --yes install ufw

#verification de l'existence du dossier /etc/postgresql/18/main
if [[ ! -d ${CHEMIN_POSTGRESQL} ]]; then
	echo "Une erreur s'est produite à l'installation de PostgreSql le script ne le trouve pas"
	exit 1
fi

#message réussite étape 1
echo -e "${VERT_GRAS}✓ Étape 1 : Installation de PostgreSql et UFW réalisées !${RESET}"

#ecriture des listen_addresses dans /etc/postgresql/18/main/conf.d/listenaddresses.conf
echo listen_addresses = "'*'" > "${CHEMIN_POSTGRESQL}/conf.d/listenaddresses.conf"

#ecriture configuration hba postgresql pour définir qui a le droit de rentrer
cat << EOF > "${CHEMIN_POSTGRESQL}/pg_hba.conf"
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
host    all             all             ${RESEAU_PRIVE}        scram-sha-256
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
ufw allow from ${RESEAU_PRIVE} to any port 22 proto tcp
ufw allow from ${RESEAU_PRIVE} to any port 5432 proto tcp

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
sudo -u postgres psql -v ON_ERROR_STOP=ON < "${CHEMIN_FICHIERS_SQL}/01_base.sql"

#configuration mot de passe pour le patron until relance la commande tant qu'elle échoue
until sudo -u postgres psql -d ${NOM_DB} -c "\password patron_novabank"
do
    echo "Les mots de passe ne correspondent pas. Réessaie."
done

#message réussite étape 4
echo -e "${VERT_GRAS}✓ Étape 4 : Création de la base de données et des schémas réussie !${RESET}"

#se connecte à la db NOM_DB et créé les tables avec les colonnes et les types
sudo -u postgres psql -v ON_ERROR_STOP=ON < "${CHEMIN_FICHIERS_SQL}/02_tables.sql" -d ${NOM_DB}

#message réussite étape 5
echo -e "${VERT_GRAS}✓ Étape 5 : Création des tables et des types réussie !${RESET}"

#se connecte à la db NOM_DB et créé les tables avec les colonnes et les types
sudo -u postgres psql -v ON_ERROR_STOP=ON < "${CHEMIN_FICHIERS_SQL}/03_donnees.sql" -d ${NOM_DB}

#message réussite étape 6
echo -e "${VERT_GRAS}✓ Étape 6 : Insertion des données dans les tables réussie !${RESET}"

#se connecte à la db NOM_DB et supprime puis recréé les roles et donnes les droits sur la db aux roles
sudo -u postgres psql -v ON_ERROR_STOP=ON < "${CHEMIN_FICHIERS_SQL}/04_droits.sql" -d ${NOM_DB}

#configuration des mots de passe des differents roles
until sudo -u postgres psql -d ${NOM_DB} -c "\password employe_analyst"
do
    echo "Les mots de passe ne correspondent pas. Réessaie."
done

until sudo -u postgres psql -d ${NOM_DB} -c "\password employe_support"
do
    echo "Les mots de passe ne correspondent pas. Réessaie."
done

until sudo -u postgres psql -d ${NOM_DB} -c "\password employe_appli"
do
    echo "Les mots de passe ne correspondent pas. Réessaie."
done

until sudo -u postgres psql -d ${NOM_DB} -c "\password employe_auditeur"
do
    echo "Les mots de passe ne correspondent pas. Réessaie."
done

#message réussite étape 7
echo -e "${VERT_GRAS}✓ Étape 7 : Création des roles et configuration des droits réussies !${RESET}"

#se connecte à la db NOM_DB et créé les vues puis attribue les roles
sudo -u postgres psql -v ON_ERROR_STOP=ON < "${CHEMIN_FICHIERS_SQL}/05_vues.sql" -d ${NOM_DB}

#message réussite étape 8
echo -e "${VERT_GRAS}✓ Étape 8 : Création des vues et attribution des droits réussies !${RESET}"

#affichage du temps d'une requête dans core.transactions SANS index
#à factoriser plus tard via une fonction
echo -e "${BLEU_GRAS}Temps d'une requête SANS index : $(sudo -u postgres psql -d "${NOM_DB}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.transactions WHERE account_id = 42;" | grep "Execution Time")${RESET}"
echo -e "${BLEU_GRAS}Temps d'une requête SANS index : $(sudo -u postgres psql -d "${NOM_DB}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.accounts WHERE customer_id = 84;" | grep "Execution Time")${RESET}"
echo -e "${BLEU_GRAS}Temps d'une requête SANS index : $(sudo -u postgres psql -d "${NOM_DB}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.transfers WHERE from_account_id = 122;" | grep "Execution Time")${RESET}"
echo -e "${BLEU_GRAS}Temps d'une requête SANS index : $(sudo -u postgres psql -d "${NOM_DB}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.transactions WHERE created_at >= '2026-08-12' AND created_at < '2026-08-13';" | grep "Execution Time")${RESET}"

#création des index
sudo -u postgres psql -v ON_ERROR_STOP=ON < "${CHEMIN_FICHIERS_SQL}/06_index.sql" -d "${NOM_DB}"

#affichage du temps d'une requête dans core.transactions AVEC index
echo -e "${BLEU_GRAS}Temps d'une requête AVEC index : $(sudo -u postgres psql -d "${NOM_DB}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.transactions WHERE account_id = 42;" | grep "Execution Time")${RESET}"
echo -e "${BLEU_GRAS}Temps d'une requête AVEC index : $(sudo -u postgres psql -d "${NOM_DB}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.accounts WHERE customer_id = 84;" | grep "Execution Time")${RESET}"
echo -e "${BLEU_GRAS}Temps d'une requête AVEC index : $(sudo -u postgres psql -d "${NOM_DB}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.transfers WHERE from_account_id = 122;" | grep "Execution Time")${RESET}"
echo -e "${BLEU_GRAS}Temps d'une requête AVEC index : $(sudo -u postgres psql -d "${NOM_DB}" -t -c "EXPLAIN ANALYZE SELECT * FROM core.transactions WHERE created_at >= '2026-08-12' AND created_at < '2026-08-13';" | grep "Execution Time")${RESET}"

#message réussite étape 9
echo -e "${VERT_GRAS}✓ Étape 9 : Création des index réussie !${RESET}"

#creation des triggers
sudo -u postgres psql -v ON_ERROR_STOP=ON < "${CHEMIN_FICHIERS_SQL}/07_triggers.sql" -d "${NOM_DB}"

#message réussite étape 10
echo -e "${VERT_GRAS}✓ Étape 10 : Création des triggers réussie !${RESET}"

#creation des procedures
sudo -u postgres psql -v ON_ERROR_STOP=ON < "${CHEMIN_FICHIERS_SQL}/08_procedures.sql" -d "${NOM_DB}"

#message réussite étape 11
echo -e "${VERT_GRAS}✓ Étape 11 : Création des procédures réussie !${RESET}"

#message final de réussite
echo -e "${VERT_GRAS}✓ Tout s'est bien passé, tout a bien été configuré !${RESET}" 
