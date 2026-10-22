--on enleve a tout le monde le droit de se connecter
REVOKE CONNECT ON DATABASE novabank FROM PUBLIC;

--on supprime les roles s'ils existent deja
DROP ROLE if exists analyst;
DROP ROLE if exists support ;
DROP ROLE if exists appli ;
DROP ROLE if exists auditeur ;
DROP ROLE if exists employe_analyst;
DROP ROLE if exists employe_support;
DROP ROLE if exists employe_appli;
DROP ROLE if exists employe_auditeur;

--puis on les recréé
CREATE ROLE analyst NOLOGIN;
CREATE ROLE support NOLOGIN;
CREATE ROLE appli NOLOGIN;
CREATE ROLE auditeur NOLOGIN;
CREATE ROLE employe_analyst LOGIN;
CREATE ROLE employe_support LOGIN;
CREATE ROLE employe_appli LOGIN;
CREATE ROLE employe_auditeur LOGIN;

--on met les roles dans les groupes
GRANT analyst TO employe_analyst;
GRANT support TO employe_support;
GRANT appli TO employe_appli;
GRANT auditeur TO employe_auditeur;

-- on donne les droits du patron
GRANT ALL PRIVILEGES ON DATABASE novabank TO patron_novabank;
GRANT ALL PRIVILEGES ON SCHEMA core, audit TO patron_novabank;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA core, audit TO patron_novabank;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA core, audit TO patron_novabank;

--on donne le droit de se connecter aux seuls comptes souhaités
GRANT CONNECT ON DATABASE novabank TO analyst,support,appli,auditeur;

--on donne les droits d'accès aux schéma aux seuls comptes souhaités
GRANT USAGE ON SCHEMA core TO analyst,support,appli;
GRANT USAGE ON SCHEMA audit TO auditeur;

--droits donnés spécifique donné à l'analyst
GRANT SELECT ON core.transactions,core.accounts TO analyst;
GRANT SELECT (customer_id,birth_date) ON core.customers TO analyst;

--droits donnés spécifique donné au support
--le support ne lit pas toute la table clients sinon il voit les emails en clair, il passe par la vue v_support
GRANT SELECT ON core.accounts TO support;
--il a juste besoin de customer_id pour savoir quel client il modifie (WHERE customer_id = ...)
GRANT SELECT (customer_id) ON core.customers TO support;
GRANT UPDATE (phone,email) ON core.customers TO support;

--droits donnés spécifique donné à l'appli
GRANT SELECT,INSERT ON core.accounts ,core.transfers , core.transactions,core.customers TO appli;
GRANT UPDATE (balance) ON core.accounts TO appli;

--droits donnés spécifique donné à l'auditeur
GRANT SELECT ON audit.audit_log TO auditeur;

--on coupe automatiquement les requêtes de l'analyste qui durent plus de 30 secondes pour qu'il ne ralentisse pas toute la base
--on le met sur employe_analyst car ce réglage s'applique au compte qui se connecte et ne passe pas par le groupe
ALTER ROLE employe_analyst SET statement_timeout = '30s';
