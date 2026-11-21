-- Least-privilege application role: DML on the benchmark tables, nothing else.
-- Tables are recreated by every reset, so default privileges cover new ones.
CREATE ROLE tb_app LOGIN PASSWORD 'tb_app';
GRANT CONNECT ON DATABASE ticketbench TO tb_app;
GRANT USAGE ON SCHEMA public TO tb_app;
ALTER DEFAULT PRIVILEGES FOR ROLE ticketbench IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO tb_app;
