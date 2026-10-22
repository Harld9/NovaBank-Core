#!/bin/bash
set -euo pipefail

VERT_GRAS="\033[1;32m"
ROUGE_GRAS="\033[1;31m"
RESET="\033[0m"
NOM_DB=novabank
NOM_DB_VERIF=novabank_verif
FICHIER="sauvegardes/novabank_$(date +%F_%H-%M-%S).dump"

#verification pour savoir si l'utilisateur qui lance le script est root sinon on arrête le script
if [[ $EUID -ne 0 ]]; then
        echo "Ce script doit être lancé en tant que root !"
        exit 1
fi

#création du dossier de sauvegarde s'il n'existe pas
mkdir -p sauvegardes

#sauvegarde de la base de données au format custom (-Fc) : un fichier compressé que pg_restore sait relire
sudo -u postgres pg_dump -Fc "${NOM_DB}" > "${FICHIER}"

#message de réussite
echo -e "${VERT_GRAS}✓ Sauvegarde de la base novabank réalisée dans ${FICHIER} !${RESET}"

#une sauvegarde jamais restaurée ne prouve rien donc on la restaure dans une base temporaire pour vérifier
sudo -u postgres dropdb --if-exists "${NOM_DB_VERIF}"
sudo -u postgres createdb -O patron_novabank "${NOM_DB_VERIF}"

#< car postgres n'a pas le droit de lire notre dossier personnel, c'est root qui ouvre le fichier et l'envoie à pg_restore
sudo -u postgres pg_restore -d "${NOM_DB_VERIF}" < "${FICHIER}"

#on compare le nombre de lignes de chaque table entre la vraie base et la base restaurée
for TABLE in core.customers core.accounts core.transfers core.transactions core.fraud_alerts audit.audit_log; do
    NB_ORIGINE=$(sudo -u postgres psql -d "${NOM_DB}" -tAc "SELECT count(*) FROM ${TABLE}")
    NB_RESTAURE=$(sudo -u postgres psql -d "${NOM_DB_VERIF}" -tAc "SELECT count(*) FROM ${TABLE}")

    if [[ "${NB_ORIGINE}" == "${NB_RESTAURE}" ]]; then
        echo -e "${VERT_GRAS}✓ ${TABLE} : ${NB_ORIGINE} lignes dans les 2 bases${RESET}"
    else
        echo -e "${ROUGE_GRAS}✗ ${TABLE} : ${NB_ORIGINE} lignes dans novabank mais ${NB_RESTAURE} dans la sauvegarde${RESET}"
        exit 1
    fi
done

#on supprime la base temporaire qui ne sert plus
sudo -u postgres dropdb "${NOM_DB_VERIF}"

#message final de réussite
echo -e "${VERT_GRAS}✓ La sauvegarde a été restaurée et vérifiée, elle est bonne !${RESET}"
