--création des tables s'ils elles n'existent pas déjà
CREATE TABLE IF NOT EXISTS core.customers (
customer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
first_name  varchar(100) NOT NULL,
last_name varchar(100) NOT NULL,
email varchar(100) UNIQUE NOT NULL CONSTRAINT chk_email_valide CHECK (email ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'),
phone varchar(100),
birth_date date NOT NULL CONSTRAINT chk_age_valide CHECK (EXTRACT(YEAR FROM age(current_date, birth_date)) >= 18),
kyc_status text,
risk_level text,
created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core.accounts (
account_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY ,
customer_id bigint NOT NULL references core.customers(customer_id),
iban VARCHAR(34) UNIQUE NOT NULL,
account_type varchar(100),
balance numeric(11,2) DEFAULT 0.00 NOT NULL CONSTRAINT chk_balance_valide  CHECK (balance >= 0),
status text,
opened_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core.transfers (
transfer_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
from_account_id bigint NOT NULL references core.accounts(account_id),
to_account_id bigint NOT NULL references core.accounts(account_id),
amount numeric(11,2) CONSTRAINT chk_amount_valide  CHECK (amount > 0) NOT NULL,
label text,
created_at timestamptz NOT NULL DEFAULT now(),
CONSTRAINT chk_different_account CHECK (from_account_id <> to_account_id) 
);

CREATE TABLE IF NOT EXISTS core.transactions (
tx_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
account_id bigint NOT NULL references core.accounts(account_id),
tx_type text NOT NULL CONSTRAINT chk_tx_type check (tx_type in ('depot','retrait','virement_entrant','virement_sortant')),
amount numeric(11,2) NOT NULL CONSTRAINT chk_tx_amount_valide CHECK (amount > 0),
balance_after numeric(11,2) NOT NULL CONSTRAINT chk_balance_after_valide CHECK (balance_after >= 0),
transfer_id bigint references core.transfers(transfer_id),
created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS core.fraud_alerts (
alert_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
account_id bigint NOT NULL references core.accounts(account_id),
tx_id bigint references core.transactions(tx_id),
rule_code text NOT NULL CONSTRAINT chk_rule_code check (rule_code in ('retrait5000ouplus','5transfers10min')),
status text NOT NULL DEFAULT 'nouvelle' CONSTRAINT chk_status check (status in ('nouvelle','en_attente', 'fermee')),
created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audit.audit_log (
log_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
table_name text NOT NULL ,
operation text NOT NULL CONSTRAINT chk_operation check (operation in ('INSERT','DELETE','UPDATE')),
old_data jsonb,
new_data jsonb,
db_user text NOT NULL DEFAULT current_user,
changed_at timestamptz NOT NULL DEFAULT now()
);
