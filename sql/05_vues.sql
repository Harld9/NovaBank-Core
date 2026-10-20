--creation de la vue qui n'affiche pas l'entiereté des infos sensibles des **** a la place du contenu sensible
CREATE VIEW v_support AS SELECT first_name, last_name, LEFT(SPLIT_PART(email, '@', 1),1) || '*****@' || SPLIT_PART(email, '@', 2) as email,LEFT(phone,2) ||'********'|| RIGHT(phone,2) as phone FROM core.customers;

--creation de la vue qui ne permet pas de modifier des comptes inactifs
CREATE VIEW v_comptes_actifs AS SELECT * FROM core.accounts WHERE status = 'actif' WITH CHECK OPTION;

--creation de la vue qui affiche la somme d'argent sur les comptes
CREATE MATERIALIZED VIEW mv_somme_soldes AS SELECT account_type, SUM(balance) AS totalargent FROM core.accounts GROUP BY account_type;

--on donne l'accès au support sur la vue
GRANT SELECT ON v_support TO support;
GRANT SELECT,INSERT,UPDATE ON v_comptes_actifs TO appli;
GRANT SELECT ON mv_somme_soldes TO auditeur,analyst;
