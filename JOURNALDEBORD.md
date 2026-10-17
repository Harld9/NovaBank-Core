## Journal de bord

### Étape 0 :

La VM Fonctionne. NAT → Passage qui permet à la VM d’aller sur internet en passant par mon PC dans un sens unique. Réseau privé d’hôte : Cable réseau privé virtuel sans internet il fonctionne dans les 2 sens et c’est grâce à lui qu’on peut accéder au SSH

### Étape 1 :

Une fois la VM lancer : Il faut regarder l’IP de son réseau privé d’hôte pour pouvoir se connecter en SSH, puis regarder si le paquet openssh-server est installé via `dpkg -l | grep openssh-server` (ii signifie que j’ai demandé l’installation et qu’il est bien installé.) puis regarder si ssh.socket est actif via `systemctl is-active ssh.socket` et s’il est activé via `systemctl is-enabled ssh.socket`. S’ils sont bien activé → Alors sur la machine hôte, il faut lancer powershell puis se connecter en SSH via `ssh NomUserLinux@IPDuRéseauPrivé`. 

### Étape 2 :

Pour mettre git en place il faut d’abord regarder si git est installé via `dpkg -l | grep git`. Puis `git config --global user.name / user.email + nom / email` (selon un schéma clé valeur, avec valeur->écriture, sans valeur -> lecture) puis connecté git à github via ssh en associant sa clé publique créé avec keygen. Ensuite se connecter à GitHub via SSH avec la commande `ssh git@github.com`.

### Étape 3 :

Écriture du script bash : je teste d’abord les commandes sur ma machine et si elles fonctionnent alors je les intégre proprement au script (apt-get pour installer dans un script) (--yes pour confirmer les demandes). Le script pour l’instant se déroule comme ceci → 3 protections -e : arrête le script dès qu’une commande échoue (code de sortie autre que 0) -u : arrête le script si une variable n’existe pas -o pipefail vérifie si une erreur se produit lors d’un | → Check si l’utilisateur est root sinon on termine avec message d’erreur → puis on met à jour le catalogue → puis on installe le paquet postgresql avec --yes pour valider les demandes et en rendant le script autonome → puis on vérifie si postgresql est bien actif et accepte les connexions. J’ai ajouté la version de postgresql en tant que variable au cas ou la version changerait, j’ai aussi ajouté dans le script une écriture dans le fichier listenaddresses.conf dans conf.d pour que postgresql écoute partout (l’ip dépendra de la machine du correcteur mais pour être sur on le fait écouter partout et puisque notre VM et en NAT donc avec une connexion à sens unique VM vers machine hôte ça ne pose pas de soucis de sécurité car déjà filtré par pg_hba et par la suite on ajoutera une sécurité via ufw.) et également un redémarrage de postgresql pour qu’il pointe vers les valeurs de listen_addresses dans listenaddresses.conf et ensuite via pg_isready on vérifie si postgresql et actif et qu’il attend bien des connexions. Le déroulé du script est maintenant : 

1. vérification root
2. mise à jour du catalogue
3. installation (apt-get, `-yes`)
4. écriture du fichier dans conf.d
5. redémarrage
6. vérification avec pg_isready.
