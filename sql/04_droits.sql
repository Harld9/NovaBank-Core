--on enleve a tout le monde le droit de se connecter
REVOKE CONNECT ON DATABASE novabank FROM PUBLIC;

--on supprime les roles s'ils existent deja
DROP ROLE if exists analyst;
DROP ROLE if exists support ;
DROP ROLE if exists appli ;
DROP ROLE if exists auditeur ;

--puis on les recréé
CREATE ROLE analyst LOGIN;
CREATE ROLE support LOGIN;
CREATE ROLE appli LOGIN;
CREATE ROLE auditeur LOGIN;

--on donne le droit de se connecter aux seuls comptes souhaités
GRANT CONNECT ON DATABASE novabank TO analyst,support,appli,auditeur;

--on donne les droits d'accès aux schéma aux seuls comptes souhaités
GRANT USAGE ON SCHEMA core TO analyst,support,appli;
GRANT USAGE ON SCHEMA audit TO auditeur;

--Droits donnés spécifique donné à l'analyst
GRANT SELECT ON core.transactions,core.accounts TO analyst; 
GRANT SELECT (customer_id,birth_date) ON core.customers TO analyst;

--Droits donnés spécifique donné au support
GRANT SELECT ON core.accounts,core.customers TO support;
GRANT UPDATE (phone,email) ON core.customers TO support;

--Droits donnés spécifique donné à l'appli
GRANT SELECT,INSERT ON core.accounts ,core.transfers , core.transactions,core.customers TO appli;
GRANT UPDATE (balance) ON core.accounts TO appli;

--Droits donnés spécifique donné à l'auditeur
GRANT SELECT ON audit.audit_log TO auditeur;
