--création des tables s'ils elles n'existent pas déjà
CREATE TABLE IF NOT EXISTS core.customers (
customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
first_name  varchar(100),
last_name varchar(100),
email varchar(100),
phone varchar(100),
birth_date date,
kyc_status text,
risk_level text,
created_at timestamptz
);

CREATE TABLE IF NOT EXISTS core.accounts (
account_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY ,
customer_id bigint,
iban VARCHAR(34),
account_type varchar(100),
balance numeric(11,2),
status text,
opened_at timestamptz
);

CREATE TABLE IF NOT EXISTS core.transfers (
transfer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
from_account_id bigint,
to_account_id bigint,
amount numeric(11,2),
label text,
created_at timestamptz
);

CREATE TABLE IF NOT EXISTS core.transactions (
tx_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
account_id bigint,
tx_type text,
amount numeric(11,2),
balance_after numeric(11,2),
transfer_id bigint,
created_at timestamptz
);

CREATE TABLE IF NOT EXISTS core.fraud_alerts (
alert_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
account_id bigint,
tx_id bigint,
rule_code text,
status text,
created_at timestamptz
);

CREATE TABLE IF NOT EXISTS audit.audit_log (
log_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
table_name text,
operation text,
old_data jsonb,
new_data jsonb,
db_user text,
changed_at timestamptz
);
