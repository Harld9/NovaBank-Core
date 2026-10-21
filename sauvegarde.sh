#!/bin/bash
set -euo pipefail

VERT_GRAS="\033[1;32m"
RESET="\033[0m"

#création du dossier de sauvegarde s'il n'existe pas
mkdir -p sauvegardes

#sauvegarde de la base de données a
sudo -u postgres pg_dump novabank > "sauvegardes/novabank_$(date +%F_%H-%M-%S).sql"

#message de réussite
echo -e "${VERT_GRAS}Sauvegarde de la base novabank réalisée !${RESET}"
