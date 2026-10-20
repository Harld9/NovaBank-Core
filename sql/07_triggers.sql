--creation d'une fonction trigger qui calcule le solde a chaque nouveaux depot/retrait/virement entrant ou sortant
CREATE FUNCTION update_solde_compte() RETURNS TRIGGER
language plpgsql
AS $$
BEGIN
	--check du type de transaction dans NEW.tx_type et en fonction du type ajoute ou retire le montant de la transaction au compte
	IF NEW.tx_type = 'depot' OR NEW.tx_type = 'virement_entrant' THEN
		UPDATE core.accounts SET balance = balance + NEW.amount WHERE account_id = NEW.account_id;
	ELSIF NEW.tx_type = 'retrait' OR NEW.tx_type = 'virement_sortant' THEN
		UPDATE core.accounts SET balance = balance - NEW.amount WHERE account_id = NEW.account_id;
	END IF;

	--si une fois le débit fait le montant du compte est en dessous de 0 alors on lève l'erreur et la transaction n'aura pas lieu
	IF (SELECT balance FROM core.accounts WHERE account_id = NEW.account_id) < 0.00 THEN
		RAISE EXCEPTION 'Solde insuffisant pour effectuer ce retrait. Découvert non autorisé dans notre banque !';
	END IF;
--autorise la lecture définitive dans la table
RETURN NEW;
END;
$$;

CREATE TRIGGER trg_update_solde_compte
AFTER INSERT ON core.transactions
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

--creation d'une fonction trigger qui écrit dans la table audit les fraudes detectées
CREATE FUNCTION audit_fraude() RETURNS TRIGGER
language plpgsql
AS $$
BEGIN
	IF OLD.balance <> NEW.balance THEN
		--to_jsonb(OLD/NEW): convertit n'importe quelle valeur ou ligne de table entière en un format JSON
		INSERT INTO audit.audit_log (table_name,operation,old_data,new_data) VALUES (TG_TABLE_NAME, TG_OP, to_jsonb(OLD),to_jsonb(NEW));
	END IF;
RETURN NEW;
END;
$$;

CREATE TRIGGER trg_audit_fraude
AFTER UPDATE ON core.accounts
FOR EACH ROW
EXECUTE FUNCTION audit_fraude();
