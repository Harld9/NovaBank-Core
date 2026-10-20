--Création des index
CREATE INDEX idx_transactions_historique ON core.transactions(account_id);
CREATE INDEX idx_comptes_client ON core.accounts(customer_id) ;
CREATE INDEX idx_virements_compte ON core.transfers(from_account_id);
CREATE INDEX idx_transactions_date ON core.transactions(created_at);
