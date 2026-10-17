##Journal de bord

### Étape 0 :

La VM Fonctionne. NAT → Passage qui permet à la VM d’aller sur internet en passant par mon PC dans un sens unique. Réseau privé d’hôte : Cable réseau privé virtuel sans internet il fonctionne dans les 2 sens et c’est grâce à lui qu’on peut accéder au SSH

### Étape 1 :

Une fois la VM lancer : Il faut regarder l’IP de son réseau privé d’hôte pour pouvoir se connecter en SSH, puis regarder si le paquet openssh-server est installé via dpkg -l | grep openssh-server (ii signifie que j’ai demandé l’installation et qu’il est bien installé.) puis regarder si ssh.socket est actif via systemctl is-active ssh.socket et s’il est activé via systemctl is-enabled ssh.socket. S’ils sont bien activé → Alors sur la machine hôte, il faut lancer powershell puis se connecter en SSH via ssh NomUserLinux@IPDuRéseauPrivé. 

### Étape 2 :

Pour mettre git en place il faut d’abord regarder si git est installé via dpkg -l | grep git. Puis git config —global user.name / user.email + nom/email (avec valeur écrit sans valeur lit puis connecté git à github via ssh en associant sa clé publique créé avec keygen. Ensuite se connecter à GitHub via SSH avec la commande ssh git@github.com . à ce Moment j’ai rencontré un problème de DNS car j’ai lancé ma VM sur une ip différente de celle sur laquelle je travailles actuellement j’ai donc fait passer la résolution de DNS par ma machine hôte avec la commande .\VBoxManage.exe modifyvm "NomDeLaVM" --natdnshostresolver1 on sur ma machine hôte.

### Étape 3 : 

ufw : C’est un pare-feu (Uncomplicated Firewall), c’est une interface simplifiée du pare-feu de Linux qui est Netfilter .

pg_hba : Host-Based Authentication soit authentification selon la machine d’**origine** de la connexion

**Écriture du script bash :** je teste d’abord les commandes sur ma machine et si elles fonctionnent alors je les intégre proprement au script (apt-get pour installer dans un script) (--yes pour confirmer les demandes). Le script pour l’instant se déroule comme ceci → 3 protections -e : arrête le script dès qu’une commande échoue (code de sortie autre que 0) -u : arrête le script si une variable n’existe pas -o pipefail vérifie si une erreur se produit lors d’un | → Check si l’utilisateur est root sinon on termine avec message d’erreur → puis on met à jour le catalogue → puis on installe le paquet postgresql avec --yes pour valider les demandes et en rendant le script autonome → puis on vérifie si postgresql est bien actif et accepte les connexions. J’ai ajouté la version de postgresql en tant que variable au cas ou la version changerait, j’ai aussi ajouté dans le script une écriture dans le fichier listenaddresses.conf dans conf.d pour que postgresql écoute partout (l’ip dépendra de la machine du correcteur mais pour être sur on le fait écouter partout et puisque notre VM et en NAT donc avec une connexion à sens unique VM vers machine hôte ça ne pose pas de soucis de sécurité car déjà filtré par pg_hba et par la suite on ajoutera une sécurité via ufw.) et également un redémarrage de postgresql pour qu’il pointe vers les valeurs de listen_addresses dans listenaddresses.conf et ensuite via pg_isready on vérifie si postgresql et actif et qu’il attend bien des connexions. Le déroulé du script est maintenant : 

**Modification pg_hba.conf dans le script :** pg_hba.conf c’est la liste des invités de PostgreSql, par défaut elle n’accepte que ma VM, mais comme je veux pouvoir modifer ma base de données via windows, je dois rajouté dans cette liste l’addresse de mon réseau privé qui est ici 192.168.56.0/24 que j’ai défini en tant que variable au début du script `reseauprive` il la faut modifier si on a pas une IP valable pour que ma machine hôte ait le droit de se connecter à Postgresql, il faut tout de même un mot de passe pour se connecter (scram-sha-256). Dans le fichier de config la première ligne est la ligne administrateur/postgres, si elle disparait plus personne ne peut toucher a la base de données postgres. Donc on a rajouté au script une étape qui modifie tout le fichier via cat > et un heredocument à chaque fois qu’on relance le script. Il est donc idempotent, pour vérifier cela j’ai regarde dans la table pg_hba_file_rules de postgres et peut importe le nombre de fois que je relance le script le résultat est le même.

**Modification ufw dans le script :** Tout d’abord il faut checker s’il est installé via : dpkg -l | grep ufw, il l’est c’est bon. J’ai mit comme regle de tout fermer via `sudo ufw default deny incoming`  il faudra par la suite ouvrir uniquement ce dont on a besoin. Puis j’ai autorisé les sorties pour par exemple pouvoir télécharger des paquets via `apt-get` ou envoyer sur github. Ensuite on doit ouvrir le port pour le SSH via `ufw allow from 192.168.56.0/24 to any port 22 proto tcp` et pour postgresql via `ufw allow from 192.168.56.0/24 to any port 5432 proto tcp`. Puis activer les règles via `ufw enable -- force` (--force pour avoir avoir de message de confirmation). J'ai rajouté des étapes de robustesse et de vérification notamment sur la vérification du statut d'ufw pour voir s'il est actif via un grep `ufw status | grep -q "Status: active`. Et pour rajouter du confort visuel j'ai défini des variables de couleurs et des echos avec des couleurs avec l'option -e (ne pas oublier de reset la couleur a la fin de la chaine de caractères).

1. vérification root
2. mise à jour du catalogue
3. installation postgresql + ufw (apt-get, `-yes`)
4. verification que le dossier /etc/postgresql/18/main existe
5. écriture du fichier listen_addressesconf dans conf.d
6. réécriture du fichier pg_hba.conf
7. redémarrage
8. vérification avec pg_isready.
9. écriture des règles ufw entrée/sortie
10. écriture des autorisations d’entrée pour ssh et postgresql
11. activation des écritures pour ufw
12. vérification qu’ufw est actif
13. message de réussite général
