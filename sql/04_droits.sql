--on enleve a tout le monde le droit de se connecter
REVOKE CONNECT ON DATABASE novabank FROM PUBLIC;

--on supprime les roles s'ils existent deja
DROP ROLE if exists analyst;
DROP ROLE if exists support ;
DROP ROLE if exists appli ;
DROP ROLE if exists auditeur ;
DROP ROLE if exists harold_analyst;
DROP ROLE if exists harold_support;
DROP ROLE if exists harold_appli;
DROP ROLE if exists harold_auditeur;

--puis on les recréé
CREATE ROLE analyst NOLOGIN;
CREATE ROLE support NOLOGIN;
CREATE ROLE appli NOLOGIN;
CREATE ROLE auditeur NOLOGIN;
CREATE ROLE harold_analyst LOGIN;
CREATE ROLE harold_support LOGIN;
CREATE ROLE harold_appli LOGIN;
CREATE ROLE harold_auditeur LOGIN;

--on met les roles dans les groupes
GRANT analyst TO harold_analyst;
GRANT support TO harold_support;
GRANT appli TO harold_appli;
GRANT auditeur TO harold_auditeur;

--on donne le droit de se connecter aux seuls comptes souhaités
GRANT CONNECT ON DATABASE novabank TO analyst,support,appli,auditeur;

--on donne les droits d'accès aux schéma aux seuls comptes souhaités
GRANT USAGE ON SCHEMA core TO analyst,support,appli;
GRANT USAGE ON SCHEMA audit TO auditeur;

--droits donnés spécifique donné à l'analyst
GRANT SELECT ON core.transactions,core.accounts TO analyst;
GRANT SELECT (customer_id,birth_date) ON core.customers TO analyst;

--droits donnés spécifique donné au support
GRANT SELECT ON core.accounts,core.customers TO support;
GRANT UPDATE (phone,email) ON core.customers TO support;

--droits donnés spécifique donné à l'appli
GRANT SELECT,INSERT ON core.accounts ,core.transfers , core.transactions,core.customers TO appli;
GRANT UPDATE (balance) ON core.accounts TO appli;

--droits donnés spécifique donné à l'auditeur
GRANT SELECT ON audit.audit_log TO auditeur;
