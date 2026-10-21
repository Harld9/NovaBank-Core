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

--insertions de 2500 transactions
INSERT INTO core.transactions(account_id, tx_type, amount, balance_after,created_at) SELECT random(1,20000) as account_id, (ARRAY['depot','retrait'])[random(1,2)] as tx_type, random(0.01 , 9999.99) as amount , random(0.01 , 9999.99) as balance_after, NOW() - (RANDOM() * 5000) * INTERVAL '1 day' as created_at FROM generate_series(1,1000000) as n ;

--insertion d'argent dans les comptes
UPDATE core.accounts SET balance = random(0.00,100000.0) 
