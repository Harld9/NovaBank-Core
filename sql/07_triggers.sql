--on dit que tout ce qui va etre créé sera créé par le role patron_novabank pour qu'il soit proprietaire des fonctions (et pas postgres qui a tous les droits)
SET ROLE patron_novabank;

--creation d'une fonction trigger qui calcule le solde a chaque nouveaux depot/retrait/virement entrant ou sortant
CREATE FUNCTION update_solde_compte() RETURNS TRIGGER
language plpgsql
AS $$
BEGIN
	--check du type de transaction dans NEW.tx_type et en fonction du type ajoute ou retire le montant de la transaction au compte
	--RETURNING balance INTO NEW.balance_after : on récupère le nouveau solde et on le met dans l'écriture avant qu'elle soit enregistrée
	IF NEW.tx_type = 'depot' OR NEW.tx_type = 'virement_entrant' THEN
		UPDATE core.accounts SET balance = balance + NEW.amount WHERE account_id = NEW.account_id RETURNING balance INTO NEW.balance_after;
	ELSIF NEW.tx_type = 'retrait' OR NEW.tx_type = 'virement_sortant' THEN
		UPDATE core.accounts SET balance = balance - NEW.amount WHERE account_id = NEW.account_id RETURNING balance INTO NEW.balance_after;
	END IF;

	--si une fois le débit fait le montant du compte est en dessous de 0 alors on lève l'erreur et la transaction n'aura pas lieu
	IF NEW.balance_after < 0.00 THEN
		RAISE EXCEPTION 'Solde insuffisant pour effectuer ce retrait. Découvert non autorisé dans notre banque !';
	END IF;
--autorise l'écriture de la ligne (avec balance_after rempli) dans la table
RETURN NEW;
END;
$$;

--BEFORE et pas AFTER car il faut remplir NEW.balance_after avant que la ligne soit écrite
CREATE TRIGGER trg_update_solde_compte
BEFORE INSERT ON core.transactions
FOR EACH ROW
EXECUTE FUNCTION update_solde_compte();

------------------------------------------------------

--creation d'une fonction trigger qui protège et sécurise les modifications et suppression sur core.transactions
CREATE FUNCTION protection_historique() RETURNS TRIGGER
language plpgsql
AS $$
BEGIN
	IF TG_OP = 'UPDATE' THEN
		RAISE EXCEPTION 'Vous ne pouvez pas modifier l''historique des transactions, nos transactions sont immutables !';
	ELSIF TG_OP = 'DELETE' THEN
		RAISE EXCEPTION 'Vous ne pouvez pas supprimer l''historique des transactions, nos transactions sont immutables !';
	END IF;
RETURN NULL;
END;
$$;

CREATE TRIGGER trg_protection_historique
BEFORE UPDATE OR DELETE ON core.transactions
FOR EACH ROW
EXECUTE FUNCTION protection_historique();

------------------------------------------------------

--creation d'une fonction trigger qui écrit dans la table audit chaque modification (qui, quand, avant, après)
--SECURITY DEFINER : la fonction tourne avec les droits de son proprietaire patron_novabank car l'appli et le support n'ont pas le droit d'écrire dans audit
--SET search_path : sécurité pour qu'on ne puisse pas tromper la fonction avec une fausse table audit_log créée ailleurs
CREATE FUNCTION audit_changement() RETURNS TRIGGER
language plpgsql
SECURITY DEFINER
SET search_path = audit, pg_temp
AS $$
BEGIN
	--on note seulement si la ligne a vraiment changé
	IF OLD IS DISTINCT FROM NEW THEN
		--to_jsonb(OLD/NEW): convertit n'importe quelle valeur ou ligne de table entière en un format JSON
		--session_user : la personne vraiment connectée (current_user donnerait patron_novabank à cause de SECURITY DEFINER)
		INSERT INTO audit.audit_log (table_name,operation,old_data,new_data,db_user) VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD),to_jsonb(NEW),session_user);
	END IF;
RETURN NEW;
END;
$$;

--on note les changements sur les comptes (solde, statut) et sur les clients (email et téléphone modifiés par le support)
CREATE TRIGGER trg_audit_comptes
AFTER UPDATE ON core.accounts
FOR EACH ROW
EXECUTE FUNCTION audit_changement();

CREATE TRIGGER trg_audit_clients
AFTER UPDATE ON core.customers
FOR EACH ROW
EXECUTE FUNCTION audit_changement();

------------------------------------------------------

--creation d'une fonction trigger qui crée une alerte : retrait de 5000 ou plus, ou 5 virements en 10 minutes
--SECURITY DEFINER pour la même raison que l'audit : l'appli n'a pas le droit d'écrire dans core.fraud_alerts
CREATE FUNCTION detection_fraude() RETURNS TRIGGER
language plpgsql
SECURITY DEFINER
SET search_path = core, pg_temp
AS $$
DECLARE
	nb_virements integer;
BEGIN
	--regle 1 : un retrait de 5000 ou plus
	IF NEW.tx_type = 'retrait' AND NEW.amount >= 5000 THEN
		INSERT INTO core.fraud_alerts (account_id,tx_id,rule_code) VALUES (NEW.account_id, NEW.tx_id, 'retrait5000ouplus');
	END IF;

	--regle 2 : on compte les virements sortants du compte sur les 10 dernieres minutes (celui-ci compris car on est en AFTER)
	IF NEW.tx_type = 'virement_sortant' THEN
		SELECT count(*) INTO nb_virements FROM core.transactions WHERE account_id = NEW.account_id AND tx_type = 'virement_sortant' AND created_at > NOW() - INTERVAL '10 minutes';
		--= 5 et pas >= 5 pour créer une seule alerte au 5e virement et pas une nouvelle à chaque virement suivant
		IF nb_virements = 5 THEN
			INSERT INTO core.fraud_alerts (account_id,tx_id,rule_code) VALUES (NEW.account_id, NEW.tx_id, '5transfers10min');
		END IF;
	END IF;
RETURN NULL;
END;
$$;

--AFTER car l'écriture doit déjà exister (avec son tx_id) pour pouvoir y relier l'alerte
CREATE TRIGGER trg_detection_fraude
AFTER INSERT ON core.transactions
FOR EACH ROW
EXECUTE FUNCTION detection_fraude();
