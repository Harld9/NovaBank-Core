--création d'une procédure pour virement sécurisé
CREATE PROCEDURE virement_securise(p_compte_emetteur bigint, p_compte_destinataire bigint,p_montant numeric)
LANGUAGE plpgsql
AS $$
DECLARE
	id_min bigint;
	id_max bigint;
	v_transfer_id bigint;
BEGIN
	--on verifie que le montant du virement soit bien positif et non nul
	IF p_montant <= 0.00 THEN 
		RAISE EXCEPTION 'Le montant ne doit être ni négatif ni nul';
	END IF;

	--on verifie que les 2 comptes soit bien distincts
	IF p_compte_emetteur = p_compte_destinataire THEN
		RAISE EXCEPTION 'Les comptes de destinatire et d''émetteur doivent être différents';
	END IF;

	--on cherche le plus grand compte pour éviter les deadlocks qui permet de ne pas avoir 2 transactions en meme temps
	IF p_compte_emetteur > p_compte_destinataire THEN
		id_min := p_compte_destinataire;
		id_max := p_compte_emetteur;
	ELSE 
		id_min := p_compte_emetteur;
		id_max := p_compte_destinataire;
	END IF;

	--perform permet d'exécuter la requete en en rejetant le resultat et for update pos un verrou pour dire celle ci en premier ou celle ci
	PERFORM 1 FROM core.accounts WHERE account_id = id_min FOR UPDATE;
 	PERFORM 1 FROM core.accounts WHERE account_id = id_max FOR UPDATE;

	--on enregistre le virement et on récupère son numéro dans v_transfer_id pour le mettre dans les 2 écritures
	INSERT INTO core.transfers (from_account_id,to_account_id,amount) VALUES (p_compte_emetteur,p_compte_destinataire,p_montant) RETURNING transfer_id INTO v_transfer_id;

	--les 2 écritures du virement, le trigger met les soldes à jour et si le solde passe sous 0 tout est annulé (virement compris)
	INSERT INTO core.transactions (account_id,tx_type,amount,transfer_id) VALUES (p_compte_emetteur,'virement_sortant',p_montant,v_transfer_id) ;
	INSERT INTO core.transactions (account_id,tx_type,amount,transfer_id) VALUES (p_compte_destinataire,'virement_entrant',p_montant,v_transfer_id) ;
END;$$;

---------------------------------------------------------------

--création d'une procédure pour ouvrir un compte
CREATE PROCEDURE ouverture_compte(p_account_type varchar(100), p_customer_id bigint, p_montant_premier_depot numeric)
LANGUAGE plpgsql
AS $$
DECLARE
	new_account_id bigint;
	nb_comptes integer;
BEGIN
	--on verifie que le montant du premier depot est inferieur a 0,s'il l'est on leve une erreur
	IF p_montant_premier_depot < 0.00 THEN
		RAISE EXCEPTION 'Le montant du premier dépôt ne peut pas être négatif';
	END IF;

	--on compte les comptes du client pour fabriquer l'iban avec la même formule que dans 03_donnees.sql (customer_id * 10 + numero du compte)
	SELECT count(*) INTO nb_comptes FROM core.accounts WHERE customer_id = p_customer_id;

	--au dela de 9 comptes la formule donnerait l'iban d'un autre client
	IF nb_comptes >= 9 THEN
		RAISE EXCEPTION 'Ce client a déjà le nombre maximum de comptes (9)';
	END IF;

	--on créé un compte actif en renvoyant l'id du nouveau compte dans new_account_id pour l'instant avec 0.00€
	INSERT INTO core.accounts (account_type,customer_id,iban,balance,status) VALUES (p_account_type,p_customer_id,'FR76'||LPAD((p_customer_id * 10 + nb_comptes + 1)::text, 23, '0'),0.00,'actif') RETURNING account_id INTO new_account_id;

	--si le client fait un premier depot alors on l'écrit dans la table des transactions pour que ca se mette a jour via le trigger qui met a jour les soldes des comptes  
	IF p_montant_premier_depot > 0.00 THEN
		INSERT INTO core.transactions (account_id,tx_type,amount) VALUES (new_account_id,'depot',p_montant_premier_depot) ;

	END IF;
END;$$;

---------------------------------------------------------------

--création d'une procédure de relevé de compte
CREATE PROCEDURE releve_compte(p_account_id bigint, p_date_debut date,p_date_fin date)
LANGUAGE plpgsql
AS $$
	DECLARE
	solde_depart numeric;
	solde_final numeric;
	i record;
BEGIN
	--on verifie que la date de début est antérieure a celle de fin
	IF p_date_debut > p_date_fin THEN
		RAISE EXCEPTION 'La date de debut doit être antérieure à la date de fin';
	END IF;
	
--on calcule le solde de départ à p_date_debut et on met coalesce pour éviter les NULL en cas de nouveau compte sans transaction
	SELECT COALESCE(SUM(amount) FILTER(WHERE tx_type IN ('virement_entrant','depot')),0.00) - COALESCE(SUM(amount) FILTER(WHERE tx_type IN ('virement_sortant','retrait')),0.00) INTO solde_depart FROM core.transactions WHERE p_account_id = account_id and created_at < p_date_debut;

	--on définit solde_final à solde_départ au cas ou y'a aucune transaction puis on l'incrémente à chaque transaction
	solde_final := solde_depart;

	--on affiche le solde au debut de la periode
	RAISE NOTICE 'Solde au % : %', p_date_debut, solde_depart;

	--on boucle sur chaque résultat de la requete ci-dessous qui cherche toutes les transactions entre les dates voulues triées par date
	--< p_date_fin + 1 et pas BETWEEN car une date seule vaut minuit, BETWEEN oublierait donc toute la journée de fin
	FOR i in
		SELECT * FROM core.transactions WHERE created_at >= p_date_debut AND created_at < p_date_fin + 1 AND p_account_id = account_id ORDER BY created_at
	LOOP
		--annoncer chaque transaction
		RAISE NOTICE 'Transaction du %, Montant : %, Type: %', i.created_at, i.amount,i.tx_type;
		--calculer solde final
		IF i.tx_type = 'depot' OR i.tx_type = 'virement_entrant' THEN
			solde_final := solde_final + i.amount;
		ELSIF i.tx_type = 'retrait' OR i.tx_type = 'virement_sortant' THEN
			solde_final := solde_final - i.amount;
		END IF;
	END LOOP;

	--on affiche le solde a la fin de la periode
	RAISE NOTICE 'Solde au % : %', p_date_fin, solde_final;
	RETURN;
END;$$;
