--fichier de tests à lancer après script.sh depuis le dossier du projet : sudo -u postgres psql -d novabank < sql/tests.sql
--chaque test dit ce qu'on attend : OK (la commande doit marcher) ou REFUS (la commande doit afficher une ERROR)
--psql continue après une erreur donc les ERROR des tests REFUS sont normales, c'est la preuve que l'interdit est bloqué

\echo '========== ETAPE 2 : LES TABLES ET LES DONNEES =========='

\echo '--- OK : 1 000 000 d''ecritures, 100 000 virements, 10 000 clients, 20 000 comptes'
SELECT (SELECT count(*) FROM core.transactions) AS ecritures, (SELECT count(*) FROM core.transfers) AS virements, (SELECT count(*) FROM core.customers) AS clients, (SELECT count(*) FROM core.accounts) AS comptes;

\echo '--- REFUS : email invalide'
INSERT INTO core.customers (first_name, last_name, email, birth_date) VALUES ('Test', 'Email', 'pas-un-email', '1990-01-01');

\echo '--- REFUS : email deja utilise'
INSERT INTO core.customers (first_name, last_name, email, birth_date) VALUES ('Test', 'Doublon', 'client1@novabank.com', '1990-01-01');

\echo '--- REFUS : client mineur'
INSERT INTO core.customers (first_name, last_name, email, birth_date) VALUES ('Test', 'Mineur', 'mineur@novabank.com', '2015-01-01');

\echo '--- REFUS : solde negatif'
UPDATE core.accounts SET balance = -1 WHERE account_id = 1;

\echo '--- REFUS : virement d''un montant negatif'
INSERT INTO core.transfers (from_account_id, to_account_id, amount) VALUES (1, 2, -10);

\echo '--- REFUS : virement vers le meme compte'
INSERT INTO core.transfers (from_account_id, to_account_id, amount) VALUES (1, 1, 10);


\echo '========== ETAPE 3 : LES DROITS =========='

SET ROLE employe_analyst;
\echo '--- OK : l''analyste lit les ecritures'
SELECT count(*) AS ecritures FROM core.transactions;
\echo '--- REFUS : l''analyste lit les emails'
SELECT email FROM core.customers LIMIT 1;
RESET ROLE;

SET ROLE employe_support;
\echo '--- REFUS : le support lit les emails en clair'
SELECT email FROM core.customers LIMIT 1;
\echo '--- OK : le support modifie un telephone'
UPDATE core.customers SET phone = '0600000000' WHERE customer_id = 1;
\echo '--- REFUS : le support modifie un solde'
UPDATE core.accounts SET balance = 0 WHERE account_id = 1;
RESET ROLE;

SET ROLE employe_appli;
\echo '--- REFUS : l''appli supprime un client'
DELETE FROM core.customers WHERE customer_id = 1;
\echo '--- REFUS : l''appli lit le journal d''audit'
SELECT * FROM audit.audit_log LIMIT 1;
RESET ROLE;

SET ROLE employe_auditeur;
\echo '--- OK : l''auditeur lit le journal d''audit'
SELECT count(*) AS lignes_audit FROM audit.audit_log;
\echo '--- REFUS : l''auditeur lit les clients'
SELECT * FROM core.customers LIMIT 1;
RESET ROLE;


\echo '========== ETAPE 4 : LES VUES =========='

SET ROLE employe_support;
\echo '--- OK : le support voit les emails et telephones masques'
SELECT * FROM v_support LIMIT 3;
RESET ROLE;

SET ROLE employe_appli;
\echo '--- REFUS : passer un compte en inactif a travers la vue des comptes actifs'
UPDATE v_comptes_actifs SET status = 'ferme' WHERE account_id = 1;
RESET ROLE;

\echo '--- OK : la vue materialisee donne le total par type de compte'
SELECT * FROM mv_somme_soldes;


\echo '========== ETAPE 5 : LES INDEX =========='

\echo '--- OK : les 4 index existent'
SELECT indexname FROM pg_indexes WHERE indexname LIKE 'idx_%';

\echo '--- OK : l''historique d''un compte utilise l''index (Index Scan ou Bitmap Index Scan et pas Seq Scan)'
EXPLAIN ANALYZE SELECT * FROM core.transactions WHERE account_id = 42;


\echo '========== ETAPE 6 : LES TRIGGERS =========='

\echo '--- OK : un depot de 100 met le solde a jour tout seul (balance_after = balance)'
INSERT INTO core.transactions (account_id, tx_type, amount) VALUES (3, 'depot', 100);
SELECT core.transactions.balance_after, core.accounts.balance FROM core.transactions JOIN core.accounts ON core.accounts.account_id = core.transactions.account_id WHERE core.transactions.account_id = 3 ORDER BY tx_id DESC LIMIT 1;

\echo '--- REFUS : retrait plus grand que le solde'
INSERT INTO core.transactions (account_id, tx_type, amount) VALUES (3, 'retrait', 999999999);

\echo '--- REFUS : modifier le passe'
UPDATE core.transactions SET amount = 1 WHERE tx_id = 1;

\echo '--- REFUS : supprimer le passe'
DELETE FROM core.transactions WHERE tx_id = 1;

\echo '--- OK : un retrait de 6000 cree une alerte retrait5000ouplus'
INSERT INTO core.transactions (account_id, tx_type, amount) VALUES (7, 'depot', 10000);
INSERT INTO core.transactions (account_id, tx_type, amount) VALUES (7, 'retrait', 6000);
SELECT account_id, rule_code, status FROM core.fraud_alerts WHERE account_id = 7;

\echo '--- OK : 5 virements en 10 minutes creent une alerte 5transfers10min'
CALL virement_securise(5, 6, 10);
CALL virement_securise(5, 6, 10);
CALL virement_securise(5, 6, 10);
CALL virement_securise(5, 6, 10);
CALL virement_securise(5, 6, 10);
SELECT account_id, rule_code, status FROM core.fraud_alerts WHERE account_id = 5;

\echo '--- OK : le changement de telephone fait par le support est note dans l''audit'
\echo '    (db_user = postgres car ce fichier se connecte en postgres puis fait SET ROLE, en se connectant vraiment en employe_support on verrait employe_support)'
SELECT table_name, operation, old_data->>'phone' AS avant, new_data->>'phone' AS apres, db_user FROM audit.audit_log WHERE table_name = 'customers';


\echo '========== ETAPE 7 : LES PROCEDURES =========='

\echo '--- OK : virement de 50 du compte 1 vers le compte 2, 1 virement et 2 ecritures avec le meme transfer_id'
CALL virement_securise(1, 2, 50);
SELECT account_id, tx_type, amount, balance_after, transfer_id FROM core.transactions ORDER BY tx_id DESC LIMIT 2;

\echo '--- REFUS : virement plus grand que le solde, et le nombre de virements ne doit pas changer (tout ou rien)'
SELECT count(*) AS virements_avant FROM core.transfers;
CALL virement_securise(1, 2, 999999999);
SELECT count(*) AS virements_apres FROM core.transfers;

\echo '--- REFUS : virement vers le meme compte'
CALL virement_securise(1, 1, 10);

\echo '--- OK : ouverture d''un compte avec un premier depot de 500 (iban, statut actif, solde 500)'
CALL ouverture_compte('epargne', 10, 500);
SELECT account_id, customer_id, iban, balance, status FROM core.accounts ORDER BY account_id DESC LIMIT 1;

\echo '--- OK : releve du compte 1 sur l''annee (solde de depart, ecritures, solde final)'
CALL releve_compte(1, '2026-01-01', '2026-12-31');

\echo '========== FIN DES TESTS =========='
