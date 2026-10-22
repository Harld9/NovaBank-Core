-- insertion de 10000 clients
INSERT INTO core.customers
    (first_name, last_name, email, phone, birth_date, kyc_status, risk_level)
SELECT
    (ARRAY['Alice','Mehdi','Sarah','Lucas','Emma'])[random(1,5)] AS first_name,
    (ARRAY['Martin','Bernard','Dubois','Thomas','Petit'])[random(1,5)] AS last_name,
    'client'||n||'@novabank.com' AS email,
    '0'||n AS phone,
    current_date - 19*365 - random(0,20000) AS birth_date,
    'en_attente',
    '0'
FROM generate_series(1,10000) AS n;

-- insertions de 2 comptes par clients soit 20000
INSERT INTO core.accounts (customer_id, iban, account_type, status) SELECT customer_id, 'FR76'||LPAD((customer_id * 10 + k)::text, 23, '0') as IBAN, (ARRAY['courant','epargne'])[k] as account_type, 'actif' from core.customers CROSS JOIN generate_series(1,2) as k;

--insertions de 100000 virements, l'emetteur est pris dans les comptes 1 à 10000 et le destinataire dans les comptes 10001 à 20000 donc ce n'est jamais le même compte
INSERT INTO core.transfers(from_account_id, to_account_id, amount, label, created_at) SELECT random(1,10000) as from_account_id, random(10001,20000) as to_account_id, random(0.01 , 999.99) as amount, (ARRAY['loyer','courses','remboursement'])[random(1,3)] as label, NOW() - (RANDOM() * 5000) * INTERVAL '1 day' as created_at FROM generate_series(1,100000) as n ;

--un virement = 2 écritures : une sortante pour l'emetteur et une entrante pour le destinataire, avec le même transfer_id et la même date
INSERT INTO core.transactions(account_id, tx_type, amount, balance_after, transfer_id, created_at) SELECT from_account_id, 'virement_sortant', amount, random(0.01 , 9999.99), transfer_id, created_at FROM core.transfers ;
INSERT INTO core.transactions(account_id, tx_type, amount, balance_after, transfer_id, created_at) SELECT to_account_id, 'virement_entrant', amount, random(0.01 , 9999.99), transfer_id, created_at FROM core.transfers ;

--insertions de 800000 depots et retraits pour arriver à 1 000 000 d'écritures avec les 200000 écritures des virements
INSERT INTO core.transactions(account_id, tx_type, amount, balance_after,created_at) SELECT random(1,20000) as account_id, (ARRAY['depot','retrait'])[random(1,2)] as tx_type, random(0.01 , 9999.99) as amount , random(0.01 , 9999.99) as balance_after, NOW() - (RANDOM() * 5000) * INTERVAL '1 day' as created_at FROM generate_series(1,800000) as n ;

--insertion d'argent dans les comptes
UPDATE core.accounts SET balance = random(0.00,100000.0) ;
