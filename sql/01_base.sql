--suppression de la db si elle existe déjà
DROP DATABASE IF EXISTS novabank;

--suppression du role de patron s'il existe deja
DROP ROLE IF EXISTS patron_novabank;

--création du role de patron (proprietaire de la db)
CREATE ROLE patron_novabank LOGIN;

--reconstruction de la db  
CREATE DATABASE novabank OWNER patron_novabank;

--connection à la db
\c novabank

--cretion schema core, audit
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS audit;
