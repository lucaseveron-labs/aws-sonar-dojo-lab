-- Crear usuarios si no existen
SELECT 'CREATE ROLE sonar_user LOGIN PASSWORD ''SonarStrongPassword'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'sonar_user')
\gexec

SELECT 'CREATE ROLE dojo_user LOGIN PASSWORD ''DojoStrongPassword'''
WHERE NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'dojo_user')
\gexec


-- Crear bases si no existen
SELECT 'CREATE DATABASE sonarqube'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'sonarqube')
\gexec

SELECT 'CREATE DATABASE defectdojo'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'defectdojo')
\gexec


-- Asignar propietarios (esto sí funciona en RDS)
ALTER DATABASE sonarqube OWNER TO sonar_user;
ALTER DATABASE defectdojo OWNER TO dojo_user;


-- Configuración recomendada de roles
ALTER ROLE sonar_user SET client_encoding TO 'utf8';
ALTER ROLE sonar_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE sonar_user SET timezone TO 'UTC';

ALTER ROLE dojo_user SET client_encoding TO 'utf8';
ALTER ROLE dojo_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE dojo_user SET timezone TO 'UTC';
