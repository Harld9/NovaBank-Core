--suppression de la db si elle existe déjà
DROP DATABASE IF EXISTS novabank;

--reconstruction de la db  
CREATE DATABASE novabank;

--connection à la db
\c novabank

--cretion schema core, audit
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS audit;
